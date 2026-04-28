import Foundation
import SwiftData

@MainActor
struct SymbolStore {
    let context: ModelContext

    func upsert(
        extractedSymbols: [ExtractedSwiftSymbol],
        sdkVersion: String,
        platform: String
    ) throws {
        let existingSymbols = try context.fetch(FetchDescriptor<IndexedSwiftSymbol>())
        var existingByID = Dictionary(grouping: existingSymbols, by: \.stableID)
            .compactMapValues { $0.first }

        for symbol in extractedSymbols {
            if let existing = existingByID[symbol.id] {
                existing.name = symbol.name
                existing.kind = symbol.kind
                existing.declaration = symbol.declaration
                existing.libraryTitle = symbol.libraryTitle
                existing.defaultInstantiation = symbol.defaultInstantiation
                existing.categoryID = symbol.categoryID
                existing.categoryName = symbol.categoryName
                existing.categoryOrdinal = symbol.categoryOrdinal
                existing.availability = symbol.availability
                existing.moduleName = "SwiftUI"
                existing.platform = platform
                existing.sdkVersion = sdkVersion
                existing.lastIndexedAt = .now
            } else {
                let newSymbol = IndexedSwiftSymbol(
                    stableID: symbol.id,
                    name: symbol.name,
                    kind: symbol.kind,
                    declaration: symbol.declaration,
                    libraryTitle: symbol.libraryTitle,
                    defaultInstantiation: symbol.defaultInstantiation,
                    categoryID: symbol.categoryID,
                    categoryName: symbol.categoryName,
                    categoryOrdinal: symbol.categoryOrdinal,
                    availability: symbol.availability,
                    platform: platform,
                    sdkVersion: sdkVersion
                )
                context.insert(newSymbol)
                existingByID[symbol.id] = newSymbol
            }
        }

        let incomingIDs = Set(extractedSymbols.map(\.id))
        for oldSymbol in existingSymbols where !incomingIDs.contains(oldSymbol.stableID) {
            context.delete(oldSymbol)
        }

        let run = IndexRun(
            sdkVersion: sdkVersion,
            platform: platform,
            viewCount: extractedSymbols.filter { $0.kind == .view }.count,
            modifierCount: extractedSymbols.filter { $0.kind == .modifier }.count
        )
        context.insert(run)

        try context.save()
    }
}
