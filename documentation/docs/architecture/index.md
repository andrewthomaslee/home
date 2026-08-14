# Architecture Decision Records (ADRs)

Architecture Decision Records capture important architectural and design decisions made in this repository, along with the context, alternatives considered, and consequences.

## Index of Records

| ADR | Title | Status | Date |
|---|---|---|---|
| [ADR 0001](adr/0001-multi-host-deployment-strategy.md) | Multi-Host Deployment Strategy via FlakeHub Hub and Clan | Accepted | 2026-08-14 |

---

## Architectural Principles

1. **All Builds Lead to Nix**: Every application, machine configuration, and toolchain must be packaged via Nix Flakes to ensure complete reproducibility.
2. **Pull-Based Updates**: Systems pull closures from FlakeHub rather than relying on brittle long-distance push pipelines.
3. **Strict Secrets Isolation**: Public configurations remain open-source; private cryptographic material is handled via SOPS / Clan vars.
