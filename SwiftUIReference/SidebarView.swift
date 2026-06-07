import SwiftUI

struct SidebarView: View {
    let statusMessage: String
    let totalCount: Int
    let viewCount: Int
    let modifierCount: Int
    let favoriteCount: Int
    let latestRun: IndexRun?
    @Binding var selectedKind: SwiftUISymbolKind?
    @Binding var selectedCategoryID: String?
    @Binding var showsFavoritesOnly: Bool

    var body: some View {
        List {
            Section {
                SidebarBrandCard(totalCount: totalCount, latestRun: latestRun)
            }

            Section("Browse") {
                SidebarFilterRow(
                    title: "All Symbols",
                    systemImage: "square.grid.2x2",
                    count: totalCount,
                    tint: .indigo,
                    isSelected: selectedKind == nil && selectedCategoryID == nil && !showsFavoritesOnly
                ) {
                    showsFavoritesOnly = false
                    selectedKind = nil
                    selectedCategoryID = nil
                }

                SidebarFilterRow(
                    title: "Favorites",
                    systemImage: "star.fill",
                    count: favoriteCount,
                    tint: .yellow,
                    isSelected: showsFavoritesOnly
                ) {
                    showsFavoritesOnly = true
                    selectedKind = nil
                    selectedCategoryID = nil
                }

                SidebarFilterRow(
                    title: "Views",
                    systemImage: SwiftUISymbolKind.view.systemImage,
                    count: viewCount,
                    tint: .teal,
                    isSelected: selectedKind == .view && selectedCategoryID == nil && !showsFavoritesOnly
                ) {
                    showsFavoritesOnly = false
                    selectedKind = .view
                    selectedCategoryID = nil
                }

                SidebarFilterRow(
                    title: "Modifiers",
                    systemImage: SwiftUISymbolKind.modifier.systemImage,
                    count: modifierCount,
                    tint: .orange,
                    isSelected: selectedKind == .modifier && selectedCategoryID == nil && !showsFavoritesOnly
                ) {
                    showsFavoritesOnly = false
                    selectedKind = .modifier
                    selectedCategoryID = nil
                }
            }

            Section("Sync") {
                StatusSummaryView(
                    statusMessage: statusMessage,
                    totalCount: totalCount,
                    latestRun: latestRun
                )
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Reference")
    }
}

private struct SidebarBrandCard: View {
    let totalCount: Int
    let latestRun: IndexRun?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "swift")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.orange.gradient, in: .rect(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text("SwiftUI Reference")
                        .font(.headline)
                    Text("iOS SDK symbol browser")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                SidebarStatChip(title: "Symbols", value: totalCount.formatted())
                SidebarStatChip(title: "Platform", value: latestRun?.platform.ifNotEmpty ?? "iOS")
            }
        }
        .padding(.vertical, 8)
    }
}

private struct SidebarStatChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.bold())
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: .rect(cornerRadius: 8))
    }
}

private struct SidebarFilterRow: View {
    let title: String
    let systemImage: String
    let count: Int
    let tint: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.body)
                    .frame(width: 28, height: 28)
                    .foregroundStyle(isSelected ? .white : tint)
                    .background {
                        if !isSelected {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(tint.opacity(0.14))
                        }
                    }

                Text(title)
                    .font(.callout)
                    .bold(isSelected)
                    .foregroundStyle(.primary)

                Spacer()

                Text(count, format: .number)
                    .font(.caption)
                    .bold()
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? .white.opacity(0.82) : .secondary)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(tint.gradient.opacity(0.9))
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

private struct StatusSummaryView: View {
    let statusMessage: String
    let totalCount: Int
    let latestRun: IndexRun?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label {
                Text(statusMessage)
                    .lineLimit(3)
            } icon: {
                Image(systemName: statusIconName)
                    .foregroundStyle(statusMessage.hasPrefix("Failed") ? .red : .green)
            }
            .font(.footnote)

            if let latestRun {
                VStack(alignment: .leading, spacing: 10) {
                    SidebarMetric(
                        title: "Last Update",
                        value: latestRun.indexedAt.formatted(.dateTime.month().day().hour().minute())
                    )
                    SidebarMetric(title: "SDK", value: latestRun.sdkVersion)
                    SidebarMetric(title: "Total Symbols", value: totalCount.formatted())
                }

                Label(
                    statusMessage.hasPrefix("Saved") || statusMessage == "Ready" ? "Up to date" : "Working",
                    systemImage: "icloud"
                )
                .font(.caption.bold())
                .foregroundStyle(.green)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.green.opacity(0.14), in: .rect(cornerRadius: 7))
            } else {
                Text("No synced symbols yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private var statusIconName: String {
        statusMessage.hasPrefix("Failed") ? "xmark.circle.fill" : "checkmark.circle.fill"
    }
}

private extension String {
    var ifNotEmpty: String? {
        isEmpty ? nil : self
    }
}

private struct SidebarMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }
}
