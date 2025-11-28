import Foundation

// MARK: - Mint Errors

/// Errors that can occur during minting operations
public enum MintError: Error, LocalizedError, Sendable {
    case invalidCID(String)
    case invalidMetadata(String)
    case transactionFailed(String)
    case networkError(String)
    case notAuthorized(String)
    case assetNotFound(UInt64)
    case pinningFailed(String)
    case indexerRequired
    case metadataNotFound(UInt64)
    case invalidTemplateURL(String)

    public var errorDescription: String? {
        switch self {
        case .invalidCID(let message):
            return "Invalid CID: \(message)"
        case .invalidMetadata(let message):
            return "Invalid metadata: \(message)"
        case .transactionFailed(let message):
            return "Transaction failed: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .notAuthorized(let message):
            return "Not authorized: \(message)"
        case .assetNotFound(let id):
            return "Asset not found: \(id)"
        case .pinningFailed(let message):
            return "Pinning failed: \(message)"
        case .indexerRequired:
            return "Indexer client is required for this operation"
        case .metadataNotFound(let assetID):
            return "Metadata not found for asset: \(assetID)"
        case .invalidTemplateURL(let url):
            return "Invalid ARC-19 template URL: \(url)"
        }
    }
}
