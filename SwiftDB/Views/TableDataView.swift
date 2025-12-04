//
//  TableDataView.swift
//  SwiftDB
//
//  Created by Remon Pel on 03/12/2025.
//

import SwiftUI

struct TableDataView: View {
    let data: QueryResult?
    let table: TableInfo?
    let dbConnection: DatabaseConnection?
    @Binding var showingFilterBar: Bool
    @State private var selectedRows: Set<Int> = []
    @State private var selectedCell: (row: Int, col: Int)? = nil
    @State private var currentPage: Int = 1
    @State private var pageSize: Int = 100
    @State private var editManager = TableEditManager()
    @State private var editingCell: (row: Int, col: Int)? = nil
    @State private var pendingEdit: (row: Int, col: Int, text: String)? = nil
    @State private var largeContentEditor: LargeContentEdit? = nil
    @State private var columnWidths: [Int: CGFloat] = [:] // Track width for each column index
    @State private var isDraggingColumn: Int? = nil
    @State private var commitError: String? = nil

    // Filtering
    @State private var filterRules: [FilterRule] = []
    @State private var columnTypes: [String: ColumnDataType] = [:]
    @State private var filteredData: QueryResult? = nil

    // Sorting
    @State private var sortColumn: String? = nil
    @State private var sortDirection: SortDirection? = nil

    // Use filtered data if available, otherwise use original data
    private var displayData: QueryResult? {
        filteredData ?? data
    }

    private var paginatedRows: [[String?]] {
        guard let data = displayData else { return [] }
        let startIndex = (currentPage - 1) * pageSize
        let endIndex = min(startIndex + pageSize, data.rows.count)
        guard startIndex < data.rows.count else { return [] }
        return Array(data.rows[startIndex..<endIndex])
    }

    private var totalPages: Int {
        guard let data = displayData, !data.rows.isEmpty else { return 1 }
        return Int(ceil(Double(data.rows.count) / Double(pageSize)))
    }

    private func columnWidth(for index: Int, totalWidth: CGFloat? = nil) -> CGFloat {
        let baseWidth = columnWidths[index] ?? 150 // Default width 150

        // If this is the last column and we have total width info, expand to fill
        guard let data = data, let totalWidth = totalWidth else {
            return baseWidth
        }

        if index == data.columns.count - 1 {
            // Calculate total used width (row number + all columns except last)
            let rowNumberWidth: CGFloat = 50
            var usedWidth: CGFloat = rowNumberWidth
            for i in 0..<data.columns.count - 1 {
                usedWidth += columnWidth(for: i)
            }

            // Account for ScrollView padding/spacing - subtract a small margin
            let scrollViewMargin: CGFloat = 100
            let availableWidth = totalWidth - scrollViewMargin

            // If there's extra space, expand the last column
            let remainingWidth = availableWidth - usedWidth
            return max(baseWidth, remainingWidth)
        }

        return baseWidth
    }

    private func loadColumnWidths() {
        guard let table = table, let data = data else { return }
        let key = "columnWidths_\(table.database)_\(table.name)"
        if let saved = UserDefaults.standard.dictionary(forKey: key) as? [String: CGFloat] {
            for (colIndex, columnName) in data.columns.enumerated() {
                if let width = saved[columnName] {
                    columnWidths[colIndex] = width
                }
            }
        }
    }

    private func saveColumnWidths() {
        guard let table = table, let data = data else { return }
        let key = "columnWidths_\(table.database)_\(table.name)"
        var saved: [String: CGFloat] = [:]
        for (colIndex, columnName) in data.columns.enumerated() {
            if let width = columnWidths[colIndex] {
                saved[columnName] = width
            }
        }
        UserDefaults.standard.set(saved, forKey: key)
    }

    private func commitChanges() async {
        guard let table = table, let dbConnection = dbConnection, let data = data else { return }

        editManager.isCommitting = true
        defer { editManager.isCommitting = false }

        do {
            // Load table structure to get primary key information
            let structure = try await dbConnection.loadTableStructure(for: table)
            let sqlStatements = generateUpdateSQL(
                tableName: table.name,
                database: table.database,
                edits: editManager.edits,
                data: data,
                structure: structure
            )

            // Execute each UPDATE statement
            for sql in sqlStatements {
                print("Executing: \(sql)")
                _ = try await dbConnection.executeQuery(sql)
            }

            // Clear edits after successful commit
            editManager.clearEdits()
            commitError = nil

            // Trigger a reload notification
            NotificationCenter.default.post(name: .reloadTableData, object: nil)
        } catch {
            commitError = "Failed to commit changes: \(error.localizedDescription)"
            print("Commit error: \(error)")
        }
    }

