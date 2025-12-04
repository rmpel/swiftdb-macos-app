//
//  ActivityLog.swift
//  SwiftDB
//
//  Created by Remon Pel on 03/12/2025.
//

import Foundation

enum ActivityLogLevel {
    case info
    case success
    case warning
    case error
}

struct ActivityLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: ActivityLogLevel
    let message: String

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
}

@Observable
class ActivityLog {
    var entries: [ActivityLogEntry] = []
    var isVisible = true
    private let logFileURL: URL

    init() {
        // Create log file in /tmp directory
        logFileURL = URL(fileURLWithPath: "/tmp/swiftdb-activity.log")

        // Create or truncate log file
        let logPath = logFileURL.path
        print("=== SwiftDB Activity Log ===")
        print("Log file: \(logPath)")

        do {
            try "".write(to: logFileURL, atomically: true, encoding: .utf8)
            print("Log file created/truncated successfully")
        } catch {
            print("Failed to create log file: \(error)")
        }

        self.info("SwiftDB Activity Log Started")
        self.info("Log file: \(logPath)")
    }

    func log(_ message: String, level: ActivityLogLevel = .info) {
        let entry = ActivityLogEntry(timestamp: Date(), level: level, message: message)
        entries.append(entry)

        let levelStr: String
        switch level {
        case .info: levelStr = "INFO"
        case .success: levelStr = "SUCCESS"
        case .warning: levelStr = "WARNING"
        case .error: levelStr = "ERROR"
        }

        let logLine = "[\(entry.formattedTime)] [\(levelStr)] \(message)\n"
        print("[\(entry.formattedTime)] [\(levelStr)] \(message)")

        // Append to file
        if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
            try? fileHandle.seekToEnd()
            if let data = logLine.data(using: .utf8) {
                try? fileHandle.write(contentsOf: data)
            }
            try? fileHandle.close()
        }
    }

    func info(_ message: String) {
        log(message, level: .info)
    }

    func success(_ message: String) {
        log(message, level: .success)
    }

    func warning(_ message: String) {
        log(message, level: .warning)
    }

    func error(_ message: String) {
        log(message, level: .error)
    }

    func clear() {
        entries.removeAll()
    }
}
