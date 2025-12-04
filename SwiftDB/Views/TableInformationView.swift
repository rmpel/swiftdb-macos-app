//
//  TableInformationView.swift
//  SwiftDB
//
//  Created by Remon Pel on 03/12/2025.
//

import SwiftUI

struct TableInformationView: View {
    let tab: OpenTab

    var body: some View {
        if case .table(let table) = tab.type {
            Form {
                Section("General") {
                    LabeledContent("Table Name", value: table.name)
                    LabeledContent("Database", value: table.database)
                    if let rowCount = table.rowCount {
                        LabeledContent("Row Count", value: "\(rowCount)")
                    }
                }

                Section("Storage") {
                    if let engine = table.engine {
                        LabeledContent("Engine", value: engine)
                    }
                    if let collation = table.collation {
                        LabeledContent("Collation", value: collation)
                    }
                }

                if let comment = table.comment, !comment.isEmpty {
                    Section("Comment") {
                        Text(comment)
                            .textSelection(.enabled)
                    }
                }
            }
            .formStyle(.grouped)
        }
    }
}
