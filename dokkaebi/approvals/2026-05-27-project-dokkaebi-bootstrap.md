# Approval record: Project Dokkaebi bootstrap scope

- **Date:** 2026-05-27
- **Decision source:** Human instruction in the active Codex session
- **Approved action:** Bind `/home/koreaplayer99/Project_Dokkaebi` as the first
  local Dokkaebi `ProjectScope` and prepare the Symphony-native bootstrap
  workflow/configuration for a GitHub Project loop.
- **Explicitly not approved by this record:** copying secrets to Workers,
  enabling host Docker helper authority, creating/scaling Workers, mutating cloud
  or infrastructure, merging PRs, deploying, production writes, or bypassing
  Manager review.
- **Affected repository:** `TwoTwo-me/Project_Dokkaebi`
- **Permitted actor/runtime:** Codex/oh-my-codex as temporary bootstrap Manager
- **Expiry/revocation:** Expires when replaced by a project-policy approval in
  the GitHub Project, or when `dokkaebi/KILL_SWITCH` is present.
- **Validation expectation:** Local static validation of generated YAML/Markdown
  and Manager review before any remote GitHub Project mutation.
- **Planned review surface:** this repository plus future GitHub Project item(s)
  after project-scope remote setup is authorized and token scope is available.
