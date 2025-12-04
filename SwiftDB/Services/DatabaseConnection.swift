//
//  DatabaseConnection.swift
//  SwiftDB
//
//  Created by Remon Pel on 03/12/2025.
//

import Foundation

@Observable
class DatabaseConnection {
    var isConnected = false
    var currentConnection: ConnectionSettings?
    var databases: [DatabaseInfo] = []
    var selectedDatabase: DatabaseInfo?
    var errorMessage: String?
    var activityLog = ActivityLog()

    private var sshTunnel: SSHTunnel?
    private var mysqlConnector: MySQLConnector?
    private var postgresConnector: PostgreSQLConnector?
    private var sqliteConnector: SQLiteConnector?

    func connect(with settings: ConnectionSettings) async throws {
        activityLog.clear()
        activityLog.info("=== Starting connection ===")
        activityLog.info("Connection name: \(settings.name)")
        activityLog.info("Connection type: \(settings.connectionType.rawValue)")
        activityLog.info("Database type: \(settings.databaseType.rawValue)")

        if settings.connectionType == .tcp {
            activityLog.info("Using TCP connection to \(settings.host):\(settings.port)")
        } else if settings.connectionType == .socket {
            activityLog.info("Using Unix socket: \(settings.socket ?? "NOT SET")")
        } else if settings.connectionType == .sshTcp {
            activityLog.info("Using SSH tunnel (TCP) via \(settings.sshHost ?? ""):\(settings.sshPort)")
            activityLog.info("Remote endpoint: \(settings.host):\(settings.port)")
        }

        activityLog.info("Username: \(settings.username)")
        activityLog.info("Database: \(settings.database ?? "(default)")")

        currentConnection = settings

        // Setup SSH tunnel if needed
        if settings.connectionType == .sshTcp {
            activityLog.info("Setting up SSH tunnel...")
            try await setupSSHTunnel(settings)
        }

        // Connect to database
        activityLog.info("Connecting to database...")
        try await connectToDatabase(settings)

        // Load databases
        activityLog.info("Loading database list...")
        try await loadDatabases()

        isConnected = true
        activityLog.success("✓ Connection established successfully!")
        activityLog.info("Found \(databases.count) databases")
    }

    func disconnect() {
        Task {
            await mysqlConnector?.disconnect()
            await postgresConnector?.disconnect()
            await sqliteConnector?.disconnect()
        }
        mysqlConnector = nil
        postgresConnector = nil
        sqliteConnector = nil
        sshTunnel?.stop()
        sshTunnel = nil
        isConnected = false
        currentConnection = nil
        databases = []
        selectedDatabase = nil
    }

    private func setupSSHTunnel(_ settings: ConnectionSettings) async throws {
        guard let sshHost = settings.sshHost else {
            throw DatabaseError.invalidSSHSettings
        }

        let tunnel = SSHTunnel(
            host: sshHost,
            port: settings.sshPort,
            username: settings.sshUsername ?? "",
            authType: settings.sshAuthType,
            password: settings.sshPassword,
            keyPath: settings.sshKeyPath,
            keyPassphrase: settings.sshKeyPassphrase,
            useSystemConfig: settings.useSystemSSHConfig,
            remoteHost: settings.host,
            remotePort: settings.port
        )

        try await tunnel.start()
        self.sshTunnel = tunnel
        activityLog.info("Local tunnel port: \(tunnel.localPort)")
    }

