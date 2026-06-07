import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \IndexedSwiftSymbol.name) private var symbols: [IndexedSwiftSymbol]
    @Query(sort: \IndexRun.indexedAt, order: .reverse) private var indexRuns: [IndexRun]

    @State private var indexer = PlatformIndexer()
    @State private var searchText = ""
    @State private var selectedKind: SwiftUISymbolKind?
    @State private var selectedCategoryID: String?
    @State private var selectedSymbol: IndexedSwiftSymbol?
    @State private var showsFavoritesOnly = false

    private var viewCount: Int {
        symbols.filter { $0.kind == .view }.count
    }

    private var modifierCount: Int {
        symbols.filter { $0.kind == .modifier }.count
    }

    private var favoriteCount: Int {
        symbols.filter(\.isFavorite).count
    }

    private var filteredSymbols: [IndexedSwiftSymbol] {
        symbols.filter { symbol in
            let matchesKind = selectedKind == nil || symbol.kind == selectedKind
            let matchesCategory = selectedCategoryID == nil || symbol.categoryID == selectedCategoryID
            let matchesFavorite = !showsFavoritesOnly || symbol.isFavorite
            let matchesSearch = searchText.isEmpty ||
            symbol.name.localizedStandardContains(searchText) ||
            symbol.libraryTitle.localizedStandardContains(searchText) ||
            symbol.categoryName.localizedStandardContains(searchText) ||
            symbol.declaration.localizedStandardContains(searchText) ||
            symbol.defaultInstantiation.localizedStandardContains(searchText)
            return matchesKind && matchesCategory && matchesFavorite && matchesSearch
        }
    }

    private var categorySummaries: [LibraryCategorySummary] {
        let baseSymbols = symbols.filter { symbol in
            selectedKind == nil || symbol.kind == selectedKind
        }
        let groupedSymbols = Dictionary(grouping: baseSymbols) { symbol in
            "\(symbol.kind.rawValue):\(symbol.categoryID)"
        }

        return groupedSymbols.compactMap { _, symbols in
            guard let first = symbols.first else { return nil }
            return LibraryCategorySummary(
                categoryID: first.categoryID,
                title: first.categoryName,
                kind: first.kind,
                count: symbols.count,
                ordinal: first.categoryOrdinal
            )
        }
        .sorted {
            if $0.kind == $1.kind {
                if $0.ordinal == $1.ordinal { return $0.title < $1.title }
                return $0.ordinal < $1.ordinal
            }
            return $0.kind == .view
        }
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(
                statusMessage: indexer.statusMessage,
                totalCount: symbols.count,
                viewCount: viewCount,
                modifierCount: modifierCount,
                favoriteCount: favoriteCount,
                latestRun: indexRuns.first,
                selectedKind: $selectedKind,
                selectedCategoryID: $selectedCategoryID,
                showsFavoritesOnly: $showsFavoritesOnly
            )
            .navigationSplitViewColumnWidth(min: 250, ideal: 290, max: 330)
        } content: {
            SymbolListView(
                symbols: filteredSymbols,
                totalSymbolCount: symbols.count,
                categorySummaries: categorySummaries,
                searchText: $searchText,
                selectedKind: $selectedKind,
                selectedCategoryID: $selectedCategoryID,
                showsFavoritesOnly: $showsFavoritesOnly,
                selectedSymbol: $selectedSymbol
            )
            .navigationSplitViewColumnWidth(min: 460, ideal: 520, max: 620)
        } detail: {
            SymbolDetailView(symbol: selectedSymbol ?? filteredSymbols.first)
        }
        .navigationTitle("SwiftUI Indexer")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: updateSymbols) {
                    Label(
                        indexer.isUpdating ? "Updating" : "Update SwiftUI Symbols",
                        systemImage: "arrow.clockwise"
                    )
                }
                .disabled(indexer.isUpdating)
                .help("Update SwiftUI Symbols")

                ShareLink(
                    item: exportSummaryText,
                    subject: Text("SwiftUI Indexer Summary")
                ) {
                    Label("Share Summary", systemImage: "square.and.arrow.up")
                }
                .help("Share Summary")
            }
        }
        #if os(macOS)
        .frame(minWidth: 1280, minHeight: 760)
        #endif
    }

    private func updateSymbols() {
        let store = SymbolStore(context: modelContext)
        Task {
            await indexer.updateSymbols(context: store)
        }
    }

    private var exportSummaryText: String {
        "SwiftUI Indexer: \(symbols.count) symbols, \(viewCount) views, \(modifierCount) modifiers, \(favoriteCount) favorites."
    }
}

#Preview {
    RootView()
        .modelContainer(for: [IndexedSwiftSymbol.self, IndexRun.self], inMemory: true)
}
