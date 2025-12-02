import Foundation
import Testing
import ARC
@testable import Mint
import Algorand

/// Integration tests for Mint library
/// These tests require a real Algorand network connection and are disabled by default.
///
/// To run these tests, set the following environment variables:
/// - ALGORAND_ALGOD_URL: URL to the Algod node (e.g., "https://testnet-api.algonode.cloud")
/// - ALGORAND_ALGOD_TOKEN: Optional API token for Algod
/// - ALGORAND_INDEXER_URL: URL to the Indexer (e.g., "https://testnet-idx.algonode.cloud")
/// - ALGORAND_INDEXER_TOKEN: Optional API token for Indexer
/// - ALGORAND_TEST_MNEMONIC: 25-word mnemonic for a funded test account
///
/// Example:
/// ```
/// ALGORAND_ALGOD_URL=https://testnet-api.algonode.cloud \
/// ALGORAND_INDEXER_URL=https://testnet-idx.algonode.cloud \
/// ALGORAND_TEST_MNEMONIC="your 25 word mnemonic here" \
/// swift test --filter IntegrationTests
/// ```

/// Check if integration tests should be enabled
private func integrationTestsEnabled() -> Bool {
    ProcessInfo.processInfo.environment["ALGORAND_ALGOD_URL"] != nil &&
    ProcessInfo.processInfo.environment["ALGORAND_TEST_MNEMONIC"] != nil
}

/// Get test configuration from environment
private func getTestConfiguration() throws -> (MinterConfiguration, Account) {
    guard let algodURL = ProcessInfo.processInfo.environment["ALGORAND_ALGOD_URL"] else {
        throw TestError.missingEnvironment("ALGORAND_ALGOD_URL")
    }

    guard let mnemonicString = ProcessInfo.processInfo.environment["ALGORAND_TEST_MNEMONIC"] else {
        throw TestError.missingEnvironment("ALGORAND_TEST_MNEMONIC")
    }

    let algodToken = ProcessInfo.processInfo.environment["ALGORAND_ALGOD_TOKEN"]
    let indexerURL = ProcessInfo.processInfo.environment["ALGORAND_INDEXER_URL"]
    let indexerToken = ProcessInfo.processInfo.environment["ALGORAND_INDEXER_TOKEN"]

    let configuration = try MinterConfiguration(
        algodURL: algodURL,
        algodToken: algodToken,
        indexerURL: indexerURL,
        indexerToken: indexerToken
    )

    // Create account from mnemonic
    let account = try Account(mnemonic: mnemonicString)

    return (configuration, account)
}

private enum TestError: Error {
    case missingEnvironment(String)
}

@Suite("Integration Tests", .disabled(if: !integrationTestsEnabled(), "Set ALGORAND_ALGOD_URL and ALGORAND_TEST_MNEMONIC to enable"))
struct IntegrationTests {

    @Test("ARC-69 full CRUD cycle")
    func arc69CRUDCycle() async throws {
        let (configuration, account) = try getTestConfiguration()
        let minter = Minter(configuration: configuration)

        // CREATE: Mint an ARC-69 NFT
        let metadata = ARC.ARC69Metadata(
            description: "Integration test NFT",
            mediaUrl: "https://example.com/test.png",
            properties: [
                "test": .string("true"),
                "Environment": .string("Test"),
                "Timestamp": .integer(Int(Date().timeIntervalSince1970))
            ]
        )

        let mintResult = try await minter.mintARC69(
            account: account,
            metadata: metadata,
            unitName: "TEST",
            assetName: "Integration Test NFT",
            url: "https://example.com/test.png"
        )

        #expect(mintResult.assetID > 0)
        print("Created ARC-69 NFT with asset ID: \(mintResult.assetID)")

        // READ: Get asset info
        let assetInfo = try await minter.getAssetInfo(assetID: mintResult.assetID)
        #expect(assetInfo.params.name == "Integration Test NFT")
        #expect(assetInfo.params.unitName == "TEST")

        // UPDATE: Update metadata
        let updatedMetadata = ARC.ARC69Metadata(
            description: "Updated integration test NFT",
            mediaUrl: "https://example.com/updated.png",
            properties: ["updated": .string("true")]
        )

        let updateTxID = try await minter.updateARC69(
            account: account,
            assetID: mintResult.assetID,
            newMetadata: updatedMetadata
        )

        #expect(!updateTxID.isEmpty)
        print("Updated ARC-69 NFT with transaction: \(updateTxID)")

        // Wait for indexer to catch up (indexer lags behind algod)
        try await Task.sleep(for: .seconds(5))

        // READ BACK: Verify the updated metadata from chain
        let readBackMetadata = try await minter.getARC69Metadata(assetID: mintResult.assetID)
        #expect(readBackMetadata.description == "Updated integration test NFT", "Description should be updated")
        #expect(readBackMetadata.mediaUrl == "https://example.com/updated.png", "Media URL should be updated")
        print("Verified updated metadata - description: \(readBackMetadata.description ?? "nil")")

        // DELETE: Destroy the asset
        let destroyTxID = try await minter.destroyAsset(
            account: account,
            assetID: mintResult.assetID
        )

        #expect(!destroyTxID.isEmpty)
        print("Destroyed asset with transaction: \(destroyTxID)")
    }

