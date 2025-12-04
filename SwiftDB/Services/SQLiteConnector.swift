//
//  SQLiteConnector.swift
//  SwiftDB
//
//  Created by Remon Pel on 04/12/2025.
//

import Foundation
import SQLite

class SQLiteConnector {
    private var connection: Connection?

    func connect(filePath: String, activityLog: ActivityLog) async throws {
        activityLog.info("Opening SQLite database: \(filePath)")

        // Check if file exists
        let fileManager = FileManager.default
        let fileExists = fileManager.fileExists(atPath: filePath)
        activityLog.info("Database file exists: \(fileExists)")

        if !fileExists {
            activityLog.warning("Database file does not exist, will be created")
        }

        do {
            let conn = try Connection(filePath)
            self.connection = conn
            activityLog.success("SQLite database opened successfully")

            // Test the connection with a simple query
            _ = try conn.scalar("SELECT 1") as? Int64
            activityLog.info("Connection test successful")
        } catch {
            activityLog.error("Failed to open SQLite database: \(error.localizedDescription)")
            throw DatabaseError.connectionFailed("SQLite: \(error.localizedDescription)")
        }
    }

    func disconnect() async {
        connection = nil
    }

    func query(_ sql: String) async throws -> ([String], [[String?]]) {
        guard let connection = connection else {
            throw DatabaseError.connectionFailed("Not connected")
        }

        do {
            let statement = try connection.prepare(sql)

            var columns: [String] = []
            var resultRows: [[String?]] = []

            // Get column names from the statement
            columns = statement.columnNames

            // Fetch all rows
            for row in statement {
                var rowData: [String?] = []

                for (index, _) in columns.enumerated() {
                    // Try to extract value - SQLite.swift uses Binding protocol
                    if let value = row[index] {
                        // Convert to string representation
                        rowData.append(String(describing: value))
                    } else {
                        rowData.append(nil)
                    }
                }

                resultRows.append(rowData)
            }

            return (columns, resultRows)
        } catch {
            throw DatabaseError.queryFailed("SQLite: \(error.localizedDescription)")
        }
    }

    func execute(_ sql: String) async throws -> Int {
        guard let connection = connection else {
            throw DatabaseError.connectionFailed("Not connected")
        }

        do {
            try connection.execute(sql)
            return connection.changes
        } catch {
            throw DatabaseError.queryFailed("SQLite: \(error.localizedDescription)")
        }
    }
}