    private func connectToDatabase(_ settings: ConnectionSettings) async throws {
        // Determine connection parameters based on connection type
        var useSocket = false
        var socketPath: String?
        var host = settings.host
        var port = settings.port

        switch settings.connectionType {
        case .tcp:
            activityLog.info("Using direct TCP connection")
            activityLog.info("Target: \(host):\(port)")

        case .socket:
            activityLog.info("Using Unix socket connection")
            guard let socket = settings.socket, !socket.isEmpty else {
                activityLog.error("Socket path is not set!")
                throw DatabaseError.connectionFailed("Socket path is required for socket connections")
            }
            useSocket = true
            socketPath = socket
            activityLog.info("Socket path: \(socket)")

        case .sshTcp:
            activityLog.info("SSH tunnel established, connecting via localhost")
            host = "127.0.0.1"
            port = sshTunnel?.localPort ?? 13306 // Use dynamically allocated tunnel port
            activityLog.info("Local tunnel endpoint: \(host):\(port)")
        }

        // Connect based on database type
        do {
            switch settings.databaseType {
            case .mysql:
                activityLog.info("Initializing MySQL connector...")
                let connector = MySQLConnector()

                if useSocket, let socketPath = socketPath {
                    activityLog.info("Connecting via MySQL socket: \(socketPath)")
                    try await connector.connectViaSocket(
                        socketPath: socketPath,
                        username: settings.username,
                        password: settings.password,
                        database: settings.database,
                        activityLog: activityLog
                    )
                } else {
                    activityLog.info("Connecting via MySQL TCP: \(host):\(port)")
                    try await connector.connect(
                        host: host,
                        port: port,
                        username: settings.username,
                        password: settings.password,
                        database: settings.database,
                        activityLog: activityLog
                    )
                }
                self.mysqlConnector = connector
                activityLog.success("✓ MySQL connector initialized")

            case .postgresql:
                activityLog.info("Initializing PostgreSQL connector...")
                let connector = PostgreSQLConnector()

                if useSocket, let socketPath = socketPath {
                    activityLog.info("Connecting via PostgreSQL socket: \(socketPath)")
                    try await connector.connectViaSocket(
                        socketPath: socketPath,
                        username: settings.username,
                        password: settings.password,
                        database: settings.database,
                        activityLog: activityLog
                    )
                } else {
                    activityLog.info("Connecting via PostgreSQL TCP: \(host):\(port)")
                    try await connector.connect(
                        host: host,
                        port: port,
                        username: settings.username,
                        password: settings.password,
                        database: settings.database,
                        activityLog: activityLog
                    )
                }
                self.postgresConnector = connector
                activityLog.success("✓ PostgreSQL connector initialized")

            case .sqlite:
                activityLog.info("Initializing SQLite connector...")
                guard let filePath = settings.socket, !filePath.isEmpty else {
                    activityLog.error("SQLite file path not specified!")
                    throw DatabaseError.connectionFailed("SQLite file path is required")
                }

                let connector = SQLiteConnector()
                try await connector.connect(
                    filePath: filePath,
                    activityLog: activityLog
                )
                self.sqliteConnector = connector
                activityLog.success("✓ SQLite connector initialized")
            }
        } catch {
            activityLog.error("Connection failed: \(error.localizedDescription)")
            throw error
        }
    }

    func loadDatabases() async throws {
        guard let settings = currentConnection else {
            throw DatabaseError.connectionFailed("No connection settings")
        }

        let (_, rows) = try await executeRawQuery(sql: getDatabasesQuery(for: settings.databaseType))

        databases = rows.compactMap { row in
            guard let dbName = row.first, let name = dbName else { return nil }
            return DatabaseInfo(name: name)
        }
    }

    private func getDatabasesQuery(for type: DatabaseType) -> String {
        switch type {
        case .mysql:
            return "SHOW DATABASES"
        case .postgresql:
            return "SELECT datname FROM pg_database WHERE datistemplate = false"
        case .sqlite:
            return "SELECT name FROM pragma_database_list()"
        }
    }

