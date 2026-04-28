import SwiftUI

struct SymbolDetailView: View {
    let symbol: IndexedSwiftSymbol?
    @State private var showInspector = false
    @State private var playgroundState = PlaygroundState()
    @Environment(\.colorScheme) private var colorScheme

    private var interactiveSymbol: InteractiveSymbol? {
        guard let symbol else { return nil }
        return InteractiveSymbol.match(for: symbol)
    }

    var body: some View {
        Group {
            if let symbol {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        SymbolDetailHeader(symbol: symbol)

                        if let interactive = interactiveSymbol {
                            InteractiveExampleSection(
                                symbol: interactive,
                                playgroundState: $playgroundState
                            )
                        } else {
                            HighlightedCodeBlock(title: "Example", code: staticExampleCode(for: symbol))
                        }

                        RelationshipsSection(symbol: symbol)
                        AvailabilitySection(symbol: symbol)
                        HighlightedCodeBlock(title: "Declaration", code: symbol.declaration)
                        MetadataSection(symbol: symbol)
                    }
                    .padding(30)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(.primary.opacity(0.03))
            } else {
                ContentUnavailableView(
                    "Select a Symbol",
                    systemImage: "curlybraces.square",
                    description: Text("Choose a SwiftUI view or modifier to inspect its declaration.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(symbol?.name ?? "Details")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if interactiveSymbol != nil {
                    Button {
                        withAnimation {
                            showInspector.toggle()
                        }
                    } label: {
                        Label("Inspector", systemImage: "sidebar.trailing")
                    }
                    .help("Toggle Inspector")
                }
            }
        }
        .inspector(isPresented: $showInspector) {
            if let interactive = interactiveSymbol {
                PlaygroundInspectorPanel(symbol: interactive, state: $playgroundState)
                    .inspectorColumnWidth(min: 260, ideal: 300, max: 360)
            }
        }
        .onChange(of: symbol?.stableID) {
            if let interactive = interactiveSymbol {
                playgroundState.reset(for: interactive)
            }
            showInspector = false
        }
    }

    /// Static example for non-interactive symbols
    private func staticExampleCode(for symbol: IndexedSwiftSymbol) -> String {
        let rawSnippet = symbol.defaultInstantiation.strippingTokenize
        let snippet = rawSnippet.ifNotEmpty ?? symbol.declaration
        guard symbol.kind == .modifier else {
            return snippet
        }

        let modifierCall = formattedModifierCall(from: snippet.ifNotEmpty ?? symbol.name)
        return """
        Text("Hello, SwiftUI")
            \(modifierCall)
        """
    }

    private func formattedModifierCall(from snippet: String) -> String {
        let cleaned = snippet.strippingTokenize
        let lines = cleaned.components(separatedBy: .newlines)
        guard let first = lines.first else {
            return ".\(cleaned)"
        }

        let firstLine = first.hasPrefix(".") ? first : ".\(first)"
        let remainingLines = lines.dropFirst().map { "    \($0)" }
        return ([firstLine] + remainingLines).joined(separator: "\n")
    }
}

private struct InteractiveExampleSection: View {
    let symbol: InteractiveSymbol
    @Binding var playgroundState: PlaygroundState

    private var selectedExample: SwiftUIExample? {
        playgroundState.selectedExample(for: symbol)
    }

    var body: some View {
        if let selectedExample {
            VStack(alignment: .leading, spacing: 14) {
                if symbol.examples.count > 1 {
                    ExamplePicker(
                        examples: symbol.examples,
                        selection: selectedExampleIDBinding(fallback: selectedExample.id)
                    )
                }

                HighlightedCodeBlock(
                    title: "\(selectedExample.title) Example",
                    code: selectedExample.code(values: playgroundState.values(for: selectedExample))
                )

                LivePreviewCanvas(
                    example: selectedExample,
                    values: playgroundState.values(for: selectedExample)
                )
                .id(selectedExample.id)
            }
            .onAppear {
                playgroundState.prepare(for: symbol)
            }
        }
    }

