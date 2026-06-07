import Foundation

struct SymbolGraph: Decodable {
    let symbols: [SymbolGraphSymbol]
    let relationships: [SymbolGraphRelationship]?
}

struct SymbolGraphSymbol: Decodable {
    let identifier: Identifier
    let names: Names
    let kind: Kind
    let declarationFragments: [DeclarationFragment]?
    let availability: [SymbolAvailability]?

    struct Identifier: Decodable {
        let precise: String
    }

    struct Names: Decodable {
        let title: String
    }

    struct Kind: Decodable {
        let identifier: String
        let displayName: String
    }

    struct DeclarationFragment: Decodable {
        let kind: String
        let spelling: String
    }

    var declaration: String {
        declarationFragments?.map(\.spelling).joined() ?? names.title
    }

    var availabilitySummary: String {
        availability?
            .compactMap(\.displayText)
            .joined(separator: ", ") ?? ""
    }

    var isCallable: Bool {
        kind.identifier.contains("func") || kind.identifier.contains("method")
    }

    var isConcreteType: Bool {
        kind.identifier.contains("struct") ||
        kind.identifier.contains("class") ||
        kind.identifier.contains("enum")
    }
}

struct SymbolAvailability: Decodable {
    let domain: String?
    let introduced: SymbolVersion?
    let deprecated: SymbolVersion?
    let obsoleted: SymbolVersion?
    let message: String?

    var displayText: String? {
        guard let domain else { return nil }

        let platform = Self.platformName(for: domain)
        let introducedText = introduced?.displayText
        let unavailableUpperBound = obsoleted?.displayText ?? deprecated?.displayText

        if let introducedText, let unavailableUpperBound {
            return "\(platform) \(introducedText)-\(unavailableUpperBound)"
        }

        if let introducedText {
            return "\(platform) \(introducedText)+"
        }

        if let unavailableUpperBound {
            return "\(platform) through \(unavailableUpperBound)"
        }

        return platform
    }

    private static func platformName(for rawValue: String) -> String {
        switch rawValue.lowercased() {
        case "ios": "iOS"
        case "macos", "macosx": "macOS"
        case "tvos": "tvOS"
        case "watchos": "watchOS"
        case "xros": "visionOS"
        default: rawValue
        }
    }
}

struct SymbolVersion: Decodable {
    let major: Int?
    let minor: Int?
    let patch: Int?

    var displayText: String {
        let major = major ?? 0
        let minor = minor ?? 0

        if let patch, patch > 0 {
            return "\(major).\(minor).\(patch)"
        }

        return "\(major).\(minor)"
    }
}

struct SymbolGraphRelationship: Decodable {
    let kind: String
    let source: String
    let target: String
}
