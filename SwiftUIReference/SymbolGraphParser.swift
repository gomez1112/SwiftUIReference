import Foundation

struct SymbolGraphParser {
    func parseSymbols(
        from directory: URL,
        libraryCatalog: SwiftUILibraryCatalog? = nil
    ) throws -> [ExtractedSwiftSymbol] {
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "json" }

        let decoder = JSONDecoder()
        var allSymbols: [SymbolGraphSymbol] = []
        var allRelationships: [SymbolGraphRelationship] = []

        for file in files {
            let data = try Data(contentsOf: file)
            let graph = try decoder.decode(SymbolGraph.self, from: data)
            allSymbols.append(contentsOf: graph.symbols)
            allRelationships.append(contentsOf: graph.relationships ?? [])
        }

        if let libraryCatalog {
            return parseLibrarySymbols(
                catalog: libraryCatalog,
                symbolGraphSymbols: allSymbols
            )
        }

        let discoveredViewProtocolIDs = allSymbols
            .filter { symbol in
                symbol.names.title == "View" && symbol.kind.identifier.contains("protocol")
            }
            .map(\.identifier.precise)
        let viewProtocolIDs = Set(
            discoveredViewProtocolIDs.isEmpty
            ? ["s:7SwiftUI4ViewP", "s:11SwiftUICore4ViewP"]
            : discoveredViewProtocolIDs
        )

        let viewIDs = Set(
            allRelationships
                .filter { relationship in
                    relationship.kind == "conformsTo" && viewProtocolIDs.contains(relationship.target)
                }
                .map(\.source)
        )

        let views = allSymbols
            .filter { viewIDs.contains($0.identifier.precise) && $0.isConcreteType }
            .map { symbol in
                ExtractedSwiftSymbol(
                    id: symbol.identifier.precise,
                    name: symbol.names.title,
                    kind: .view,
                    declaration: symbol.declaration
                )
            }

        let modifiers = allSymbols
            .filter { symbol in
                symbol.isCallable && symbol.declaration.contains("-> some View")
            }
            .map { symbol in
                ExtractedSwiftSymbol(
                    id: symbol.identifier.precise,
                    name: symbol.names.title,
                    kind: .modifier,
                    declaration: symbol.declaration
                )
            }

        return Array(Set(views + modifiers)).sorted {
            if $0.kind == $1.kind { return $0.name < $1.name }
            return $0.kind.rawValue < $1.kind.rawValue
        }
    }

    private func parseLibrarySymbols(
        catalog: SwiftUILibraryCatalog,
        symbolGraphSymbols: [SymbolGraphSymbol]
    ) -> [ExtractedSwiftSymbol] {
        let graphSymbolsByID = Dictionary(grouping: symbolGraphSymbols) { symbol in
            symbol.identifier.precise.canonicalSymbolID
        }
            .compactMapValues(\.first)

        return (catalog.types + catalog.modifiers)
            .map { item in
                let declaration = graphSymbolsByID[item.id]?.declaration.ifNotEmpty ??
                item.signature.ifNotEmpty ??
                item.defaultInstantiation.ifNotEmpty ??
                item.name

                return ExtractedSwiftSymbol(
                    id: item.id,
                    name: item.name,
                    kind: item.kind,
                    declaration: declaration,
                    libraryTitle: item.title,
                    defaultInstantiation: item.defaultInstantiation,
                    categoryID: item.categoryID,
                    categoryName: item.categoryName,
                    categoryOrdinal: item.categoryOrdinal,
                    availability: item.availability
                )
            }
            .sorted {
                if $0.kind == $1.kind {
                    if $0.categoryOrdinal == $1.categoryOrdinal { return $0.name < $1.name }
                    return $0.categoryOrdinal < $1.categoryOrdinal
                }
                return $0.kind.rawValue < $1.kind.rawValue
            }
    }
}

private extension String {
    var ifNotEmpty: String? {
        isEmpty ? nil : self
    }

    var canonicalSymbolID: String {
        components(separatedBy: "::SYNTHESIZED::").first ?? self
    }
}
