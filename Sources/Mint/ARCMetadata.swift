@preconcurrency import Foundation

// MARK: - ARC-3 Metadata (Base for all ARC standards)

/// ARC-3 compliant metadata structure
/// https://github.com/algorandfoundation/ARCs/blob/main/ARCs/arc-0003.md
public struct ARC3Metadata: Codable, Sendable, Equatable {
    /// Name of the asset (required)
    public let name: String

    /// Description of the asset
    public let description: String?

    /// URI pointing to the asset's image
    public let image: String?

    /// MIME type of the image
    public let imageMimetype: String?

    /// Integrity hash of the image
    public let imageIntegrity: String?

    /// URI pointing to external content
    public let externalUrl: String?

    /// Background color (hex without #)
    public let backgroundColor: String?

    /// URI pointing to animation
    public let animationUrl: String?

    /// MIME type of animation
    public let animationUrlMimetype: String?

    /// Additional properties
    public let properties: [String: AnyCodable]?

    /// Localization info
    public let localization: Localization?

    /// Extra arbitrary data
    public let extra: [String: AnyCodable]?

    public struct Localization: Codable, Sendable, Equatable {
        public let uri: String
        public let defaultLocale: String
        public let locales: [String]

        enum CodingKeys: String, CodingKey {
            case uri
            case defaultLocale = "default"
            case locales
        }

        public init(uri: String, defaultLocale: String, locales: [String]) {
            self.uri = uri
            self.defaultLocale = defaultLocale
            self.locales = locales
        }
    }

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case image
        case imageMimetype = "image_mimetype"
        case imageIntegrity = "image_integrity"
        case externalUrl = "external_url"
        case backgroundColor = "background_color"
        case animationUrl = "animation_url"
        case animationUrlMimetype = "animation_url_mimetype"
        case properties
        case localization
        case extra
    }

    public init(
        name: String,
        description: String? = nil,
        image: String? = nil,
        imageMimetype: String? = nil,
        imageIntegrity: String? = nil,
        externalUrl: String? = nil,
        backgroundColor: String? = nil,
        animationUrl: String? = nil,
        animationUrlMimetype: String? = nil,
        properties: [String: AnyCodable]? = nil,
        localization: Localization? = nil,
        extra: [String: AnyCodable]? = nil
    ) {
        self.name = name
        self.description = description
        self.image = image
        self.imageMimetype = imageMimetype
        self.imageIntegrity = imageIntegrity
        self.externalUrl = externalUrl
        self.backgroundColor = backgroundColor
        self.animationUrl = animationUrl
        self.animationUrlMimetype = animationUrlMimetype
        self.properties = properties
        self.localization = localization
        self.extra = extra
    }
}

// MARK: - ARC-69 Metadata

/// ARC-69 compliant metadata for mutable NFT metadata stored in note field
/// https://github.com/algorandfoundation/ARCs/blob/main/ARCs/arc-0069.md
public struct ARC69Metadata: Codable, Sendable, Equatable {
    /// Standard identifier
    public let standard: String

    /// Description of the asset
    public let description: String?

    /// URI pointing to external content
    public let externalUrl: String?

    /// Media type
    public let mediaUrl: String?

    /// Attributes/traits
    public let properties: [String: AnyCodable]?

    /// MIME type
    public let mimeType: String?

    enum CodingKeys: String, CodingKey {
        case standard
        case description
        case externalUrl = "external_url"
        case mediaUrl = "media_url"
        case properties
        case mimeType = "mime_type"
    }

    public init(
        description: String? = nil,
        externalUrl: String? = nil,
        mediaUrl: String? = nil,
        properties: [String: AnyCodable]? = nil,
        mimeType: String? = nil
    ) {
        self.standard = "arc69"
        self.description = description
        self.externalUrl = externalUrl
        self.mediaUrl = mediaUrl
        self.properties = properties
        self.mimeType = mimeType
    }

    /// Encode to JSON data for transaction note
    public func toNoteData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }
}

// MARK: - AnyCodable Helper

/// Type-erased Codable value for flexible JSON encoding/decoding
public struct AnyCodable: Codable, Equatable, @unchecked Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unable to encode value"))
        }
    }

    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case is (NSNull, NSNull):
            return true
        case let (l as Bool, r as Bool):
            return l == r
        case let (l as Int, r as Int):
            return l == r
        case let (l as Double, r as Double):
            return l == r
        case let (l as String, r as String):
            return l == r
        default:
            return false
        }
    }
}