    func loadTables(for database: DatabaseInfo) async throws -> [TableInfo] {
        guard let settings = currentConnection else {
            throw DatabaseError.connectionFailed("No connection settings")
        }

        let query: String
        switch settings.databaseType {
        case .mysql:
            query = """
                SELECT
                    TABLE_NAME,
                    ENGINE,
                    TABLE_ROWS,
                    TABLE_COLLATION,
                    TABLE_COMMENT
                FROM information_schema.TABLES
                WHERE TABLE_SCHEMA = '\(database.name)'
                """
        case .postgresql:
            query = """
                SELECT
                    tablename as table_name,
                    NULL as engine,
                    NULL as table_rows,
                    NULL as table_collation,
                    NULL as table_comment
                FROM pg_catalog.pg_tables
                WHERE schemaname = 'public'
                """
        case .sqlite:
            query = """
                SELECT
                    name as table_name,
                    NULL as engine,
                    NULL as table_rows,
                    NULL as table_collation,
                    NULL as table_comment
                FROM sqlite_master
                WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
                """
        }

        let (_, rows) = try await executeRawQuery(sql: query)

        return rows.compactMap { row in
            guard row.count >= 1, let tableName = row[0] else { return nil }
            return TableInfo(
                name: tableName,
                database: database.name,
                rowCount: row.count > 2 ? Int(row[2] ?? "0") : nil,
                engine: row.count > 1 ? row[1] : nil,
                collation: row.count > 3 ? row[3] : nil,
                comment: row.count > 4 ? row[4] : nil
            )
        }
    }


    func loadTableStructure(for table: TableInfo) async throws -> TableStructure {
        guard let settings = currentConnection else {
            throw DatabaseError.connectionFailed("No connection settings")
        }

        activityLog.info("Loading structure for table: \(table.name)")

        var columns: [ColumnInfo] = []
        var indexes: [IndexInfo] = []
        var foreignKeys: [ForeignKeyInfo] = []

        // Load columns
        switch settings.databaseType {
        case .mysql:
            let columnsQuery = """
                SELECT
                    COLUMN_NAME,
                    COLUMN_TYPE,
                    IS_NULLABLE,
                    COLUMN_DEFAULT,
                    COLUMN_KEY,
                    EXTRA,
                    COLUMN_COMMENT
                FROM information_schema.COLUMNS
                WHERE TABLE_SCHEMA = '\(table.database)' AND TABLE_NAME = '\(table.name)'
                ORDER BY ORDINAL_POSITION
                """
            activityLog.info("Fetching columns...")
            let (_, columnRows) = try await executeRawQuery(sql: columnsQuery)
            activityLog.info("Found \(columnRows.count) columns")

            columns = columnRows.compactMap { row in
                guard row.count >= 7,
                      let name = row[0],
                      let type = row[1],
                      let nullable = row[2] else { return nil }

                return ColumnInfo(
                    name: name,
                    type: type,
                    nullable: nullable == "YES",
                    defaultValue: row[3],
                    isPrimaryKey: row[4] == "PRI",
                    isAutoIncrement: row[5]?.contains("auto_increment") ?? false,
                    extra: row[5],
                    comment: row[6]
                )
            }

            // Load indexes - temporarily disabled due to MySQLNIO crash
            activityLog.info("Skipping indexes (temporarily disabled due to MySQLNIO assertion failures)")
            // Note: Complex information_schema queries cause MySQLNIO internal state corruption
            // This results in "Statement not closed" assertion failures in MySQLQueryCommand.deinit
            // We'll implement this in a future update with better error handling or alternative approach
            indexes = []

            // Load foreign keys - skipped for now due to query complexity
            activityLog.info("Skipping foreign keys (not yet implemented for MySQL)")
            // Note: Foreign key queries can be complex and cause crashes in MySQLNIO
            // We'll implement this in a future update with better error handling
            foreignKeys = []

        case .postgresql:
            let columnsQuery = """
                SELECT
                    column_name,
                    data_type,
                    is_nullable,
                    column_default
                FROM information_schema.columns
                WHERE table_name = '\(table.name)'
                ORDER BY ordinal_position
                """
            let (_, columnRows) = try await executeRawQuery(sql: columnsQuery)

            columns = columnRows.compactMap { row in
                guard row.count >= 4,
                      let name = row[0],
                      let type = row[1],
                      let nullable = row[2] else { return nil }

                return ColumnInfo(
                    name: name,
                    type: type,
                    nullable: nullable == "YES",
                    defaultValue: row[3],
                    isPrimaryKey: false,
                    isAutoIncrement: row[3]?.contains("nextval") ?? false,
                    extra: nil,
                    comment: nil
                )
            }

        case .sqlite:
            let columnsQuery = "PRAGMA table_info('\(table.name)')"
            let (_, columnRows) = try await executeRawQuery(sql: columnsQuery)

            columns = columnRows.compactMap { row in
                guard row.count >= 6,
                      let name = row[1],
                      let type = row[2],
                      let notNull = row[3],
                      let pk = row[5] else { return nil }

                return ColumnInfo(
                    name: name,
                    type: type,
                    nullable: notNull == "0",
                    defaultValue: row[4],
                    isPrimaryKey: pk != "0",
                    isAutoIncrement: false, // SQLite doesn't expose this easily
                    extra: nil,
                    comment: nil
                )
            }
        }

        activityLog.success("Table structure loaded: \(columns.count) columns, \(indexes.count) indexes, \(foreignKeys.count) foreign keys")
        return TableStructure(tableName: table.name, columns: columns, indexes: indexes, foreignKeys: foreignKeys)
    }

