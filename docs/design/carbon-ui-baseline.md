# Carbon UI Token And Accessibility Baseline

This document defines the docs-only Carbon Design System baseline for future
Project Dokkaebi product UI surfaces. It does not implement a first-party UI,
change design tokens in an application, deploy a frontend, mutate GitHub Project
schemas, grant credentials, launch workers, touch remote hosts, run Docker or
Kubernetes, or write production data.

Source guidance: <https://carbondesignsystem.com/elements/color/overview/>.

The goal is to make visual decisions reviewable before UI implementation work
starts. Future UI work must use Carbon role-based tokens, theme layering,
interaction states, focus and contrast requirements, status semantics, visual QA
captures, and operational information density instead of one-off palettes.

The validation contract for this docs-only baseline explicitly covers theme
choice, role-based token mapping, layering model, interaction states, focus
requirements, contrast thresholds, data visualization rules, status color rules,
component state inventory, visual QA checklist, remaining operational gaps,
permission level, docs-only, and Carbon Design System source guidance.

Required exact terms: theme choice; role-based token mapping; layering model; interaction states; focus requirements; contrast thresholds; data visualization rules; status color rules; component state inventory; visual QA checklist; remaining operational gaps; permission level; docs-only; Carbon Design System.

## Enterprise Standard

All Dokkaebi UI surfaces must:

- use Carbon role-based tokens rather than arbitrary hard-coded product colors;
- support a documented light theme and dark theme strategy;
- follow Carbon layering rules for page, shell, panel, card, field, and overlay
  depth;
- provide default, hover, selected, active, focus, disabled, error, warning,
  success, and informational states where the component supports them;
- make focus visible on every interactive element;
- meet accessibility contrast requirements for text, focus indicators,
  graphical elements, data visualization, and status indicators;
- keep operations surfaces dense, scannable, and restrained rather than
  marketing-oriented.

## Theme Choice

Default UI guidance:

- use Carbon Gray 10 for light operational surfaces unless a White theme is
  needed for document-heavy review flows;
- use Carbon Gray 100 for dark operational surfaces unless Gray 90 better
  matches shell and panel layering;
- keep the primary action family on Carbon interactive tokens;
- reserve support colors for semantic status, notifications, alerts, and
  incident or validation outcomes;
- do not introduce a product-specific palette unless a later design ADR maps it
  back to Carbon token roles.

## Role-Based Token Mapping

| Dokkaebi role | Carbon token role |
| --- | --- |
| App background | `$background` |
| Page or workspace layer | `$layer` and layering variants |
| Form and command fields | `$field` and field variants |
| Dividers and panel edges | `$border-subtle`, `$border-strong` |
| Primary text | `$text-primary` |
| Secondary text and metadata | `$text-secondary` |
| Disabled text | `$text-disabled` |
| Inline links | `$link-primary` |
| Navigation and command icons | `$icon-primary`, `$icon-secondary` |
| Primary action | `$button-primary`, `$interactive` |
| Danger or destructive action | `$button-danger-primary` |
| Focus ring | `$focus`, `$focus-inset`, `$focus-inverse` |
| Error state | `$support-error` |
| Warning state | `$support-warning` |
| Success state | `$support-success` |
| Informational state | `$support-info` |
| Overlay and modal scrim | `$overlay` |
| Loading placeholder | `$skeleton-background`, `$skeleton-element` |

Component-specific Carbon tokens must stay scoped to their matching component.
They must not become general-purpose color shortcuts.

## Layering Model

Light surfaces alternate between the global background and the next layer token
to show page, panel, table, drawer, and modal depth. Dark surfaces move one
layer lighter as surfaces stack. Dokkaebi UI implementations must document the
layer stack for:

- global shell;
- navigation;
- work queue;
- issue detail;
- approval panel;
- worker result packet;
- modal or drawer;
- data table or metrics chart;
- toast or inline notification.

## Interaction States

Future UI PRs must inventory states for every interactive component:

- default state;
- hover state with the matching `-hover` token;
- selected state with the matching `-selected` token;
- active state with the matching `-active` token;
- focus state with a visible focus token;
- disabled state with disabled tokens and no hover or focus behavior;
- error state only for invalid or failed conditions;
- warning state only for risk or attention conditions;
- success state only for completed or passing conditions;
- informational state only for neutral guidance.

