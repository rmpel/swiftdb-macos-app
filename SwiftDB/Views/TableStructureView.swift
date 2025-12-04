//
//  TableStructureView.swift
//  SwiftDB
//
//  Created by Remon Pel on 03/12/2025.
//

import SwiftUI

struct TableStructureView: View {
    let structure: TableStructure?

    var body: some View {
        if let structure = structure {
            VStack(spacing: 0) {
                // Columns Table
                VStack(alignment: .leading, spacing: 8) {
                    Text("Columns")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    Table(structure.columns) {
                        TableColumn("Name", value: \.name)
                        TableColumn("Type", value: \.type)
                        TableColumn("Nullable") { column in
                            Text(column.nullable ? "YES" : "NO")
                        }
                        TableColumn("Default") { column in
                            Text(column.defaultValue ?? "NULL")
                                .foregroundStyle(.secondary)
                        }
                        TableColumn("Extra") { column in
                            HStack {
                                if column.isPrimaryKey {
                                    Label("PK", systemImage: "key.fill")
                                        .labelStyle(.iconOnly)
                                        .foregroundStyle(.blue)
                                }
                                if column.isAutoIncrement {
                                    Text("AUTO_INCREMENT")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Indexes Table (if any)
                if !structure.indexes.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Indexes")
                            .font(.headline)
                            .padding(.horizontal)
                            .padding(.top, 8)

                        Table(structure.indexes) {
                            TableColumn("Name", value: \.name)
                            TableColumn("Columns") { index in
                                Text(index.columns.joined(separator: ", "))
                            }
                            TableColumn("Type") { index in
                                if index.isPrimary {
                                    Text("PRIMARY")
                                } else if index.isUnique {
                                    Text("UNIQUE")
                                } else {
                                    Text("INDEX")
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Foreign Keys Table (if any)
                if !structure.foreignKeys.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Foreign Keys")
                            .font(.headline)
                            .padding(.horizontal)
                            .padding(.top, 8)

                        Table(structure.foreignKeys) {
                            TableColumn("Name", value: \.name)
                            TableColumn("Column", value: \.column)
                            TableColumn("References") { fk in
                                Text("\(fk.referencedTable).\(fk.referencedColumn)")
                            }
                            TableColumn("On Delete") { fk in
                                Text(fk.onDelete ?? "NO ACTION")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        } else {
            ContentUnavailableView(
                "Loading Structure",
                systemImage: "gearshape.2",
                description: Text("Please wait...")
            )
        }
    }
}
