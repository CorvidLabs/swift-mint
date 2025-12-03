@preconcurrency import Foundation
import Algorand

// MARK: - CID (Content Identifier) for IPFS

/// IPFS Content Identifier utilities for ARC-19
public struct CID: Sendable, Equatable {
    /// The raw CID string (e.g., "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi")
    public let value: String

    /// CID version (0 or 1)
    public let version: Int

    /// Codec name for ARC-19 template URL (e.g., "dag-pb", "raw")
    public let codec: String

    public init(_ value: String) throws {
        self.value = value

        // Determine version and codec based on prefix
        if value.hasPrefix("Qm") {
            self.version = 0
            self.codec = "dag-pb"  // CIDv0 is always dag-pb
        } else if value.hasPrefix("bafyb") {
            // CIDv1 with dag-pb codec (0x70)
            self.version = 1
            self.codec = "dag-pb"
        } else if value.hasPrefix("bafkr") {
            // CIDv1 with raw codec (0x55)
            self.version = 1
            self.codec = "raw"
        } else if value.hasPrefix("bafy") || value.hasPrefix("bafk") {
            // Other CIDv1 variants - try to detect from bytes
            self.version = 1
            // Default to raw for bafk, dag-pb for bafy
            self.codec = value.hasPrefix("bafk") ? "raw" : "dag-pb"
        } else {
            throw MintError.invalidCID("Unknown CID format: \(value)")
        }
    }

    /**
     Convert CID to reserve address for ARC-19
     Uses the raw 32-byte hash from the CID as the address bytes
     */
    public func toReserveAddress() throws -> Address {
        let bytes = try cidToBytes()

        guard bytes.count == 32 else {
            throw MintError.invalidCID("CID hash must be 32 bytes for reserve address, got \(bytes.count)")
        }

        return try Address(bytes: Data(bytes))
    }

    /// Extract the raw hash bytes from the CID
    private func cidToBytes() throws -> [UInt8] {
        if version == 0 {
            // CIDv0: Base58 encoded multihash
            return try decodeBase58Multihash(value)
        } else {
            // CIDv1: Multibase encoded
            return try decodeMultibaseCID(value)
        }
    }

    /// Decode a CIDv0 (Base58 multihash)
    private func decodeBase58Multihash(_ cid: String) throws -> [UInt8] {
        let decoded = try Base58.decode(cid)

        // Multihash format: <hash-fn-code><digest-size><digest>
        // For SHA2-256: 0x12 (18) + 0x20 (32) + 32 bytes
        guard decoded.count >= 34,
              decoded[0] == 0x12, // SHA2-256
              decoded[1] == 0x20  // 32 bytes
        else {
            throw MintError.invalidCID("Invalid CIDv0 multihash format")
        }

        return Array(decoded[2...])
    }

    /// Decode a CIDv1 (Multibase encoded)
    private func decodeMultibaseCID(_ cid: String) throws -> [UInt8] {
        // CIDv1 with base32lower prefix 'b'
        guard cid.hasPrefix("b") else {
            throw MintError.invalidCID("Unsupported multibase encoding for CIDv1")
        }

        let base32Part = String(cid.dropFirst())
        let decoded = try Base32.decode(base32Part.lowercased())

        // CIDv1 format: <version><codec><multihash>
        // Skip version (1 byte) and codec (1-2 bytes varint)
        guard decoded.count > 4 else {
            throw MintError.invalidCID("CIDv1 too short")
        }

        // Find multihash start (after version + codec)
        var offset = 1 // Skip version byte (0x01)

        // Skip codec varint
        while offset < decoded.count && decoded[offset] & 0x80 != 0 {
            offset += 1
        }
        offset += 1 // Final byte of varint

        guard offset + 34 <= decoded.count else {
            throw MintError.invalidCID("Invalid CIDv1 structure")
        }

        // Now at multihash: <hash-fn><size><digest>
        guard decoded[offset] == 0x12, // SHA2-256
              decoded[offset + 1] == 0x20 // 32 bytes
        else {
            throw MintError.invalidCID("CIDv1 must use SHA2-256 for ARC-19")
        }

        return Array(decoded[(offset + 2)...])
    }

