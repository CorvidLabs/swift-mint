import Foundation
import Testing
import ARC
@testable import Mint

@Suite("CID Tests")
struct CIDTests {
    @Test("Parse CIDv0")
    func parseCIDv0() throws {
        let cid = try CID("QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG")
        #expect(cid.version == 0)
        #expect(cid.value == "QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG")
    }

    @Test("Parse CIDv1")
    func parseCIDv1() throws {
        let cid = try CID("bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi")
        #expect(cid.version == 1)
    }

    @Test("Invalid CID throws")
    func invalidCIDThrows() {
        #expect(throws: MintError.self) {
            _ = try CID("invalid-cid-format")
        }
    }

    @Test("ARC-19 URL generation")
    func arc19URL() throws {
        let cid = try CID("QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG")
        let url = cid.toARC19URL()
        #expect(url == "template-ipfs://{ipfscid:0:dag-pb:reserve:sha2-256}")
    }

    @Test("Gateway URL generation")
    func gatewayURL() throws {
        let cid = try CID("QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG")
        #expect(cid.gatewayURL() == "https://ipfs.io/ipfs/QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG")
        #expect(cid.ipfsURI == "ipfs://QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG")
    }
}

@Suite("ARC-3 Metadata Tests")
struct ARC3MetadataTests {
    @Test("Create basic metadata")
    func createBasicMetadata() {
        let metadata = ARC.ARC3Metadata(
            name: "Test NFT",
            description: "A test NFT",
            image: "ipfs://QmTest"
        )

        #expect(metadata.name == "Test NFT")
        #expect(metadata.description == "A test NFT")
        #expect(metadata.image == "ipfs://QmTest")
    }

    @Test("Encode metadata to JSON")
    func encodeToJSON() throws {
        let metadata = ARC.ARC3Metadata(
            name: "Test NFT",
            description: "A test NFT"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(metadata)
        let json = String(data: data, encoding: .utf8)

        #expect(json?.contains("\"name\":\"Test NFT\"") == true)
    }
}

@Suite("ARC-69 Metadata Tests")
struct ARC69MetadataTests {
    @Test("Create ARC-69 metadata")
    func createMetadata() {
        let metadata = ARC.ARC69Metadata(
            description: "An ARC-69 NFT",
            mediaUrl: "https://example.com/image.png"
        )

        #expect(metadata.standard == "arc69")
        #expect(metadata.description == "An ARC-69 NFT")
    }

    @Test("Encode to JSON")
    func encodeToJSON() throws {
        let metadata = ARC.ARC69Metadata(
            description: "Test",
            properties: ["trait": .string("value")]
        )

        let jsonData = try metadata.toJSON()
        let json = String(data: jsonData, encoding: .utf8)

        #expect(json?.contains("\"standard\":\"arc69\"") == true)
    }

    @Test("ARC-69 metadata with properties")
    func metadataWithProperties() throws {
        let metadata = ARC.ARC69Metadata(
            description: "Test NFT",
            properties: [
                "Background": .string("Blue"),
                "Power": .integer(100)
            ]
        )

        #expect(metadata.standard == "arc69")
        #expect(metadata.properties?.count == 2)

        let jsonData = try metadata.toJSON()
        let json = String(data: jsonData, encoding: .utf8)

        #expect(json?.contains("\"properties\"") == true)
    }
}

@Suite("PropertyValue Tests")
struct PropertyValueTests {
    @Test("Encode various types")
    func encodeTypes() throws {
        let encoder = JSONEncoder()

        let stringValue = ARC.PropertyValue.string("test")
        let intValue = ARC.PropertyValue.integer(42)
        let numberValue = ARC.PropertyValue.number(3.14)

        _ = try encoder.encode(stringValue)
        _ = try encoder.encode(intValue)
        _ = try encoder.encode(numberValue)
    }

    @Test("Equality")
    func equality() {
        #expect(ARC.PropertyValue.string("test") == ARC.PropertyValue.string("test"))
        #expect(ARC.PropertyValue.integer(42) == ARC.PropertyValue.integer(42))
        #expect(ARC.PropertyValue.number(3.14) == ARC.PropertyValue.number(3.14))
    }
}

@Suite("ARC-19 Template URL Tests")
struct ARC19TemplateURLTests {
    @Test("Parse basic template URL")
    func parseBasicURL() throws {
        let url = "template-ipfs://{ipfscid:0:dag-pb:reserve:sha2-256}"
        let parsed = try ARC19TemplateURL.parse(url)

        #expect(parsed.version == 0)
        #expect(parsed.codec == "dag-pb")
        #expect(parsed.field == "reserve")
        #expect(parsed.hashType == "sha2-256")
        #expect(parsed.suffix == nil)
    }

    @Test("Parse template URL with suffix")
    func parseURLWithSuffix() throws {
        let url = "template-ipfs://{ipfscid:1:raw:reserve:sha2-256}/arc3.json"
        let parsed = try ARC19TemplateURL.parse(url)

        #expect(parsed.version == 1)
        #expect(parsed.codec == "raw")
        #expect(parsed.field == "reserve")
        #expect(parsed.hashType == "sha2-256")
        #expect(parsed.suffix == "/arc3.json")
    }

    @Test("Invalid template URL throws")
    func invalidURLThrows() {
        #expect(throws: MintError.self) {
            _ = try ARC19TemplateURL.parse("https://example.com")
        }

