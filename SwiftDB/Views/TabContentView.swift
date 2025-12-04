//
//  TabContentView.swift
//  SwiftDB
//
//  Created by Remon Pel on 03/12/2025.
//

import SwiftUI

extension Notification.Name {
    static let reloadTableData = Notification.Name("reloadTableData")
}

struct TabContentView: View {
    let dbConnection: DatabaseConnection
    @Bindable var tabManager: TabManager

    var body: some View {
        VStack(spacing: 0) {
            // Tab content (includes combined header for table tabs)
            if let selectedTab = tabManager.selectedTab {
                Group {
                    switch selectedTab.type {
                    case .table:
                        TableTabDetailView(tab: selectedTab, dbConnection: dbConnection, tabManager: tabManager)
                    case .query:
                        VStack(spacing: 0) {
                            // Tab bar for query tabs
                            CustomTabBar(tabManager: tabManager)
                                .frame(height: 32)
                                .background(Color(nsColor: .windowBackgroundColor))
                            Divider()
                            QueryTabView(tab: selectedTab, dbConnection: dbConnection)
                        }
                    }
                }
            }
        }
    }
}

// Custom Tab Bar with inline close buttons
struct CustomTabBar: View {
    @Bindable var tabManager: TabManager
    @State private var hoveredTab: UUID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(tabManager.openTabs) { tab in
                    TabButton(
                        tab: tab,
                        isSelected: tabManager.selectedTab?.id == tab.id,
                        isHovered: hoveredTab == tab.id,
                        onSelect: {
                            tabManager.selectedTab = tab
                        },
                        onClose: {
                            tabManager.closeTab(tab)
                        },
                        onHover: { hovering in
                            hoveredTab = hovering ? tab.id : nil
                        }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }
}

// Individual Tab Button
struct TabButton: View {
    let tab: OpenTab
    let isSelected: Bool
    let isHovered: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let onHover: (Bool) -> Void

