@preconcurrency import Foundation

#if canImport(FoundationNetworking)
@preconcurrency import FoundationNetworking
#endif

// MARK: - Pinata Provider Protocol

/// Protocol for IPFS pinning services (e.g., Pinata)
/// Implement this protocol in your own package or use a Pinata-specific package
public protocol IPFSPinningProvider: Sendable {
    /// Pin JSON metadata and return the CID
    /// - Parameter metadata: The metadata to pin
    /// - Returns: CID of the pinned content
    func pinJSON(_ metadata: ARC3Metadata) async throws -> CID

    /// Pin a file and return the CID
    /// - Parameters:
    ///   - data: File data to pin
    ///   - name: File name
    ///   - mimeType: MIME type of the file
    /// - Returns: CID of the pinned content
    func pinFile(data: Data, name: String, mimeType: String) async throws -> CID

    /// Unpin content by CID
    /// - Parameter cid: CID to unpin
    func unpin(_ cid: CID) async throws

    /// Fetch JSON content from IPFS by CID
    /// - Parameters:
    ///   - cid: The CID of the content to fetch
    ///   - type: The type to decode the JSON into
    /// - Returns: Decoded content
    func fetchJSON<T: Decodable>(_ cid: CID, as type: T.Type) async throws -> T
}

// MARK: - Pin Result

/// Result of a pinning operation
public struct PinResult: Sendable {
    /// The IPFS CID of the pinned content
    public let cid: CID

    /// Size of the pinned content in bytes
    public let size: Int?

    /// Timestamp when content was pinned
    public let timestamp: Date

    public init(cid: CID, size: Int? = nil, timestamp: Date = Date()) {
        self.cid = cid
        self.size = size
        self.timestamp = timestamp
    }
}

// MARK: - IPFS URL Helpers

public extension CID {
    /// Get the IPFS gateway URL for this CID
    /// - Parameter gateway: Gateway base URL (default: ipfs.io)
    /// - Returns: Full URL to access the content
    func gatewayURL(gateway: String = "https://ipfs.io") -> String {
        "\(gateway)/ipfs/\(value)"
    }

    /// Get the native IPFS URI
    var ipfsURI: String {
        "ipfs://\(value)"
    }
}

// MARK: - Default fetchJSON Implementation

public extension IPFSPinningProvider {
    /// Default implementation that fetches from a public IPFS gateway
    /// Providers can override this with their own gateway or dedicated API
    func fetchJSON<T: Decodable>(_ cid: CID, as type: T.Type) async throws -> T {
        try await fetchJSON(cid, as: type, gateway: "https://ipfs.io")
    }

    /// Fetch JSON from a specific IPFS gateway
    func fetchJSON<T: Decodable>(_ cid: CID, as type: T.Type, gateway: String) async throws -> T {
        let urlString = cid.gatewayURL(gateway: gateway)

        guard let url = URL(string: urlString) else {
            throw MintError.networkError("Invalid gateway URL: \(urlString)")
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MintError.networkError("Invalid response type")
        }

        guard httpResponse.statusCode == 200 else {
            throw MintError.networkError("HTTP \(httpResponse.statusCode) from IPFS gateway")
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw MintError.invalidMetadata("Failed to decode JSON: \(error.localizedDescription)")
        }
    }
}

// MARK: - Minter + Pinning Extension

public extension Minter {
    /// Mint an ARC-19 NFT with automatic IPFS pinning
    /// - Parameters:
    ///   - account: The creator/manager account
    ///   - metadata: ARC-3 compliant metadata
    ///   - pinningProvider: IPFS pinning service
    ///   - unitName: Asset unit name (max 8 chars)
    ///   - assetName: Asset name (max 32 chars)
    ///   - freeze: Optional freeze address
    ///   - clawback: Optional clawback address
    /// - Returns: MintResult with asset ID and transaction details
    func mintARC19WithPinning(
        account: Account,
        metadata: ARC3Metadata,
        pinningProvider: some IPFSPinningProvider,
        unitName: String,
        assetName: String,
        freeze: Address? = nil,
        clawback: Address? = nil
    ) async throws -> MintResult {
        // Pin metadata to IPFS
        let cid = try await pinningProvider.pinJSON(metadata)

        // Mint the NFT
        return try await mintARC19(
            account: account,
            metadata: metadata,
            cid: cid,
            unitName: unitName,
            assetName: assetName,
            freeze: freeze,
            clawback: clawback
        )
    }

    /// Update an ARC-19 NFT with automatic IPFS pinning
    /// - Parameters:
    ///   - account: The manager account
    ///   - assetID: The asset to update
    ///   - newMetadata: New ARC-3 compliant metadata
    ///   - pinningProvider: IPFS pinning service
    ///   - manager: New manager address (optional)
    ///   - freeze: New freeze address (optional)
    ///   - clawback: New clawback address (optional)
    /// - Returns: Transaction ID
    func updateARC19WithPinning(
        account: Account,
        assetID: UInt64,
        newMetadata: ARC3Metadata,
        pinningProvider: some IPFSPinningProvider,
        manager: Address? = nil,
        freeze: Address? = nil,
        clawback: Address? = nil
    ) async throws -> String {
        // Pin new metadata to IPFS
        let newCID = try await pinningProvider.pinJSON(newMetadata)

        // Update the NFT
        return try await updateARC19(
            account: account,
            assetID: assetID,
            newCID: newCID,
            manager: manager,
            freeze: freeze,
            clawback: clawback
        )
    }
}
