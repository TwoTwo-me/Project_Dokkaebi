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

DOC_PATH="docs/operations/dispatch-lease-recovery.md"
for term in \
  "lease store" \
  "owner identity" \
  "retry persistence" \
  "recovery behavior" \
  "no duplicate dispatch after restart" \
  "live GitHub Project residual risks" \
  "lease token" \
  "idempotency key" \
  "stale lease"; do
  require_text "$DOC_PATH" "$term"
done

command -v python3 >/dev/null || fail "missing command: python3"

python3 - <<'PY'
from __future__ import annotations

import json
import re
import sys
import tempfile
from pathlib import Path
from typing import Any


OWNER_RE = re.compile(r"^fire-[a-z]+$")
TOKEN_RE = re.compile(r"^lease-token-[a-z0-9-]+$")
KEY_RE = re.compile(r"^dispatch-[a-z0-9-]+$")
RETRY_AT = "2026-06-13T13:45:00Z"


def fail(message: str) -> None:
    print(f"FAIL dispatch lease recovery simulation: {message}", file=sys.stderr)
    raise SystemExit(1)


def assert_equal(actual: Any, expected: Any, label: str) -> None:
    if actual != expected:
        fail(f"{label}; expected {expected!r}, got {actual!r}")


def validate(owner: str, key: str, token: str | None = None) -> str | None:
    if OWNER_RE.fullmatch(owner) is None:
        return "malformed-owner-identity"
    if token is not None and TOKEN_RE.fullmatch(token) is None:
        return "malformed-lease-token"
    if KEY_RE.fullmatch(key) is None:
        return "malformed-idempotency-key"
    return None


class Store:
    def __init__(self, root: Path) -> None:
        self.lease = root / "lease-store.json"
        self.log = root / "hammer-dispatch-log.json"
        self.retry = root / "retry-intent.json"

    def read(self, path: Path, default: Any) -> Any:
        if not path.exists():
            return default
        return json.loads(path.read_text(encoding="utf-8"))

    def write(self, path: Path, value: Any) -> None:
        path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    def acquire(self, ticket: str, owner: str, token: str, key: str) -> dict[str, Any]:
        invalid = validate(owner, key, token)
        if invalid:
            return {"status": "rejected", "reason": invalid}

        lease = self.read(self.lease, None)
        if lease:
            if lease["ticket"] != ticket:
                return {"status": "rejected", "reason": "ticket-mismatch"}
            if lease["state"] == "completed":
                return {"status": "rejected", "reason": "work-already-completed"}
            if lease["state"] == "active":
                return {
                    "status": "rejected",
                    "reason": "active-lease-present",
                    "owner": lease["owner"],
                }
            return {"status": "rejected", "reason": "unknown-lease-state"}

        lease = {
            "ticket": ticket,
            "state": "active",
            "owner": owner,
            "lease_token": token,
            "idempotency_key": key,
            "hammer_dispatch_state": "pending",
        }
        self.write(self.lease, lease)
        return {"status": "acquired", "lease": lease}

    def dispatch(self, ticket: str, owner: str, key: str) -> dict[str, Any]:
        invalid = validate(owner, key)
        if invalid:
            return {"status": "rejected", "reason": invalid}

        lease = self.read(self.lease, None)
        if lease is None:
            return {"status": "rejected", "reason": "no-active-lease"}
        if lease["state"] != "active":
            return {"status": "rejected", "reason": "work-already-completed"}
        if lease["ticket"] != ticket:
            return {"status": "rejected", "reason": "ticket-mismatch"}
        if lease["owner"] != owner or lease["idempotency_key"] != key:
            return {"status": "rejected", "reason": "lease-owner-or-key-mismatch"}

        log = self.read(self.log, [])
        if any(entry["idempotency_key"] == key for entry in log):
            return {"status": "rejected", "reason": "duplicate-idempotency-key"}

        entry = {
            "attempt_number": len(log) + 1,
            "ticket": ticket,
            "owner": owner,
            "idempotency_key": key,
            "worker": "Hammer",
        }
        log.append(entry)
        lease["hammer_dispatch_state"] = "dispatched"
        self.write(self.log, log)
        self.write(self.lease, lease)
        return {"status": "dispatched", "entry": entry}

    def remember_retry(self, ticket: str, key: str, reason: str) -> None:
        intents = self.read(self.retry, {})
        retry_count = int(intents.get(ticket, {}).get("retry_count", 0)) + 1
        intents[ticket] = {
            "idempotency_key": key,
            "next_retry_at": RETRY_AT,
            "reason": reason,
            "retry_count": retry_count,
        }
        self.write(self.retry, intents)

    def complete(self, ticket: str, key: str) -> dict[str, Any]:
        lease = self.read(self.lease, None)
        if lease is None:
            return {"status": "rejected", "reason": "no-active-lease"}
        if lease["state"] == "completed":
            return {"status": "rejected", "reason": "work-already-completed"}
        if lease["ticket"] != ticket:
            return {"status": "rejected", "reason": "ticket-mismatch"}
        if lease["idempotency_key"] != key:
            return {"status": "rejected", "reason": "idempotency-key-mismatch"}

        lease["state"] = "completed"
        lease["hammer_dispatch_state"] = "completed"
        self.write(self.lease, lease)
        intents = self.read(self.retry, {})
        intents.pop(ticket, None)
        self.write(self.retry, intents)
        return {"status": "completed"}

    def boot_and_dispatch(self, ticket: str, owner: str, token: str, key: str) -> dict[str, Any]:
        acquired = self.acquire(ticket, owner, token, key)
        dispatched = None
        if acquired["status"] == "acquired":
            dispatched = self.dispatch(ticket, owner, key)
        return {"acquisition": acquired, "dispatch": dispatched}

    def dispatch_count(self) -> int:
        return len(self.read(self.log, []))


