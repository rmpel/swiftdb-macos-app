# SwiftDB TODO List

## Security Enhancements

### High Priority
- [ ] **Keychain Integration for Password Storage**
  - Migrate passwords from SwiftData to macOS Keychain
  - Store only non-sensitive connection metadata in SwiftData
  - Use Keychain Services API for secure credential storage
  - Add option to "prompt for password on connect" (don't store)
  - Implement migration path for existing stored connections

### Medium Priority
- [ ] **Connection Encryption Options**
  - Add SSL/TLS support for MySQL connections
  - Add SSL/TLS support for PostgreSQL connections
  - Certificate validation options

## UI/UX Improvements

### Table View Issues
- [ ] **Fix Table Vertical Alignment**
  - Table content is vertically centered instead of top-aligned
  - Large gap between filter bar and table content
  - Investigate SwiftUI GeometryReader layout behavior
  - Consider alternative layout approaches (SwiftUI Table, NSTableView)

### Feature Enhancements
- [ ] **Table Editing**
  - Add support for INSERT operations (new rows)
  - Add support for DELETE operations
  - Bulk edit capabilities
  - Row selection and multi-row operations

- [ ] **Data Export**
  - Export query results to CSV
  - Export query results to JSON
  - Export query results to SQL INSERT statements
  - Copy data to clipboard

- [ ] **Query Management**
  - Query history (persistent)
  - Favorite queries
  - Query templates
  - Multi-statement execution

## Database Features

### MySQL/PostgreSQL
- [ ] **Re-enable Indexes Display**
  - Fix MySQLNIO assertion failures in information_schema queries
  - Implement safer query approach or error handling
  - Display indexes in Structure view

- [ ] **Re-enable Foreign Keys Display**
  - Implement foreign key queries without MySQLNIO crashes
  - Display foreign keys in Structure view
  - Visual relationship diagrams

### SQLite
- [ ] **Enhanced SQLite Support**
  - Add PRAGMA settings interface
  - Display triggers
  - Display views
  - Vacuum database option

### General
- [ ] **Multiple Simultaneous Connections**
  - Support for multiple open connections
  - Connection switcher in UI
  - Per-connection tabs

- [ ] **Database Schema Tools**
  - Schema comparison/diff tool
  - Schema export/import
  - Database migration helpers

## Performance

- [ ] **Query Optimization**
  - Query execution plans
  - Explain query option
  - Performance metrics

- [ ] **Large Dataset Handling**
  - Streaming for very large result sets
  - Virtual scrolling improvements
  - Memory optimization for large tables

## Testing

- [ ] **Unit Tests**
  - Connection manager tests
  - Query builder tests
  - SSH tunnel tests

- [ ] **Integration Tests**
  - End-to-end connection tests
  - Database operation tests

- [ ] **UI Tests**
  - Automated UI testing with SwiftDBUITests
  - Connection workflow tests

## Documentation

- [ ] **User Guide**
  - Getting started guide
  - Connection setup walkthrough
  - Query writing tips
  - Keyboard shortcuts reference

- [ ] **Developer Documentation**
  - Architecture overview
  - Adding new database drivers
  - Plugin/extension system

## Code Quality

- [ ] **Refactoring**
  - Break down large view files
  - Extract reusable components
  - Improve error handling consistency

- [ ] **Code Organization**
  - Group related files better
  - Add more detailed code comments
  - SwiftLint integration

## Nice to Have

- [ ] **Advanced Features**
  - Dark mode improvements
  - Customizable themes
  - Window state persistence
  - Multi-window support improvements
  - Drag & drop for connections
  - Backup/restore connections

- [ ] **Productivity**
  - Auto-complete for SQL keywords
  - Table/column name suggestions
  - Syntax highlighting improvements
  - Code formatting

## Known Issues

### Layout Issues
- Table content vertically centered (gap above table) - attempted 8+ fixes, all unsuccessful
- Horizontal scrollbar appears when columns expand to full width (workaround: 100px margin)

### Database-Specific Issues
- MySQLNIO crashes on complex information_schema queries (indexes, foreign keys disabled)
- Socket path auto-detection for Local by Flywheel not implemented

---

## Recently Completed ✅

- ✅ SQLite support with SQLite.swift
- ✅ SSH tunnel with dynamic port allocation
- ✅ Table cell editing (double-click)
- ✅ Large content editor for long text
- ✅ Filtering and sorting
- ✅ Column resizing with persistence
- ✅ Pagination
- ✅ Activity logging
- ✅ CLI arguments support
- ✅ Connection management UI
- ✅ File browser for SQLite/SSH keys
- ✅ Custom app icon