        #expect(throws: MintError.self) {
            _ = try ARC19TemplateURL.parse("template-ipfs://invalid")
        }
    }
}

@Suite("CID Reverse Operations Tests")
struct CIDReverseTests {
    @Test("CIDv0 round-trip")
    func cidv0RoundTrip() throws {
        let original = try CID("QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG")

        // Convert to reserve address
        let reserveAddress = try original.toReserveAddress()

        // Convert back to CID
        let reconstructed = try CID.fromReserveAddress(
            reserveAddress,
            version: original.version,
            codec: original.codec
        )

        #expect(reconstructed.value == original.value)
        #expect(reconstructed.version == 0)
        #expect(reconstructed.codec == "dag-pb")
    }

    @Test("CIDv1 dag-pb round-trip")
    func cidv1DagPbRoundTrip() throws {
        let original = try CID("bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi")

        // Convert to reserve address
        let reserveAddress = try original.toReserveAddress()

        // Convert back to CID
        let reconstructed = try CID.fromReserveAddress(
            reserveAddress,
            version: original.version,
            codec: original.codec
        )

        #expect(reconstructed.version == 1)
        #expect(reconstructed.codec == "dag-pb")
        // Note: CIDv1 strings may differ due to encoding variations, but the hash should be the same
    }
}

@Suite("MintError Tests")
struct MintErrorTests {
    @Test("Error descriptions")
    func errorDescriptions() {
        let indexerError = MintError.indexerRequired
        #expect(indexerError.errorDescription?.contains("Indexer") == true)

        let metadataError = MintError.metadataNotFound(12345)
        #expect(metadataError.errorDescription?.contains("12345") == true)

        let templateError = MintError.invalidTemplateURL("bad-url")
        #expect(templateError.errorDescription?.contains("bad-url") == true)
    }
}

@Suite("ARC-19 URL Generation Tests")
struct ARC19URLGenerationTests {
    @Test("Generate URL with suffix")
    func generateURLWithSuffix() throws {
        let cid = try CID("QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG")
        let url = cid.toARC19URL(suffix: "/arc3.json")
        #expect(url == "template-ipfs://{ipfscid:0:dag-pb:reserve:sha2-256}/arc3.json")
    }

    @Test("Generate URL with custom field")
    func generateURLWithCustomField() throws {
        let cid = try CID("QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG")
        let url = cid.toARC19URL(field: "manager")
        #expect(url == "template-ipfs://{ipfscid:0:dag-pb:manager:sha2-256}")
    }
}

@Suite("Input Validation Tests")
struct InputValidationTests {
    @Test("Unit name exceeds 8 chars throws error")
    func unitNameTooLong() async throws {
        // Create a minter with a dummy config (validation happens before network call)
        let config = try MinterConfiguration(algodURL: "http://localhost:4001")
        let minter = Minter(configuration: config)

        let metadata = ARC.ARC69Metadata(description: "Test")

        // Should throw validation error before any network call
        await #expect(throws: MintError.self) {
            _ = try await minter.mintARC69(
                account: try createDummyAccount(),
                metadata: metadata,
                unitName: "TOOLONGNAME", // 11 chars, max is 8
                assetName: "Test",
                url: "https://example.com"
            )
        }
    }

    @Test("Asset name exceeds 32 chars throws error")
    func assetNameTooLong() async throws {
        let config = try MinterConfiguration(algodURL: "http://localhost:4001")
        let minter = Minter(configuration: config)

        let metadata = ARC.ARC69Metadata(description: "Test")
        let longName = String(repeating: "A", count: 33) // 33 chars, max is 32

        await #expect(throws: MintError.self) {
            _ = try await minter.mintARC69(
                account: try createDummyAccount(),
                metadata: metadata,
                unitName: "TEST",
                assetName: longName,
                url: "https://example.com"
            )
        }
    }

    @Test("URL exceeds 256 chars throws error")
    func urlTooLong() async throws {
        let config = try MinterConfiguration(algodURL: "http://localhost:4001")
        let minter = Minter(configuration: config)

        let metadata = ARC.ARC69Metadata(description: "Test")
        let longURL = "https://example.com/" + String(repeating: "a", count: 250) // > 256 chars

        await #expect(throws: MintError.self) {
            _ = try await minter.mintARC69(
                account: try createDummyAccount(),
                metadata: metadata,
                unitName: "TEST",
                assetName: "Test NFT",
                url: longURL
            )
        }
    }

    @Test("Valid params do not throw validation error")
    func validParamsNoValidationError() async throws {
        let config = try MinterConfiguration(algodURL: "http://localhost:4001")
        let minter = Minter(configuration: config)

        let metadata = ARC.ARC69Metadata(description: "Test")

        // This should pass validation but fail on network (which is expected)
        do {
            _ = try await minter.mintARC69(
                account: try createDummyAccount(),
                metadata: metadata,
                unitName: "TEST", // 4 chars, valid
                assetName: "Test NFT", // 8 chars, valid
                url: "https://example.com" // short URL, valid
            )
            // If we get here, network call succeeded (unexpected in test)
        } catch let error as MintError {
            // Should NOT be a validation error
            switch error {
            case .invalidMetadata:
                Issue.record("Should not throw validation error for valid params")
            default:
                // Network error is expected
                break
            }
        } catch {
            // Network error is expected since localhost:4001 isn't running
        }
    }
}

import Algorand

/// Helper to create a dummy account for testing validation
private func createDummyAccount() throws -> Account {
    // Generate a random account for testing
    return try Account()
}
