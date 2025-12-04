//
//  PostgreSQLConnector.swift
//  SwiftDB
//
//  Created by Remon Pel on 03/12/2025.
//

import Foundation
import PostgresNIO
import NIOCore
import NIOPosix
import Logging

class PostgreSQLConnector {
    private var connection: PostgresConnection?
    private let eventLoopGroup: MultiThreadedEventLoopGroup
    private let logger = Logger(label: "swiftdb.postgres")

    init() {
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }

    func connect(host: String, port: Int, username: String, password: String?, database: String?, activityLog: ActivityLog) async throws {
        activityLog.info("Creating PostgreSQL configuration")
        activityLog.info("Host: \(host), Port: \(port)")
        activityLog.info("Username: \(username), Database: \(database ?? "(none)")")

        let config = PostgresConnection.Configuration(
            host: host,
            port: port,
            username: username,
            password: password,
            database: database,
            tls: .disable
        )

        activityLog.info("Establishing PostgreSQL connection...")

        do {
            let conn = try await PostgresConnection.connect(
                on: eventLoopGroup.next(),
                configuration: config,
                id: 1,
                logger: logger
            ).get()

            self.connection = conn
            activityLog.success("PostgreSQL connection established")
        } catch {
            activityLog.error("PostgreSQL connection failed: \(error.localizedDescription)")
            throw error
        }
    }

    func connectViaSocket(socketPath: String, username: String, password: String?, database: String?, activityLog: ActivityLog) async throws {
        activityLog.info("Creating PostgreSQL socket configuration")
        activityLog.info("Socket: \(socketPath)")
        activityLog.info("Username: \(username), Database: \(database ?? "(none)")")

        // PostgreSQL uses the socket directory, not the full path
        let socketDir = (socketPath as NSString).deletingLastPathComponent

        let config = PostgresConnection.Configuration(
            host: socketDir,
            port: 0, // Port 0 means use socket
            username: username,
            password: password,
            database: database,
            tls: .disable
        )

        activityLog.info("Establishing PostgreSQL connection via socket...")

        do {
            let conn = try await PostgresConnection.connect(
                on: eventLoopGroup.next(),
                configuration: config,
                id: 1,
                logger: logger
            ).get()

            self.connection = conn
            activityLog.success("PostgreSQL socket connection established")
        } catch {
            activityLog.error("PostgreSQL socket connection failed: \(error.localizedDescription)")
            throw error
        }
    }

    func disconnect() async {
        try? await connection?.close().get()
        connection = nil
    }

    func query(_ sql: String) async throws -> ([String], [[String?]]) {
        guard let connection = connection else {
            throw DatabaseError.connectionFailed("Not connected")
        }

        let postgresQuery = PostgresQuery(unsafeSQL: sql)
        let stream = try await connection.query(postgresQuery, logger: logger).get()

        var columns: [String] = []
        var resultRows: [[String?]] = []

        // PostgresNIO doesn't expose column names easily, so we'll get them from the first row
        // and use indexed access

        for (index, row) in stream.rows.enumerated() {
            var rowData: [String?] = []

            // For the first row, we need to figure out column count
            if index == 0 {
                // Try to decode as many columns as possible
                var colIndex = 0
                while true {
                    do {
                        if let value: String = try? row.decode(String?.self) {
                            if columns.isEmpty {
                                columns.append("column_\(colIndex)")
                            }
                            rowData.append(value)
                            colIndex += 1
                        } else if let value: Int = try? row.decode(Int?.self) {
                            if columns.isEmpty {
                                columns.append("column_\(colIndex)")
                            }
                            rowData.append(String(value))
                            colIndex += 1
                        } else {
                            break
                        }
                    } catch {
                        break
                    }
                }
            } else {
                // For subsequent rows, decode same number of columns
                for colIndex in 0..<columns.count {
                    if let value: String = try? row.decode(String?.self) {
                        rowData.append(value)
                    } else if let value: Int = try? row.decode(Int?.self) {
                        rowData.append(String(value))
                    } else {
                        rowData.append(nil)
                    }
                }
            }

            resultRows.append(rowData)
        }

        // If no rows, return empty with no columns
        if columns.isEmpty {
            columns = ["result"]
        }

        return (columns, resultRows)
    }

    func execute(_ sql: String) async throws -> Int {
        guard let connection = connection else {
            throw DatabaseError.connectionFailed("Not connected")
        }

        let postgresQuery = PostgresQuery(unsafeSQL: sql)
        let stream = try await connection.query(postgresQuery, logger: logger).get()

        return stream.rows.count
    }

    deinit {
        try? eventLoopGroup.syncShutdownGracefully()
    }
}
