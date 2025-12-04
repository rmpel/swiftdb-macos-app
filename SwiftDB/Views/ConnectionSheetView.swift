//
//  ConnectionSheetView.swift
//  SwiftDB
//
//  Created by Remon Pel on 03/12/2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct ConnectionSheetView: View {
    let dbConnection: DatabaseConnection
    @Binding var isPresented: Bool
    var existingConnection: ConnectionSettings? = nil
    var onConnectionSaved: ((ConnectionSettings) -> Void)? = nil
    var onConnectionSuccess: (() -> Void)? = nil

    @State private var connectionName = "New Connection"
    @State private var connectionType: ConnectionType = .tcp
    @State private var databaseType: DatabaseType = .mysql

    // Database settings
    @State private var host = "localhost"
    @State private var port = "3306"
    @State private var socket = ""
    @State private var username = "root"
    @State private var password = ""
    @State private var database = ""

    // SSH settings
    @State private var sshHost = ""
    @State private var sshPort = "22"
    @State private var sshUsername = ""
    @State private var sshPassword = ""
    @State private var sshAuthType: SSHAuthType = .systemConfig
    @State private var sshKeyPath = ""
    @State private var sshKeyPassphrase = ""
    @State private var useSystemSSHConfig = true

    @State private var isConnecting = false
    @State private var errorMessage: String?

    private var isEditMode: Bool {
        existingConnection != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Connection") {
                    TextField("Connection Name", text: $connectionName)

                    Picker("Database Type", selection: $databaseType) {
                        Text("MySQL").tag(DatabaseType.mysql)
                        Text("PostgreSQL").tag(DatabaseType.postgresql)
                        Text("SQLite").tag(DatabaseType.sqlite)
                    }
                    .onChange(of: databaseType) { _, newValue in
                        updateDefaultPort(for: newValue)
                    }

                    // Hide connection type for SQLite (file-based, not applicable)
                    if databaseType != .sqlite {
                        Picker("Connection Type", selection: $connectionType) {
                            Text("TCP/IP").tag(ConnectionType.tcp)
                            Text("Socket").tag(ConnectionType.socket)
                            Text("SSH Tunnel (TCP)").tag(ConnectionType.sshTcp)
                        }
                    }
                }

                Section("Database Settings") {
                    if databaseType == .sqlite {
                        HStack {
                            TextField("Database File Path", text: $socket)
                                .help("e.g., /path/to/database.sqlite")
                            Button("Browse...") {
                                selectDatabaseFile()
                            }
                        }
                    } else {
                        if connectionType == .tcp || connectionType == .sshTcp {
                            TextField("Host", text: $host)
                            TextField("Port", text: $port)
                        }

                        if connectionType == .socket {
                            TextField("Socket Path", text: $socket)
                                .help("e.g., /tmp/mysql.sock")
                        }

                        TextField("Username", text: $username)
                        SecureField("Password", text: $password)
                        TextField("Database (optional)", text: $database)
                    }
                }

                if connectionType == .sshTcp {
                    Section("SSH Tunnel Settings") {
                        TextField("SSH Host", text: $sshHost)
                        TextField("SSH Port", text: $sshPort)
                        TextField("SSH Username", text: $sshUsername)

                        Picker("Authentication", selection: $sshAuthType) {
                            Text("System SSH Config").tag(SSHAuthType.systemConfig)
                            Text("Password").tag(SSHAuthType.password)
                            Text("Public Key").tag(SSHAuthType.publicKey)
                            Text("SSH Agent").tag(SSHAuthType.agent)
                        }

                        if sshAuthType == .systemConfig {
                            Toggle("Use ~/.ssh/config", isOn: $useSystemSSHConfig)
                                .help("Read connection settings from your SSH config file")
                        }

                        if sshAuthType == .password {
                            SecureField("SSH Password", text: $sshPassword)
                        }

                        if sshAuthType == .publicKey {
                            HStack {
                                TextField("Key Path", text: $sshKeyPath)
                                Button("Browse...") {
                                    selectSSHKey()
                                }
                            }
                            SecureField("Key Passphrase (optional)", text: $sshKeyPassphrase)
                        }
                    }
                }

                if let error = errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isEditMode ? "Edit Connection" : "New Connection")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                if isEditMode {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            saveConnection()
                        }
                        .disabled(!isFormValid)
                    }
                } else {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Connect") {
                            connectToDatabase()
                        }
                        .disabled(isConnecting || !isFormValid)
                    }

                    ToolbarItem(placement: .secondaryAction) {
                        Button("Save") {
                            saveConnection()
                        }
                        .disabled(!isFormValid)
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    if isConnecting {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
            }
            .onAppear {
                loadExistingConnection()
            }
        }
        .frame(minWidth: 500, minHeight: 600)
    }

    private var isFormValid: Bool {
        guard !connectionName.isEmpty else { return false }

        // SQLite only needs a file path
        if databaseType == .sqlite {
            return !socket.isEmpty
        }

        // For MySQL/PostgreSQL
        let hasValidConnection = (connectionType == .socket ? !socket.isEmpty : !host.isEmpty)
        let hasUsername = !username.isEmpty
        let hasValidSSH = (connectionType == .sshTcp ? !sshHost.isEmpty && !sshUsername.isEmpty : true)

        return hasValidConnection && hasUsername && hasValidSSH
    }

    private func updateDefaultPort(for dbType: DatabaseType) {
        switch dbType {
        case .mysql:
            port = "3306"
        case .postgresql:
            port = "5432"
        case .sqlite:
            port = ""
        }
    }

    private func selectSSHKey() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Select SSH Private Key"

        if panel.runModal() == .OK, let url = panel.url {
            sshKeyPath = url.path
        }
    }

    private func selectDatabaseFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.canCreateDirectories = true
        panel.message = "Select SQLite Database File"
        panel.allowedContentTypes = [.database, .data]
        panel.allowsOtherFileTypes = true

        if panel.runModal() == .OK, let url = panel.url {
            socket = url.path
        }
    }

    private func loadExistingConnection() {
        guard let existing = existingConnection else { return }

        connectionName = existing.name
        connectionType = existing.connectionType
        databaseType = existing.databaseType
        host = existing.host
        port = String(existing.port)
        socket = existing.socket ?? ""
        username = existing.username
        password = existing.password ?? ""
        database = existing.database ?? ""
        sshHost = existing.sshHost ?? ""
        sshPort = String(existing.sshPort)
        sshUsername = existing.sshUsername ?? ""
        sshPassword = existing.sshPassword ?? ""
        sshAuthType = existing.sshAuthType
        sshKeyPath = existing.sshKeyPath ?? ""
        sshKeyPassphrase = existing.sshKeyPassphrase ?? ""
        useSystemSSHConfig = existing.useSystemSSHConfig
    }

    private func createConnectionSettings() -> ConnectionSettings {
        return ConnectionSettings(
            name: connectionName,
            connectionType: connectionType,
            host: host,
            port: Int(port) ?? 3306,
            socket: socket.isEmpty ? nil : socket,
            username: username,
            password: password.isEmpty ? nil : password,
            database: database.isEmpty ? nil : database,
            sshHost: sshHost.isEmpty ? nil : sshHost,
            sshPort: Int(sshPort) ?? 22,
            sshUsername: sshUsername.isEmpty ? nil : sshUsername,
            sshPassword: sshPassword.isEmpty ? nil : sshPassword,
            sshAuthType: sshAuthType,
            sshKeyPath: sshKeyPath.isEmpty ? nil : sshKeyPath,
            sshKeyPassphrase: sshKeyPassphrase.isEmpty ? nil : sshKeyPassphrase,
            useSystemSSHConfig: useSystemSSHConfig,
            databaseType: databaseType
        )
    }

    private func saveConnection() {
        if let existing = existingConnection {
            // Update existing connection
            existing.name = connectionName
            existing.connectionType = connectionType
            existing.databaseType = databaseType
            existing.host = host
            existing.port = Int(port) ?? 3306
            existing.socket = socket.isEmpty ? nil : socket
            existing.username = username
            existing.password = password.isEmpty ? nil : password
            existing.database = database.isEmpty ? nil : database
            existing.sshHost = sshHost.isEmpty ? nil : sshHost
            existing.sshPort = Int(sshPort) ?? 22
            existing.sshUsername = sshUsername.isEmpty ? nil : sshUsername
            existing.sshPassword = sshPassword.isEmpty ? nil : sshPassword
            existing.sshAuthType = sshAuthType
            existing.sshKeyPath = sshKeyPath.isEmpty ? nil : sshKeyPath
            existing.sshKeyPassphrase = sshKeyPassphrase.isEmpty ? nil : sshKeyPassphrase
            existing.useSystemSSHConfig = useSystemSSHConfig

            onConnectionSaved?(existing)
        } else {
            // Create new connection
            let settings = createConnectionSettings()
            onConnectionSaved?(settings)
        }

        isPresented = false
    }

    private func connectToDatabase() {
        errorMessage = nil
        isConnecting = true

        let settings = createConnectionSettings()

        Task {
            do {
                try await dbConnection.connect(with: settings)

                // Auto-save the connection if it's not from CLI and not already saved
                if existingConnection == nil {
                    onConnectionSaved?(settings)
                }

                // Notify parent that connection succeeded
                onConnectionSuccess?()

                isPresented = false
            } catch {
                errorMessage = error.localizedDescription
            }
            isConnecting = false
        }
    }
}

#Preview {
    ConnectionSheetView(
        dbConnection: DatabaseConnection(),
        isPresented: .constant(true)
    )
}
