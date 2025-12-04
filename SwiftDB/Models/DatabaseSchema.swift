//
//  DatabaseSchema.swift
//  SwiftDB
//
//  Created by Remon Pel on 03/12/2025.
//

import Foundation

struct DatabaseInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    var tables: [TableInfo] = []
}

struct TableInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let database: String
    var rowCount: Int?
    var engine: String?
    var collation: String?
    var comment: String?
}

struct ColumnInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let type: String
    let nullable: Bool
    let defaultValue: String?
    let isPrimaryKey: Bool
    let isAutoIncrement: Bool
    let extra: String?
    let comment: String?
}

struct TableStructure: Identifiable {
    let id = UUID()
    let tableName: String
    let columns: [ColumnInfo]
    let indexes: [IndexInfo]
    let foreignKeys: [ForeignKeyInfo]
}

struct IndexInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let columns: [String]
    let isUnique: Bool
    let isPrimary: Bool
}

struct ForeignKeyInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let column: String
    let referencedTable: String
    let referencedColumn: String
    let onDelete: String?
    let onUpdate: String?
}

struct QueryResult: Identifiable {
    let id = UUID()
    let columns: [String]
    let rows: [[String?]]
    let affectedRows: Int?
    let executionTime: TimeInterval
    let error: String?
}
