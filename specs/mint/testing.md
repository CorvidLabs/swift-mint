---
spec: mint.spec.md
---

## Automated Testing

The package has twenty-nine Swift Testing cases across eleven suites in two files. The default lane runs
`swift build -v` and `swift test -v`; live integration cases remain disabled without their environment variables.

| Test File | Coverage |
|-----------|----------|
| `Tests/MintTests/MintTests.swift` | CID parsing and round trips, templates, configuration, results, URL helpers, errors, pinning, parameter validation, and `Sendable` contracts. |
| `Tests/MintTests/IntegrationTests.swift` | Opt-in ARC-19/ARC-69 CRUD, configuration updates, algod connectivity, and indexer connectivity. |

## Requirement Evidence

| Requirements | Evidence |
|--------------|----------|
| `REQ-mint-001` | CID and ARC-19 template unit tests. |
| `REQ-mint-002` | Configuration, result, error-description, and Sendable tests. |
| `REQ-mint-003` | Parameter validation tests plus opt-in ARC-19/ARC-69 creation cycles. |
| `REQ-mint-004` | Opt-in ARC-19, ARC-69, and asset-configuration update cycles. |
| `REQ-mint-005` | Opt-in asset, ARC-19 metadata, and ARC-69 metadata reads. |
| `REQ-mint-006` | Pinning mock tests, URL helper tests, and opt-in pinning boundaries. |
| `REQ-mint-007` | Opt-in destruction and full CRUD cleanup. |
| `REQ-mint-008` | Native concurrency, typed errors, and network-boundary tests. |

## Manual Review

Confirm all exports against the five source files and verify no diff exists under `Sources/` or `Tests/`.
