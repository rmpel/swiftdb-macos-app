# Setting Up Database Dependencies

The SwiftDB application now uses **real database connectivity** via MySQLNIO and PostgresNIO. To complete the setup, you need to add these Swift Package dependencies to your Xcode project.

## Steps to Add Dependencies in Xcode

1. **Open the Project in Xcode**
   ```bash
   open SwiftDB.xcodeproj
   ```

2. **Add Package Dependencies**
   - In Xcode, select the **SwiftDB** project in the navigator (the blue icon at the top)
   - Select the **SwiftDB** target
   - Click on the **"Package Dependencies"** tab
   - Click the **"+"** button at the bottom

3. **Add MySQLNIO**
   - In the search field, paste: `https://github.com/vapor/mysql-nio.git`
   - Click **"Add Package"**
   - Select version: **"Up to Next Major Version"** with **1.7.0**
   - Click **"Add Package"** again
   - Select **MySQLNIO** from the products list
   - Click **"Add Package"**

4. **Add PostgresNIO**
   - Click the **"+"** button again
   - In the search field, paste: `https://github.com/vapor/postgres-nio.git`
   - Click **"Add Package"**
   - Select version: **"Up to Next Major Version"** with **1.18.0**
   - Click **"Add Package"** again
   - Select **PostgresNIO** from the products list
   - Click **"Add Package"**

5. **Add SQLite.swift**
   - Click the **"+"** button again
   - In the search field, paste: `https://github.com/stephencelis/SQLite.swift.git`
   - Click **"Add Package"**
   - Select version: **"Up to Next Major Version"** with **0.15.0**
   - Click **"Add Package"** again
   - Select **SQLite** from the products list
   - Click **"Add Package"**

6. **Build the Project**
   - Press **⌘B** or go to **Product > Build**
   - Xcode will download and compile the dependencies
   - This may take a few minutes on the first build

## Alternative: Using Xcode 15+ Package Integration

If you're using Xcode 15 or later:

1. Go to **File > Add Package Dependencies...**
2. Add all three packages:
   - `https://github.com/vapor/mysql-nio.git` (version 1.7.0 or later)
   - `https://github.com/vapor/postgres-nio.git` (version 1.18.0 or later)
   - `https://github.com/stephencelis/SQLite.swift.git` (version 0.15.0 or later)

## What's Changed

The application now:
- ✅ Connects to **real MySQL**, **PostgreSQL**, and **SQLite** databases
- ✅ Executes **actual SQL queries** on your database server
- ✅ Displays **real table structures** with columns
- ✅ Shows **actual data** from your tables
- ✅ Supports **SSH tunneling** for remote connections
- ✅ Handles **pagination**, **sorting**, and **filtering** with real queries
- ✅ Supports **in-place cell editing** with commit/rollback functionality

## Testing the Connection

After adding dependencies and building:

1. Click **"New Connection"**
2. Enter your database credentials:
   - **MySQL**: Usually port 3306
   - **PostgreSQL**: Usually port 5432
   - **SQLite**: Browse to your .sqlite, .db, or .sqlite3 file
3. Click **"Connect"**
4. The app will now connect to your **actual database** and show **real data**

## Troubleshooting

### Build Errors
If you get build errors after adding packages:
- Clean build folder: **Product > Clean Build Folder** (⌘⇧K)
- Rebuild: **Product > Build** (⌘B)

### Connection Issues
- Verify your database server is running
- Check firewall settings
- For SSH tunnels, ensure your SSH key is set up correctly
- Test connection with command line first:
  ```bash
  mysql -h hostname -u username -p
  # or
  psql -h hostname -U username -d database
  ```

### Package Resolution Issues
If packages fail to resolve:
- Go to **File > Packages > Reset Package Caches**
- Try again

## Dependencies Overview

- **MySQLNIO** (1.7.0+): Non-blocking, event-driven MySQL client
- **PostgresNIO** (1.18.0+): Non-blocking, event-driven PostgreSQL client
- **SQLite.swift** (0.15.0+): Type-safe SQLite3 wrapper with query builder
- MySQLNIO and PostgresNIO are built on **Swift NIO** (Network framework)
- All support async/await natively
