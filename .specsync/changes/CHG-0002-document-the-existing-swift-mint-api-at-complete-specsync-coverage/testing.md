---
change: CHG-0002-document-the-existing-swift-mint-api-at-complete-specsync-coverage
artifact: testing
---

# Testing

Verification runs the native Fledge lane and all twenty-nine discovered tests. Network integration suites are
truthfully opt-in, so unit evidence covers deterministic behavior while those suites specify live transaction flows.

| Requirement | Evidence |
|-------------|----------|
| `REQ-mint-001` | CID and template parsing/round-trip tests. |
| `REQ-mint-002` | Configuration, result, error, and Sendable tests. |
| `REQ-mint-003` | Length validation plus opt-in creation cycles. |
| `REQ-mint-004` | Opt-in ARC and configuration update cycles. |
| `REQ-mint-005` | Opt-in indexer and metadata reads. |
| `REQ-mint-006` | Pinning mocks, URL helpers, and decoding tests. |
| `REQ-mint-007` | Opt-in CRUD destruction cleanup. |
| `REQ-mint-008` | Actor, validation, and workflow boundaries. |