    @Test("ARC-19 full CRUD cycle")
    func arc19CRUDCycle() async throws {
        let (configuration, account) = try getTestConfiguration()
        let minter = Minter(configuration: configuration)

        // Use two different well-known CIDs to simulate image/metadata change
        let originalCID = try CID("QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG")
        let updatedCID = try CID("QmT78zSuBmuS4z925WZfrqQ1qHaJ56DQaTfyMUF7F8ff5o")

        let metadata = ARC.ARC3Metadata(
            name: "ARC-19 Test NFT",
            description: "Integration test for ARC-19",
            image: originalCID.ipfsURI
        )

        // CREATE: Mint an ARC-19 NFT
        let mintResult = try await minter.mintARC19(
            account: account,
            metadata: metadata,
            cid: originalCID,
            unitName: "ARC19",
            assetName: "ARC-19 Test NFT"
        )

        #expect(mintResult.assetID > 0)
        #expect(mintResult.reserveAddress != nil)
        print("Created ARC-19 NFT with asset ID: \(mintResult.assetID)")

        // READ: Verify the asset info
        let assetInfo = try await minter.getAssetInfo(assetID: mintResult.assetID)
        #expect(assetInfo.params.url?.contains("template-ipfs://") == true)
        let originalReserve = assetInfo.params.reserve
        #expect(originalReserve != nil)
        print("Original reserve address: \(originalReserve ?? "nil")")

        // UPDATE: Change to new CID (simulates new image/metadata)
        let updateTxID = try await minter.updateARC19(
            account: account,
            assetID: mintResult.assetID,
            newCID: updatedCID
        )
        #expect(!updateTxID.isEmpty)
        print("Updated ARC-19 NFT with transaction: \(updateTxID)")

        // Verify reserve address changed to encode new CID
        let updatedAssetInfo = try await minter.getAssetInfo(assetID: mintResult.assetID)
        let newReserve = updatedAssetInfo.params.reserve
        #expect(newReserve != originalReserve, "Reserve address should change after update")
        print("Updated reserve address: \(newReserve ?? "nil")")

        // READ BACK: Decode CID from new reserve address and verify it matches
        guard let urlString = updatedAssetInfo.params.url,
              let reserveString = newReserve else {
            throw TestError.missingEnvironment("Asset URL or reserve missing after update")
        }
        let templateURL = try ARC19TemplateURL.parse(urlString)
        let reserveAddress = try Address(string: reserveString)
        let decodedCID = try CID.fromReserveAddress(
            reserveAddress,
            version: templateURL.version,
            codec: templateURL.codec
        )
        #expect(decodedCID.value == updatedCID.value, "Decoded CID should match the updated CID")
        print("Verified CID round-trip - decoded: \(decodedCID.value), expected: \(updatedCID.value)")

        // DELETE: Destroy the asset
        let destroyTxID = try await minter.destroyAsset(
            account: account,
            assetID: mintResult.assetID
        )
        #expect(!destroyTxID.isEmpty)
        print("Destroyed asset with transaction: \(destroyTxID)")
    }

    @Test("Asset configuration update")
    func assetConfigUpdate() async throws {
        let (configuration, account) = try getTestConfiguration()
        let minter = Minter(configuration: configuration)

        // Create a simple NFT
        let metadata = ARC.ARC69Metadata(description: "Config update test")

        let mintResult = try await minter.mintARC69(
            account: account,
            metadata: metadata,
            unitName: "CFG",
            assetName: "Config Test",
            url: "https://example.com"
        )

        // Update config (just the manager, keeping it the same account)
        let updateTxID = try await minter.updateAssetConfig(
            account: account,
            assetID: mintResult.assetID,
            manager: account.address
        )

        #expect(!updateTxID.isEmpty)

        // Clean up
        _ = try await minter.destroyAsset(
            account: account,
            assetID: mintResult.assetID
        )
    }
}

@Suite("Network Connectivity Tests", .disabled(if: !integrationTestsEnabled(), "Set ALGORAND_ALGOD_URL to enable"))
struct NetworkConnectivityTests {

    @Test("Algod client connection")
    func algodConnection() async throws {
        let (configuration, _) = try getTestConfiguration()

        // Test that we can get transaction params (proves connectivity)
        let params = try await configuration.algodClient.transactionParams()
        #expect(params.firstRound > 0)
        #expect(!params.genesisID.isEmpty)
        print("Connected to network: \(params.genesisID), round: \(params.firstRound)")
    }

    @Test("Indexer client connection")
    func indexerConnection() async throws {
        let (configuration, _) = try getTestConfiguration()

        guard let indexer = configuration.indexerClient else {
            print("Indexer not configured, skipping test")
            return
        }

        // Test indexer health
        let health = try await indexer.health()
        print("Indexer health: \(health)")
    }
}