    func loadTableData(for table: TableInfo) async throws -> QueryResult {
        let startTime = Date()

        // Load ALL rows - pagination will be handled client-side
        let query: String
        if let settings = currentConnection, settings.databaseType == .sqlite {
            // SQLite doesn't use database.table syntax
            query = "SELECT * FROM \(table.name)"
        } else {
            // MySQL/PostgreSQL can use database.table syntax
            query = "SELECT * FROM `\(table.database)`.`\(table.name)`"
        }

        let (columns, rows) = try await executeRawQuery(sql: query)

        let executionTime = Date().timeIntervalSince(startTime)

        return QueryResult(
            columns: columns,
            rows: rows,
            affectedRows: nil,
            executionTime: executionTime,
            error: nil
        )
    }

    func executeQuery(_ query: String) async throws -> QueryResult {
        let startTime = Date()

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Check if it's a SELECT query (returns rows) or other type (returns affected rows)
        if trimmedQuery.hasPrefix("select") || trimmedQuery.hasPrefix("show") || trimmedQuery.hasPrefix("describe") {
            let (columns, rows) = try await executeRawQuery(sql: query)
            let executionTime = Date().timeIntervalSince(startTime)

            return QueryResult(
                columns: columns,
                rows: rows,
                affectedRows: nil,
                executionTime: executionTime,
                error: nil
            )
        } else {
            // INSERT, UPDATE, DELETE, CREATE, ALTER, DROP, etc.
            let affectedRows = try await executeRawModify(sql: query)
            let executionTime = Date().timeIntervalSince(startTime)

            return QueryResult(
                columns: [],
                rows: [],
                affectedRows: affectedRows,
                executionTime: executionTime,
                error: nil
            )
        }
    }

    // Helper method to execute queries that return rows
    private func executeRawQuery(sql: String) async throws -> ([String], [[String?]]) {
        if let mysql = mysqlConnector {
            return try await mysql.query(sql)
        } else if let postgres = postgresConnector {
            return try await postgres.query(sql)
        } else if let sqlite = sqliteConnector {
            return try await sqlite.query(sql)
        } else {
            throw DatabaseError.connectionFailed("No active connection")
        }
    }

    // Helper method to execute queries that modify data
    private func executeRawModify(sql: String) async throws -> Int {
        if let mysql = mysqlConnector {
            return try await mysql.execute(sql)
        } else if let postgres = postgresConnector {
            return try await postgres.execute(sql)
        } else if let sqlite = sqliteConnector {
            return try await sqlite.execute(sql)
        } else {
            throw DatabaseError.connectionFailed("No active connection")
        }
    }
}

enum DatabaseError: LocalizedError {
    case invalidSSHSettings
    case connectionFailed(String)
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidSSHSettings:
            return "Invalid SSH settings"
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .queryFailed(let message):
            return "Query failed: \(message)"
        }
    }
}
