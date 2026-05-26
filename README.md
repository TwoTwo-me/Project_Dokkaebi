# Project Dokkaebi

Project Dokkaebi is the upper AI Manager layer for a three-tier project-management system:

```text
Human -> AI Manager Agent -> Symphony/GitHub Project -> AI Worker -> verifiable result return
```

Dokkaebi manages Human intent, approval boundaries, work contracts, and result review. Symphony is treated as the first worker orchestration backend for GitHub Project based dispatch, isolated worker execution, and progress/result tracking.

## Initial scope

Milestone 1 is a repository-contract milestone:

- Define the Dokkaebi concept and manager role.
- Document architecture and trust boundaries.
- Define Manager-to-Symphony-to-Worker workflow contracts.
- Define safety/authority policy.
- Create GitHub Project ticket templates for Worker-ready tasks.

See [`docs/deep-interview-project-dokkaebi.md`](docs/deep-interview-project-dokkaebi.md) for the clarified initial specification.
