import Foundation
import FoundationModels
import Observation

struct SymbolSummaryContext: Equatable, Sendable {
    let name: String
    let kind: String
    let category: String
    let platform: String
    let sdkVersion: String
    let availability: String
    let declaration: String
    let defaultInstantiation: String
    let exampleTitle: String?
    let exampleSummary: String?
    let exampleCode: String?
}

@Generable
struct SymbolGeneratedSummary: Sendable {
    @Guide(description: "One short sentence explaining what this SwiftUI symbol is")
    let whatItIs: String

    @Guide(description: "One short sentence explaining when a developer should use this symbol")
    let whenToUse: String

    @Guide(description: "A concise availability summary using only the provided platform and SDK metadata")
    let availability: String

    @Guide(description: "One practical note about usage, composition, or common setup")
    let implementationNote: String
}

@MainActor
@Observable
final class SymbolSummaryGenerator {
    var summary: SymbolGeneratedSummary?
    var statusMessage: String?
    var isStreaming = false

    private let model = SystemLanguageModel.default
    private var activeRequestID: UUID?

    @ObservationIgnored
    private var responseTask: Task<Void, Never>?

    var unavailableMessage: String? {
        Self.unavailableMessage(for: model.availability)
    }

    var canGenerate: Bool {
        !isStreaming && unavailableMessage == nil
    }

    func reset() {
        responseTask?.cancel()
        responseTask = nil
        activeRequestID = nil
        summary = nil
        statusMessage = nil
        isStreaming = false
    }

    func generateSummary(for context: SymbolSummaryContext) {
        responseTask?.cancel()
        summary = nil
        statusMessage = nil

        if let unavailableMessage {
            statusMessage = unavailableMessage
            isStreaming = false
            return
        }

        let requestID = UUID()
        activeRequestID = requestID
        isStreaming = true

        responseTask = Task {
            do {
                let session = LanguageModelSession(
                    model: model,
                    instructions: Self.instructions
                )
                let response = try await session.respond(
                    to: Self.prompt(for: context),
                    generating: SymbolGeneratedSummary.self,
                    options: GenerationOptions(
                        sampling: .greedy,
                        maximumResponseTokens: 220
                    )
                )

                try Task.checkCancellation()
                updateSummary(response.content, requestID: requestID)
                finish(requestID: requestID)
            } catch is CancellationError {
                finish(requestID: requestID, cancelled: true)
            } catch {
                finish(
                    requestID: requestID,
                    message: "Could not summarize: \(error.localizedDescription)"
                )
            }
        }
    }

    private func updateSummary(_ newSummary: SymbolGeneratedSummary, requestID: UUID) {
        guard activeRequestID == requestID else { return }
        summary = newSummary
    }

    private func finish(
        requestID: UUID,
        message: String? = nil,
        cancelled: Bool = false
    ) {
        guard activeRequestID == requestID else { return }

        if cancelled {
            isStreaming = false
            return
        }

        if summary == nil {
            statusMessage = message ?? "The model did not return a summary."
        } else {
            statusMessage = message
        }

        isStreaming = false
    }

    private static let instructions = """
    You explain SwiftUI APIs inside a reference app. Use only the provided \
    symbol metadata and example context. Keep every generated field concise, \
    factual, and specific. Do not invent platform availability or version \
    information.
    """

    private static func prompt(for context: SymbolSummaryContext) -> String {
        var lines = [
            "Summarize what this SwiftUI \(context.kind.lowercased()) does and when a developer would use it.",
            "Name: \(context.name)",
            "Kind: \(context.kind)",
            "Category: \(context.category)",
            "Platform: \(context.platform)",
            "SDK version: \(context.sdkVersion)",
            "Availability metadata: \(context.availability)",
            "Declaration: \(context.declaration.limitedForPrompt)"
        ]

        if !context.defaultInstantiation.isEmpty {
            lines.append("Default instantiation: \(context.defaultInstantiation.limitedForPrompt)")
        }

        if let exampleTitle = context.exampleTitle, !exampleTitle.isEmpty {
            lines.append("Selected example: \(exampleTitle)")
        }

        if let exampleSummary = context.exampleSummary, !exampleSummary.isEmpty {
            lines.append("Example summary: \(exampleSummary)")
        }

        if let exampleCode = context.exampleCode, !exampleCode.isEmpty {
            lines.append("Example code: \(exampleCode.limitedForPrompt)")
        }

        return lines.joined(separator: "\n")
    }

    private static func unavailableMessage(
        for availability: SystemLanguageModel.Availability
    ) -> String? {
        switch availability {
        case .available:
            nil
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                "Foundation Models require a device that supports Apple Intelligence."
            case .appleIntelligenceNotEnabled:
                "Turn on Apple Intelligence in Settings to use Foundation Models."
            case .modelNotReady:
                "Foundation Models are still preparing. Try again after the model finishes downloading."
            @unknown default:
                "Foundation Models are not available right now."
            }
        }
    }
}

private extension String {
    var limitedForPrompt: String {
        let maxLength = 1_200
        guard count > maxLength else { return self }
        return "\(prefix(maxLength))..."
    }
}
