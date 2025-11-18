import Foundation
import Testing
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
        let metadata = ARC3Metadata(
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
        let metadata = ARC3Metadata(
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
        let metadata = ARC69Metadata(
            description: "An ARC-69 NFT",
            mediaUrl: "https://example.com/image.png"
        )

        #expect(metadata.standard == "arc69")
        #expect(metadata.description == "An ARC-69 NFT")
    }

    @Test("Encode to note data")
    func encodeToNote() throws {
        let metadata = ARC69Metadata(
            description: "Test",
            properties: ["trait": AnyCodable("value")]
        )

        let noteData = try metadata.toNoteData()
        let json = String(data: noteData, encoding: .utf8)

        #expect(json?.contains("\"standard\":\"arc69\"") == true)
    }
}

@Suite("AnyCodable Tests")
struct AnyCodableTests {
    @Test("Encode various types")
    func encodeTypes() throws {
        let encoder = JSONEncoder()

        let stringValue = AnyCodable("test")
        let intValue = AnyCodable(42)
        let boolValue = AnyCodable(true)

        _ = try encoder.encode(stringValue)
        _ = try encoder.encode(intValue)
        _ = try encoder.encode(boolValue)
    }

    @Test("Equality")
    func equality() {
        #expect(AnyCodable("test") == AnyCodable("test"))
        #expect(AnyCodable(42) == AnyCodable(42))
        #expect(AnyCodable(true) == AnyCodable(true))
    }
}
