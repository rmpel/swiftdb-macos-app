//
//  TabManager.swift
//  SwiftDB
//
//  Created by Remon Pel on 03/12/2025.
//

import Foundation

enum TabType: Hashable {
    case table(TableInfo)
    case query(String)
}

enum TableTabView: String, CaseIterable {
    case information = "Information"
    case structure = "Structure"
    case content = "Content"
}

struct OpenTab: Identifiable, Hashable {
    let id = UUID()
    let type: TabType
    var selectedView: TableTabView = .content
    let isPermanent: Bool  // If true, this tab cannot be closed

    init(type: TabType, isPermanent: Bool = false) {
        self.type = type
        self.isPermanent = isPermanent
    }

    var title: String {
        switch type {
        case .table(let table):
            return table.name
        case .query(let name):
            return name
        }
    }

    static func == (lhs: OpenTab, rhs: OpenTab) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@Observable
class TabManager {
    var openTabs: [OpenTab] = []
    var selectedTab: OpenTab?

    // Permanent SQL Console tab
    private var sqlConsoleTab: OpenTab?

    init() {
        // Create and add the permanent SQL Console tab
        let consoleTab = OpenTab(type: .query("SQL Console"), isPermanent: true)
        sqlConsoleTab = consoleTab
        openTabs.append(consoleTab)
        selectedTab = consoleTab
    }

    func openTable(_ table: TableInfo) {
        // Check if already open
        if let existing = openTabs.first(where: {
            if case .table(let t) = $0.type, t.name == table.name {
                return true
            }
            return false
        }) {
            selectedTab = existing
            return
        }

        let newTab = OpenTab(type: .table(table))
        openTabs.append(newTab)
        selectedTab = newTab
    }

    func openNewQueryTab() {
        let queryNumber = openTabs.filter {
            if case .query = $0.type { return true }
            return false
        }.count

        let newTab = OpenTab(type: .query("Query \(queryNumber)"))
        openTabs.append(newTab)
        selectedTab = newTab
    }

    func closeTab(_ tab: OpenTab) {
        // Don't allow closing the permanent SQL Console tab
        if tab.isPermanent {
            return
        }

        if let index = openTabs.firstIndex(of: tab) {
            openTabs.remove(at: index)
            if selectedTab == tab {
                // Select the tab to the left, or to the right, or SQL Console
                if index > 0 {
                    // Select tab to the left
                    selectedTab = openTabs[index - 1]
                } else if !openTabs.isEmpty {
                    // Select the first tab (now at index 0)
                    selectedTab = openTabs[0]
                } else {
                    // Fallback to SQL Console
                    selectedTab = sqlConsoleTab ?? openTabs.first
                }
            }
        }
    }

    func closeAllTabs() {
        // Remove all tabs except the permanent SQL Console
        openTabs.removeAll { !$0.isPermanent }
        selectedTab = sqlConsoleTab
    }
}
