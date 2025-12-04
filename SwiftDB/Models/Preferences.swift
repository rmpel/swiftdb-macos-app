//
//  Preferences.swift
//  SwiftDB
//
//  Created by Remon Pel on 03/12/2025.
//

import Foundation
import SwiftUI

enum CellExitBehavior: String, CaseIterable {
    case dismiss = "Dismiss the changes (Escape)"
    case accept = "Accept the changes (Enter)"
}

@Observable
class Preferences {
    static let shared = Preferences()

    // SQL Console split position (0.0 to 1.0, default 0.5 = 50%)
    var sqlConsoleEditorHeight: CGFloat {
        didSet {
            UserDefaults.standard.set(sqlConsoleEditorHeight, forKey: "sqlConsoleEditorHeight")
        }
    }

    // Activity log height
    var activityLogHeight: CGFloat {
        didSet {
            UserDefaults.standard.set(activityLogHeight, forKey: "activityLogHeight")
        }
    }

    // Sidebar width
    var sidebarWidth: CGFloat {
        didSet {
            UserDefaults.standard.set(sidebarWidth, forKey: "sidebarWidth")
        }
    }

    // Hidden databases list
    var hiddenDatabases: [String] {
        didSet {
            UserDefaults.standard.set(hiddenDatabases, forKey: "hiddenDatabases")
        }
    }

    // Show hidden databases toggle
    var showHiddenDatabases: Bool {
        didSet {
            UserDefaults.standard.set(showHiddenDatabases, forKey: "showHiddenDatabases")
        }
    }

    // Cell exit behavior
    var cellExitBehavior: CellExitBehavior {
        didSet {
            UserDefaults.standard.set(cellExitBehavior.rawValue, forKey: "cellExitBehavior")
        }
    }

    // Large content editor size
    var largeEditorWidth: CGFloat {
        didSet {
            UserDefaults.standard.set(largeEditorWidth, forKey: "largeEditorWidth")
        }
    }

    var largeEditorHeight: CGFloat {
        didSet {
            UserDefaults.standard.set(largeEditorHeight, forKey: "largeEditorHeight")
        }
    }

    private init() {
        // Load preferences from UserDefaults with default values
        self.sqlConsoleEditorHeight = UserDefaults.standard.object(forKey: "sqlConsoleEditorHeight") as? CGFloat ?? 0.5
        self.activityLogHeight = UserDefaults.standard.object(forKey: "activityLogHeight") as? CGFloat ?? 200
        self.sidebarWidth = UserDefaults.standard.object(forKey: "sidebarWidth") as? CGFloat ?? 250

        // Hidden databases (default system databases)
        self.hiddenDatabases = UserDefaults.standard.stringArray(forKey: "hiddenDatabases") ?? [
            "information_schema",
            "mysql",
            "performance_schema",
            "sys"
        ]

        // Show hidden databases toggle
        self.showHiddenDatabases = UserDefaults.standard.bool(forKey: "showHiddenDatabases")

        // Cell exit behavior
        let behaviorString = UserDefaults.standard.string(forKey: "cellExitBehavior") ?? CellExitBehavior.dismiss.rawValue
        self.cellExitBehavior = CellExitBehavior(rawValue: behaviorString) ?? .dismiss

        // Large content editor size
        self.largeEditorWidth = UserDefaults.standard.object(forKey: "largeEditorWidth") as? CGFloat ?? 600
        self.largeEditorHeight = UserDefaults.standard.object(forKey: "largeEditorHeight") as? CGFloat ?? 400
    }

    func reset() {
        sqlConsoleEditorHeight = 0.5
        activityLogHeight = 200
        sidebarWidth = 250
        hiddenDatabases = ["information_schema", "mysql", "performance_schema", "sys"]
        showHiddenDatabases = false
        cellExitBehavior = .dismiss
        largeEditorWidth = 600
        largeEditorHeight = 400
    }
}
