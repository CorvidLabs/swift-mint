@preconcurrency import Foundation
import Algorand
import ARC

// MARK: - Minter Configuration

/// Configuration for the Minter
public struct MinterConfiguration: Sendable {
    public let algodClient: AlgodClient
    public let indexerClient: IndexerClient?

    public init(algodClient: AlgodClient, indexerClient: IndexerClient? = nil) {
        self.algodClient = algodClient
        self.indexerClient = indexerClient
    }

    public init(
        algodURL: String,
        algodToken: String? = nil,
        indexerURL: String? = nil,
        indexerToken: String? = nil
    ) throws {
        self.algodClient = try AlgodClient(baseURL: algodURL, apiToken: algodToken)
        if let indexerURL = indexerURL {
            self.indexerClient = try IndexerClient(baseURL: indexerURL, apiToken: indexerToken)
        } else {
            self.indexerClient = nil
        }
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

    /**
     Creates a new mint result

     - Parameters:
       - assetID: The created asset ID
       - transactionID: Transaction ID
       - reserveAddress: The reserve address (for ARC-19, contains the CID)
     */
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

    // MARK: - Validation

    /**
     Validates asset parameters before minting

     - Parameters:
       - unitName: Asset unit name (max 8 chars)
       - assetName: Asset name (max 32 chars)
       - url: Optional URL (max 256 chars)
     */
    private func validateAssetParams(
        unitName: String,
        assetName: String,
        url: String?
    ) throws {
        guard unitName.count <= 8 else {
            throw MintError.invalidMetadata("Unit name exceeds 8 character limit: \(unitName.count) chars")
        }
        guard assetName.count <= 32 else {
            throw MintError.invalidMetadata("Asset name exceeds 32 character limit: \(assetName.count) chars")
        }
        if let url = url, url.count > 256 {
            throw MintError.invalidMetadata("URL exceeds 256 character limit: \(url.count) chars")
        }
    }

    // MARK: - ARC-19 Minting

    /**
     Mint an ARC-19 NFT with mutable metadata via reserve address

     - Parameters:
       - account: The creator/manager account
       - metadata: ARC-3 compliant metadata
       - cid: IPFS CID pointing to the metadata JSON
       - unitName: Asset unit name (max 8 chars)
       - assetName: Asset name (max 32 chars)
       - freeze: Optional freeze address
       - clawback: Optional clawback address
     - Returns: MintResult with asset ID and transaction details
     */
    public func mintARC19(
        account: Account,
        metadata: ARC.ARC3Metadata,
        cid: CID,
        unitName: String,
        assetName: String,
        freeze: Address? = nil,
        clawback: Address? = nil
    ) async throws -> MintResult {
        // Validate input parameters
        let url = cid.toARC19URL()
        try validateAssetParams(unitName: unitName, assetName: assetName, url: url)

        // Convert CID to reserve address
        let reserveAddress = try cid.toReserveAddress()

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

    /**
     Mint an ARC-69 NFT with mutable metadata in transaction note

     - Parameters:
       - account: The creator/manager account
       - metadata: ARC-69 compliant metadata
       - unitName: Asset unit name (max 8 chars)
       - assetName: Asset name (max 32 chars)
       - url: URL to the asset media
       - metadataHash: Optional hash of the metadata
       - freeze: Optional freeze address
       - clawback: Optional clawback address
     - Returns: MintResult with asset ID and transaction details
     */
    public func mintARC69(
        account: Account,
        metadata: ARC.ARC69Metadata,
        unitName: String,
        assetName: String,
        url: String,
        metadataHash: Data? = nil,
        freeze: Address? = nil,
        clawback: Address? = nil
    ) async throws -> MintResult {
        // Validate input parameters
        try validateAssetParams(unitName: unitName, assetName: assetName, url: url)

        // Encode metadata as note
        let noteData = try metadata.toJSON()

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

    /**
     Update an ARC-19 NFT's metadata by changing the reserve address

     - Parameters:
       - account: The manager account
       - assetID: The asset to update
       - newCID: New IPFS CID pointing to updated metadata
       - manager: New manager address (optional, keeps current if nil)
       - freeze: New freeze address (optional)
       - clawback: New clawback address (optional)
     - Returns: Transaction ID
     */
    public func updateARC19(
        account: Account,
        assetID: UInt64,
        newCID: CID,
        manager: Address? = nil,
        freeze: Address? = nil,
        clawback: Address? = nil
    ) async throws -> String {
        // Pre-flight: Verify asset exists
        _ = try await getAssetInfo(assetID: assetID)

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

    /**
     Update an ARC-69 NFT's metadata via an asset configuration transaction
     Per ARC-69 spec, metadata updates use acfg transactions with JSON in the note field.

     - Parameters:
       - account: The manager account (must be the asset's manager)
       - assetID: The asset to update
       - newMetadata: New ARC-69 metadata
       - manager: New manager address (optional, keeps current if nil)
       - reserve: New reserve address (optional, keeps current if nil)
       - freeze: New freeze address (optional, keeps current if nil)
       - clawback: New clawback address (optional, keeps current if nil)
     - Returns: Transaction ID
     */
    public func updateARC69(
        account: Account,
        assetID: UInt64,
        newMetadata: ARC.ARC69Metadata,
        manager: Address? = nil,
        reserve: Address? = nil,
        freeze: Address? = nil,
        clawback: Address? = nil
    ) async throws -> String {
        // Pre-flight: Verify asset exists
        _ = try await getAssetInfo(assetID: assetID)

        // Encode new metadata as note
        let noteData = try newMetadata.toJSON()

        // Get transaction parameters
        let params = try await configuration.algodClient.transactionParams()

        // Create asset config transaction with new metadata in note
        // Per ARC-69 spec, the manager sends an acfg transaction
        let configTxn = AssetConfigTransaction(
            sender: account.address,
            assetID: assetID,
            manager: manager ?? account.address,
            reserve: reserve,
            freeze: freeze,
            clawback: clawback,
            firstValid: params.firstRound,
            lastValid: params.firstRound + 1000,
            genesisID: params.genesisID,
            genesisHash: params.genesisHash,
            note: noteData
        )

        // Sign and send
        let signedTxn = try SignedTransaction.sign(configTxn, with: account)
        let txid = try await configuration.algodClient.sendTransaction(signedTxn)

        // Wait for confirmation
        _ = try await configuration.algodClient.waitForConfirmation(transactionID: txid)

        return txid
    }

    // MARK: - Asset Configuration Update

    /**
     Update asset configuration addresses

     - Parameters:
       - account: The manager account
       - assetID: The asset to update
       - manager: New manager address
       - reserve: New reserve address
       - freeze: New freeze address
       - clawback: New clawback address
     - Returns: Transaction ID
     */
    public func updateAssetConfig(
        account: Account,
        assetID: UInt64,
        manager: Address? = nil,
        reserve: Address? = nil,
        freeze: Address? = nil,
        clawback: Address? = nil
    ) async throws -> String {
        // Pre-flight: Verify asset exists
        _ = try await getAssetInfo(assetID: assetID)

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

    // MARK: - Read Operations

    /**
     Get asset information from the blockchain

     - Parameter assetID: The asset ID to look up
     - Returns: Asset information including creator, manager, reserve, url, etc.
     */
    public func getAssetInfo(assetID: UInt64) async throws -> AssetInfo {
        try await configuration.algodClient.assetInfo(assetID)
    }

    /**
     Get ARC-19 metadata by fetching from IPFS

     - Parameters:
       - assetID: The asset ID
       - pinningProvider: IPFS provider to fetch the metadata
     - Returns: The ARC-3 metadata
     */
    public func getARC19Metadata(
        assetID: UInt64,
        pinningProvider: some IPFSPinningProvider
    ) async throws -> ARC.ARC3Metadata {
        // Get asset info to retrieve reserve address and URL
        let assetInfo = try await getAssetInfo(assetID: assetID)

        // Parse the template URL to get CID version and codec
        guard let url = assetInfo.params.url else {
            throw MintError.metadataNotFound(assetID)
        }

        let templateURL = try ARC19TemplateURL.parse(url)

        // Get the reserve address which contains the CID hash
        guard let reserveString = assetInfo.params.reserve else {
            throw MintError.metadataNotFound(assetID)
        }

        let reserveAddress = try Address(string: reserveString)

        // Reconstruct the CID from reserve address
        let cid = try CID.fromReserveAddress(
            reserveAddress,
            version: templateURL.version,
            codec: templateURL.codec
        )

        // Fetch metadata from IPFS
        return try await pinningProvider.fetchJSON(cid, as: ARC.ARC3Metadata.self)
    }

    /**
     Get ARC-69 metadata from the most recent asset configuration transaction

     - Parameter assetID: The asset ID
     - Returns: The ARC-69 metadata
     - Note: Requires IndexerClient to be configured
     */
    public func getARC69Metadata(assetID: UInt64) async throws -> ARC.ARC69Metadata {
        guard let indexer = configuration.indexerClient else {
            throw MintError.indexerRequired
        }

        // Get asset info from Algod to find the creator
        let assetInfo = try await getAssetInfo(assetID: assetID)

        let creatorString = assetInfo.params.creator
        let creator = try Address(string: creatorString)

        // Search for transactions from the creator
        // We need to find acfg transactions with ARC-69 metadata in the note
        let txResponse = try await indexer.searchTransactions(
            address: creator,
            limit: 100
        )

        // Filter for acfg transactions for this asset and find the most recent one with ARC-69 metadata
        var latestMetadata: ARC.ARC69Metadata?
        var latestRound: UInt64 = 0

        for tx in txResponse.transactions {
            // Check if this is an acfg transaction for our asset
            if tx.txType == "acfg" {
                // For asset creation, assetID might be nil (it's assigned after creation)
                // For asset updates, assetID should match
                let isRelevantTx: Bool
                if let configTx = tx.assetConfigTransaction {
                    isRelevantTx = configTx.assetID == assetID || configTx.assetID == nil
                } else {
                    isRelevantTx = false
                }

                if isRelevantTx {
                    // Try to decode ARC-69 metadata from the note
                    if let noteData = tx.noteData {
                        if let metadata = try? JSONDecoder().decode(ARC.ARC69Metadata.self, from: noteData),
                           metadata.standard == "arc69" {
                            let round = tx.confirmedRound ?? 0
                            if round >= latestRound {
                                latestRound = round
                                latestMetadata = metadata
                            }
                        }
                    }
                }
            }
        }

        guard let metadata = latestMetadata else {
            throw MintError.metadataNotFound(assetID)
        }

        return metadata
    }

    // MARK: - Delete Operations

    /**
     Destroy an asset

     - Parameters:
       - account: The manager account (must hold all asset units)
       - assetID: The asset to destroy
     - Returns: Transaction ID
     - Note: The account must be the manager AND hold all units of the asset
     */
    public func destroyAsset(
        account: Account,
        assetID: UInt64
    ) async throws -> String {
        // Pre-flight: Verify asset exists
        _ = try await getAssetInfo(assetID: assetID)

        let params = try await configuration.algodClient.transactionParams()

        // Create destroy transaction (all addresses nil = destroy)
        let destroyTxn = AssetConfigTransaction.destroy(
            sender: account.address,
            assetID: assetID,
            firstValid: params.firstRound,
            lastValid: params.firstRound + 1000,
            genesisID: params.genesisID,
            genesisHash: params.genesisHash
        )

        let signedTxn = try SignedTransaction.sign(destroyTxn, with: account)
        let txid = try await configuration.algodClient.sendTransaction(signedTxn)

        _ = try await configuration.algodClient.waitForConfirmation(transactionID: txid)

        return txid
    }
}