State color must not be used as the only indicator. Text, iconography, or
structure must also communicate status.

## Focus Requirements

Focus states are mandatory on buttons, links, inputs, menus, tabs, tree items,
table rows when actionable, cards when clickable, command palette entries, and
workflow controls. The default focus treatment is a two pixel visible border
using the Carbon focus token. Use an inset separator when needed to preserve
contrast against the component surface.

Focus indicators must reach at least a 3:1 contrast ratio against adjacent
colors. Keyboard navigation must expose focus order without causing layout shift
or hiding focused content behind sticky panels.

## Contrast Thresholds

Minimum contrast requirements:

- small text below 24 px: at least 4.5:1;
- large text at or above 24 px: at least 3:1;
- focus indicators: at least 3:1 against adjacent colors;
- icons that communicate state or action: at least 3:1;
- graphical elements and data visualization marks: at least 3:1;
- status indicators: at least 3:1 and not color-only.

Disabled state styling is intentionally de-emphasized, but disabled controls must
remain clearly unavailable and must not receive hover or focus behavior.

## Data Visualization And Status Rules

Operational dashboards, SLO panels, incident views, and validation summaries must
use tokenized semantic colors:

- error for failed checks, denied authority, broken routes, or data loss risk;
- warning for stale review, elevated risk, missing optional evidence, or nearing
  SLO breach;
- success for passing validation, completed closeout, healthy route, or
  confirmed cleanup;
- info for neutral system status or next-action guidance.

Charts must pair color with labels, legends, patterns, icons, or text. Do not
reuse the primary action color as a status color.

## Component State Inventory

Future UI implementation PRs must include a state inventory for:

- app shell and navigation;
- project and tenant switcher;
- work queue table;
- issue intake form;
- approval gate panel;
- worker route picker;
- result packet review;
- evidence package viewer;
- metrics dashboard;
- alert or incident banner;
- settings and credential-scope summary;
- modal, drawer, toast, and inline notification surfaces.

The inventory must name the Carbon token roles used by each component and state.

## Visual QA Checklist

Every future UI PR must capture visual QA evidence for:

- desktop viewport;
- mobile viewport;
- light theme;
- dark theme when implemented;
- default, hover, selected, active, focus, disabled, error, warning, success, and
  informational states where applicable;
- dense operational layout without marketing-style hero composition;
- no text overlap, clipped labels, hidden focus, or layout shift;
- color token usage instead of arbitrary palette usage;
- contrast evidence for text, focus, icons, status, and data visualization;
- cleanup of any local server, browser context, screenshots temp directory, and
  test data used during QA.

## Validation

The baseline is intentionally docs-only. It raises readiness by creating a
reviewable design contract and validation gate, while
[`carbon-component-library-visual-regression.md`](carbon-component-library-visual-regression.md)
records the first checked-in desktop/mobile visual QA captures, contrast report,
component inventory, and CI visual regression gate for issue #67.