    private func selectedExampleIDBinding(fallback: String) -> Binding<String> {
        Binding(
            get: { playgroundState.selectedExampleID ?? fallback },
            set: { newValue in
                playgroundState.selectExample(id: newValue, for: symbol)
            }
        )
    }
}

// MARK: - Header

private struct SymbolDetailHeader: View {
    let symbol: IndexedSwiftSymbol

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(symbol.name)
                .font(.system(size: 30, weight: .bold))
                .lineLimit(2)
                .textSelection(.enabled)

            HStack(spacing: 8) {
                DetailPill(
                    title: symbol.kind.singularTitle,
                    color: symbol.kind == .view ? .blue : .purple
                )
                DetailPill(title: symbol.categoryName, color: .secondary)
            }

            Text(symbol.declaration)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
}

private struct DetailPill: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.72), in: .capsule)
    }
}

// MARK: - Highlighted Code Block

struct HighlightedCodeBlock: View {
    let title: String
    let code: String
    @Environment(\.colorScheme) private var colorScheme
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button {
                    copyToClipboard(code)
                    copied = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        copied = false
                    }
                } label: {
                    Label(
                        copied ? "Copied" : "Copy",
                        systemImage: copied ? "checkmark" : "doc.on.doc"
                    )
                    .font(.caption)
                    .foregroundStyle(copied ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .contentTransition(.symbolEffect(.replace))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Text(SwiftSyntaxHighlighter.highlight(code, colorScheme: colorScheme))
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(18)
        .background(codeBackground, in: .rect(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.quaternary, lineWidth: 1)
        }
    }

    private var codeBackground: some ShapeStyle {
        .ultraThinMaterial
    }

    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}

// MARK: - Relationships

private struct RelationshipsSection: View {
    let symbol: IndexedSwiftSymbol

    var body: some View {
        DetailSection(title: "Relationships") {
            InfoRow(
                title: symbol.kind == .view ? "Conforms To" : "Applies To",
                value: "View"
            )
            Divider()
            InfoRow(title: "Module", value: symbol.moduleName)
            Divider()
            InfoRow(title: "Category", value: symbol.categoryName)
        }
    }
}

// MARK: - Availability

private struct AvailabilitySection: View {
    let symbol: IndexedSwiftSymbol

    var body: some View {
        DetailSection(title: "Availability") {
            Text(formattedAvailability)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 2)
        }
    }

    private var formattedAvailability: String {
        guard !symbol.availability.isEmpty else {
            return "\(symbol.platform) SDK \(symbol.sdkVersion)"
        }

        return symbol.availability
            .split(separator: ",")
            .map { platformName(for: String($0)) }
            .joined(separator: ", ")
    }

    private func platformName(for rawValue: String) -> String {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "ios": "iOS"
        case "macosx": "macOS"
        case "tvos": "tvOS"
        case "watchos": "watchOS"
        case "xros": "visionOS"
        default: rawValue
        }
    }
}

// MARK: - Metadata

private struct MetadataSection: View {
    let symbol: IndexedSwiftSymbol

    var body: some View {
        DetailSection(title: "Metadata") {
            InfoRow(title: "Library Title", value: symbol.libraryTitle.ifNotEmpty ?? symbol.name)
            Divider()
            InfoRow(
                title: "Indexed",
                value: symbol.lastIndexedAt.formatted(.dateTime.month().day().hour().minute())
            )
            Divider()
            InfoRow(title: "Stable ID", value: symbol.stableID, monospaced: true)
        }
    }
}

// MARK: - Shared Components

private struct DetailSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            VStack(spacing: 0) {
                content
            }
            .padding(14)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.quaternary, lineWidth: 1)
            }
        }
    }
}

private struct InfoRow: View {
    let title: String
    let value: String
    var monospaced = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 24)
            Text(value)
                .font(monospaced ? .system(.caption, design: .monospaced) : .callout)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - String Extension

private extension String {
    var ifNotEmpty: String? {
        isEmpty ? nil : self
    }
}
