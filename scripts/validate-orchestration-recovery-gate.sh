#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}

require_text() {
  local path="$1"
  local needle="$2"
  [[ -f "$path" ]] || fail "missing file: $path"
  grep -Fqi -- "$needle" "$path" || fail "missing text in $path: $needle"
}

DOC_PATH="docs/operations/orchestration-recovery-gate.md"
for term in \
  "worker failure" \
  "Fire restarts" \
  "stale lease recovery" \
  "retry intent" \
  "route result handling" \
  "closeout" \
  "Duplicate dispatch" \
  "Retry loss after restart" \
  "Live GitHub Project Boundary"; do
  require_text "$DOC_PATH" "$term"
done

command -v python3 >/dev/null || fail "missing command: python3"

python3 - <<'PY'
from __future__ import annotations

import json
import sys
import tempfile
from pathlib import Path
from typing import Any


def fail(message: str) -> None:
    print(f"FAIL orchestration recovery gate: {message}", file=sys.stderr)
    raise SystemExit(1)


def assert_equal(actual: Any, expected: Any, label: str) -> None:
    if actual != expected:
        fail(f"{label}; expected {expected!r}, got {actual!r}")


class GateStore:
    def __init__(self, root: Path) -> None:
        root.mkdir(parents=True, exist_ok=True)
        self.lease = root / "lease.json"
        self.dispatches = root / "dispatches.json"
        self.results = root / "route-results.json"
        self.retries = root / "retries.json"
        self.closeouts = root / "closeouts.json"

    def read(self, path: Path, default: Any) -> Any:
        if not path.exists():
            return default
        return json.loads(path.read_text(encoding="utf-8"))

    def write(self, path: Path, value: Any) -> None:
        path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    def acquire(self, owner: str, token: str, key: str, now: int, expires: int) -> dict[str, Any]:
        lease = self.read(self.lease, None)
        if lease and lease["state"] == "completed":
            return {"status": "rejected", "reason": "work-already-completed"}
        if lease and lease["state"] == "active" and now < lease["lease_expires_at"]:
            return {"status": "rejected", "reason": "lease-not-expired"}
        if lease and lease["state"] == "active" and now >= lease["lease_expires_at"]:
            recovered_from = lease["lease_token"]
        else:
            recovered_from = None

        next_attempt = int(lease.get("attempt", 0)) + 1 if lease else 1
        new_lease = {
            "attempt": next_attempt,
            "idempotency_key": key,
            "lease_expires_at": expires,
            "lease_token": token,
            "owner": owner,
            "recovered_from": recovered_from,
            "state": "active",
        }
        self.write(self.lease, new_lease)
        status = "recovered" if recovered_from else "acquired"
        return {"status": status, "lease": new_lease}

    def dispatch(self, route: str, key: str) -> dict[str, Any]:
        lease = self.read(self.lease, None)
        if not lease or lease["state"] != "active":
            return {"status": "rejected", "reason": "no-active-lease"}
        if lease["idempotency_key"] != key:
            return {"status": "rejected", "reason": "idempotency-key-mismatch"}

        log = self.read(self.dispatches, [])
        if any(entry["idempotency_key"] == key for entry in log):
            return {"status": "rejected", "reason": "duplicate-dispatch"}
        log.append({"attempt": lease["attempt"], "idempotency_key": key, "route": route})
        self.write(self.dispatches, log)
        return {"status": "dispatched"}

    def worker_failed(self, key: str, reason: str, next_retry_at: int) -> None:
        retries = self.read(self.retries, {})
        prior = retries.get(key, {})
        retries[key] = {
            "failure_reason": reason,
            "next_retry_at": next_retry_at,
            "retry_count": int(prior.get("retry_count", 0)) + 1,
        }
        self.write(self.retries, retries)

    def resume_after_restart(self, key: str) -> dict[str, Any]:
        retries = self.read(self.retries, {})
        if key not in retries:
            return {"status": "rejected", "reason": "retry-intent-missing"}
        return {"status": "waiting", "retry": retries[key]}

    def record_route_result(self, key: str, result_packet: str, validation: str) -> dict[str, Any]:
        results = self.read(self.results, {})
        results[key] = {
            "result_packet": result_packet,
            "validation": validation,
        }
        self.write(self.results, results)
        return {"status": "recorded"}

    def closeout(self, key: str, manager_review: str) -> dict[str, Any]:
        results = self.read(self.results, {})
        if key not in results:
            return {"status": "rejected", "reason": "result-evidence-missing"}
        lease = self.read(self.lease, None)
        if not lease or lease["idempotency_key"] != key:
            return {"status": "rejected", "reason": "lease-evidence-missing"}
        lease["state"] = "completed"
        self.write(self.lease, lease)
        closeouts = self.read(self.closeouts, {})
        closeouts[key] = {
            "manager_review": manager_review,
            "result_packet": results[key]["result_packet"],
        }
        self.write(self.closeouts, closeouts)
        return {"status": "closed"}

    def dispatch_count(self) -> int:
        return len(self.read(self.dispatches, []))


with tempfile.TemporaryDirectory(prefix="dokkaebi-orchestration-recovery-") as tmp:
    root = Path(tmp)
    store = GateStore(root)

    first_key = "dispatch-ticket-42-attempt-1"
    first = store.acquire("fire-alpha", "lease-token-ticket-42-1", first_key, now=0, expires=10)
    assert_equal(first["status"], "acquired", "initial lease")
    assert_equal(store.dispatch("local_worktree", first_key)["status"], "dispatched", "first dispatch")
    assert_equal(store.dispatch("local_worktree", first_key)["reason"], "duplicate-dispatch", "duplicate dispatch rejected")

    store.worker_failed(first_key, "hammer-process-exited", next_retry_at=15)
    restarted = GateStore(root)
    resume = restarted.resume_after_restart(first_key)
    assert_equal(resume["status"], "waiting", "retry persisted after restart")
    assert_equal(resume["retry"]["retry_count"], 1, "retry count persisted")

    early = restarted.acquire("fire-beta", "lease-token-ticket-42-2", "dispatch-ticket-42-attempt-2", now=5, expires=20)
    assert_equal(early["reason"], "lease-not-expired", "early stale lease recovery rejected")

    recovered_key = "dispatch-ticket-42-attempt-2"
    recovered = restarted.acquire("fire-beta", "lease-token-ticket-42-2", recovered_key, now=11, expires=20)
    assert_equal(recovered["status"], "recovered", "stale lease recovered after expiry")
    assert_equal(restarted.dispatch("local_worktree", recovered_key)["status"], "dispatched", "recovered dispatch")
    assert_equal(restarted.closeout(recovered_key, "manager-review-before-result")["reason"], "result-evidence-missing", "closeout without result rejected")

    result = restarted.record_route_result(
        recovered_key,
        "result-packets/ticket-42-attempt-2.md",
        "validation passed",
    )
    assert_equal(result["status"], "recorded", "route result recorded")
    assert_equal(restarted.closeout(recovered_key, "manager-review-approved")["status"], "closed", "manager closeout")
    assert_equal(restarted.dispatch_count(), 2, "two dispatches across original and recovered attempts")

    retry_loss = GateStore(Path(tmp) / "retry-loss")
    retry_loss.acquire("fire-gamma", "lease-token-ticket-42-3", "dispatch-ticket-42-attempt-3", now=0, expires=10)
    assert_equal(
        retry_loss.resume_after_restart("dispatch-ticket-42-attempt-3")["reason"],
        "retry-intent-missing",
        "retry loss rejected",
    )

print("PASS Dokkaebi orchestration recovery gate validation passed")
PY
