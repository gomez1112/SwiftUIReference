//
//  SwiftUIReferenceApp.swift
//  SwiftUIReference
//
//  Created by Gerard Gomez on 4/26/26.
//

import SwiftData
import SwiftUI

@main
struct SwiftUIReferenceApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(Self.sharedModelContainer)
        #if os(macOS)
        .defaultSize(width: 1380, height: 840)
        #endif
    }

    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            IndexedSwiftSymbol.self,
            IndexRun.self,
            ManualSymbolExample.self
        ])

        let configuration = ModelConfiguration(schema: schema,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(
                for: schema,
                configurations: configuration
            )
        } catch {
            fatalError("Could not create SwiftData container: \(error)")
        }
    }()
}
