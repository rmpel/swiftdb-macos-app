//
//  SidebarView.swift
//  SwiftDB
//
//  Created by Remon Pel on 03/12/2025.
//

import SwiftUI

struct SidebarView: View {
    @Bindable var dbConnection: DatabaseConnection
    @Bindable var tabManager: TabManager
    @State private var expandedDatabases: Set<String> = []
    @State private var loadingDatabases: Set<String> = []

    // Computed properties for filtering databases
    private var visibleDatabases: [DatabaseInfo] {
        let hiddenNames = Preferences.shared.hiddenDatabases
        return dbConnection.databases.filter { !hiddenNames.contains($0.name) }
    }

    private var hiddenDatabases: [DatabaseInfo] {
        let hiddenNames = Preferences.shared.hiddenDatabases
        return dbConnection.databases.filter { hiddenNames.contains($0.name) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Reload buttons at the top
            if dbConnection.isConnected {
                HStack(spacing: 8) {
                    Button(action: reloadDatabases) {
                        Label("Reload Databases", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                    .help("Reload database list")

                    Button(action: reloadTables) {
                        Label("Reload Tables", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                    .help("Reload tables in expanded databases")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))

                Divider()
            }

            List(selection: $dbConnection.selectedDatabase) {
                if dbConnection.isConnected {
                    // Show visible (non-hidden) databases
                    ForEach(visibleDatabases) { database in
                        DatabaseSection(
                            database: database,
                            isExpanded: Binding(
                                get: { expandedDatabases.contains(database.name) },
                                set: { newValue in
                                    if newValue {
                                        expandDatabase(database)
                                    } else {
                                        expandedDatabases.remove(database.name)
                                    }
                                }
                            ),
                            isLoading: loadingDatabases.contains(database.name),
                            dbConnection: dbConnection,
                            tabManager: tabManager
                        )
                    }

                    // Show hidden databases at the bottom if toggle is enabled
                    if Preferences.shared.showHiddenDatabases && !hiddenDatabases.isEmpty {
                        Section(header: Text("Hidden Databases").font(.caption).foregroundStyle(.secondary)) {
                            ForEach(hiddenDatabases) { database in
                                DatabaseSection(
                                    database: database,
                                    isExpanded: Binding(
                                        get: { expandedDatabases.contains(database.name) },
                                        set: { newValue in
                                            if newValue {
                                                expandDatabase(database)
                                            } else {
                                                expandedDatabases.remove(database.name)
                                            }
                                        }
                                    ),
                                    isLoading: loadingDatabases.contains(database.name),
                                    dbConnection: dbConnection,
                                    tabManager: tabManager,
                                    isHidden: true
                                )
                            }
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "No Connection",
                        systemImage: "network.slash",
                        description: Text("Connect to a database to view tables")
                    )
                }
            }
            .navigationTitle("Databases")
            .listStyle(.sidebar)
            .onAppear {
                autoOpenDatabaseIfNeeded()
            }
            .onChange(of: dbConnection.databases) {
                autoOpenDatabaseIfNeeded()
            }
        }
    }

    private func expandDatabase(_ database: DatabaseInfo) {
        expandedDatabases.insert(database.name)

        // Only load tables if not already loaded
        guard database.tables.isEmpty else { return }

        loadingDatabases.insert(database.name)
        Task {
            do {
                let tables = try await dbConnection.loadTables(for: database)
                if let index = dbConnection.databases.firstIndex(where: { $0.id == database.id }) {
                    var updatedDb = dbConnection.databases[index]
                    updatedDb.tables = tables
                    dbConnection.databases[index] = updatedDb
                }
            } catch {
                print("Error loading tables: \(error)")
            }
            loadingDatabases.remove(database.name)
        }
    }

    private func reloadDatabases() {
        Task {
            do {
                // Remember which databases were expanded
                let wasExpanded = expandedDatabases

                // Reload the database list
                try await dbConnection.loadDatabases()

                // Re-expand and reload tables for previously expanded databases
                for dbName in wasExpanded {
                    if let database = dbConnection.databases.first(where: { $0.name == dbName }) {
                        expandedDatabases.insert(dbName)
                        loadingDatabases.insert(dbName)

                        let tables = try await dbConnection.loadTables(for: database)
                        if let index = dbConnection.databases.firstIndex(where: { $0.id == database.id }) {
                            var updatedDb = dbConnection.databases[index]
                            updatedDb.tables = tables
                            dbConnection.databases[index] = updatedDb
                        }

                        loadingDatabases.remove(dbName)
                    }
                }
            } catch {
                print("Error reloading databases: \(error)")
            }
        }
    }

    private func reloadTables() {
        // Reload tables for all expanded databases
        Task {
            for database in dbConnection.databases where expandedDatabases.contains(database.name) {
                loadingDatabases.insert(database.name)
                do {
                    let tables = try await dbConnection.loadTables(for: database)
                    if let index = dbConnection.databases.firstIndex(where: { $0.id == database.id }) {
                        var updatedDb = dbConnection.databases[index]
                        updatedDb.tables = tables
                        dbConnection.databases[index] = updatedDb
                    }
                } catch {
                    print("Error reloading tables for \(database.name): \(error)")
                }
                loadingDatabases.remove(database.name)
            }
        }
    }

    private func autoOpenDatabaseIfNeeded() {
        // Only auto-open if there's exactly one non-hidden database
        guard visibleDatabases.count == 1,
              let singleDatabase = visibleDatabases.first,
              !expandedDatabases.contains(singleDatabase.name) else {
            return
        }

        // Auto-expand the single visible database
        expandDatabase(singleDatabase)
    }
}

struct DatabaseSection: View {
    let database: DatabaseInfo
    @Binding var isExpanded: Bool
    let isLoading: Bool
    let dbConnection: DatabaseConnection
    let tabManager: TabManager
    var isHidden: Bool = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Loading tables...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } else if database.tables.isEmpty {
                Text("No tables")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(database.tables) { table in
                    TableRow(table: table, tabManager: tabManager)
                }
            }
        } label: {
            HStack {
                Label {
                    Text(database.name)
                } icon: {
                    Image(systemName: "cylinder")
                }

                if isLoading {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isExpanded.toggle()
            }
        }
    }
}

struct TableRow: View {
    let table: TableInfo
    let tabManager: TabManager
    @State private var isHovered = false

    var body: some View {
        Label {
            Text(table.name)
        } icon: {
            Image(systemName: "tablecells")
        }
        .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(4)
        .onHover { hovering in
            isHovered = hovering
        }
        .contentShape(Rectangle())
        .onTapGesture {
            tabManager.openTable(table)
        }
        .contextMenu {
            Button("Open in New Tab") {
                tabManager.openTable(table)
            }
            Divider()
            Button("Refresh") {
                // Refresh table info
            }
        }
    }
}

#Preview {
    SidebarView(
        dbConnection: DatabaseConnection(),
        tabManager: TabManager()
    )
}
