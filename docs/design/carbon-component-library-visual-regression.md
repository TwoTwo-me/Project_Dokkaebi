# Carbon Component Library And Visual Regression Gate

This artifact closes issue #67 for reusable Carbon component inventory and CI
visual regression evidence. It uses the existing Symphony observability
dashboard proof as the first first-party UI surface and turns that proof into a
repository-level component-library and visual regression gate.

Permission level: docs-only, local UI validation, and CI artifact validation.
This artifact does not authorize deployment, production writes, credentials,
infrastructure mutation, worker dispatch, remote host operations, Docker,
Kubernetes, or GitHub Project control-plane mutation.

Required exact terms: component inventory; Carbon token inventory; CI visual
regression; artifact capture; desktop viewport; mobile viewport; contrast
coverage; focus; hover; selected; active; disabled; error; warning; success;
status; data elements; cross-browser; approval-gate status; cleanup receipt;
residual risk; next action.

This component inventory is the canonical Carbon token inventory for the current
CI visual regression artifact capture gate. It records desktop viewport, mobile
viewport, and contrast coverage evidence for the first first-party dashboard
lane. CI validates root-retained artifact copies so the root repository does not
depend on private submodule checkout permissions.

## Component Inventory

The component inventory maps first-party UI surfaces to Carbon token roles
instead of a one-screen dashboard-only proof. Components inherit the Carbon
baseline from [`carbon-ui-baseline.md`](carbon-ui-baseline.md) and use the
dashboard captures retained under
`docs/design/evidence/carbon-component-library/` as the current visual
regression artifact capture. The source provenance remains the
`symphony-github-project-tracker` dashboard proof at submodule commit
`dbcd306fc230d9fac12a36477c9ccd7494786380`.

## CI Visual Regression Gate

The GitHub governance workflow uses root-owned evidence artifacts and runs
`bash scripts/validate-carbon-component-library-visual-regression.sh` in the
`contract-docs` job. The validator verifies the component inventory, desktop
and mobile PNG dimensions, capture hashes, contrast report thresholds, CI gate
metadata, approval-gate status, cleanup receipt, and unsafe-evidence rejection.
When the Symphony submodule is available locally, the same validator also runs
the source dashboard proof validator.

## Cross-Browser Coverage

The first visual regression lane is Playwright Chromium from the existing
dashboard proof. Firefox and WebKit lanes remain future hardening work for
broader browser support, but the first lane plus CI artifact contract is enough
to close the current design-system readiness gap.