    /**
     Create a template URL for ARC-19
     The template uses `{ipfscid:VERSION:CODEC:FIELD:HASH}` format
     Uses the codec detected from the CID by default
     */
    public func toARC19URL(field: String = "reserve", suffix: String? = nil) -> String {
        var url = "template-ipfs://{ipfscid:\(version):\(codec):\(field):sha2-256}"
        if let suffix = suffix {
            url += suffix
        }
        return url
    }

    /**
     Reconstruct a CID from a reserve address and template URL parameters

     - Parameters:
       - address: The reserve address containing the 32-byte hash
       - version: CID version (0 or 1)
       - codec: Multicodec name ("dag-pb" or "raw")
     - Returns: Reconstructed CID
     */
    public static func fromReserveAddress(
        _ address: Address,
        version: Int,
        codec: String
    ) throws -> CID {
        let hashBytes = address.bytes

        guard hashBytes.count == 32 else {
            throw MintError.invalidCID("Reserve address must contain 32 bytes, got \(hashBytes.count)")
        }

        // Create multihash: <hash-fn-code><digest-size><digest>
        // SHA2-256: 0x12 (18) + 0x20 (32) + 32 bytes
        var multihash = Data([0x12, 0x20])
        multihash.append(hashBytes)

        if version == 0 {
            // CIDv0: Base58 encoded multihash
            let cidString = Base58.encode(Array(multihash))
            return try CID(cidString)
        } else {
            // CIDv1: <version><codec><multihash> in base32
            var cidBytes = Data()
            cidBytes.append(0x01) // Version 1

            // Add codec varint
            switch codec {
            case "dag-pb":
                cidBytes.append(0x70) // dag-pb codec
            case "raw":
                cidBytes.append(0x55) // raw codec
            default:
                throw MintError.invalidCID("Unsupported codec for CIDv1: \(codec)")
            }

            cidBytes.append(multihash)

            // Encode as base32 with 'b' prefix
            let base32 = Base32.encode(Array(cidBytes))
            let cidString = "b" + base32
            return try CID(cidString)
        }
    }
}

// MARK: - ARC-19 Template URL Parser

/// Parsed ARC-19 template URL
public struct ARC19TemplateURL: Sendable, Equatable {
    /// CID version (0 or 1)
    public let version: Int

    /// Multicodec name (dag-pb, raw)
    public let codec: String

    /// Field name containing the hash (usually "reserve")
    public let field: String

    /// Hash type (usually sha2-256)
    public let hashType: String

    /// Optional suffix path (e.g., "/arc3.json")
    public let suffix: String?

    /**
     Parse an ARC-19 template URL
     Format: template-ipfs://{ipfscid:VERSION:CODEC:FIELD:HASH}[/suffix]
     */
    public static func parse(_ url: String) throws -> ARC19TemplateURL {
        // Check prefix
        guard url.hasPrefix("template-ipfs://") else {
            throw MintError.invalidTemplateURL("Must start with template-ipfs://")
        }

        let afterPrefix = String(url.dropFirst("template-ipfs://".count))

        // Find the template part {ipfscid:...}
        guard afterPrefix.hasPrefix("{ipfscid:") else {
            throw MintError.invalidTemplateURL("Missing {ipfscid:...} template")
        }

        // Find closing brace
        guard let closingBrace = afterPrefix.firstIndex(of: "}") else {
            throw MintError.invalidTemplateURL("Missing closing brace")
        }

        let templateStart = afterPrefix.index(afterPrefix.startIndex, offsetBy: "{ipfscid:".count)
        let templateContent = String(afterPrefix[templateStart..<closingBrace])

        // Parse suffix (everything after the closing brace)
        let afterBrace = afterPrefix.index(after: closingBrace)
        let suffix: String? = afterBrace < afterPrefix.endIndex
            ? String(afterPrefix[afterBrace...])
            : nil

        // Split template into parts: VERSION:CODEC:FIELD:HASH
        let parts = templateContent.split(separator: ":")
        guard parts.count == 4 else {
            throw MintError.invalidTemplateURL("Expected 4 parts (version:codec:field:hash), got \(parts.count)")
        }

        guard let version = Int(parts[0]) else {
            throw MintError.invalidTemplateURL("Invalid version: \(parts[0])")
        }

        guard version == 0 || version == 1 else {
            throw MintError.invalidTemplateURL("Version must be 0 or 1, got \(version)")
        }

        let codec = String(parts[1])
        let field = String(parts[2])
        let hashType = String(parts[3])

        return ARC19TemplateURL(
            version: version,
            codec: codec,
            field: field,
            hashType: hashType,
            suffix: suffix?.isEmpty == true ? nil : suffix
        )
    }
}

