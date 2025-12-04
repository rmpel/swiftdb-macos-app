//
//  FilterBarView.swift
//  SwiftDB
//
//  Created by Remon Pel on 04/12/2025.
//

import SwiftUI

struct FilterBarView: View {
    let columns: [String]
    let columnTypes: [String: ColumnDataType]
    @Binding var filterRules: [FilterRule]
    let onApply: () -> Void
    let onClear: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach($filterRules) { $rule in
                FilterRuleRow(
                    columns: columns,
                    columnTypes: columnTypes,
                    rule: $rule,
                    onRemove: {
                        filterRules.removeAll { $0.id == rule.id }
                    }
                )
            }
            
            HStack {
                Button(action: addFilterRule) {
                    Label("Add Filter", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Clear All") {
                    onClear()
                }
                .buttonStyle(.bordered)
                .disabled(filterRules.isEmpty)
                
                Button("Filter") {
                    onApply()
                }
                .buttonStyle(.borderedProminent)
                .disabled(filterRules.isEmpty)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private func addFilterRule() {
        guard let firstColumn = columns.first else { return }
        let columnType = columnTypes[firstColumn] ?? .text
        let availableOperators = ComparisonOperator.operators(for: columnType)
        
        filterRules.append(FilterRule(
            column: firstColumn,
            comparisonOperator: availableOperators.first ?? .equal,
            value1: "",
            value2: "",
            columnType: columnType
        ))
    }
}

struct FilterRuleRow: View {
    let columns: [String]
    let columnTypes: [String: ColumnDataType]
    @Binding var rule: FilterRule
    let onRemove: () -> Void
    
    var availableOperators: [ComparisonOperator] {
        ComparisonOperator.operators(for: rule.columnType)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Column picker
            Picker("", selection: $rule.column) {
                ForEach(columns, id: \.self) { column in
                    Text(column).tag(column)
                }
            }
            .frame(width: 150)
            .onChange(of: rule.column) { _, newColumn in
                // Update column type and reset operator when column changes
                rule.columnType = columnTypes[newColumn] ?? .text
                let ops = ComparisonOperator.operators(for: rule.columnType)
                if !ops.contains(rule.comparisonOperator) {
                    rule.comparisonOperator = ops.first ?? .equal
                }
            }

            // Operator picker
            Picker("", selection: $rule.comparisonOperator) {
                ForEach(availableOperators, id: \.self) { op in
                    Text(op.rawValue).tag(op)
                }
            }
            .frame(width: 120)
            
            // Value input(s)
            if rule.comparisonOperator.requiresValue {
                if rule.comparisonOperator.requiresTwoValues {
                    // BETWEEN requires two values
                    TextField("Value 1", text: $rule.value1)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                    
                    Text("AND")
                        .foregroundStyle(.secondary)
                    
                    TextField("Value 2", text: $rule.value2)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                } else {
                    // Single value input
                    TextField(placeholderText, text: $rule.value1)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 300)
                }
            } else {
                // No value needed (IS NULL, IS NOT NULL)
                Spacer()
            }
            
            // Remove button
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .help("Remove filter")
        }
    }
    
    private var placeholderText: String {
        switch rule.comparisonOperator {
        case .like:
            return "Use % for wildcard (e.g., %search%)"
        case .inList:
            return "Comma-separated values (e.g., 1,2,3)"
        default:
            return "Value"
        }
    }
}

#Preview {
    FilterBarView(
        columns: ["id", "name", "email", "created_at"],
        columnTypes: ["id": .number, "name": .text, "email": .text, "created_at": .date],
        filterRules: .constant([
            FilterRule(column: "id", comparisonOperator: .equal, value1: "1", value2: "", columnType: .number)
        ]),
        onApply: {},
        onClear: {}
    )
}
