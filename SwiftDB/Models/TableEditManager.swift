//
//  TableEditManager.swift
//  SwiftDB
//
//  Created by Remon Pel on 03/12/2025.
//

import Foundation

// Represents a single cell edit
struct CellEdit: Identifiable, Hashable {
    let id = UUID()
    let row: Int
    let column: Int
    let columnName: String
    let originalValue: String?
    var newValue: String?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CellEdit, rhs: CellEdit) -> Bool {
        lhs.id == rhs.id
    }
}

@Observable
class TableEditManager {
    var edits: [CellEdit] = []
    var isCommitting = false

    func addEdit(row: Int, column: Int, columnName: String, originalValue: String?, newValue: String?) {
        // Check if there's already an edit for this cell
        if let existingIndex = edits.firstIndex(where: { $0.row == row && $0.column == column }) {
            // Update existing edit
            edits[existingIndex].newValue = newValue

            // If new value matches original, remove the edit
            if edits[existingIndex].newValue == originalValue {
                edits.remove(at: existingIndex)
            }
        } else {
            // Add new edit only if value changed
            if newValue != originalValue {
                edits.append(CellEdit(
                    row: row,
                    column: column,
                    columnName: columnName,
                    originalValue: originalValue,
                    newValue: newValue
                ))
            }
        }
    }

    func hasEdit(row: Int, column: Int) -> Bool {
        edits.contains { $0.row == row && $0.column == column }
    }

    func getEdit(row: Int, column: Int) -> CellEdit? {
        edits.first { $0.row == row && $0.column == column }
    }

    func clearEdits() {
        edits.removeAll()
    }

    func hasEdits() -> Bool {
        !edits.isEmpty
    }

    // Generate UPDATE SQL for the edits
    func generateUpdateSQL(tableName: String, primaryKeyColumn: String?, primaryKeyValues: [Int: String?]) -> [String] {
        var sqlStatements: [String] = []

        // Group edits by row
        let editsByRow = Dictionary(grouping: edits) { $0.row }

        for (rowIndex, rowEdits) in editsByRow {
            var setClauses: [String] = []

            for edit in rowEdits {
                let value: String
                if let newVal = edit.newValue {
                    // Escape single quotes and wrap in quotes
                    let escaped = newVal.replacingOccurrences(of: "'", with: "''")
                    value = "'\(escaped)'"
                } else {
                    value = "NULL"
                }

                setClauses.append("`\(edit.columnName)` = \(value)")
            }

            let setClause = setClauses.joined(separator: ", ")

            // Build WHERE clause
            var whereClause = ""
            if let pkColumn = primaryKeyColumn, let pkValue = primaryKeyValues[rowIndex] {
                if let val = pkValue {
                    let escaped = val.replacingOccurrences(of: "'", with: "''")
                    whereClause = "WHERE `\(pkColumn)` = '\(escaped)'"
                } else {
                    // Can't update row without primary key
                    continue
                }
            } else {
                // If no primary key, we need to match all original values (risky)
                // For now, skip rows without primary key
                continue
            }

            let sql = "UPDATE `\(tableName)` SET \(setClause) \(whereClause);"
            sqlStatements.append(sql)
        }

        return sqlStatements
    }
}
