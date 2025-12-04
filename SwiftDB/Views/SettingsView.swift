//
//  SettingsView.swift
//  SwiftDB
//
//  Created by Remon Pel on 04/12/2025.
//

import SwiftUI

struct SettingsView: View {
    @State private var hiddenDatabasesText: String = ""
    @State private var cellExitBehavior: CellExitBehavior = .dismiss
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            DatabaseSettingsView()
                .tabItem {
                    Label("Databases", systemImage: "cylinder")
                }
        }
        .frame(width: 500, height: 350)
    }
}

struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Section(header: Text("Cell Editing").font(.headline)) {
                Picker("Leaving a cell will:", selection: Binding(
                    get: { Preferences.shared.cellExitBehavior },
                    set: { Preferences.shared.cellExitBehavior = $0 }
                )) {
                    ForEach(CellExitBehavior.allCases, id: \.self) { behavior in
                        Text(behavior.rawValue).tag(behavior)
                    }
                }
                .pickerStyle(.radioGroup)
                
                Text("Choose what happens when you click outside an editing cell")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct DatabaseSettingsView: View {
    @State private var hiddenDatabasesText: String = ""
    
    var body: some View {
        Form {
            Section(header: Text("Hidden Databases").font(.headline)) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Database names to hide from the sidebar (one per line):")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    TextEditor(text: $hiddenDatabasesText)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 150)
                        .scrollContentBackground(.hidden)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                    
                    HStack {
                        Button("Reset to Defaults") {
                            Preferences.shared.hiddenDatabases = [
                                "information_schema",
                                "mysql",
                                "performance_schema",
                                "sys"
                            ]
                            updateTextFromPreferences()
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button("Apply") {
                            applyChanges()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            updateTextFromPreferences()
        }
    }
    
    private func updateTextFromPreferences() {
        hiddenDatabasesText = Preferences.shared.hiddenDatabases.joined(separator: "\n")
    }
    
    private func applyChanges() {
        let databases = hiddenDatabasesText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        Preferences.shared.hiddenDatabases = databases
    }
}

#Preview {
    SettingsView()
}
