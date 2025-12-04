//
//  ConnectionManagerView.swift
//  SwiftDB
//
//  Created by Remon Pel on 03/12/2025.
//

import SwiftUI
import SwiftData

struct ConnectionManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var savedConnections: [ConnectionSettings]

    let dbConnection: DatabaseConnection
    @Binding var isPresented: Bool

    @State private var showNewConnectionSheet = false
    @State private var connectionToEdit: ConnectionSettings?
    @State private var connectingToId: UUID? = nil
    @State private var connectionError: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "cylinder.split.1x2")
                    .font(.title)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("SwiftDB")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Connection Manager")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: { showNewConnectionSheet = true }) {
                    Label("New Connection", systemImage: "plus.circle.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Connection list
            if savedConnections.isEmpty {
                EmptyConnectionsView(onCreateNew: { showNewConnectionSheet = true })
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(savedConnections) { connection in
                            ConnectionCard(
                                connection: connection,
                                isConnecting: connectingToId == connection.id,
                                onConnect: { connectTo(connection) },
                                onEdit: { connectionToEdit = connection },
                                onDelete: { deleteConnection(connection) }
                            )
                        }
                    }
                    .padding()
                }
            }

            // Error display
            if let error = connectionError {
                Divider()
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                    Spacer()
                    Button("Dismiss") {
                        connectionError = nil
                    }
                    .buttonStyle(.borderless)
                }
                .padding()
                .background(Color.red.opacity(0.1))
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .sheet(isPresented: $showNewConnectionSheet) {
            ConnectionSheetView(
                dbConnection: dbConnection,
                isPresented: $showNewConnectionSheet,
                onConnectionSaved: { connection in
                    modelContext.insert(connection)
                    try? modelContext.save()
                },
                onConnectionSuccess: {
                    // Close the connection manager when connection succeeds
                    isPresented = false
                }
            )
        }
        .sheet(item: $connectionToEdit) { connection in
            ConnectionSheetView(
                dbConnection: dbConnection,
                isPresented: Binding(
                    get: { connectionToEdit != nil },
                    set: { if !$0 { connectionToEdit = nil } }
                ),
                existingConnection: connection,
                onConnectionSaved: { updatedConnection in
                    // Update happens automatically via SwiftData
                    try? modelContext.save()
                    connectionToEdit = nil
                }
            )
        }
    }

    private func connectTo(_ connection: ConnectionSettings) {
        connectingToId = connection.id
        connectionError = nil

        Task {
            do {
                try await dbConnection.connect(with: connection)
                isPresented = false
            } catch {
                connectionError = error.localizedDescription
            }
            connectingToId = nil
        }
    }

    private func deleteConnection(_ connection: ConnectionSettings) {
        modelContext.delete(connection)
        try? modelContext.save()
    }
}

struct EmptyConnectionsView: View {
    let onCreateNew: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "externaldrive.badge.plus")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)

            Text("No Saved Connections")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Create your first database connection to get started")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: onCreateNew) {
                Label("Create Connection", systemImage: "plus.circle")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct ConnectionCard: View {
    let connection: ConnectionSettings
    let isConnecting: Bool
    let onConnect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 50, height: 50)

                Image(systemName: iconForDatabase)
                    .font(.title2)
                    .foregroundStyle(.blue)
            }

            // Connection info
            VStack(alignment: .leading, spacing: 4) {
                Text(connection.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    Label(connection.databaseType.rawValue.uppercased(), systemImage: "cylinder")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Label(connectionTypeLabel, systemImage: connectionTypeIcon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if connection.connectionType == .tcp {
                    Text("\(connection.host):\(connection.port)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else if connection.connectionType == .socket {
                    Text(connection.socket ?? "Socket")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else if connection.connectionType == .sshTcp {
                    Text("via \(connection.sshHost ?? "SSH")")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("Edit connection")

                Button(action: onDelete) {
                    Label("Delete", systemImage: "trash")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
                .help("Delete connection")

                if isConnecting {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 80)
                } else {
                    Button(action: onConnect) {
                        Label("Connect", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
        }
        .padding()
        .background(isHovered ? Color.accentColor.opacity(0.05) : Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovered ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var iconForDatabase: String {
        switch connection.databaseType {
        case .mysql:
            return "cylinder"
        case .postgresql:
            return "cylinder.split.1x2"
        case .sqlite:
            return "doc.badge.gearshape"
        }
    }

    private var connectionTypeLabel: String {
        switch connection.connectionType {
        case .tcp:
            return "TCP"
        case .socket:
            return "Socket"
        case .sshTcp:
            return "SSH+TCP"
        }
    }

    private var connectionTypeIcon: String {
        switch connection.connectionType {
        case .tcp:
            return "network"
        case .socket:
            return "point.3.connected.trianglepath.dotted"
        case .sshTcp:
            return "lock.shield"
        }
    }
}

#Preview {
    ConnectionManagerView(
        dbConnection: DatabaseConnection(),
        isPresented: .constant(true)
    )
    .modelContainer(for: ConnectionSettings.self, inMemory: true)
}
