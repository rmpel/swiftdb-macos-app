# SwiftDB

A full-featured database management application for macOS, built with SwiftUI.

## Features

### Database Connectivity
- **Multiple Connection Types**:
  - TCP/IP connections
  - Unix socket connections
  - SSH tunnels with TCP
  - SSH tunnels with sockets

- **Database Support**:
  - MySQL
  - PostgreSQL
  - SQLite

- **SSH Authentication**:
  - System SSH config (`~/.ssh/config`) integration
  - Password authentication
  - Public key authentication
  - SSH agent support

### User Interface

#### Three-Panel Layout
1. **Left Sidebar**: Hierarchical database and table browser
   - Expandable database list
   - Table listing per database
   - Double-click to open tables

2. **Center Panel**: Tabbed interface for open tables
   - Multiple tables can be open simultaneously
   - Each table has three sub-tabs:
     - **Information**: Table metadata (name, row count, engine, collation)
     - **Structure**: Column definitions, indexes, foreign keys
     - **Content**: Table data in a grid view with pagination

3. **Bottom Console**: SQL query execution
   - Multi-line SQL editor
   - Execute queries with ⌘↩
   - View results in grid format
   - Query execution time tracking
   - Error display

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
│   └── TabManager.swift             # Tab state management
├── Services/
│   ├── DatabaseConnection.swift    # Database operations
│   └── SSHTunnel.swift             # SSH tunnel management
└── Views/
    ├── MainView.swift               # Root layout
    ├── SidebarView.swift            # Database/table browser
    ├── TabContentView.swift         # Tab management
    ├── TableInformationView.swift   # Table info display
    ├── TableStructureView.swift     # Schema viewer
    ├── TableDataView.swift          # Data grid
    ├── ConsoleView.swift            # SQL console
    └── ConnectionSheetView.swift    # Connection form
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

## Current Limitations

### SQLite Support
SQLite support is not yet implemented. Only MySQL and PostgreSQL are currently supported.

### SSH Password Authentication
The current SSH tunnel implementation works best with key-based authentication or SSH agent. For password authentication, you may need to integrate with a library like [NMSSH](https://github.com/NMSSH/NMSSH) or use `expect` scripts.

### Advanced Features Not Yet Implemented
- Table data editing (INSERT/UPDATE/DELETE via UI)
- Query result export (CSV, JSON, etc.)
- Database schema diffing
- Query history persistence
- Multiple simultaneous connections

## Contributing

This is a template/framework for a database management application. Feel free to:
- Add real database driver implementations
- Enhance the UI with additional features
- Add support for more database types
- Implement data editing capabilities
- Add import/export functionality

## License

This project is provided as-is for educational and development purposes.