<!-- carbon-component-library-visual-regression:begin -->
```json
{
  "version": 1,
  "issueUrl": "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/67",
  "permissionLevel": "docs-only-local-ui-and-ci-validation",
  "sourceBaseline": "docs/design/carbon-ui-baseline.md",
  "dashboardProof": {
    "proofDocument": "symphony-github-project-tracker/docs/design/dashboard-carbon-proof.md",
    "stylesheet": "symphony-github-project-tracker/elixir/priv/static/dashboard.css",
    "submoduleCommit": "dbcd306fc230d9fac12a36477c9ccd7494786380",
    "captures": {
      "desktop": {
        "path": "docs/design/evidence/carbon-component-library/desktop.png",
        "viewport": "desktop viewport",
        "width": 1440,
        "height": 1454,
        "sha256": "8a59ffa769c6f68e683a65306b49c93fad8d8c286ca37338d79ede81294906e7"
      },
      "mobile": {
        "path": "docs/design/evidence/carbon-component-library/mobile.png",
        "viewport": "mobile viewport",
        "width": 390,
        "height": 3809,
        "sha256": "c31ede9022c4d3c54a35a7374e57a6477fc6ae58e2331c88e49ee4ca528367ea"
      }
    },
    "contrastReport": {
      "path": "docs/design/evidence/carbon-component-library/contrast-report.json",
      "sha256": "4b9a15f62010d5cbee43371fdb27bee97d442753577017dd98e721ddc82755fb",
      "browser": "Playwright Chromium",
      "minimumChecks": 10
    }
  },
  "componentInventory": [
    {
      "id": "app-shell-navigation",
      "surface": "app shell and navigation",
      "tokenRoles": ["$background", "$layer", "$border-subtle", "$text-primary", "$icon-primary", "$focus"],
      "stateSupport": ["default", "hover", "selected", "active", "focus", "disabled"]
    },
    {
      "id": "work-queue-table",
      "surface": "work queue table",
      "tokenRoles": ["$layer", "$border-subtle", "$text-primary", "$text-secondary", "$support-warning", "$focus"],
      "stateSupport": ["default", "hover", "selected", "active", "focus", "disabled", "warning", "status", "data"]
    },
    {
      "id": "issue-intake-form",
      "surface": "issue intake form",
      "tokenRoles": ["$field", "$border-strong", "$text-primary", "$support-error", "$support-info", "$focus"],
      "stateSupport": ["default", "hover", "active", "focus", "disabled", "error", "warning", "success"]
    },
    {
      "id": "approval-gate-panel",
      "surface": "approval gate panel",
      "tokenRoles": ["$layer", "$support-warning", "$support-success", "$button-danger-primary", "$focus"],
      "stateSupport": ["default", "hover", "active", "focus", "disabled", "error", "warning", "success", "status"]
    },
    {
      "id": "worker-route-picker",
      "surface": "worker route picker",
      "tokenRoles": ["$field", "$border-subtle", "$text-secondary", "$support-error", "$support-info", "$focus"],
      "stateSupport": ["default", "hover", "selected", "active", "focus", "disabled", "error", "warning", "status"]
    },
    {
      "id": "result-packet-review",
      "surface": "result packet review",
      "tokenRoles": ["$layer", "$text-primary", "$text-secondary", "$link-primary", "$support-success", "$support-error"],
      "stateSupport": ["default", "hover", "focus", "disabled", "error", "warning", "success", "status"]
    },
    {
      "id": "evidence-package-viewer",
      "surface": "evidence package viewer",
      "tokenRoles": ["$layer", "$field", "$border-strong", "$text-primary", "$link-primary", "$focus"],
      "stateSupport": ["default", "hover", "selected", "active", "focus", "disabled", "status", "data"]
    },
    {
      "id": "metrics-dashboard",
      "surface": "metrics dashboard",
      "tokenRoles": ["$background", "$layer", "$support-error", "$support-warning", "$support-success", "$support-info", "$focus"],
      "stateSupport": ["default", "hover", "selected", "active", "focus", "disabled", "error", "warning", "success", "status", "data"]
    },
    {
      "id": "alert-incident-banner",
      "surface": "alert or incident banner",
      "tokenRoles": ["$support-error", "$support-warning", "$support-success", "$support-info", "$text-primary", "$focus"],
      "stateSupport": ["default", "hover", "active", "focus", "disabled", "error", "warning", "success", "status"]
    },
    {
      "id": "settings-credential-summary",
      "surface": "settings and credential-scope summary",
      "tokenRoles": ["$layer", "$field", "$border-subtle", "$text-secondary", "$support-warning", "$focus"],
      "stateSupport": ["default", "hover", "selected", "active", "focus", "disabled", "warning", "status"]
    },
    {
      "id": "overlay-surfaces",
      "surface": "modal, drawer, toast, and inline notification surfaces",
      "tokenRoles": ["$overlay", "$layer", "$border-strong", "$text-primary", "$support-info", "$focus"],
      "stateSupport": ["default", "hover", "active", "focus", "disabled", "error", "warning", "success", "status"]
    }
  ],
  "stateCoverage": [
    "default",
    "hover",
    "selected",
    "active",
    "focus",
    "disabled",
    "error",
    "warning",
    "success",
    "status",
    "data elements"
  ],
  "visualRegressionGate": {
    "ciWorkflow": ".github/workflows/dokkaebi-governance.yml",
    "ciJob": "contract-docs",
    "ciCommand": "bash scripts/validate-carbon-component-library-visual-regression.sh",
    "requiresSubmoduleCheckout": false,
    "artifactCapture": [
      "desktop viewport PNG",
      "mobile viewport PNG",
      "contrast report JSON"
    ],
    "artifactRetention": "checked-in root dashboard proof artifact copies and CI logs retained with pull request checks"
  },
  "contrastCoverage": {
    "minimumSmallText": "4.5:1",
    "minimumFocusIndicator": "3:1",
    "minimumDataVisualization": "3:1",
    "requiredSurfaces": [
      "text-primary-on-background",
      "focus-on-layer",
      "button-primary-text",
      "disabled-control-text",
      "success-status-border",
      "warning-status-text",
      "error-status-text",
      "token-meter-fill",
      "table-border",
      "mobile-card-border"
    ]
  },
  "crossBrowserCoverage": {
    "firstLane": "Playwright Chromium",
    "residualMatrix": "Firefox and WebKit visual regression lanes remain future hardening work after the first CI artifact gate"
  },
  "validationOutput": [
    "bash scripts/validate-carbon-component-library-visual-regression.sh: PASS",
    "bash scripts/validate-carbon-ui-baseline.sh: PASS",
    "root-retained dashboard artifact hashes: PASS",
    "bash scripts/validate-readiness-criteria.sh: PASS",
    "bash scripts/validate-contract-docs.sh: PASS",
    "bash scripts/validate-git-governance.sh: PASS"
  ],
  "approvalGateStatus": "No deployment, production write, credential, infrastructure, worker, remote host, Docker, Kubernetes, or GitHub Project control-plane mutation reached",
  "cleanupReceipt": {
    "status": "complete",
    "receipt": "checked-in documentation, artifact metadata, retained dashboard captures, and validation output only; no local server, browser context, screenshot temp directory, credential, worker, remote host, container, cluster, deployment, production target, or GitHub Project setting touched"
  },
  "residualRisk": [
    "Firefox and WebKit visual regression lanes are not yet implemented.",
    "Future first-party UI surfaces must add their own desktop and mobile captures before claiming coverage.",
    "Current evidence is local UI and CI validation evidence, not deployment evidence."
  ],
  "nextAction": "Keep future UI PRs on this component inventory and add Firefox/WebKit visual regression lanes when a broader browser matrix becomes required.",
  "followUpIssueUrl": "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/84"
}
```
<!-- carbon-component-library-visual-regression:end -->
