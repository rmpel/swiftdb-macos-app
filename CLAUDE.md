# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SwiftDB is a full-featured database management application for macOS, built with SwiftUI. It provides **real database connectivity** to MySQL, PostgreSQL, and SQLite databases via TCP, Unix sockets, or SSH tunnels with comprehensive authentication options including system SSH config support.

**Important**: The project requires MySQLNIO, PostgresNIO, and SQLite.swift Swift packages. See SETUP_DEPENDENCIES.md for setup instructions.

## Build and Test Commands

### Building

**IMPORTANT**: Before first build, add Swift Package dependencies in Xcode (see SETUP_DEPENDENCIES.md):
- MySQLNIO: `https://github.com/vapor/mysql-nio.git` (v1.7.0+)
- PostgresNIO: `https://github.com/vapor/postgres-nio.git` (v1.18.0+)
- SQLite.swift: `https://github.com/stephencelis/SQLite.swift.git` (v0.15.0+)

```bash
# Build the project
xcodebuild -scheme SwiftDB -project SwiftDB.xcodeproj build

# Build for specific configuration
xcodebuild -scheme SwiftDB -project SwiftDB.xcodeproj -configuration Debug build
xcodebuild -scheme SwiftDB -project SwiftDB.xcodeproj -configuration Release build
```

### Testing
```bash
# Run all tests
xcodebuild test -scheme SwiftDB -project SwiftDB.xcodeproj

# Run only unit tests
xcodebuild test -scheme SwiftDB -project SwiftDB.xcodeproj -only-testing:SwiftDBTests

# Run only UI tests
xcodebuild test -scheme SwiftDB -project SwiftDB.xcodeproj -only-testing:SwiftDBUITests

# Run a specific test
xcodebuild test -scheme SwiftDB -project SwiftDB.xcodeproj -only-testing:SwiftDBTests/SwiftDBTests/example
```

### Running the App
Open `SwiftDB.xcodeproj` in Xcode and run the SwiftDB scheme (⌘R), or:
```bash
xcodebuild -scheme SwiftDB -project SwiftDB.xcodeproj
```

## Architecture

### Models (`SwiftDB/Models/`)
- **ConnectionSettings.swift**: SwiftData model for storing database connection configurations (TCP, socket, SSH tunnel settings). **Security note**: Passwords currently stored in plain text - see SECURITY.md
- **DatabaseSchema.swift**: Defines data structures for database metadata (DatabaseInfo, TableInfo, ColumnInfo, IndexInfo, ForeignKeyInfo, QueryResult)
- **TabManager.swift**: Observable class managing open table tabs and their states (Information, Structure, Content, SQL Console views)
- **TableEditManager.swift**: Manages table cell editing state with pending changes tracking
- **FilterModels.swift**: Data structures for column filtering (operators, conditions)
- **ActivityLog.swift**: Model for color-coded connection activity logging
- **Preferences.swift**: Application preferences and settings storage

### Services (`SwiftDB/Services/`)
- **DatabaseConnection.swift**: Core service managing database connections, executing queries, and loading schema information. Uses `@Observable` for reactive state management. **Now uses real MySQL/PostgreSQL/SQLite connections via respective drivers.**
- **MySQLConnector.swift**: Wraps MySQLNIO for executing real MySQL queries (SELECT, INSERT, UPDATE, DELETE, etc.)
- **PostgreSQLConnector.swift**: Wraps PostgresNIO for executing real PostgreSQL queries
- **SQLiteConnector.swift**: Wraps SQLite.swift for executing SQLite queries on local database files
- **SSHTunnel.swift**: Handles SSH tunnel creation using system `ssh` command with support for key-based and password authentication. Includes `SSHConfigParser` for reading `~/.ssh/config`
- **CLIArguments.swift**: Parses command-line arguments for automated testing and debugging

### Views (`SwiftDB/Views/`)
- **MainView.swift**: Root layout with NavigationSplitView containing sidebar, tabbed content area, and bottom console
- **SidebarView.swift**: Hierarchical list of databases and tables with expand/collapse functionality
- **TabContentView.swift**: Manages multiple open table tabs, each with sub-tabs for different views
- **TableInformationView.swift**: Displays table metadata (name, row count, engine, collation)
- **TableStructureView.swift**: Shows table schema with columns (indexes and foreign keys temporarily disabled)
- **TableDataView.swift**: Editable data grid with filtering, sorting, and pagination
- **ConsoleView.swift**: SQL query editor at bottom with execution and result display
- **ConnectionSheetView.swift**: Modal form for creating new database connections with all connection options
- **ConnectionManagerView.swift**: View for managing saved database connections
- **ActivityLogView.swift**: Displays color-coded connection activity logs
- **FilterBarView.swift**: Column-based filtering UI with multiple operators
- **SettingsView.swift**: Application settings and preferences

### Key Architectural Patterns
- **Observable State**: DatabaseConnection and TabManager use `@Observable` macro for reactive state
- **Three-Panel Layout**: Left sidebar (tables) + Center tabs (content) + Bottom panel (Activity Log + SQL Console)
- **Tab Management**: Each table opens in a new tab with four sub-tabs (Content, Information, Structure, SQL Console)
- **SSH Tunneling**: System SSH integration with config file parsing for seamless remote connections
- **Connection Types**: Supports TCP, Unix socket, SSH+TCP with multiple auth methods (password, key, agent, system SSH config)
- **Async/Await**: All database operations use async/await for non-blocking UI
- **Activity Logging**: Color-coded diagnostic logging (info, success, warning, error) for debugging connections

### SwiftData Usage
- **ConnectionSettings** is persisted using SwiftData for storing saved connections
- **Security Warning**: Passwords are currently stored in plain text - see SECURITY.md for details and recommended practices
- Other models (DatabaseSchema, etc.) are runtime-only and not persisted
- Schema configured in `SwiftDBApp.swift` with `ModelContainer`

### Connection Flow
1. User creates connection via ConnectionSheetView
2. DatabaseConnection.connect() establishes SSH tunnel if needed (SSHTunnel)
3. **Real database connection established** via MySQLConnector, PostgreSQLConnector, or SQLiteConnector
4. **Real SQL query**: `SHOW DATABASES` (MySQL), `SELECT FROM pg_database` (PostgreSQL), or list tables (SQLite)
5. Databases loaded and displayed in SidebarView
6. User expands database → **real SQL query** for tables from information_schema or sqlite_master
7. User opens table → new tab created via TabManager.openTable()
8. Tab loads structure via **real DESCRIBE/information_schema/PRAGMA queries**
9. Tab loads data via **real SELECT queries with LIMIT/OFFSET**
10. Console executes **user-entered SQL queries** with real results
11. User can edit cells → generates UPDATE statements with WHERE clauses for primary keys

### Testing Structure
- **Unit Tests**: `SwiftDBTests/` uses the Swift Testing framework (`import Testing`)
- **UI Tests**: `SwiftDBUITests/` for UI automation tests
- Tests use `@testable import SwiftDB` to access internal members