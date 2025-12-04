//
//  SwiftDBApp.swift
//  SwiftDB
//
//  Created by Remon Pel on 03/12/2025.
//

import SwiftUI
import SwiftData

// FocusedValues extension to expose TabManager to Scene-level commands
struct TabManagerFocusedValueKey: FocusedValueKey {
    typealias Value = TabManager
}

extension FocusedValues {
    var tabManager: TabManagerFocusedValueKey.Value? {
        get { self[TabManagerFocusedValueKey.self] }
        set { self[TabManagerFocusedValueKey.self] = newValue }
    }
}

@main
struct SwiftDBApp: App {
    @FocusedValue(\.tabManager) private var focusedTabManager: TabManager?

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ConnectionSettings.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)

        Settings {
            SettingsView()
        }

        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Window") {
                    // Open a new window
                    NSApp.sendAction(#selector(NSResponder.newWindowForTab(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            // Override Cmd+W to close tabs instead of windows
            CommandMenu("File") {
                Button("Close Tab") {
                    if let tabManager = focusedTabManager,
                       let selectedTab = tabManager.selectedTab {
                        tabManager.closeTab(selectedTab)
                    } else {
                        // No tab selected - close the window instead
                        // This triggers default Cmd+W behavior
                        NSApplication.shared.keyWindow?.close()
                    }
                }
                .keyboardShortcut("w", modifiers: .command)
                .disabled(focusedTabManager?.selectedTab == nil)
            }

            // View menu for toggling hidden databases
            CommandMenu("View") {
                Toggle("Show Hidden Databases", isOn: Binding(
                    get: { Preferences.shared.showHiddenDatabases },
                    set: { Preferences.shared.showHiddenDatabases = $0 }
                ))
                .keyboardShortcut("h", modifiers: [.command, .shift])
            }
        }
    }
}
