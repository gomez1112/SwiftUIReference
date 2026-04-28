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

    var isCallable: Bool {
        kind.identifier.contains("func") || kind.identifier.contains("method")
    }

    var isConcreteType: Bool {
        kind.identifier.contains("struct") ||
        kind.identifier.contains("class") ||
        kind.identifier.contains("enum")
    }
}

struct SymbolGraphRelationship: Decodable {
    let kind: String
    let source: String
    let target: String
}
