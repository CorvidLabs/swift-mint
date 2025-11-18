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

    /// Convert CID to reserve address for ARC-19
    /// Uses the raw 32-byte hash from the CID as the address bytes
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

    /// Create a template URL for ARC-19
    /// The template uses `{ipfscid:VERSION:CODEC:FIELD:HASH}` format
    /// Uses the codec detected from the CID by default
    public func toARC19URL(field: String = "reserve") -> String {
        "template-ipfs://{ipfscid:\(version):\(codec):\(field):sha2-256}"
    }
}

// MARK: - Base58 Decoder

private enum Base58 {
    private static let alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

    static func decode(_ string: String) throws -> [UInt8] {
        var result: [UInt8] = [0]

        for char in string {
            guard let index = alphabet.firstIndex(of: char) else {
                throw MintError.invalidCID("Invalid Base58 character: \(char)")
            }

            var carry = alphabet.distance(from: alphabet.startIndex, to: index)

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

// MARK: - Base32 Decoder (RFC 4648)

private enum Base32 {
    private static let alphabet = "abcdefghijklmnopqrstuvwxyz234567"

    static func decode(_ string: String) throws -> [UInt8] {
        var bits = 0
        var value = 0
        var result: [UInt8] = []

        for char in string {
            if char == "=" { break }

            guard let index = alphabet.firstIndex(of: char) else {
                throw MintError.invalidCID("Invalid Base32 character: \(char)")
            }

            value = (value << 5) | alphabet.distance(from: alphabet.startIndex, to: index)
            bits += 5

            if bits >= 8 {
                bits -= 8
                result.append(UInt8((value >> bits) & 0xFF))
            }
        }

        return result
    }
}
