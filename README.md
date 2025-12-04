# SwiftDB

A full-featured database management application for macOS, built with SwiftUI.

## ⚠️ Security Notice

**Passwords are currently stored in plain text.** Connection credentials are saved using SwiftData in an unencrypted SQLite database. See **[SECURITY.md](SECURITY.md)** for details and recommended security practices.

**For production use**: Use SSH keys, system SSH config, or don't save passwords.

## Features

### Database Connectivity
- **Multiple Connection Types**:
  - TCP/IP connections
  - Unix socket connections
  - SSH tunnels (TCP)

- **Database Support**:
  - MySQL (via MySQLNIO)
  - PostgreSQL (via PostgresNIO)
  - SQLite (via SQLite.swift)

- **SSH Authentication**:
  - System SSH config (`~/.ssh/config`) integration
  - Password authentication
  - Public key authentication
  - SSH agent support

### User Interface

#### Main Layout
1. **Left Sidebar**: Hierarchical database and table browser
   - Expandable database list
   - Table listing per database
   - Double-click to open tables in tabs
   - Right-click for table actions

2. **Center Panel**: Tabbed interface for open tables
   - Multiple tables can be open simultaneously
   - Close tabs with ⌘W
   - Each table has four sub-tabs:
     - **Content**: Editable data grid with filtering, sorting, and pagination
     - **Information**: Table metadata (name, row count, engine, collation, comment)
     - **Structure**: Column definitions (indexes and foreign keys temporarily disabled)
     - **SQL Console**: Execute custom queries on the table

3. **Bottom Panel**: Activity Log & SQL Console
   - **Activity Log**: Color-coded connection diagnostics (info, success, warning, error)
   - **SQL Console**: Global SQL editor for executing queries
   - Execute queries with ⌘↩
   - View results in grid format
   - Query execution time tracking

### Connection Management
- Save and manage multiple database connections
- Connections persist using SwiftData
- Quick connect/disconnect from toolbar
- Comprehensive connection configuration form

## Building

### Prerequisites
- macOS 14.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later

### Setup and Build Commands

**First time setup:**
```bash
# 1. Open project in Xcode
open SwiftDB.xcodeproj

# 2. Follow instructions in SETUP_DEPENDENCIES.md to add:
#    - MySQLNIO package
#    - PostgresNIO package

# 3. Build the project
# Press ⌘B in Xcode, or:
xcodebuild -scheme SwiftDB -project SwiftDB.xcodeproj build
```

**Subsequent builds:**
```bash
# Build for Debug
xcodebuild -scheme SwiftDB -project SwiftDB.xcodeproj -configuration Debug build

# Build for Release
xcodebuild -scheme SwiftDB -project SwiftDB.xcodeproj -configuration Release build

# Run from Xcode
open SwiftDB.xcodeproj
# Then press ⌘R to run
```

## Architecture

### Project Structure
```
SwiftDB/
├── Models/
│   ├── ConnectionSettings.swift    # Connection configuration (SwiftData)
│   ├── DatabaseSchema.swift        # Database metadata structures
│   ├── TabManager.swift            # Tab state management
│   ├── TableEditManager.swift      # Table editing state
│   ├── FilterModels.swift          # Filtering data structures
│   ├── ActivityLog.swift           # Connection activity logging
│   └── Preferences.swift           # App preferences
├── Services/
│   ├── DatabaseConnection.swift    # Database orchestration
│   ├── MySQLConnector.swift        # MySQL driver (MySQLNIO)
│   ├── PostgreSQLConnector.swift   # PostgreSQL driver (PostgresNIO)
│   ├── SQLiteConnector.swift       # SQLite driver (SQLite.swift)
│   ├── SSHTunnel.swift             # SSH tunnel management
│   └── CLIArguments.swift          # Command-line argument parsing
└── Views/
    ├── MainView.swift              # Root layout with sidebar
    ├── SidebarView.swift           # Database/table browser
    ├── TabContentView.swift        # Tab management
    ├── TableInformationView.swift  # Table metadata display
    ├── TableStructureView.swift    # Column/index/FK viewer
    ├── TableDataView.swift         # Data grid with editing
    ├── ConsoleView.swift           # SQL console
    ├── ConnectionSheetView.swift   # Connection form
    ├── ConnectionManagerView.swift # Saved connections list
    ├── ActivityLogView.swift       # Connection activity viewer
    ├── FilterBarView.swift         # Column filtering UI
    └── SettingsView.swift          # App settings
```

### Key Technologies
- **SwiftUI**: Declarative UI framework
- **SwiftData**: Persistent storage for connections
- **@Observable**: Reactive state management
- **Async/Await**: Non-blocking database operations
- **SSH**: System SSH integration for secure tunneling

## Usage

### Creating a Connection

1. Click the "+" button in the toolbar or the "New Connection" button on the welcome screen
2. Fill in the connection details:
   - **Connection Name**: A friendly name for this connection
   - **Connection Type**: Choose TCP/IP, Socket, or SSH Tunnel
   - **Database Type**: MySQL, PostgreSQL, or SQLite
   - **Host/Port or Socket**: Database server location
   - **Username/Password**: Database credentials
   - **SSH Settings** (if using SSH tunnel):
     - SSH host and port
     - SSH username
     - Authentication method (config, password, key, agent)
     - Optional: SSH key path and passphrase

3. Click "Connect"

### Using SSH Config

If you have an existing `~/.ssh/config` file, SwiftDB can use it:

```
# Example ~/.ssh/config
Host myserver
    HostName example.com
    User myuser
    Port 22
    IdentityFile ~/.ssh/id_rsa
```

Simply select "System SSH Config" as the authentication method and enter "myserver" as the SSH host.

### Opening Tables

1. Expand a database in the sidebar by clicking on it
2. Double-click a table to open it in a new tab
3. Use the segmented control to switch between Information, Structure, and Content views

### Executing SQL Queries

1. Click in the console at the bottom of the window
2. Type your SQL query
3. Press ⌘↩ to execute
4. View results in the console area

## Setup Instructions

**IMPORTANT**: Before running the app, you must add the required Swift Package dependencies:

1. See **[SETUP_DEPENDENCIES.md](SETUP_DEPENDENCIES.md)** for detailed instructions
2. Add MySQLNIO and PostgresNIO packages in Xcode
3. Build the project (⌘B)

The app now uses **real database connectivity** - it will connect to actual MySQL and PostgreSQL servers and execute real queries.

## Implemented Features

### Table Editing
- In-place cell editing (double-click cells)
- Large content editor for long text fields
- Pending changes tracking with orange highlighting
- Commit/rollback functionality
- UPDATE statement generation with proper WHERE clauses

### Data Management
- Column-based filtering with multiple operators (equals, contains, starts with, etc.)
- Column sorting (ascending/descending)
- Pagination with customizable page sizes (10-500 rows)
- Resizable columns with persistent width storage
- Zebra striping for improved readability

### Connection Features
- Dynamic SSH tunnel port allocation (no hardcoded ports)
- Comprehensive activity logging with color-coded messages
- CLI arguments support for automated testing
- File browser for SQLite databases and SSH keys

## Current Limitations

### Advanced Features Not Yet Implemented
- Query result export (CSV, JSON, etc.)
- Database schema diffing
- Query history persistence
- Multiple simultaneous connections
- Foreign keys and indexes display (temporarily disabled due to MySQLNIO limitations)

## Contributing

This is a template/framework for a database management application. Feel free to:
- Add real database driver implementations
- Enhance the UI with additional features
- Add support for more database types
- Implement data editing capabilities
- Add import/export functionality

## License

This project is provided as-is for educational and development purposes.
