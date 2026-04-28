import Foundation

struct SwiftUILibraryCatalog {
    let types: [SwiftUILibraryItem]
    let modifiers: [SwiftUILibraryItem]
    let categories: [String: SwiftUILibraryCategory]

    static func load(developerDirectory: URL) throws -> SwiftUILibraryCatalog {
        let contentsURL = developerDirectory
            .appending(path: "Library/Previews/Metadata/SwiftUIMetadata.xcpext/Contents/Resources/Contents.json")
        let categoriesURL = developerDirectory
            .deletingLastPathComponent()
            .appending(path: "SharedFrameworks/PreviewsUI.framework/Versions/A/Resources/LibraryCategories.json")

        let decoder = JSONDecoder()
        let contents = try decoder.decode(
            SwiftUILibraryContents.self,
            from: Data(contentsOf: contentsURL)
        )
        let categories = try decoder.decode(
            [String: SwiftUILibraryCategory].self,
            from: Data(contentsOf: categoriesURL)
        )

        return SwiftUILibraryCatalog(
            types: contents.types.libraryItems(kind: .view, categories: categories),
            modifiers: contents.modifiers.libraryItems(kind: .modifier, categories: categories),
            categories: categories
        )
    }
}

struct SwiftUILibraryItem: Hashable {
    let id: String
    let name: String
    let title: String
    let kind: SwiftUISymbolKind
    let categoryID: String
    let categoryName: String
    let categoryOrdinal: Int
    let signature: String
    let defaultInstantiation: String
    let availability: String
}

struct SwiftUILibraryCategory: Decodable, Hashable {
    let displayName: String
    let ordinal: Int
}

private struct SwiftUILibraryContents: Decodable {
    let types: [String: SwiftUILibraryMetadataEntry]
    let modifiers: [String: SwiftUILibraryMetadataEntry]
}

private struct SwiftUILibraryMetadataEntry: Decodable {
    let availability: String?
    let defaultInstantiation: String?
    let libraryDescription: SwiftUILibraryDescription?
    let overloads: [String: SwiftUILibrarySignature]?
    let initializers: [String: SwiftUILibrarySignature]?
}

private struct SwiftUILibraryDescription: Decodable {
    let category: String?
    let excludedLibraryHosts: [String]?
    let title: String?
    let usr: String?
}

private struct SwiftUILibrarySignature: Decodable {
    let signature: String?
}

private extension Dictionary where Key == String, Value == SwiftUILibraryMetadataEntry {
    func libraryItems(
        kind: SwiftUISymbolKind,
        categories: [String: SwiftUILibraryCategory]
    ) -> [SwiftUILibraryItem] {
        compactMap { key, entry in
            guard
                let description = entry.libraryDescription,
                description.excludedLibraryHosts?.contains("xcode") != true,
                let id = description.usr,
                let categoryID = description.category
            else {
                return nil
            }

            let category = categories[categoryID]
            let signature = entry.preferredSignature(for: id)
            return SwiftUILibraryItem(
                id: id,
                name: kind == .modifier ? signature.ifNotEmpty ?? key : key,
                title: description.title ?? key,
                kind: kind,
                categoryID: categoryID,
                categoryName: category?.displayName ?? "Other",
                categoryOrdinal: category?.ordinal ?? 100,
                signature: signature,
                defaultInstantiation: entry.defaultInstantiation ?? "",
                availability: entry.availability ?? ""
            )
        }
        .sorted {
            if $0.categoryOrdinal == $1.categoryOrdinal { return $0.name < $1.name }
            return $0.categoryOrdinal < $1.categoryOrdinal
        }
    }
}

private extension SwiftUILibraryMetadataEntry {
    func preferredSignature(for id: String) -> String {
        if let signature = overloads?[id]?.signature?.ifNotEmpty {
            return signature
        }

        if let signature = initializers?[id]?.signature?.ifNotEmpty {
            return signature
        }

        return ""
    }
}

private extension String {
    var ifNotEmpty: String? {
        isEmpty ? nil : self
    }
}