    private func generateUpdateSQL(tableName: String, database: String, edits: [CellEdit], data: QueryResult, structure: TableStructure) -> [String] {
        var sqlStatements: [String] = []

        // Find primary key columns
        let primaryKeyColumns = structure.columns.filter { $0.isPrimaryKey }

        if primaryKeyColumns.isEmpty {
            print("Warning: No primary key found for table \(tableName). Using all columns in WHERE clause.")
        }

        // Group edits by row
        let editsByRow = Dictionary(grouping: edits) { $0.row }

        for (rowIndex, rowEdits) in editsByRow {
            guard rowIndex < data.rows.count else { continue }

            // Build SET clause (only edited columns)
            var setClauses: [String] = []
            for edit in rowEdits {
                let value: String
                if let newVal = edit.newValue {
                    let escaped = newVal.replacingOccurrences(of: "'", with: "''")
                    value = "'\(escaped)'"
                } else {
                    value = "NULL"
                }
                setClauses.append("`\(edit.columnName)` = \(value)")
            }

            let setClause = setClauses.joined(separator: ", ")

            // Build WHERE clause using ONLY primary key columns (or all columns if no PK)
            var whereClauses: [String] = []
            let row = data.rows[rowIndex]

            let columnsToMatch = primaryKeyColumns.isEmpty ? structure.columns : primaryKeyColumns

            for column in columnsToMatch {
                guard let colIndex = data.columns.firstIndex(of: column.name) else { continue }

                if let value = row[colIndex] {
                    let escaped = value.replacingOccurrences(of: "'", with: "''")
                    whereClauses.append("`\(column.name)` = '\(escaped)'")
                } else {
                    whereClauses.append("`\(column.name)` IS NULL")
                }
            }

            let whereClause = whereClauses.joined(separator: " AND ")

            let sql = "UPDATE `\(database)`.`\(tableName)` SET \(setClause) WHERE \(whereClause) LIMIT 1;"
            sqlStatements.append(sql)
        }

        return sqlStatements
    }

    private func detectColumnTypes() {
        guard let data = data, !data.columns.isEmpty else { return }

        var types: [String: ColumnDataType] = [:]
        for (colIndex, columnName) in data.columns.enumerated() {
            // Get sample values from first 10 rows
            let sampleValues = data.rows.prefix(10).map { $0[colIndex] }
            types[columnName] = ColumnDataType.detect(columnName: columnName, sampleValues: sampleValues)
        }
        columnTypes = types
    }

    private func handleColumnHeaderClick(column: String) {
        // Cycle through sort states: none → ascending → descending → none
        if sortColumn == column {
            // Same column - cycle through states
            if sortDirection == .ascending {
                sortDirection = .descending
            } else if sortDirection == .descending {
                // Reset sorting
                sortColumn = nil
                sortDirection = nil
            }
        } else {
            // Different column - start with ascending
            sortColumn = column
            sortDirection = .ascending
        }

        // Reapply filters/sorting
        Task {
            await applySortingAndFilters()
        }
    }

    private func applySortingAndFilters() async {
        guard let table = table, let dbConnection = dbConnection else {
            filteredData = nil
            return
        }

        do {
            // Build WHERE clause from filter rules
            var whereClause = ""
            if !filterRules.isEmpty {
                let whereClauses = filterRules.map { $0.toSQLWhere() }
                whereClause = " WHERE " + whereClauses.joined(separator: " AND ")
            }

            // Build ORDER BY clause if sorting is active
            var orderByClause = ""
            if let sortCol = sortColumn, let sortDir = sortDirection {
                orderByClause = " ORDER BY `\(sortCol)` \(sortDir.toSQL())"
            }

            // Build and execute query
            let sql = "SELECT * FROM `\(table.database)`.`\(table.name)`\(whereClause)\(orderByClause)"
            print("Executing query: \(sql)")

            let result = try await dbConnection.executeQuery(sql)
            filteredData = result
            currentPage = 1 // Reset to first page
        } catch {
            print("Query error: \(error)")
            commitError = "Failed to execute query: \(error.localizedDescription)"
        }
    }

