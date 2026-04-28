import SwiftUI

struct SidebarView: View {
    let statusMessage: String
    let totalCount: Int
    let viewCount: Int
    let modifierCount: Int
    let latestRun: IndexRun?
    @Binding var selectedKind: SwiftUISymbolKind?
    @Binding var selectedCategoryID: String?

    var body: some View {
        List {
            Section("Categories") {
                SidebarFilterRow(
                    title: "All Symbols",
                    systemImage: "square.grid.2x2",
                    count: totalCount,
                    isSelected: selectedKind == nil && selectedCategoryID == nil
                ) {
                    selectedKind = nil
                    selectedCategoryID = nil
                }

                SidebarFilterRow(
                    title: "Views",
                    systemImage: SwiftUISymbolKind.view.systemImage,
                    count: viewCount,
                    isSelected: selectedKind == .view && selectedCategoryID == nil
                ) {
                    selectedKind = .view
                    selectedCategoryID = nil
                }

                SidebarFilterRow(
                    title: "Modifiers",
                    systemImage: SwiftUISymbolKind.modifier.systemImage,
                    count: modifierCount,
                    isSelected: selectedKind == .modifier && selectedCategoryID == nil
                ) {
                    selectedKind = .modifier
                    selectedCategoryID = nil
                }
            }

            Section("Status") {
                StatusSummaryView(
                    statusMessage: statusMessage,
                    totalCount: totalCount,
                    latestRun: latestRun
                )
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("SwiftUI Indexer")
    }
}

private struct SidebarFilterRow: View {
    let title: String
    let systemImage: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 22)
                    .foregroundStyle(isSelected ? .white : .secondary)

                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(.primary)

                Spacer()

                Text(count, format: .number)
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? .white.opacity(0.82) : .secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.blue.gradient.opacity(0.72))
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
        VStack(alignment: .leading, spacing: 18) {
            Label {
                Text(statusMessage)
                    .lineLimit(2)
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

                Text(statusMessage.hasPrefix("Saved") || statusMessage == "Ready" ? "Up to date" : "Working")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.green.opacity(0.16), in: .capsule)
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