    private var icon: String {
        switch tab.type {
        case .table:
            return "tablecells"
        case .query:
            return tab.isPermanent ? "terminal" : "doc.text"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(isSelected ? .white : .secondary)

            Text(tab.title)
                .font(.system(size: 13))
                .lineLimit(1)

            if !tab.isPermanent {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)
                .contentShape(Circle())
                .help("Close Tab")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color.accentColor :
                      (isHovered ? Color.secondary.opacity(0.1) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(isSelected ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 0.5)
        )
        .foregroundStyle(isSelected ? .white : .primary)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            onHover(hovering)
        }
    }
}

struct TableTabDetailView: View {
    let tab: OpenTab
    let dbConnection: DatabaseConnection
    let tabManager: TabManager
    @State private var selectedSubTab: SwiftDB.TableTabView = .content
    @State private var tableStructure: TableStructure?
    @State private var tableData: QueryResult?
    @State private var isLoading = false
    @State private var showingFilterBar = false

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar at the top
            CustomTabBar(tabManager: tabManager)
                .frame(height: 32)
                .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // View picker on its own line, aligned to the right
            HStack {
                Spacer()

                // Filter toggle button (only show for content view)
                if selectedSubTab == .content {
                    Button(action: {
                        showingFilterBar.toggle()
                    }) {
                        Label("Filter", systemImage: showingFilterBar ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Toggle filter bar (⌘F)")
                }

                Button(action: {
                    Task {
                        await loadData()
                    }
                }) {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Reload data")

                Picker("View", selection: $selectedSubTab) {
                    ForEach(SwiftDB.TableTabView.allCases, id: \.self) { view in
                        Text(view.rawValue).tag(view as SwiftDB.TableTabView)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            Divider()

            // Content based on selected sub-tab
            if isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch selectedSubTab {
                case .information:
                    TableInformationView(tab: tab)
                case .structure:
                    TableStructureView(structure: tableStructure)
                case .content:
                    if case .table(let tableInfo) = tab.type {
                        TableDataView(data: tableData, table: tableInfo, dbConnection: dbConnection, showingFilterBar: $showingFilterBar)
                    } else {
                        TableDataView(data: tableData, table: nil, dbConnection: nil, showingFilterBar: $showingFilterBar)
                    }
                }
            }
        }
        .task {
            await loadData()
        }
        .onChange(of: selectedSubTab) {
            Task {
                await loadData()
            }
        }
        .onChange(of: tab.id) {
            // Reset data when tab changes
            tableStructure = nil
            tableData = nil
            Task {
                await loadData()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .reloadTableData)) { _ in
            Task {
                await loadData()
            }
        }
        .onAppear {
            // Set up keyboard shortcuts for CMD+R and CMD+F
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.modifierFlags.contains(.command) {
                    if event.charactersIgnoringModifiers == "r" {
                        Task {
                            await loadData()
                        }
                        return nil // Consume the event
                    } else if event.charactersIgnoringModifiers == "f" && selectedSubTab == .content {
                        showingFilterBar.toggle()
                        return nil // Consume the event
                    }
                }
                return event
            }
        }
    }

    private func loadData() async {
        guard case .table(let table) = tab.type else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            switch selectedSubTab {
            case .structure:
                // Always reload structure data
                tableStructure = try await dbConnection.loadTableStructure(for: table)
            case .content:
                tableData = try await dbConnection.loadTableData(for: table)
            case .information:
                break
            }
        } catch {
            print("Error loading data: \(error)")
        }
    }
}

// Query Tab View - for standalone query tabs with adjustable split
struct QueryTabView: View {
    let tab: OpenTab
    let dbConnection: DatabaseConnection
    @State private var queryText = ""
    @State private var queryResult: QueryResult?
    @State private var isExecuting = false
    @State private var editorHeightRatio: CGFloat = Preferences.shared.sqlConsoleEditorHeight
    @State private var isDragging = false
    @State private var showingFilterBar = false

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Query editor area
                VStack(spacing: 8) {
                    HStack {
                        Text("SQL Editor")
                            .font(.headline)
                        Spacer()
                        Button(action: executeQuery) {
                            Label("Execute", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isExecuting)
                        .keyboardShortcut(.return, modifiers: [.command])
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    TextEditor(text: $queryText)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
                .frame(height: geometry.size.height * editorHeightRatio)

                // Draggable divider
                Rectangle()
                    .fill(isDragging ? Color.accentColor : Color.secondary.opacity(0.2))
                    .frame(height: 8)
                    .overlay(
                        Rectangle()
                            .fill(Color.secondary.opacity(0.5))
                            .frame(width: 60, height: 3)
                            .cornerRadius(1.5)
                    )
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDragging = true
                                let newRatio = (geometry.size.height * editorHeightRatio + value.translation.height) / geometry.size.height
                                editorHeightRatio = min(max(newRatio, 0.2), 0.8) // Clamp between 20% and 80%
                            }
                            .onEnded { _ in
                                isDragging = false
                                Preferences.shared.sqlConsoleEditorHeight = editorHeightRatio
                            }
                    )
                    .onHover { hovering in
                        if hovering {
                            NSCursor.resizeUpDown.push()
                        } else {
                            NSCursor.pop()
                        }
                    }

                // Results area
                VStack(spacing: 0) {
                    if isExecuting {
                        ProgressView("Executing query...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let result = queryResult {
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
                                TableDataView(data: result, table: nil, dbConnection: nil, showingFilterBar: $showingFilterBar)
                            }
                        }
                    } else {
                        ContentUnavailableView(
                            "No Results",
                            systemImage: "terminal",
                            description: Text("Enter a SQL query and press ⌘↩ to execute")
                        )
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .onAppear {
            // Initialize with query name if available
            if case .query(let name) = tab.type {
                // For permanent SQL Console, start with empty query
                if !tab.isPermanent && name != "SQL Console" {
                    queryText = name
                }
            }
        }
    }

    private func executeQuery() {
        let query = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        isExecuting = true

        Task {
            do {
                let result = try await dbConnection.executeQuery(query)
                queryResult = result
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
}

#Preview {
    TabContentView(
        dbConnection: DatabaseConnection(),
        tabManager: TabManager()
    )
}
