# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SwiftDB is a full-featured database management application for macOS, built with SwiftUI. It provides **real database connectivity** to MySQL and PostgreSQL servers via TCP, Unix sockets, or SSH tunnels with comprehensive authentication options including system SSH config support.

**Important**: The project requires MySQLNIO and PostgresNIO Swift packages. See SETUP_DEPENDENCIES.md for setup instructions.

## Build and Test Commands

### Building

**IMPORTANT**: Before first build, add Swift Package dependencies in Xcode (see SETUP_DEPENDENCIES.md):
- MySQLNIO: `https://github.com/vapor/mysql-nio.git` (v1.7.0+)
- PostgresNIO: `https://github.com/vapor/postgres-nio.git` (v1.18.0+)

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
- **ConnectionSettings.swift**: SwiftData model for storing database connection configurations (TCP, socket, SSH tunnel settings)
- **DatabaseSchema.swift**: Defines data structures for database metadata (DatabaseInfo, TableInfo, ColumnInfo, IndexInfo, ForeignKeyInfo, QueryResult)
- **TabManager.swift**: Observable class managing open table tabs and their states (Information, Structure, Content views)

### Services (`SwiftDB/Services/`)
- **DatabaseConnection.swift**: Core service managing database connections, executing queries, and loading schema information. Uses `@Observable` for reactive state management. **Now uses real MySQL/PostgreSQL connections via NIO drivers.**
- **MySQLConnector.swift**: Wraps MySQLNIO for executing real MySQL queries (SELECT, INSERT, UPDATE, DELETE, etc.)
- **PostgreSQLConnector.swift**: Wraps PostgresNIO for executing real PostgreSQL queries
- **SSHTunnel.swift**: Handles SSH tunnel creation using system `ssh` command with support for key-based and password authentication. Includes `SSHConfigParser` for reading `~/.ssh/config`

### Views (`SwiftDB/Views/`)
- **MainView.swift**: Root layout with NavigationSplitView containing sidebar, tabbed content area, and bottom console
- **SidebarView.swift**: Hierarchical list of databases and tables with expand/collapse functionality
- **TabContentView.swift**: Manages multiple open table tabs, each with sub-tabs for different views
- **TableInformationView.swift**: Displays table metadata (name, row count, engine, collation)
- **TableStructureView.swift**: Shows table schema with columns, indexes, and foreign keys in tables
- **TableDataView.swift**: Grid view displaying table rows with selection support
- **ConsoleView.swift**: SQL query editor at bottom with syntax highlighting, execution, and result display
- **ConnectionSheetView.swift**: Modal form for creating new database connections with all connection options

### Key Architectural Patterns
- **Observable State**: DatabaseConnection and TabManager use `@Observable` macro for reactive state
- **Three-Panel Layout**: Left sidebar (tables) + Center tabs (content) + Bottom console (SQL queries)
- **Tab Management**: Each table opens in a new tab with sub-tabs (Information/Structure/Content)
- **SSH Tunneling**: System SSH integration with config file parsing for seamless remote connections
- **Connection Types**: Supports TCP, Unix socket, SSH+TCP, SSH+Socket with multiple auth methods
- **Async/Await**: All database operations use async/await for non-blocking UI

### SwiftData Usage
- **ConnectionSettings** is persisted using SwiftData for storing saved connections
- Other models (DatabaseSchema, etc.) are runtime-only and not persisted
- Schema configured in `SwiftDBApp.swift` with `ModelContainer`

### Connection Flow
1. User creates connection via ConnectionSheetView
2. DatabaseConnection.connect() establishes SSH tunnel if needed (SSHTunnel)
3. **Real database connection established** via MySQLConnector or PostgreSQLConnector
4. **Real SQL query**: `SHOW DATABASES` (MySQL) or `SELECT FROM pg_database` (PostgreSQL)
5. Databases loaded and displayed in SidebarView
6. User expands database → **real SQL query** for tables from information_schema
7. User opens table → new tab created via TabManager.openTable()
8. Tab loads structure via **real DESCRIBE/information_schema queries**
9. Tab loads data via **real SELECT queries with LIMIT/OFFSET**
10. Console executes **user-entered SQL queries** with real results

### Testing Structure
- **Unit Tests**: `SwiftDBTests/` uses the Swift Testing framework (`import Testing`)
- **UI Tests**: `SwiftDBUITests/` for UI automation tests
- Tests use `@testable import SwiftDB` to access internal members
- Features to add: connection manager, ability to open a connection with a config file (xml or json) or command line parameters
- All screenshots are stored in the `issues/` folder (not tracked in git)