    private func applyFilters() async {
        await applySortingAndFilters()
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let error = commitError {
            HStack {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                Spacer()
                Button("Dismiss") {
                    commitError = nil
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.1))
            Divider()
        }
    }

    @ViewBuilder
    private var editControlsBar: some View {
        if editManager.hasEdits() {
            HStack(spacing: 12) {
                Image(systemName: "pencil.circle.fill")
                    .foregroundStyle(.orange)

                Text("\(editManager.edits.count) unsaved change\(editManager.edits.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Cancel") {
                    editManager.clearEdits()
                }
                .buttonStyle(.bordered)

                Button("Commit Changes") {
                    Task {
                        await commitChanges()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(editManager.isCommitting)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.1))

            Divider()
        }
    }

    @ViewBuilder
    private var filterBar: some View {
        if showingFilterBar, let data = data, !data.columns.isEmpty {
            FilterBarView(
                columns: data.columns,
                columnTypes: columnTypes,
                filterRules: $filterRules,
                onApply: {
                    Task {
                        await applyFilters()
                    }
                },
                onClear: {
                    filterRules = []
                    sortColumn = nil
                    sortDirection = nil
                    filteredData = nil
                    currentPage = 1
                }
            )
            Divider()
        }
    }

    @ViewBuilder
    private func tableContent(data: QueryResult, geometry: GeometryProxy) -> some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                // Header row
                GridRow {
                    Text("#")
                        .font(.caption.bold())
                        .frame(width: 50)
                        .padding(8)
                        .background(Color(nsColor: .controlBackgroundColor))

                    ForEach(Array(data.columns.enumerated()), id: \.offset) { colIndex, column in
                        ResizableColumnHeader(
                            title: column,
                            width: columnWidth(for: colIndex, totalWidth: geometry.size.width),
                            isDragging: isDraggingColumn == colIndex,
                            background: columnHeaderBackground(col: colIndex),
                            sortDirection: sortColumn == column ? sortDirection : nil,
                            onWidthChange: { newWidth in
                                columnWidths[colIndex] = max(50, newWidth)
                                saveColumnWidths()
                            },
                            onDragStateChange: { isDragging in
                                isDraggingColumn = isDragging ? colIndex : nil
                            },
                            onHeaderClick: {
                                handleColumnHeaderClick(column: column)
                            }
                        )
                    }
                }

                // Data rows
                ForEach(Array(paginatedRows.enumerated()), id: \.offset) { index, row in
                    let actualRowIndex = (currentPage - 1) * pageSize + index
                    GridRow {
                        Text("\(actualRowIndex + 1)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 50)
                            .padding(8)
                            .background(rowNumberBackground(row: actualRowIndex))

                        ForEach(Array(row.enumerated()), id: \.offset) { colIndex, value in
                            let columnName = data.columns[colIndex]
                            EditableCell(
                                value: value,
                                row: actualRowIndex,
                                column: colIndex,
                                columnName: columnName,
                                isEditing: editingCell?.row == actualRowIndex && editingCell?.col == colIndex,
                                editManager: editManager,
                                background: cellBackground(row: actualRowIndex, col: colIndex),
                                columnWidth: columnWidth(for: colIndex, totalWidth: geometry.size.width),
                                onTap: {
                                    handleCellTap(data: data, actualRowIndex: actualRowIndex, colIndex: colIndex)
                                },
                                onDoubleClick: {
                                    handleCellDoubleClick(data: data, actualRowIndex: actualRowIndex, colIndex: colIndex, value: value, columnName: columnName)
                                },
                                onValueChange: { newValue in
                                    editManager.addEdit(
                                        row: actualRowIndex,
                                        column: colIndex,
                                        columnName: columnName,
                                        originalValue: value,
                                        newValue: newValue
                                    )
                                    editingCell = nil
                                    pendingEdit = nil
                                },
                                onCancelEdit: {
                                    editingCell = nil
                                    pendingEdit = nil
                                },
                                onTextChange: { newText in
                                    pendingEdit = (row: actualRowIndex, col: colIndex, text: newText)
                                }
                            )
                        }
                    }
                }
                }
            }
        }
    }

    private func handleCellTap(data: QueryResult, actualRowIndex: Int, colIndex: Int) {
        // Handle pending edit if clicking a different cell
        if let ec = editingCell, (ec.row != actualRowIndex || ec.col != colIndex) {
            let editingRow = data.rows[ec.row]
            let originalVal = editingRow[ec.col]
            let editingColName = data.columns[ec.col]
            handlePendingEdit(originalValue: originalVal, row: ec.row, col: ec.col, columnName: editingColName)
            editingCell = nil
        }
        selectedCell = (row: actualRowIndex, col: colIndex)
    }

    private func handleCellDoubleClick(data: QueryResult, actualRowIndex: Int, colIndex: Int, value: String?, columnName: String) {
        // Handle pending edit if editing a different cell
        if let ec = editingCell, (ec.row != actualRowIndex || ec.col != colIndex) {
            let editingRow = data.rows[ec.row]
            let originalVal = editingRow[ec.col]
            let editingColName = data.columns[ec.col]
            handlePendingEdit(originalValue: originalVal, row: ec.row, col: ec.col, columnName: editingColName)
        }

        // Check if content is large
        let currentValue = editManager.getEdit(row: actualRowIndex, column: colIndex)?.newValue ?? value
        let content = currentValue ?? ""
        if content.count > 100 || content.contains("\n") {
            // Open large content editor
            largeContentEditor = LargeContentEdit(
                row: actualRowIndex,
                column: colIndex,
                columnName: columnName,
                value: currentValue
            )
        } else {
            // Enable in-place editing
            editingCell = (row: actualRowIndex, col: colIndex)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            errorBanner
            editControlsBar
            filterBar

            if let data = displayData, !data.columns.isEmpty {
                GeometryReader { geometry in
                    tableContent(data: data, geometry: geometry)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    // Handle click in empty space - end editing
                    if let ec = editingCell, let data = displayData {
                        let editingRow = data.rows[ec.row]
                        let originalVal = editingRow[ec.col]
                        let editingColName = data.columns[ec.col]
                        handlePendingEdit(originalValue: originalVal, row: ec.row, col: ec.col, columnName: editingColName)
                        editingCell = nil
                    }
                }

                Divider()

                PaginationFooter(
                    totalRows: displayData?.rows.count ?? 0,
                    executionTime: displayData?.executionTime ?? 0,
                    currentPage: $currentPage,
                    pageSize: $pageSize,
                    totalPages: totalPages
                )
            } else {
                ContentUnavailableView(
                    "No Data",
                    systemImage: "tablecells",
                    description: Text("Execute a query to view data")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            loadColumnWidths()
            detectColumnTypes()
        }
        .onChange(of: data?.columns) {
            loadColumnWidths()
            detectColumnTypes()
        }
        .sheet(item: $largeContentEditor) { edit in
            LargeContentEditorSheet(
                edit: edit,
                onSave: { newValue in
                    editManager.addEdit(
                        row: edit.row,
                        column: edit.column,
                        columnName: edit.columnName,
                        originalValue: edit.value,
                        newValue: newValue
                    )
                    largeContentEditor = nil
                },
                onCancel: {
                    largeContentEditor = nil
                }
            )
            .presentationSizing(.fitted)
        }
    }

    private func rowBackground(for index: Int) -> Color {
        if selectedRows.contains(index) {
            return Color.accentColor.opacity(0.2)
        }
        return index % 2 == 0 ? Color(nsColor: .controlBackgroundColor).opacity(0.3) : Color.clear
    }

    private func cellBackground(row: Int, col: Int) -> Color {
        // Check if this cell is selected
        if let selected = selectedCell, selected.row == row, selected.col == col {
            return Color.accentColor.opacity(0.4)
        }

        // ZEBRA STRIPING - alternating rows with visible contrast
        // Even rows: lighter, Odd rows: darker gray overlay
        return row % 2 == 0 ? Color.clear : Color.gray.opacity(0.15)
    }

    private func rowNumberBackground(row: Int) -> Color {
        // Highlight row number if this row is selected
        if let selected = selectedCell, selected.row == row {
            return Color.accentColor.opacity(0.4)
        }

        // Default zebra striping
        return row % 2 == 0 ? Color(nsColor: .controlBackgroundColor).opacity(0.3) : Color.clear
    }

    private func columnHeaderBackground(col: Int) -> Color {
        // Highlight column header if this column is selected
        if let selected = selectedCell, selected.col == col {
            return Color.accentColor.opacity(0.4)
        }

        // Default header background
        return Color(nsColor: .controlBackgroundColor)
    }

    private func truncateText(_ text: String) -> String {
        // Remove newlines and truncate long strings
        let singleLine = text.replacingOccurrences(of: "\n", with: " ")
                            .replacingOccurrences(of: "\r", with: " ")
                            .replacingOccurrences(of: "\t", with: " ")

        if singleLine.count > 500 {
            return String(singleLine.prefix(500)) + "..."
        }
        return singleLine
    }

    private func handlePendingEdit(originalValue: String?, row: Int, col: Int, columnName: String) {
        guard let pending = pendingEdit,
              pending.row == editingCell?.row,
              pending.col == editingCell?.col else {
            return
        }

        // Check the preference
        switch Preferences.shared.cellExitBehavior {
        case .accept:
            // Accept the changes
            let trimmed = pending.text.trimmingCharacters(in: .whitespacesAndNewlines)
            editManager.addEdit(
                row: pending.row,
                column: pending.col,
                columnName: columnName,
                originalValue: originalValue,
                newValue: trimmed.isEmpty ? nil : trimmed
            )
        case .dismiss:
            // Dismiss - do nothing
            break
        }

        pendingEdit = nil
    }
}

// Large Content Edit Model
struct LargeContentEdit: Identifiable {
    let id = UUID()
    let row: Int
    let column: Int
    let columnName: String
    let value: String?
}

// Editable Cell Component
struct EditableCell: View {
    let value: String? // Original value from database
    let row: Int
    let column: Int
    let columnName: String
    let isEditing: Bool
    let editManager: TableEditManager
    let background: Color
    let columnWidth: CGFloat
    let onTap: () -> Void
    let onDoubleClick: () -> Void
    let onValueChange: (String?) -> Void
    let onCancelEdit: () -> Void
    let onTextChange: (String) -> Void

    @State private var editedText: String = ""
    @FocusState private var isFocused: Bool

    // Compute display value dynamically from editManager
    private var displayValue: String? {
        editManager.getEdit(row: row, column: column)?.newValue ?? value
    }

    private var hasEdit: Bool {
        editManager.hasEdit(row: row, column: column)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            if isEditing {
                TextField("", text: $editedText)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .focused($isFocused)
                    .onSubmit {
                        // Enter key pressed - always accept
                        let trimmed = editedText.trimmingCharacters(in: .whitespacesAndNewlines)
                        onValueChange(trimmed.isEmpty ? nil : trimmed)
                    }
                    .onAppear {
                        editedText = displayValue ?? ""
                        isFocused = true
                    }
                    .onExitCommand {
                        onCancelEdit()
                    }
                    .onChange(of: editedText) { _, newValue in
                        onTextChange(newValue)
                    }
                    .onChange(of: isFocused) { _, focused in
                        // Handle focus loss (clicking outside)
                        if !focused {
                            if Preferences.shared.cellExitBehavior == .accept {
                                let trimmed = editedText.trimmingCharacters(in: .whitespacesAndNewlines)
                                onValueChange(trimmed.isEmpty ? nil : trimmed)
                            } else {
                                onCancelEdit()
                            }
                        }
                    }
            } else {
                Text(truncateText(displayValue ?? "NULL"))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(displayValue == nil ? .secondary : .primary)
                    .help(displayValue ?? "NULL")
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: columnWidth, alignment: .leading)
        .padding(8)
        .background(
            isEditing ? Color.accentColor.opacity(0.15) :
            (hasEdit ? Color.orange.opacity(0.2) : background)
        )
        .overlay(
            isEditing ?
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(Color.accentColor, lineWidth: 3)
            : (hasEdit ?
               RoundedRectangle(cornerRadius: 2)
                .strokeBorder(Color.orange, lineWidth: 2)
               : nil)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onTapGesture(count: 2) {
            onDoubleClick()
        }
    }

    private func truncateText(_ text: String) -> String {
        let singleLine = text.replacingOccurrences(of: "\n", with: " ")
                            .replacingOccurrences(of: "\r", with: " ")
                            .replacingOccurrences(of: "\t", with: " ")

        if singleLine.count > 500 {
            return String(singleLine.prefix(500)) + "..."
        }
        return singleLine
    }
}

// Large Content Editor Sheet
struct LargeContentEditorSheet: View {
    let edit: LargeContentEdit
    let onSave: (String?) -> Void
    let onCancel: () -> Void

    @State private var editedText: String

    init(edit: LargeContentEdit, onSave: @escaping (String?) -> Void, onCancel: @escaping () -> Void) {
        self.edit = edit
        self.onSave = onSave
        self.onCancel = onCancel
        _editedText = State(initialValue: edit.value ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Edit Cell Content")
                        .font(.headline)

                    Text("Column: \(edit.columnName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    let trimmed = editedText.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(trimmed.isEmpty ? nil : trimmed)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Text editor
            TextEditor(text: $editedText)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: .textBackgroundColor))
                .padding()
        }
        .frame(minWidth: 600, idealWidth: Preferences.shared.largeEditorWidth, maxWidth: .infinity)
        .frame(minHeight: 400, idealHeight: Preferences.shared.largeEditorHeight, maxHeight: .infinity)
        .background(
            GeometryReader { geometry in
                Color.clear.onChange(of: geometry.size) { _, newSize in
                    // Save size to preferences when sheet is resized
                    Preferences.shared.largeEditorWidth = newSize.width
                    Preferences.shared.largeEditorHeight = newSize.height
                }
            }
        )
    }
}

// Pagination Footer Component
struct PaginationFooter: View {
    let totalRows: Int
    let executionTime: TimeInterval
    @Binding var currentPage: Int
    @Binding var pageSize: Int
    let totalPages: Int

    var body: some View {
        HStack(spacing: 16) {
            // Total rows
            Text("\(totalRows) rows")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Page size selector
            HStack(spacing: 4) {
                Text("Page size:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("", selection: $pageSize) {
                    Text("10").tag(10)
                    Text("25").tag(25)
                    Text("50").tag(50)
                    Text("100").tag(100)
                    Text("250").tag(250)
                    Text("500").tag(500)
                }
                .labelsHidden()
                .frame(width: 70)
            }

            // Page navigation
            HStack(spacing: 8) {
                Button(action: {
                    if currentPage > 1 {
                        currentPage -= 1
                    }
                }) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                .disabled(currentPage <= 1)

                Text("Page \(currentPage) of \(totalPages)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 80)

                Button(action: {
                    if currentPage < totalPages {
                        currentPage += 1
                    }
                }) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
                .disabled(currentPage >= totalPages)
            }

            Spacer()

            Text("Execution time: \(String(format: "%.2f", executionTime))s")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor))
        .onChange(of: pageSize) {
            // Reset to page 1 when page size changes
            currentPage = 1
        }
    }
}

// Resizable Column Header Component
struct ResizableColumnHeader: View {
    let title: String
    let width: CGFloat
    let isDragging: Bool
    let background: Color
    let sortDirection: SortDirection?
    let onWidthChange: (CGFloat) -> Void
    let onDragStateChange: (Bool) -> Void
    let onHeaderClick: () -> Void

    @State private var isHoveringHandle = false

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption.bold())

                // Sort indicator
                if let direction = sortDirection {
                    Image(systemName: direction == .ascending ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }
            .frame(width: width - 8, alignment: .leading)
            .padding(8)
            .background(background)
            .contentShape(Rectangle())
            .onTapGesture {
                onHeaderClick()
            }

            // Resize handle
            Rectangle()
                .fill(isDragging || isHoveringHandle ? Color.accentColor : Color.secondary.opacity(0.3))
                .frame(width: 3)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            onDragStateChange(true)
                            onWidthChange(width + value.translation.width)
                        }
                        .onEnded { _ in
                            onDragStateChange(false)
                        }
                )
                .onHover { hovering in
                    isHoveringHandle = hovering
                    if hovering {
                        NSCursor.resizeLeftRight.push()
                    } else {
                        NSCursor.pop()
                    }
                }
        }
        .frame(width: width)
    }
}
