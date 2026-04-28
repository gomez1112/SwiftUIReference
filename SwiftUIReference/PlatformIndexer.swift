import Foundation

#if os(macOS)
@Observable
final class PlatformIndexer {
    var isUpdating = false
    var statusMessage = "Ready"
    var latestExtractedCount = 0

    func updateSymbols(context: SymbolStore) async {
        isUpdating = true
        statusMessage = "Preparing symbol graph folder…"

        do {
            let workingDirectory = URL.temporaryDirectory
                .appending(path: "SwiftUIIndexerCloud", directoryHint: .isDirectory)
            let outputDirectory = workingDirectory
                .appending(path: "SwiftUISymbols", directoryHint: .isDirectory)

            try? FileManager.default.removeItem(at: workingDirectory)
            try FileManager.default.createDirectory(
                at: outputDirectory,
                withIntermediateDirectories: true
            )

            statusMessage = "Finding installed iOS SDK…"
            let sdkPath = try await runCommand(
                executable: "/usr/bin/xcrun",
                arguments: ["--sdk", "iphoneos", "--show-sdk-path"]
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)

            let sdkVersion = try await runCommand(
                executable: "/usr/bin/xcrun",
                arguments: ["--sdk", "iphoneos", "--show-sdk-version"]
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)

            statusMessage = "Loading Xcode Library metadata…"
            let developerDirectoryPath = try await runCommand(
                executable: "/usr/bin/xcode-select",
                arguments: ["-p"]
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
            let libraryCatalog = try SwiftUILibraryCatalog.load(
                developerDirectory: URL(filePath: developerDirectoryPath)
            )

            statusMessage = "Extracting SwiftUI symbols from iOS \(sdkVersion)…"
            try await runSymbolGraphExtract(sdkPath: sdkPath, outputDirectory: outputDirectory)

            statusMessage = "Parsing views and modifiers…"
            let parser = SymbolGraphParser()
            let symbols = try parser.parseSymbols(
                from: outputDirectory,
                libraryCatalog: libraryCatalog
            )
            guard !symbols.isEmpty else {
                throw IndexerError.noSymbolsExtracted
            }
            latestExtractedCount = symbols.count

            statusMessage = "Saving \(symbols.count) symbols to SwiftData…"
            try context.upsert(
                extractedSymbols: symbols,
                sdkVersion: sdkVersion,
                platform: "iOS"
            )

            statusMessage = "Saved \(symbols.count) symbols. iCloud will sync to iPhone and iPad."
        } catch {
            statusMessage = "Failed: \(error.localizedDescription)"
        }

        isUpdating = false
    }

    private func runSymbolGraphExtract(sdkPath: String, outputDirectory: URL) async throws {
        _ = try await runCommand(
            executable: "/usr/bin/xcrun",
            arguments: [
                "swift-symbolgraph-extract",
                "-module-name", "SwiftUI",
                "-target", "arm64-apple-ios26.0",
                "-sdk", sdkPath,
                "-pretty-print",
                "-output-dir", outputDirectory.path()
            ]
        )
    }

    private func runCommand(executable: String, arguments: [String]) async throws -> String {
        try await Task.detached {
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            let output = String(data: outputData, encoding: .utf8) ?? ""
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

            guard process.terminationStatus == 0 else {
                throw IndexerError.commandFailed(errorOutput)
            }

            return output
        }
        .value
    }
}
#else
@Observable
final class PlatformIndexer {
    var isUpdating = false
    var statusMessage = "iPhone and iPad browse symbols synced from macOS through iCloud."

    func updateSymbols(context: SymbolStore) async {
        statusMessage = "Run Update SwiftUI Symbols on macOS to refresh this database."
    }
}
#endif

enum IndexerError: LocalizedError {
    case commandFailed(String)
    case noSymbolsExtracted

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            message.isEmpty ? "The command failed." : message
        case .noSymbolsExtracted:
            "SwiftUI symbol extraction completed, but no views or modifiers were parsed."
        }
    }
}
