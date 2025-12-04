//
//  ConsoleView.swift
//  SwiftDB
//
//  Created by Remon Pel on 03/12/2025.
//

import SwiftUI

struct ConsoleView: View {
    let dbConnection: DatabaseConnection
    @State private var queryText = ""
    @State private var queryResult: QueryResult?
    @State private var isExecuting = false
    @State private var queryHistory: [String] = []
    @State private var historyIndex: Int?

    var body: some View {
        VStack(spacing: 0) {
            // Query input area
            HStack(spacing: 8) {
                Text("SQL:")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                TextEditor(text: $queryText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 60)
                    .scrollContentBackground(.hidden)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .onSubmit {
                        executeQuery()
                    }

                VStack(spacing: 4) {
                    Button(action: executeQuery) {
                        Label("Execute", systemImage: "play.fill")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isExecuting)
                    .keyboardShortcut(.return, modifiers: [.command])

                    Button(action: clearQuery) {
                        Label("Clear", systemImage: "trash")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(8)

            Divider()

            // Results area
            if isExecuting {
                ProgressView("Executing query...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let result = queryResult {
                QueryResultView(result: result)
            } else {
                Text("Enter a SQL query and press ⌘↩ to execute")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func executeQuery() {
        let query = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        isExecuting = true

        Task {
            do {
                let result = try await dbConnection.executeQuery(query)
                queryResult = result
                queryHistory.append(query)
            } catch {
                queryResult = QueryResult(
                    columns: ["Error"],
                    rows: [[error.localizedDescription]],
                    affectedRows: nil,
                    executionTime: 0,
                    error: error.localizedDescription
                )
            }
            isExecuting = false
        }
    }

    private func clearQuery() {
        queryText = ""
        queryResult = nil
    }
}

struct QueryResultView: View {
    let result: QueryResult

    var body: some View {
        VStack(spacing: 0) {
            if let error = result.error {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                    Spacer()
                }
                .padding(8)
                .background(Color.red.opacity(0.1))
            } else if let affectedRows = result.affectedRows {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Query executed successfully. \(affectedRows) row(s) affected.")
                        .font(.caption)
                    Spacer()
                    Text(String(format: "%.2fs", result.executionTime))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(Color.green.opacity(0.1))
            } else {
                ScrollView([.horizontal, .vertical]) {
                    Grid(alignment: .leading, horizontalSpacing: 1, verticalSpacing: 1) {
                        GridRow {
                            ForEach(result.columns, id: \.self) { column in
                                Text(column)
                                    .font(.caption.bold())
                                    .padding(4)
                                    .frame(minWidth: 80)
                                    .background(Color(nsColor: .controlBackgroundColor))
                            }
                        }

                        ForEach(Array(result.rows.enumerated()), id: \.offset) { _, row in
                            GridRow {
                                ForEach(Array(row.enumerated()), id: \.offset) { _, value in
                                    Text(value ?? "NULL")
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(value == nil ? .secondary : .primary)
                                        .padding(4)
                                        .frame(minWidth: 80)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                    }
                }

                HStack {
                    Text("\(result.rows.count) rows")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.2fs", result.executionTime))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(4)
            }
        }
    }
}

#Preview {
    ConsoleView(dbConnection: DatabaseConnection())
        .frame(height: 200)
}
