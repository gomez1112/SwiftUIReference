import SwiftUI

struct SymbolListView: View {
    let symbols: [IndexedSwiftSymbol]
    let totalSymbolCount: Int
    let categorySummaries: [LibraryCategorySummary]
    @Binding var searchText: String
    @Binding var selectedKind: SwiftUISymbolKind?
    @Binding var selectedCategoryID: String?
    @Binding var showsFavoritesOnly: Bool
    @Binding var selectedSymbol: IndexedSwiftSymbol?

    private var selectedSymbolID: String? {
        if let selectedSymbol, symbols.contains(where: { $0.stableID == selectedSymbol.stableID }) {
            return selectedSymbol.stableID
        }

        return symbols.first?.stableID
    }

    var body: some View {
        VStack(spacing: 0) {
            BrowserHeaderView(
                symbolsCount: symbols.count,
                totalSymbolCount: totalSymbolCount,
                categorySummaries: categorySummaries,
                searchText: $searchText,
                selectedKind: $selectedKind,
                selectedCategoryID: $selectedCategoryID,
                showsFavoritesOnly: $showsFavoritesOnly,
                resetAction: resetFilters
            )

            Divider()

            if symbols.isEmpty {
                ContentUnavailableView(
                    "No Symbols",
                    systemImage: "shippingbox",
                    description: Text(showsFavoritesOnly ? "Star symbols from the detail view to build this list." : "Try a different search or category.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(symbols, id: \.stableID) { symbol in
                                Button {
                                    selectedSymbol = symbol
                                } label: {
                                    SymbolRow(
                                        symbol: symbol,
                                        isSelected: selectedSymbolID == symbol.stableID
                                    )
                                }
                                .buttonStyle(.plain)
                                .id(symbol.stableID)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                    .background(.primary.opacity(0.03))
                    .onAppear {
                        ensureSelection()
                    }
                    .onChange(of: symbols.map(\.stableID)) { _, _ in
                        ensureSelection()
                        if let selectedSymbolID {
                            proxy.scrollTo(selectedSymbolID, anchor: .center)
                        }
                    }
                }

                Divider()

                Text(selectionSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
            }
        }
        .navigationTitle("SwiftUI Indexer")
    }

    private var categorySelection: Binding<String> {
        Binding {
            if let selectedKind, let selectedCategoryID {
                return "\(selectedKind.rawValue):\(selectedCategoryID)"
            }

            return "all"
        } set: { value in
            guard value != "all" else {
                selectedCategoryID = nil
                return
            }

            guard let summary = categorySummaries.first(where: { $0.id == value }) else {
                selectedCategoryID = nil
                return
            }

            selectedKind = summary.kind
            selectedCategoryID = summary.categoryID
        }
    }

    private var selectionSummary: String {
        guard
            let selectedSymbolID,
            let index = symbols.firstIndex(where: { $0.stableID == selectedSymbolID })
        else {
            return "\(symbols.count.formatted()) symbols"
        }

        return "\(index + 1) of \(symbols.count.formatted()) selected"
    }

    private func resetFilters() {
        searchText = ""
        selectedKind = nil
        selectedCategoryID = nil
        showsFavoritesOnly = false
    }

    private func ensureSelection() {
        guard !symbols.isEmpty else {
            selectedSymbol = nil
            return
        }

        if let selectedSymbol, symbols.contains(where: { $0.stableID == selectedSymbol.stableID }) {
            return
        }

        selectedSymbol = symbols.first
    }
}

private struct BrowserHeaderView: View {
    let symbolsCount: Int
    let totalSymbolCount: Int
    let categorySummaries: [LibraryCategorySummary]
    @Binding var searchText: String
    @Binding var selectedKind: SwiftUISymbolKind?
    @Binding var selectedCategoryID: String?
    @Binding var showsFavoritesOnly: Bool
    let resetAction: () -> Void

    private var categorySelection: Binding<String> {
        Binding {
            if let selectedKind, let selectedCategoryID {
                return "\(selectedKind.rawValue):\(selectedCategoryID)"
            }

            return "all"
        } set: { value in
            guard value != "all" else {
                showsFavoritesOnly = false
                selectedCategoryID = nil
                return
            }

            guard let summary = categorySummaries.first(where: { $0.id == value }) else {
                selectedCategoryID = nil
                return
            }

            showsFavoritesOnly = false
            selectedKind = summary.kind
            selectedCategoryID = summary.categoryID
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                SearchField(text: $searchText)

                Picker("Category", selection: categorySelection) {
                    Text("All Categories").tag("all")
                    ForEach(categorySummaries) { summary in
                        Text(summary.label).tag(summary.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 210)

                Button(action: resetAction) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.bordered)
                .help("Reset Filters")
            }

            Text("\(symbolsCount.formatted()) symbols")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())

            if showsFavoritesOnly {
                Label("Favorites", systemImage: "star.fill")
                    .font(.footnote)
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(.regularMaterial)
    }
}

private struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Search symbols by name or declaration...", text: $text)
                .textFieldStyle(.plain)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.thinMaterial, in: .rect(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.quaternary, lineWidth: 1)
        }
    }
}

struct SymbolRow: View {
    let symbol: IndexedSwiftSymbol
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            SymbolIcon(kind: symbol.kind, categoryName: symbol.categoryName)

            VStack(alignment: .leading, spacing: 4) {
                Text(symbol.name)
                    .font(.headline)
                    .lineLimit(1)

                Text(symbol.declaration)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(isSelected ? .white.opacity(0.86) : .secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Text(symbol.kind.singularTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.thinMaterial, in: .capsule)

            if symbol.isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(isSelected ? .white : .yellow)
                    .accessibilityLabel("Favorite")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.blue.gradient.opacity(0.72))
            }
        }
        .contentShape(.rect)
    }
}

struct SymbolIcon: View {
    let kind: SwiftUISymbolKind
    let categoryName: String

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(backgroundGradient, in: .rect(cornerRadius: 8))
    }

    private var iconName: String {
        if kind == .modifier {
            return "wand.and.stars"
        }

        switch categoryName {
        case "Layout": return "rectangle.3.group"
        case "Controls": return "rectangle.inset.filled"
        case "Paint": return "paintbrush"
        default: return kind.systemImage
        }
    }

    private var backgroundGradient: LinearGradient {
        let colors: [Color] = kind == .view
        ? [.blue, .cyan.opacity(0.8)]
        : [.purple, .pink.opacity(0.75)]

        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
