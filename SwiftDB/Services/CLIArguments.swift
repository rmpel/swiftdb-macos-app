//
//  CLIArguments.swift
//  SwiftDB
//
//  Created by Remon Pel on 03/12/2025.
//

import Foundation

@Observable
class CLIArguments {
    var socket: String?
    var host: String?
    var port: Int?
    var username: String?
    var password: String?
    var database: String?
    var databaseType: DatabaseType?

    static let shared = CLIArguments()
    static var hasBeenUsedForInitialConnection = false

    private init() {
        parseArguments()
    }

    private func parseArguments() {
        let args = CommandLine.arguments

        var i = 1
        while i < args.count {
            let arg = args[i]

            switch arg {
            case "--socket":
                i += 1
                if i < args.count {
                    socket = args[i]
                }
            case "--host":
                i += 1
                if i < args.count {
                    host = args[i]
                }
            case "--port":
                i += 1
                if i < args.count {
                    port = Int(args[i])
                }
            case "--user", "--username":
                i += 1
                if i < args.count {
                    username = args[i]
                }
            case "--password":
                i += 1
                if i < args.count {
                    password = args[i]
                }
            case "--database", "--db":
                i += 1
                if i < args.count {
                    database = args[i]
                }
            case "--type":
                i += 1
                if i < args.count {
                    databaseType = DatabaseType(rawValue: args[i].lowercased())
                }
            default:
                break
            }

            i += 1
        }
    }

    func hasArguments() -> Bool {
        return socket != nil || host != nil
    }

    func createConnectionSettings() -> ConnectionSettings? {
        guard hasArguments() else { return nil }

        let connectionType: ConnectionType = socket != nil ? .socket : .tcp
        let dbType = databaseType ?? .mysql

        return ConnectionSettings(
            name: "CLI Debug Connection",
            connectionType: connectionType,
            host: host ?? "localhost",
            port: port ?? 3306,
            socket: socket,
            username: username ?? "root",
            password: password,
            database: database,
            sshHost: nil,
            sshPort: 22,
            sshUsername: nil,
            sshPassword: nil,
            sshAuthType: .systemConfig,
            sshKeyPath: nil,
            sshKeyPassphrase: nil,
            useSystemSSHConfig: false,
            databaseType: dbType
        )
    }
}
