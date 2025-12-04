//
//  ConnectionSettings.swift
//  SwiftDB
//
//  Created by Remon Pel on 03/12/2025.
//

import Foundation
import SwiftData

enum ConnectionType: String, Codable {
    case tcp
    case socket
    case sshTcp
}

enum SSHAuthType: String, Codable {
    case password
    case publicKey
    case agent
    case systemConfig
}

@Model
final class ConnectionSettings {
    var id: UUID
    var name: String
    var connectionType: ConnectionType

    // Database connection
    var host: String
    var port: Int
    var socket: String?
    var username: String
    var password: String?
    var database: String?

    // SSH tunnel settings
    var sshHost: String?
    var sshPort: Int
    var sshUsername: String?
    var sshPassword: String?
    var sshAuthType: SSHAuthType
    var sshKeyPath: String?
    var sshKeyPassphrase: String?
    var useSystemSSHConfig: Bool

    // Database type
    var databaseType: DatabaseType

    init(
        name: String,
        connectionType: ConnectionType = .tcp,
        host: String = "localhost",
        port: Int = 3306,
        socket: String? = nil,
        username: String = "root",
        password: String? = nil,
        database: String? = nil,
        sshHost: String? = nil,
        sshPort: Int = 22,
        sshUsername: String? = nil,
        sshPassword: String? = nil,
        sshAuthType: SSHAuthType = .systemConfig,
        sshKeyPath: String? = nil,
        sshKeyPassphrase: String? = nil,
        useSystemSSHConfig: Bool = true,
        databaseType: DatabaseType = .mysql
    ) {
        self.id = UUID()
        self.name = name
        self.connectionType = connectionType
        self.host = host
        self.port = port
        self.socket = socket
        self.username = username
        self.password = password
        self.database = database
        self.sshHost = sshHost
        self.sshPort = sshPort
        self.sshUsername = sshUsername
        self.sshPassword = sshPassword
        self.sshAuthType = sshAuthType
        self.sshKeyPath = sshKeyPath
        self.sshKeyPassphrase = sshKeyPassphrase
        self.useSystemSSHConfig = useSystemSSHConfig
        self.databaseType = databaseType
    }
}

enum DatabaseType: String, Codable {
    case mysql
    case postgresql
    case sqlite
}
