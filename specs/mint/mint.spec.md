---
module: mint
version: 3
status: active
files:
  - Sources/Mint/CID.swift
  - Sources/Mint/Mint.swift
  - Sources/Mint/MintError.swift
  - Sources/Mint/Minter.swift
  - Sources/Mint/PinataProvider.swift
db_tables: []
depends_on: []
---

# Mint

## Purpose

The `Mint` module creates, reads, updates, and destroys Algorand ARC-19 and ARC-69 assets. It owns CID and ARC-19
template conversion, transaction orchestration, optional indexer reads, IPFS pinning abstractions, and typed errors.
It does not operate an Algorand node, indexer, IPFS service, wallet, or persistent store.

## Public API

| Export | Contract |
|--------|----------|
| `CID` | Parsed IPFS identifier used by ARC-19. |
| `value` | Original CID text. |
| `version` | Detected CID version. |
| `codec` | Detected ARC-19 codec. |
| `init` | Public value and service initialization. |
| `toReserveAddress` | Converts a SHA2-256 CID digest to an Algorand address. |
| `toARC19URL` | Builds a template-IPFS URL. |
| `fromReserveAddress` | Reconstructs a supported CID. |
| `ARC19TemplateURL` | Parsed ARC-19 template parameters. |
| `field` | Template address field. |
| `hashType` | Template hash identifier. |
| `suffix` | Optional template path. |
| `parse` | ARC-19 template parser. |
| `MinterConfiguration` | Algod and optional indexer clients. |
| `algodClient` | Transaction node client. |
| `indexerClient` | Optional query client. |
| `MintResult` | Created asset result. |
| `assetID` | Algorand asset identifier. |
| `transactionID` | Submitted transaction identifier. |
| `reserveAddress` | Optional ARC-19 reserve address. |
| `Minter` | Actor-isolated asset service. |
| `mintARC19` | Creates an ARC-19 NFT. |
| `mintARC69` | Creates an ARC-69 NFT. |
| `updateARC19` | Changes ARC-19 reserve CID and configuration. |
| `updateARC69` | Changes ARC-69 metadata note. |
| `updateAssetConfig` | Changes manager, reserve, freeze, or clawback addresses. |
| `getAssetInfo` | Reads asset information from the configured indexer. |
| `getARC19Metadata` | Reconstructs the CID and fetches ARC-3 JSON through a pinning provider. |
| `getARC69Metadata` | Reads and decodes the latest ARC-69 configuration note. |
| `destroyAsset` | Destroys an asset through a signed configuration transaction. |
| `IPFSPinningProvider` | Async pin, unpin, and fetch abstraction. |
| `pinJSON` | Pins ARC-3 JSON. |
| `pinFile` | Pins named file data. |
| `unpin` | Removes a pin. |
| `fetchJSON` | Fetches and decodes CID JSON, with a default gateway implementation. |
| `PinResult` | CID, optional size, and timestamp result. |
| `cid` | Pinned content identifier. |
| `size` | Optional pinned byte count. |
| `timestamp` | Pin completion time. |
| `gatewayURL` | HTTP gateway URL. |
| `ipfsURI` | Native IPFS URI. |
| `mintARC19WithPinning` | Pins metadata before ARC-19 creation. |
| `updateARC19WithPinning` | Pins metadata before ARC-19 update. |
| `MintError` | Typed minting error. |
| `invalidCID` | CID error. |
| `invalidMetadata` | Metadata and asset-parameter error. |
| `transactionFailed` | Transaction confirmation error. |
| `networkError` | HTTP or client response error. |
| `notAuthorized` | Authorization error. |
| `assetNotFound` | Missing asset error. |
| `pinningFailed` | Pinning error. |
| `indexerRequired` | Missing indexer error. |
| `metadataNotFound` | Missing on-chain metadata error. |
| `invalidTemplateURL` | ARC-19 template error. |
| `errorDescription` | Human-readable typed diagnostic. |

## Invariants

1. `Minter` serializes service access as an actor and uses async/await for network operations.
2. NFTs are created with total one, zero decimals, manager set to the signing account, and standard-specific fields.
3. Unit names are at most eight characters, asset names at most thirty-two, and URLs at most 256.
4. ARC-19 reserve addresses contain exactly a 32-byte SHA2-256 digest; template versions are zero or one.
5. ARC-69 metadata is encoded into the transaction note, while ARC-19 mutability is the reserve address.
6. Reads requiring indexer history fail with `indexerRequired` when no indexer is configured.
7. Every mutating operation signs with the supplied account, submits through algod, and waits for confirmation.

## Behavioral Examples

### Scenario: Mint ARC-19
- **Given** valid ARC-3 metadata, a supported CID, and legal asset names
- **When** `mintARC19` succeeds
- **Then** it returns the asset and transaction IDs plus the CID-derived reserve address

### Scenario: Read ARC-69 metadata
- **Given** an indexer and an asset with a configuration note
- **When** `getARC69Metadata` runs
- **Then** it decodes the most recent note as ARC-69 JSON or throws a typed metadata error

## Error Cases

| Condition | Behavior |
|-----------|----------|
| Unknown CID, invalid multihash, codec, or digest size | Throw `invalidCID`. |
| Invalid ARC-19 template structure or version | Throw `invalidTemplateURL`. |
| Asset parameter exceeds protocol length | Throw `invalidMetadata` before networking. |
| Indexer-backed operation has no indexer | Throw `indexerRequired`. |
| Asset or metadata cannot be found | Throw `assetNotFound` or `metadataNotFound`. |
| Gateway response is invalid, non-200, or undecodable | Throw `networkError` or `invalidMetadata`. |

## Dependencies

| Module | Use |
|--------|-----|
| Algorand | Accounts, addresses, clients, asset transactions, signing, confirmation, and indexer models. |
| ARC | ARC-3 and ARC-69 metadata encoding and decoding. |
| Foundation | Data, dates, JSON, URLSession, and HTTP responses. |

## Change Log

| Date | Author | Change |
|------|--------|--------|
| 2026-07-13 | 0xLeif | Documented the existing Swift Mint behavior for SpecSync 5.0.1. |
| 2026-07-14 | CHG-0002-document-the-existing-swift-mint-api-at-complete-specsync-coverage: Document the existing Swift Mint API at complete SpecSync coverage |