// MARK: - Base58 Encoder/Decoder

private enum Base58 {
    private static let alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
    private static let alphabetString = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

    static func encode(_ bytes: [UInt8]) -> String {
        // Count leading zeros
        var leadingZeros = 0
        for byte in bytes {
            if byte == 0 {
                leadingZeros += 1
            } else {
                break
            }
        }

        // Allocate enough space for base58 representation
        let size = bytes.count * 138 / 100 + 1
        var result = [UInt8](repeating: 0, count: size)

        var length = 0
        for byte in bytes {
            var carry = Int(byte)
            var i = 0

            for j in stride(from: size - 1, through: 0, by: -1) {
                if carry == 0 && i >= length { break }
                carry += 256 * Int(result[j])
                result[j] = UInt8(carry % 58)
                carry /= 58
                i += 1
            }

            length = i
        }

        // Skip leading zeros in result
        var startIndex = 0
        while startIndex < size && result[startIndex] == 0 {
            startIndex += 1
        }

        // Build the string
        var output = String(repeating: "1", count: leadingZeros)
        for i in startIndex..<size {
            output.append(alphabet[Int(result[i])])
        }

        return output
    }

    static func decode(_ string: String) throws -> [UInt8] {
        var result: [UInt8] = [0]

        for char in string {
            guard let index = alphabetString.firstIndex(of: char) else {
                throw MintError.invalidCID("Invalid Base58 character: \(char)")
            }

            var carry = alphabetString.distance(from: alphabetString.startIndex, to: index)

            for i in 0..<result.count {
                carry += 58 * Int(result[result.count - 1 - i])
                result[result.count - 1 - i] = UInt8(carry % 256)
                carry /= 256
            }

            while carry > 0 {
                result.insert(UInt8(carry % 256), at: 0)
                carry /= 256
            }
        }

        // Handle leading zeros
        for char in string {
            if char != "1" { break }
            result.insert(0, at: 0)
        }

        return result
    }
}

// MARK: - Base32 Encoder/Decoder (RFC 4648)

private enum Base32 {
    private static let alphabet = Array("abcdefghijklmnopqrstuvwxyz234567")
    private static let alphabetString = "abcdefghijklmnopqrstuvwxyz234567"

    static func encode(_ bytes: [UInt8]) -> String {
        var result = ""
        var bits = 0
        var value = 0

        for byte in bytes {
            value = (value << 8) | Int(byte)
            bits += 8

            while bits >= 5 {
                bits -= 5
                let index = (value >> bits) & 0x1F
                result.append(alphabet[index])
            }
        }

        // Handle remaining bits
        if bits > 0 {
            let index = (value << (5 - bits)) & 0x1F
            result.append(alphabet[index])
        }

        return result
    }

    static func decode(_ string: String) throws -> [UInt8] {
        var bits = 0
        var value = 0
        var result: [UInt8] = []

        for char in string {
            if char == "=" { break }

            guard let index = alphabetString.firstIndex(of: char) else {
                throw MintError.invalidCID("Invalid Base32 character: \(char)")
            }

            value = (value << 5) | alphabetString.distance(from: alphabetString.startIndex, to: index)
            bits += 5

            if bits >= 8 {
                bits -= 8
                result.append(UInt8((value >> bits) & 0xFF))
            }
        }

        return result
    }
}
