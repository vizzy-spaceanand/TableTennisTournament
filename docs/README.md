# Documentation

This folder contains all product, architecture, and technical documentation for the Tournament Platform.

## Index

| Document | Description | Status |
|---|---|---|
| [Codebase Walkthrough](./Codebase-Walkthrough.md) | Plain-English explanation of every file and block | Draft v0.1 |
| [Product Specification](./Product-Specification.md) | Vision, personas, feature roadmap, NFRs | Draft v0.1 |
| [Schema](./Schema.md) | Full database schema and migration notes | Draft v0.1 |
| [RBAC & Security](./RBAC.md) | Role definitions, access matrix, RLS policy patterns | Draft v0.1 |
| [API Contract](./API-Contract.md) | Supabase query patterns and data contracts | Draft v0.1 |

## Conventions

### Keeping docs in sync with code
- Every PR that changes schema must update `Schema.md`
- Every PR that changes roles or permissions must update `RBAC.md`
- Commit doc changes with the prefix `docs:` e.g. `docs: add tournament_players table`
- Mark completed phase checkboxes in `Product-Specification.md` when a phase ships

### Phases
The product is built in 6 phases. Current phase status is tracked in [Product Specification → Feature Roadmap](./Product-Specification.md#3-feature-roadmap-by-phase).