<!-- carbon-ui-baseline:begin -->
```json
{
  "version": 1,
  "permissionLevel": "docs-only",
  "sourceGuidance": {
    "system": "Carbon Design System",
    "url": "https://carbondesignsystem.com/elements/color/overview/",
    "requiredConcepts": [
      "role-based color tokens",
      "theme values",
      "light and dark layering model",
      "interaction state tokens",
      "focus token",
      "contrast ratios"
    ]
  },
  "themeChoice": {
    "defaultLight": "Gray 10 for operational surfaces, White for document-heavy review flows",
    "defaultDark": "Gray 100 for operational surfaces, Gray 90 when shell layering requires it",
    "primaryAction": "Carbon interactive and button-primary token roles",
    "supportUse": "support tokens only for semantic status, notification, alert, and validation outcomes"
  },
  "roleBasedTokenMapping": {
    "background": "$background",
    "layer": "$layer",
    "field": "$field",
    "border": [
      "$border-subtle",
      "$border-strong"
    ],
    "text": [
      "$text-primary",
      "$text-secondary",
      "$text-disabled"
    ],
    "link": "$link-primary",
    "icon": [
      "$icon-primary",
      "$icon-secondary"
    ],
    "interactive": [
      "$interactive",
      "$button-primary",
      "$button-danger-primary"
    ],
    "focus": [
      "$focus",
      "$focus-inset",
      "$focus-inverse"
    ],
    "support": [
      "$support-error",
      "$support-warning",
      "$support-success",
      "$support-info"
    ],
    "overlay": "$overlay",
    "skeleton": [
      "$skeleton-background",
      "$skeleton-element"
    ]
  },
  "layeringModel": {
    "light": "alternate global background and layer tokens for shell, panels, tables, drawers, modals, and overlays",
    "dark": "move one layer lighter as surfaces stack",
    "requiredSurfaces": [
      "global shell",
      "navigation",
      "work queue",
      "issue detail",
      "approval panel",
      "worker result packet",
      "modal or drawer",
      "data table or metrics chart",
      "toast or inline notification"
    ]
  },
  "interactionStates": [
    "default",
    "hover with -hover token",
    "selected with -selected token",
    "active with -active token",
    "focus with visible focus token",
    "disabled with disabled tokens and no hover or focus behavior",
    "error with support-error token plus non-color cue",
    "warning with support-warning token plus non-color cue",
    "success with support-success token plus non-color cue",
    "informational with support-info token plus non-color cue"
  ],
  "focusRequirements": {
    "treatment": "two pixel visible border using focus token",
    "contrast": "at least 3:1 against adjacent colors",
    "inset": "use focus-inset when needed to preserve contrast",
    "scope": [
      "buttons",
      "links",
      "inputs",
      "menus",
      "tabs",
      "tree items",
      "actionable table rows",
      "clickable cards",
      "command palette entries",
      "workflow controls"
    ]
  },
  "contrastThresholds": {
    "smallText": "at least 4.5:1",
    "largeText": "at least 3:1",
    "focusIndicators": "at least 3:1",
    "icons": "at least 3:1 when communicative",
    "graphicalElements": "at least 3:1",
    "dataVisualization": "at least 3:1",
    "statusIndicators": "at least 3:1 and not color-only"
  },
  "dataVisualizationStatusRules": {
    "error": "failed checks, denied authority, broken routes, or data loss risk",
    "warning": "stale review, elevated risk, missing optional evidence, or nearing SLO breach",
    "success": "passing validation, completed closeout, healthy route, or confirmed cleanup",
    "info": "neutral system status or next-action guidance",
    "nonColorCue": "charts and status indicators must pair color with labels, legends, patterns, icons, or text"
  },
  "componentStateInventory": [
    "app shell and navigation",
    "project and tenant switcher",
    "work queue table",
    "issue intake form",
    "approval gate panel",
    "worker route picker",
    "result packet review",
    "evidence package viewer",
    "metrics dashboard",
    "alert or incident banner",
    "settings and credential-scope summary",
    "modal, drawer, toast, and inline notification surfaces"
  ],
  "visualQaChecklist": [
    "desktop viewport",
    "mobile viewport",
    "light theme",
    "dark theme when implemented",
    "default state",
    "hover state",
    "selected state",
    "active state",
    "focus state",
    "disabled state",
    "error state",
    "warning state",
    "success state",
    "informational state",
    "dense operational layout",
    "no text overlap",
    "no clipped labels",
    "no hidden focus",
    "no layout shift",
    "token usage evidence",
    "contrast evidence",
    "cleanup receipt"
  ],
  "implementationRules": [
    "use Carbon role-based tokens",
    "do not use arbitrary hard-coded UI colors",
    "do not create a one-off palette",
    "do not use color as the only status indicator",
    "document token roles in UI PRs"
  ],
  "remainingOperationalGaps": [
    "full cross-browser visual regression matrix is not complete",
    "Firefox visual regression lane is not automated",
    "WebKit visual regression lane is not automated",
    "non-dashboard first-party UI surfaces must add their own visual QA before launch",
    "live UI deployment is not present"
  ],
  "followUpIssueUrl": "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/84"
}
```
<!-- carbon-ui-baseline:end -->
