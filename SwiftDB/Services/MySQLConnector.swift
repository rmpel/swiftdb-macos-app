//
//  MySQLConnector.swift
//  SwiftDB
//
//  Created by Remon Pel on 03/12/2025.
//

import Foundation
import MySQLNIO
import NIOCore
import NIOPosix

class MySQLConnector {
    private var connection: MySQLConnection?
    private let eventLoopGroup: MultiThreadedEventLoopGroup

    init() {
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }

    func connect(host: String, port: Int, username: String, password: String?, database: String?, activityLog: ActivityLog) async throws {
        activityLog.info("Resolving address: \(host):\(port)")
        let address: SocketAddress
        do {
            address = try SocketAddress.makeAddressResolvingHost(host, port: port)
            activityLog.info("Address resolved successfully")
        } catch {
            activityLog.error("Failed to resolve address: \(error.localizedDescription)")
            throw DatabaseError.connectionFailed("Invalid host: \(host):\(port)")
        }

        activityLog.info("Establishing MySQL connection...")
        activityLog.info("Username: \(username), Database: \(database ?? "(none)")")

        do {
            let conn = try await MySQLConnection.connect(
                to: address,
                username: username,
                database: database ?? "",
                password: password,
                tlsConfiguration: nil,
                on: eventLoopGroup.next()
            ).get()

            self.connection = conn
            activityLog.success("MySQL connection established")
        } catch {
            activityLog.error("MySQL connection failed: \(error.localizedDescription)")
            throw error
        }
    }

    func connectViaSocket(socketPath: String, username: String, password: String?, database: String?, activityLog: ActivityLog) async throws {
        activityLog.info("=== MySQL Socket Connection Attempt ===")
        activityLog.info("Socket path: \(socketPath)")

        // Check if socket file exists
        let fileManager = FileManager.default
        let socketExists = fileManager.fileExists(atPath: socketPath)
        activityLog.info("Socket file exists: \(socketExists)")

        if socketExists {
            // Check if it's actually a socket
            do {
                let attrs = try fileManager.attributesOfItem(atPath: socketPath)
                if let fileType = attrs[.type] as? FileAttributeType {
                    activityLog.info("File type: \(fileType.rawValue)")
                }
            } catch {
                activityLog.warning("Could not read socket attributes: \(error.localizedDescription)")
            }
        } else {
            activityLog.error("Socket file does not exist at path!")
        }

        activityLog.info("Creating socket address for: \(socketPath)")

        let address: SocketAddress
        do {
            address = try SocketAddress(unixDomainSocketPath: socketPath)
            activityLog.info("Socket address created successfully")
            activityLog.info("Address description: \(address.description)")
        } catch {
            activityLog.error("Failed to create socket address: \(error.localizedDescription)")
            activityLog.error("Error details: \(error)")
            throw DatabaseError.connectionFailed("Invalid socket path: \(socketPath)")
        }

        activityLog.info("Establishing MySQL connection via socket...")
        activityLog.info("Username: \(username)")
        activityLog.info("Database: \(database ?? "(none)")")
        activityLog.info("Password provided: \(password != nil)")

        do {
            activityLog.info("Calling MySQLConnection.connect()...")
            let conn = try await MySQLConnection.connect(
                to: address,
                username: username,
                database: database ?? "",
                password: password,
                tlsConfiguration: nil,
                on: eventLoopGroup.next()
            ).get()

            self.connection = conn
            activityLog.success("MySQL socket connection established successfully!")
        } catch {
            activityLog.error("MySQL socket connection failed: \(error.localizedDescription)")
            activityLog.error("Full error: \(error)")
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

        let stream = try await connection.query(sql).get()

        var columns: [String] = []
        var resultRows: [[String?]] = []

        for row in stream {
            // Get column names from first row
            if columns.isEmpty {
                columns = row.columnDefinitions.map { $0.name }
            }

            // Extract row data
            var rowData: [String?] = []
            for column in row.columnDefinitions {
                if let data = row.column(column.name) {
                    // Try to convert to string with proper type handling
                    if let stringValue = data.string {
                        rowData.append(stringValue)
                    } else if let intValue = data.int {
                        rowData.append(String(intValue))
                    } else if let doubleValue = data.double {
                        rowData.append(String(doubleValue))
                    } else if let floatValue = data.float {
                        rowData.append(String(floatValue))
                    } else if let boolValue = data.bool {
                        rowData.append(boolValue ? "1" : "0")
                    } else if let dateValue = data.date {
                        rowData.append(formatDate(dateValue))
                    } else if let timeValue = data.time {
                        rowData.append(formatMySQLTime(timeValue))
                    } else {
                        // For binary data or unknown types, show hex representation
                        if let buffer = data.buffer {
                            let bytes = buffer.readableBytesView
                            if bytes.count > 50 {
                                rowData.append("<BLOB: \(bytes.count) bytes>")
                            } else {
                                let hex = bytes.map { String(format: "%02x", $0) }.joined()
                                rowData.append("0x\(hex)")
                            }
                        } else {
                            rowData.append("<unknown>")
                        }
                    }
                } else {
                    rowData.append(nil)
                }
            }
            resultRows.append(rowData)
        }

        return (columns, resultRows)
    }

    func execute(_ sql: String) async throws -> Int {
        guard let connection = connection else {
            throw DatabaseError.connectionFailed("Not connected")
        }

        let stream = try await connection.query(sql).get()
        return stream.count
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    private func formatMySQLTime(_ time: MySQLTime) -> String {
        // Format MySQLTime as a readable date/time string
        var parts: [String] = []

        // Date part (YYYY-MM-DD)
        if let year = time.year, let month = time.month, let day = time.day {
            parts.append(String(format: "%04d-%02d-%02d", year, month, day))
        }

        // Time part (HH:MM:SS)
        if let hour = time.hour, let minute = time.minute, let second = time.second {
            parts.append(String(format: "%02d:%02d:%02d", hour, minute, second))
        }

        // Join date and time parts, or return NULL if completely empty
        if parts.isEmpty {
            return "NULL"
        } else {
            return parts.joined(separator: " ")
        }
    }

    deinit {
        try? eventLoopGroup.syncShutdownGracefully()
    }
}
