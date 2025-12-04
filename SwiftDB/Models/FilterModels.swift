//
//  FilterModels.swift
//  SwiftDB
//
//  Created by Remon Pel on 04/12/2025.
//

import Foundation

enum SortDirection {
    case ascending
    case descending

    func toSQL() -> String {
        switch self {
        case .ascending: return "ASC"
        case .descending: return "DESC"
        }
    }
}

enum ComparisonOperator: String, CaseIterable {
    case equal = "="
    case notEqual = "≠"
    case greaterThan = ">"
    case lessThan = "<"
    case greaterOrEqual = "≥"
    case lessOrEqual = "≤"
    case inList = "IN"
    case like = "LIKE"
    case between = "BETWEEN"
    case isNull = "IS NULL"
    case isNotNull = "IS NOT NULL"
    
    var requiresValue: Bool {
        ![.isNull, .isNotNull].contains(self)
    }
    
    var requiresTwoValues: Bool {
        self == .between
    }
    
    // Get operators appropriate for column type
    static func operators(for columnType: ColumnDataType) -> [ComparisonOperator] {
        switch columnType {
        case .text:
            return [.equal, .notEqual, .like, .inList, .isNull, .isNotNull]
        case .number:
            return [.equal, .notEqual, .greaterThan, .lessThan, .greaterOrEqual, .lessOrEqual, .between, .inList, .isNull, .isNotNull]
        case .date:
            return [.equal, .notEqual, .greaterThan, .lessThan, .greaterOrEqual, .lessOrEqual, .between, .isNull, .isNotNull]
        case .boolean:
            return [.equal, .notEqual, .isNull, .isNotNull]
        }
    }
    
    func toSQL() -> String {
        switch self {
        case .equal: return "="
        case .notEqual: return "!="
        case .greaterThan: return ">"
        case .lessThan: return "<"
        case .greaterOrEqual: return ">="
        case .lessOrEqual: return "<="
        case .inList: return "IN"
        case .like: return "LIKE"
        case .between: return "BETWEEN"
        case .isNull: return "IS NULL"
        case .isNotNull: return "IS NOT NULL"
        }
    }
}

enum ColumnDataType {
    case text
    case number
    case date
    case boolean
    
    // Detect type from sample values or column name
    static func detect(columnName: String, sampleValues: [String?]) -> ColumnDataType {
        // Try to detect from sample values
        let nonNullValues = sampleValues.compactMap { $0 }.prefix(10)
        
        if nonNullValues.isEmpty {
            return .text  // Default
        }
        
        // Check if all are numbers
        let numberCount = nonNullValues.filter { Double($0) != nil }.count
        if numberCount == nonNullValues.count {
            return .number
        }
        
        // Check if date-like
        let datePatterns = ["date", "time", "created", "updated", "modified"]
        if datePatterns.contains(where: { columnName.lowercased().contains($0) }) {
            return .date
        }
        
        // Check if boolean
        let boolValues = Set(["0", "1", "true", "false", "yes", "no"])
        if nonNullValues.allSatisfy({ boolValues.contains($0.lowercased()) }) {
            return .boolean
        }
        
        return .text  // Default
    }
}

struct FilterRule: Identifiable {
    var id = UUID()
    var column: String
    var comparisonOperator: ComparisonOperator
    var value1: String
    var value2: String  // For BETWEEN
    var columnType: ColumnDataType

    func toSQLWhere() -> String {
        let escapedColumn = "`\(column)`"

        switch comparisonOperator {
        case .isNull:
            return "\(escapedColumn) IS NULL"
        case .isNotNull:
            return "\(escapedColumn) IS NOT NULL"
        case .between:
            return "\(escapedColumn) BETWEEN '\(value1.escapingSQLString())' AND '\(value2.escapingSQLString())'"
        case .inList:
            let values = value1.split(separator: ",").map { "'\($0.trimmingCharacters(in: .whitespaces).escapingSQLString())'" }.joined(separator: ", ")
            return "\(escapedColumn) IN (\(values))"
        case .like:
            return "\(escapedColumn) LIKE '\(value1.escapingSQLString())'"
        default:
            return "\(escapedColumn) \(comparisonOperator.toSQL()) '\(value1.escapingSQLString())'"
        }
    }
}

extension String {
    func escapingSQLString() -> String {
        return self.replacingOccurrences(of: "'", with: "''")
    }
}
