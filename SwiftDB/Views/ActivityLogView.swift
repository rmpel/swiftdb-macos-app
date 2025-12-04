//
//  ActivityLogView.swift
//  SwiftDB
//
//  Created by Remon Pel on 03/12/2025.
//

import SwiftUI

struct ActivityLogView: View {
    @Bindable var activityLog: ActivityLog

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "list.bullet.rectangle")
                Text("Activity Log")
                    .font(.headline)

                Spacer()

                Button(action: { activityLog.clear() }) {
                    Label("Clear", systemImage: "trash")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("Clear log")

                Button(action: { activityLog.isVisible.toggle() }) {
                    Label("Hide", systemImage: activityLog.isVisible ? "chevron.down" : "chevron.up")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("Toggle log visibility")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))

            if activityLog.isVisible {
                Divider()

                // Log entries
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(activityLog.entries) { entry in
                                HStack(alignment: .top, spacing: 8) {
                                    Text(entry.formattedTime)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 80, alignment: .leading)

                                    Image(systemName: iconFor(level: entry.level))
                                        .font(.caption)
                                        .foregroundStyle(colorFor(level: entry.level))
                                        .frame(width: 16)

                                    Text(entry.message)
                                        .font(.system(.caption, design: .monospaced))
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .id(entry.id)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onChange(of: activityLog.entries.count) { _, _ in
                        if let lastEntry = activityLog.entries.last {
                            withAnimation {
                                proxy.scrollTo(lastEntry.id, anchor: .bottom)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
            }
        }
    }

    private func iconFor(level: ActivityLogLevel) -> String {
        switch level {
        case .info:
            return "info.circle"
        case .success:
            return "checkmark.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.circle"
        }
    }

    private func colorFor(level: ActivityLogLevel) -> Color {
        switch level {
        case .info:
            return .blue
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}

#Preview {
    let log = ActivityLog()
    log.info("Starting connection...")
    log.success("Connected to database")
    log.warning("Table 'users' has no primary key")
    log.error("Connection failed: timeout")

    return ActivityLogView(activityLog: log)
        .frame(height: 200)
}
