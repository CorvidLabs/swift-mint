# swift-mint

![Swift 6.0+](https://img.shields.io/badge/Swift-6.0+-orange.svg)
![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20visionOS-lightgrey.svg)
![License](https://img.shields.io/badge/license-MIT-blue.svg)

> **Pre-1.0 Notice**: This library is under active development. The API may change between minor versions until 1.0.

A Swift library for minting NFTs on Algorand. Built with Swift 6 and async/await.

## Features

- **ARC-19** - Mutable NFT metadata via reserve address (IPFS CID encoding)
- **ARC-69** - Mutable NFT metadata via transaction notes
- **ARC-3** - Standard NFT metadata structure
- **CID Support** - Parse and encode IPFS CIDv0 and CIDv1
- **Swift 6** - Full concurrency support with `Sendable` types

## Installation

### Swift Package Manager

Add Mint to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/CorvidLabs/swift-mint.git", from: "0.1.0")
]
```

Or add it via Xcode:
1. File > Add Package Dependencies
2. Enter: `https://github.com/CorvidLabs/swift-mint.git`

## Quick Start

### Minting an ARC-19 NFT

```swift
import Mint

// Create minter with algod client
let config = try MinterConfiguration(
    algodURL: "https://testnet-api.algonode.cloud"
)
let minter = Minter(configuration: config)

// Create metadata
let metadata = ARC3Metadata(
    name: "My NFT",
    description: "A unique digital collectible",
    image: "ipfs://QmYourImageCID"
)

// Parse your metadata CID from IPFS
let cid = try CID("bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi")

// Mint the NFT
let result = try await minter.mintARC19(
    account: account,
    metadata: metadata,
    cid: cid,
    unitName: "MYNFT",
    assetName: "My NFT #1"
)

print("Asset ID: \(result.assetID)")
print("Transaction: \(result.transactionID)")
```

### Minting an ARC-69 NFT

```swift
// Create ARC-69 metadata (stored in transaction note)
let metadata = ARC69Metadata(
    description: "An ARC-69 NFT",
    properties: [
        "trait": AnyCodable("rare"),
        "power": AnyCodable(100)
    ]
)

// Mint with metadata in note field
let result = try await minter.mintARC69(
    account: account,
    metadata: metadata,
    unitName: "ARC69",
    assetName: "My ARC-69 NFT",
    url: "https://example.com/image.png"
)
```

### Updating NFT Metadata

```swift
// Update ARC-19 metadata by changing reserve address
let newCid = try CID("QmNewMetadataCID...")
try await minter.updateARC19(
    account: account,
    assetID: result.assetID,
    newCID: newCid
)

// Update ARC-69 metadata via zero-amount transfer
let newMetadata = ARC69Metadata(
    description: "Updated description",
    properties: ["trait": AnyCodable("legendary")]
)
try await minter.updateARC69(
    account: account,
    assetID: result.assetID,
    newMetadata: newMetadata
)
```

## Core Concepts

### CID (Content Identifier)

IPFS Content Identifiers for referencing metadata:

```swift
// Parse CIDv0 (starts with "Qm")
let cidV0 = try CID("QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG")
print(cidV0.version)  // 0
print(cidV0.codec)    // "dag-pb"

// Parse CIDv1 (starts with "bafy" or "bafk")
let cidV1 = try CID("bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi")
print(cidV1.version)  // 1
print(cidV1.codec)    // "dag-pb"

// Convert to reserve address for ARC-19
let reserveAddress = try cid.toReserveAddress()

// Generate ARC-19 template URL
let url = cid.toARC19URL()
// "template-ipfs://{ipfscid:1:dag-pb:reserve:sha2-256}"

// Get gateway URLs
print(cid.gatewayURL())  // "https://ipfs.io/ipfs/..."
print(cid.ipfsURI)       // "ipfs://..."
```

### ARC-3 Metadata

The base metadata format for Algorand NFTs:

```swift
let metadata = ARC3Metadata(
    name: "NFT Name",
    description: "Description",
    image: "ipfs://...",
    imageMimetype: "image/png",
    externalUrl: "https://example.com",
    properties: [
        "trait_type": AnyCodable("value")
    ]
)
```

### ARC-69 Metadata

Metadata stored in transaction notes:

```swift
let metadata = ARC69Metadata(
    description: "Description",
    mediaUrl: "https://example.com/image.png",
    properties: [
        "trait": AnyCodable("rare")
    ]
)

// Encode to note data
let noteData = try metadata.toNoteData()
```

### IPFS Pinning Integration

Implement the `IPFSPinningProvider` protocol for automatic pinning:

```swift
struct MyPinataProvider: IPFSPinningProvider {
    func pinJSON(_ metadata: ARC3Metadata) async throws -> CID {
        // Upload to Pinata/IPFS and return CID
    }

    func pinFile(data: Data, name: String, mimeType: String) async throws -> CID {
        // Upload file to IPFS
    }

    func unpin(_ cid: CID) async throws {
        // Remove pin
    }
}

// Mint with automatic pinning
let result = try await minter.mintARC19WithPinning(
    account: account,
    metadata: metadata,
    pinningProvider: MyPinataProvider(),
    unitName: "MYNFT",
    assetName: "My NFT"
)
```

## Architecture

The library is organized into several key components:

- **Core Types**: `CID`, `ARC3Metadata`, `ARC69Metadata`, `AnyCodable`
- **Minting**: `Minter`, `MinterConfiguration`, `MintResult`
- **Pinning**: `IPFSPinningProvider`, `PinResult`
- **Errors**: `MintError`

The `Minter` is implemented as an `actor` for thread safety.

## ARC Standards

| Standard | Metadata Location | Update Method |
|----------|------------------|---------------|
| ARC-19 | IPFS (off-chain) | Change reserve address |
| ARC-69 | Transaction note (on-chain) | Zero-amount transfer |
| ARC-3 | Metadata format | N/A (format spec) |

## Requirements

- Swift 6.0+
- iOS 15.0+ / macOS 12.0+ / tvOS 15.0+ / watchOS 8.0+ / visionOS 1.0+

## License

MIT License - See [LICENSE](LICENSE) file for details.

## Resources

- [ARC-3: NFT Metadata Standard](https://github.com/algorandfoundation/ARCs/blob/main/ARCs/arc-0003.md)
- [ARC-19: Mutable Asset URL](https://github.com/algorandfoundation/ARCs/blob/main/ARCs/arc-0019.md)
- [ARC-69: Community NFT Standard](https://github.com/algorandfoundation/ARCs/blob/main/ARCs/arc-0069.md)
- [Algorand Developer Portal](https://developer.algorand.org)
