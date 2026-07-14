---
spec: mint.spec.md
---

## Key Decisions

- Use an actor for the state-free but networked minting service so client access remains concurrency-safe.
- Represent ARC-19 mutability through the reserve-address CID digest and ARC-69 metadata through transaction notes.
- Keep IPFS operations behind `IPFSPinningProvider`; the default fetch implementation uses a configurable gateway.
- Require an indexer only for reads that cannot be answered by algod.

## Files to Read First

- `Sources/Mint/Minter.swift` for asset transactions and reads.
- `Sources/Mint/CID.swift` for CID and template conversion.
- `Sources/Mint/PinataProvider.swift` for IPFS contracts.
- Both files under `Tests/MintTests` for native and opt-in integration evidence.

## Current Status

Five Swift files implement the public surface. Twenty-nine Swift Testing cases across eleven suites pass locally;
network integration suites are deliberately disabled unless their documented environment is configured.
