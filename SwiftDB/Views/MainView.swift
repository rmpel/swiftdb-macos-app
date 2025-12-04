//
//  MainView.swift
//  SwiftDB
//
//  Created by Remon Pel on 03/12/2025.
//

import SwiftUI

struct MainView: View {
    @State private var dbConnection = DatabaseConnection()
    @State private var tabManager = TabManager()
    @State private var showConnectionManager = false
    @State private var consoleHeight: CGFloat = 150
    @State private var activityLogHeight: CGFloat = 200
    @State private var sidebarWidth: CGFloat = 250
    @State private var hasCheckedCLIArgs = false
    @State private var isFromCLI = false

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            SidebarView(dbConnection: dbConnection, tabManager: tabManager)
                .frame(minWidth: 200, idealWidth: sidebarWidth)
        } detail: {
            VStack(spacing: 0) {
                if dbConnection.isConnected {
                    // Main content area with tabs
                    TabContentView(dbConnection: dbConnection, tabManager: tabManager)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()

                    // Activity log at the bottom
                    ActivityLogView(activityLog: dbConnection.activityLog)
                        .frame(height: activityLogHeight)
                } else {
                    VStack(spacing: 0) {
                        // Connection manager - shown when not connected
                        Text("Not connected")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .foregroundStyle(.secondary)

                        Divider()

                        // Activity log visible even when not connected
                        ActivityLogView(activityLog: dbConnection.activityLog)
                            .frame(height: activityLogHeight)
                    }
                }
            }
        }
        .focusedValue(\.tabManager, tabManager)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: { showConnectionManager = true }) {
                    Label("Connections", systemImage: "list.bullet")
                }
            }

            ToolbarItem {
                if dbConnection.isConnected {
                    Button(action: {
                        tabManager.openNewQueryTab()
                    }) {
                        Label("New Query", systemImage: "plus.square.on.square")
                    }
                }
            }

            ToolbarItem {
                if dbConnection.isConnected {
                    Button(action: {
                        dbConnection.disconnect()
                        showConnectionManager = true
                    }) {
                        Label("Disconnect", systemImage: "xmark.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showConnectionManager) {
            ConnectionManagerView(
                dbConnection: dbConnection,
                isPresented: $showConnectionManager
            )
        }
        .onAppear {
            // Check for CLI arguments first (only on first launch)
            if !hasCheckedCLIArgs {
                hasCheckedCLIArgs = true

                // Only use CLI args if they exist and haven't been used yet
                if CLIArguments.shared.hasArguments() && !CLIArguments.hasBeenUsedForInitialConnection {
                    // CLI args provided and first window - attempt connection, don't show manager
                    CLIArguments.hasBeenUsedForInitialConnection = true
                    isFromCLI = true
                    checkCLIArgumentsAndConnect()
                } else {
                    // No CLI args OR this is a new window (CMD-N) - always show connection manager
                    showConnectionManager = true
                }
            } else {
                // Subsequent windows should always show connection manager if not connected
                if !dbConnection.isConnected {
                    showConnectionManager = true
                }
            }
        }
    }

    private func checkCLIArgumentsAndConnect() {
        let cliArgs = CLIArguments.shared

        if cliArgs.hasArguments() {
            dbConnection.activityLog.info("CLI arguments detected")

            if let settings = cliArgs.createConnectionSettings() {
                dbConnection.activityLog.info("Connecting with CLI arguments:")
                dbConnection.activityLog.info("  Type: \(settings.databaseType.rawValue)")
                dbConnection.activityLog.info("  Connection: \(settings.connectionType == .socket ? "Socket" : "TCP")")
                if let socket = settings.socket {
                    dbConnection.activityLog.info("  Socket: \(socket)")
                } else {
                    dbConnection.activityLog.info("  Host: \(settings.host):\(settings.port)")
                }
                dbConnection.activityLog.info("  Username: \(settings.username)")
                dbConnection.activityLog.info("  Database: \(settings.database ?? "(none)")")

                Task {
                    do {
                        try await dbConnection.connect(with: settings)
                        dbConnection.activityLog.success("CLI connection successful!")
                    } catch {
                        dbConnection.activityLog.error("CLI connection failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

}

struct WelcomeView: View {
    @Binding var showConnectionSheet: Bool

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "cylinder.split.1x2")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)

            Text("SwiftDB")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Database Management Tool")
                .font(.headline)
                .foregroundStyle(.secondary)

            Button(action: { showConnectionSheet = true }) {
                Label("New Connection", systemImage: "plus.circle")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    MainView()
}
