---
spec: mint.spec.md
---

## User Stories

- As a creator, I want to mint and update ARC-19 or ARC-69 NFTs with typed Swift values.
- As a reader, I want to retrieve asset and metadata state with explicit indexer requirements.
- As an IPFS integrator, I want pinning abstracted from asset transactions.

## Constraints

- This migration changes no source, tests, transaction semantics, package manifest, or public API.
- Supported ARC-19 CIDs use SHA2-256 32-byte digests and dag-pb or raw reconstruction.
- Live integration tests remain opt-in and require the documented Algorand credentials and funded account.

## Out of Scope

- Hosting nodes, managing secrets, funding accounts, retrying networks, or persisting transaction state.
- Adding new standards, codecs, hash algorithms, pinning vendors, or wallet behavior.

### REQ-mint-001

CID and ARC-19 template utilities SHALL detect supported CID versions/codecs, convert 32-byte SHA2-256 digests to
reserve addresses, reconstruct supported CIDs, and parse or emit the declared template-IPFS structure.

Acceptance Criteria
- CIDv0 uses dag-pb; recognized CIDv1 prefixes select dag-pb or raw.
- Invalid formats, multihashes, codecs, versions, and digest sizes throw typed errors.
- Reserve round trips preserve supported CID text, and template parsing preserves version, codec, field, hash, suffix.

### REQ-mint-002

Configuration, result, and error values SHALL preserve their declared clients, identifiers, addresses, associated
error context, `Sendable` contracts, and localized descriptions.

Acceptance Criteria
- URL configuration creates algod and optional indexer clients.
- Mint results retain asset ID, transaction ID, and optional reserve address.
- Every `MintError` case produces a case-specific diagnostic.

### REQ-mint-003

ARC-19 and ARC-69 creation SHALL validate name and URL lengths, build a one-unit zero-decimal asset, sign and submit
the creation transaction, wait for confirmation, and return its created asset identifier.

Acceptance Criteria
- Overlong unit, asset, or URL values fail before a network request.
- ARC-19 uses template URL and CID reserve address; ARC-69 uses supplied URL and encoded metadata note.
- Successful results contain nonempty transaction ID and created asset ID.

### REQ-mint-004

ARC-19, ARC-69, and general asset updates SHALL preserve current configuration unless an optional replacement is
supplied, sign through the manager account, submit, confirm, and return the transaction ID.

Acceptance Criteria
- ARC-19 update replaces reserve with the new CID digest.
- ARC-69 update replaces the note with compact metadata JSON.
- Configuration update applies declared manager, reserve, freeze, and clawback replacements.

### REQ-mint-005

Asset and metadata reads SHALL require the configured indexer, map missing records to typed errors, reconstruct
ARC-19 CID parameters from asset URL/reserve, and decode ARC-69 metadata from the latest applicable note.

Acceptance Criteria
- Missing indexer throws `indexerRequired`.
- Missing asset or note metadata throws its corresponding typed error.
- ARC-19 fetch delegates JSON decoding to the provided pinning provider.

### REQ-mint-006

IPFS integration SHALL expose async pin, file, unpin, and JSON fetch contracts; build deterministic gateway/native
URLs; validate HTTP success; decode requested JSON; and support pin-before-mint and pin-before-update composition.

Acceptance Criteria
- Gateway URL uses `<gateway>/ipfs/<cid>` and native URI uses `ipfs://<cid>`.
- Invalid response, status, or JSON maps to typed network or metadata errors.
- Composed methods pass the pinned CID into the corresponding ARC-19 operation.

### REQ-mint-007

Asset destruction SHALL create, sign, submit, and confirm an asset-destroy transaction for the supplied asset and
return its transaction identifier.

Acceptance Criteria
- The signing account is the transaction sender.
- The requested asset ID is destroyed only after confirmation succeeds.

### REQ-mint-008

Public minting operations SHALL remain actor-isolated async/await APIs with typed, deterministic local validation
before external Algorand or IPFS effects.

Acceptance Criteria
- `Minter` remains an actor and public cross-concurrency values remain `Sendable`.
- Local CID, template, and length failures occur without successful network submission.
- Existing macOS, Linux, integration, documentation, and release workflows remain independent.

