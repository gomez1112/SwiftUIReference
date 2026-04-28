import Foundation
import FoundationModels
import Observation

struct SymbolSummaryContext: Equatable, Sendable {
    let name: String
    let kind: String
    let category: String
    let declaration: String
    let defaultInstantiation: String
    let exampleTitle: String?
    let exampleSummary: String?
    let exampleCode: String?
}

@MainActor
@Observable
final class SymbolSummaryGenerator {
    var summary = ""
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
        summary = ""
        statusMessage = nil
        isStreaming = false
    }

    func generateSummary(for context: SymbolSummaryContext) {
        responseTask?.cancel()
        summary = ""
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
                let stream = session.streamResponse(
                    to: Self.prompt(for: context),
                    options: GenerationOptions(
                        sampling: .greedy,
                        maximumResponseTokens: 140
                    )
                )

                for try await snapshot in stream {
                    try Task.checkCancellation()
                    updateSummary(Self.oneParagraph(snapshot.content), requestID: requestID)
                }

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

    private func updateSummary(_ newSummary: String, requestID: UUID) {
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

        if summary.isEmpty {
            statusMessage = message ?? "The model did not return a summary."
        } else {
            statusMessage = message
        }

        isStreaming = false
    }

    private static let instructions = """
    You explain SwiftUI APIs inside a reference app. Use only the provided \
    symbol metadata and example context. Return exactly one concise paragraph \
    of two to four sentences. Do not use Markdown, headings, bullet points, \
    or code blocks.
    """

    private static func prompt(for context: SymbolSummaryContext) -> String {
        var lines = [
            "Summarize what this SwiftUI \(context.kind.lowercased()) does and when a developer would use it.",
            "Name: \(context.name)",
            "Kind: \(context.kind)",
            "Category: \(context.category)",
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

    private static func oneParagraph(_ value: String) -> String {
        value
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
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
