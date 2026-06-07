import Foundation
import SwiftData

enum SwiftUISymbolKind: String, Codable, CaseIterable, Identifiable {
    case view
    case modifier

    var id: String { rawValue }

    var title: String {
        switch self {
        case .view: "Views"
        case .modifier: "Modifiers"
        }
    }

    var systemImage: String {
        switch self {
        case .view: "rectangle.stack"
        case .modifier: "slider.horizontal.3"
        }
    }

    var singularTitle: String {
        switch self {
        case .view: "View"
        case .modifier: "Modifier"
        }
    }
}

struct LibraryCategorySummary: Identifiable, Hashable {
    var id: String { "\(kind.rawValue):\(categoryID)" }
    var categoryID: String
    var title: String
    var kind: SwiftUISymbolKind
    var count: Int
    var ordinal: Int

    var label: String {
        "\(kind.title): \(title)"
    }
}

@Model
final class IndexedSwiftSymbol {
    var stableID: String = UUID().uuidString
    var name: String = ""
    var symbolKindRawValue: String = SwiftUISymbolKind.view.rawValue
    var declaration: String = ""
    var libraryTitle: String = ""
    var defaultInstantiation: String = ""
    var categoryID: String = "other"
    var categoryName: String = "Other"
    var categoryOrdinal: Int = 100
    var availability: String = ""
    var moduleName: String = "SwiftUI"
    var platform: String = "iOS"
    var sdkVersion: String = ""
    var lastIndexedAt: Date = Date()
    var isFavorite: Bool = false

    init(
        stableID: String,
        name: String,
        kind: SwiftUISymbolKind,
        declaration: String,
        libraryTitle: String = "",
        defaultInstantiation: String = "",
        categoryID: String = "other",
        categoryName: String = "Other",
        categoryOrdinal: Int = 100,
        availability: String = "",
        moduleName: String = "SwiftUI",
        platform: String = "iOS",
        sdkVersion: String,
        lastIndexedAt: Date = .now,
        isFavorite: Bool = false
    ) {
        self.stableID = stableID
        self.name = name
        self.symbolKindRawValue = kind.rawValue
        self.declaration = declaration
        self.libraryTitle = libraryTitle
        self.defaultInstantiation = defaultInstantiation
        self.categoryID = categoryID
        self.categoryName = categoryName
        self.categoryOrdinal = categoryOrdinal
        self.availability = availability
        self.moduleName = moduleName
        self.platform = platform
        self.sdkVersion = sdkVersion
        self.lastIndexedAt = lastIndexedAt
        self.isFavorite = isFavorite
    }

    var kind: SwiftUISymbolKind {
        get { SwiftUISymbolKind(rawValue: symbolKindRawValue) ?? .view }
        set { symbolKindRawValue = newValue.rawValue }
    }
}

@Model
final class IndexRun {
    var id: String = UUID().uuidString
    var indexedAt: Date = Date()
    var sdkVersion: String = ""
    var platform: String = "iOS"
    var viewCount: Int = 0
    var modifierCount: Int = 0
    var statusMessage: String = "Completed"

    init(
        id: String = UUID().uuidString,
        indexedAt: Date = .now,
        sdkVersion: String,
        platform: String,
        viewCount: Int,
        modifierCount: Int,
        statusMessage: String = "Completed"
    ) {
        self.id = id
        self.indexedAt = indexedAt
        self.sdkVersion = sdkVersion
        self.platform = platform
        self.viewCount = viewCount
        self.modifierCount = modifierCount
        self.statusMessage = statusMessage
    }
}

@Model
final class ManualSymbolExample {
    var id: String = UUID().uuidString
    var symbolStableID: String = ""
    var title: String = ""
    var summary: String = ""
    var code: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: String = UUID().uuidString,
        symbolStableID: String,
        title: String,
        summary: String = "",
        code: String,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.symbolStableID = symbolStableID
        self.title = title
        self.summary = summary
        self.code = code
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct ExtractedSwiftSymbol: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var kind: SwiftUISymbolKind
    var declaration: String
    var libraryTitle: String = ""
    var defaultInstantiation: String = ""
    var categoryID: String = "other"
    var categoryName: String = "Other"
    var categoryOrdinal: Int = 100
    var availability: String = ""
}