with tempfile.TemporaryDirectory(prefix="dokkaebi-lease-recovery-") as tmp:
    root = Path(tmp)
    ticket = "ticket-dispatch-lease-recovery"
    key1 = "dispatch-ticket-001-attempt-001"
    token1 = "lease-token-ticket-001-attempt-001"

    first = Store(root)
    result = first.boot_and_dispatch(ticket, "fire-alpha", token1, key1)
    assert_equal(result["acquisition"]["status"], "acquired", "first Fire acquisition")
    assert_equal(result["dispatch"]["status"], "dispatched", "first Hammer dispatch")
    assert_equal(first.dispatch_count(), 1, "first dispatch count")

    first.remember_retry(ticket, key1, "hammer-result-packet-pending")

    restarted = Store(root)
    retry = restarted.read(restarted.retry, {}).get(ticket)
    assert_equal(
        retry,
        {
            "idempotency_key": key1,
            "next_retry_at": RETRY_AT,
            "reason": "hammer-result-packet-pending",
            "retry_count": 1,
        },
        "retry intent persisted across restart",
    )

    second = restarted.boot_and_dispatch(
        ticket,
        "fire-beta",
        "lease-token-ticket-001-attempt-002",
        "dispatch-ticket-001-attempt-002",
    )
    assert_equal(second["acquisition"]["reason"], "active-lease-present", "restart duplicate acquisition")
    assert_equal(second["dispatch"], None, "restart did not dispatch Hammer")
    assert_equal(restarted.dispatch_count(), 1, "dispatch count after restart")

    malformed = restarted.dispatch(ticket, "fire-alpha", "not a valid idempotency key")
    assert_equal(malformed["reason"], "malformed-idempotency-key", "malformed dispatch rejection")

    duplicate = restarted.dispatch(ticket, "fire-alpha", key1)
    assert_equal(duplicate["reason"], "duplicate-idempotency-key", "duplicate dispatch rejection")
    assert_equal(restarted.dispatch_count(), 1, "dispatch count after rejected attempts")

    completed = restarted.complete(ticket, key1)
    assert_equal(completed["status"], "completed", "lease completion")

    final = Store(root).boot_and_dispatch(
        ticket,
        "fire-gamma",
        "lease-token-ticket-001-attempt-003",
        "dispatch-ticket-001-attempt-003",
    )
    assert_equal(final["acquisition"]["reason"], "work-already-completed", "completion prevents re-dispatch")
    assert_equal(final["dispatch"], None, "completed work did not dispatch Hammer")
    assert_equal(Store(root).dispatch_count(), 1, "final dispatch count")

print("PASS Dokkaebi dispatch lease recovery validation passed")
PY
