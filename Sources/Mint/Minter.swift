@preconcurrency import Foundation
import Algorand

// MARK: - Minter Configuration

/// Configuration for the Minter
public struct MinterConfiguration: Sendable {
    public let algodClient: AlgodClient

    public init(algodClient: AlgodClient) {
        self.algodClient = algodClient
    }

    public init(
        algodURL: String,
        algodToken: String? = nil
    ) throws {
        self.algodClient = try AlgodClient(baseURL: algodURL, apiToken: algodToken)
    }
}

// MARK: - Mint Result

/// Result of a minting operation
public struct MintResult: Sendable {
    /// The created asset ID
    public let assetID: UInt64

    /// Transaction ID
    public let transactionID: String

    /// The reserve address (for ARC-19, contains the CID)
    public let reserveAddress: Address?

    /// Creates a new mint result
    ///
    /// - Parameters:
    ///   - assetID: The created asset ID
    ///   - transactionID: Transaction ID
    ///   - reserveAddress: The reserve address (for ARC-19, contains the CID)
    public init(assetID: UInt64, transactionID: String, reserveAddress: Address?) {
        self.assetID = assetID
        self.transactionID = transactionID
        self.reserveAddress = reserveAddress
    }
}

// MARK: - Minter

/// Main minting service for creating and updating NFTs
public actor Minter {
    private let configuration: MinterConfiguration

    public init(configuration: MinterConfiguration) {
        self.configuration = configuration
    }

    // MARK: - ARC-19 Minting

    /// Mint an ARC-19 NFT with mutable metadata via reserve address
    /// - Parameters:
    ///   - account: The creator/manager account
    ///   - metadata: ARC-3 compliant metadata
    ///   - cid: IPFS CID pointing to the metadata JSON
    ///   - unitName: Asset unit name (max 8 chars)
    ///   - assetName: Asset name (max 32 chars)
    ///   - freeze: Optional freeze address
    ///   - clawback: Optional clawback address
    /// - Returns: MintResult with asset ID and transaction details
    public func mintARC19(
        account: Account,
        metadata: ARC3Metadata,
        cid: CID,
        unitName: String,
        assetName: String,
        freeze: Address? = nil,
        clawback: Address? = nil
    ) async throws -> MintResult {
        // Convert CID to reserve address
        let reserveAddress = try cid.toReserveAddress()

        // Create ARC-19 template URL
        let url = cid.toARC19URL()

        // Get transaction parameters
        let params = try await configuration.algodClient.transactionParams()

        // Create asset parameters
        let assetParams = AssetParams(
            total: 1,
            decimals: 0,
            defaultFrozen: false,
            unitName: unitName,
            assetName: assetName,
            url: url,
            metadataHash: nil,
            manager: account.address,
            reserve: reserveAddress,
            freeze: freeze,
            clawback: clawback
        )

        // Create transaction
        let createTxn = AssetCreateTransaction(
            sender: account.address,
            assetParams: assetParams,
            firstValid: params.firstRound,
            lastValid: params.firstRound + 1000,
            genesisID: params.genesisID,
            genesisHash: params.genesisHash
        )

        // Sign and send
        let signedTxn = try SignedTransaction.sign(createTxn, with: account)
        let txid = try await configuration.algodClient.sendTransaction(signedTxn)

        // Wait for confirmation
        let result = try await configuration.algodClient.waitForConfirmation(transactionID: txid)

        guard let assetID = result.assetIndex else {
            throw MintError.transactionFailed("Failed to get asset ID from confirmation")
        }

        return MintResult(
            assetID: assetID,
            transactionID: txid,
            reserveAddress: reserveAddress
        )
    }

    // MARK: - ARC-69 Minting

    /// Mint an ARC-69 NFT with mutable metadata in transaction note
    /// - Parameters:
    ///   - account: The creator/manager account
    ///   - metadata: ARC-69 compliant metadata
    ///   - unitName: Asset unit name (max 8 chars)
    ///   - assetName: Asset name (max 32 chars)
    ///   - url: URL to the asset media
    ///   - metadataHash: Optional hash of the metadata
    ///   - freeze: Optional freeze address
    ///   - clawback: Optional clawback address
    /// - Returns: MintResult with asset ID and transaction details
    public func mintARC69(
        account: Account,
        metadata: ARC69Metadata,
        unitName: String,
        assetName: String,
        url: String,
        metadataHash: Data? = nil,
        freeze: Address? = nil,
        clawback: Address? = nil
    ) async throws -> MintResult {
        // Encode metadata as note
        let noteData = try metadata.toNoteData()

        // Get transaction parameters
        let params = try await configuration.algodClient.transactionParams()

        // Create asset parameters
        let assetParams = AssetParams(
            total: 1,
            decimals: 0,
            defaultFrozen: false,
            unitName: unitName,
            assetName: assetName,
            url: url,
            metadataHash: metadataHash,
            manager: account.address,
            reserve: account.address,
            freeze: freeze,
            clawback: clawback
        )

        // Create transaction with metadata in note
        let createTxn = AssetCreateTransaction(
            sender: account.address,
            assetParams: assetParams,
            firstValid: params.firstRound,
            lastValid: params.firstRound + 1000,
            genesisID: params.genesisID,
            genesisHash: params.genesisHash,
            note: noteData
        )

        // Sign and send
        let signedTxn = try SignedTransaction.sign(createTxn, with: account)
        let txid = try await configuration.algodClient.sendTransaction(signedTxn)

        // Wait for confirmation
        let result = try await configuration.algodClient.waitForConfirmation(transactionID: txid)

        guard let assetID = result.assetIndex else {
            throw MintError.transactionFailed("Failed to get asset ID from confirmation")
        }

        return MintResult(
            assetID: assetID,
            transactionID: txid,
            reserveAddress: nil
        )
    }

    // MARK: - ARC-19 Update

    /// Update an ARC-19 NFT's metadata by changing the reserve address
    /// - Parameters:
    ///   - account: The manager account
    ///   - assetID: The asset to update
    ///   - newCID: New IPFS CID pointing to updated metadata
    ///   - manager: New manager address (optional, keeps current if nil)
    ///   - freeze: New freeze address (optional)
    ///   - clawback: New clawback address (optional)
    /// - Returns: Transaction ID
    public func updateARC19(
        account: Account,
        assetID: UInt64,
        newCID: CID,
        manager: Address? = nil,
        freeze: Address? = nil,
        clawback: Address? = nil
    ) async throws -> String {
        // Convert new CID to reserve address
        let newReserveAddress = try newCID.toReserveAddress()

        // Get transaction parameters
        let params = try await configuration.algodClient.transactionParams()

        // Create config transaction to update reserve
        let configTxn = AssetConfigTransaction.update(
            sender: account.address,
            assetID: assetID,
            manager: manager ?? account.address,
            reserve: newReserveAddress,
            freeze: freeze,
            clawback: clawback,
            firstValid: params.firstRound,
            lastValid: params.firstRound + 1000,
            genesisID: params.genesisID,
            genesisHash: params.genesisHash
        )

        // Sign and send
        let signedTxn = try SignedTransaction.sign(configTxn, with: account)
        let txid = try await configuration.algodClient.sendTransaction(signedTxn)

        // Wait for confirmation
        _ = try await configuration.algodClient.waitForConfirmation(transactionID: txid)

        return txid
    }

    // MARK: - ARC-69 Update

    /// Update an ARC-69 NFT's metadata via a zero-amount transfer
    /// - Parameters:
    ///   - account: The holder account (must hold the NFT)
    ///   - assetID: The asset to update
    ///   - newMetadata: New ARC-69 metadata
    /// - Returns: Transaction ID
    public func updateARC69(
        account: Account,
        assetID: UInt64,
        newMetadata: ARC69Metadata
    ) async throws -> String {
        // Encode new metadata as note
        let noteData = try newMetadata.toNoteData()

        // Get transaction parameters
        let params = try await configuration.algodClient.transactionParams()

        // Create zero-amount transfer to self with new metadata in note
        let transferTxn = AssetTransferTransaction(
            sender: account.address,
            receiver: account.address,
            assetID: assetID,
            amount: 0,
            firstValid: params.firstRound,
            lastValid: params.firstRound + 1000,
            genesisID: params.genesisID,
            genesisHash: params.genesisHash,
            note: noteData
        )

        // Sign and send
        let signedTxn = try SignedTransaction.sign(transferTxn, with: account)
        let txid = try await configuration.algodClient.sendTransaction(signedTxn)

        // Wait for confirmation
        _ = try await configuration.algodClient.waitForConfirmation(transactionID: txid)

        return txid
    }

    // MARK: - Asset Configuration Update

    /// Update asset configuration addresses
    /// - Parameters:
    ///   - account: The manager account
    ///   - assetID: The asset to update
    ///   - manager: New manager address
    ///   - reserve: New reserve address
    ///   - freeze: New freeze address
    ///   - clawback: New clawback address
    /// - Returns: Transaction ID
    public func updateAssetConfig(
        account: Account,
        assetID: UInt64,
        manager: Address? = nil,
        reserve: Address? = nil,
        freeze: Address? = nil,
        clawback: Address? = nil
    ) async throws -> String {
        let params = try await configuration.algodClient.transactionParams()

        let configTxn = AssetConfigTransaction.update(
            sender: account.address,
            assetID: assetID,
            manager: manager,
            reserve: reserve,
            freeze: freeze,
            clawback: clawback,
            firstValid: params.firstRound,
            lastValid: params.firstRound + 1000,
            genesisID: params.genesisID,
            genesisHash: params.genesisHash
        )

        let signedTxn = try SignedTransaction.sign(configTxn, with: account)
        let txid = try await configuration.algodClient.sendTransaction(signedTxn)

        _ = try await configuration.algodClient.waitForConfirmation(transactionID: txid)

        return txid
    }
}
