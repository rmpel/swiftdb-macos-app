#!/bin/bash
# Test script for SwiftDB socket connection
# This will launch the app with CLI arguments to test your Local MySQL socket connection

# Build the app first
echo "Building SwiftDB..."
xcodebuild -scheme SwiftDB -configuration Debug build > /dev/null 2>&1

# Find the built app
APP_PATH="$HOME/Library/Developer/Xcode/DerivedData/SwiftDB-*/Build/Products/Debug/SwiftDB.app"
APP_PATH=$(ls -td $APP_PATH 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
    echo "Error: Could not find built app. Please build the project in Xcode first."
    exit 1
fi

echo "Found app at: $APP_PATH"
echo ""
echo "Launching SwiftDB with CLI arguments:"
echo "  Socket: /Users/rmpel/Library/Application Support/Local/run/EqiyRCcBh/mysql/mysqld.sock"
echo "  User: root"
echo "  Password: root"
echo "  Database: local"
echo ""
echo "Watch the Activity Log panel in the app for detailed connection information."
echo ""

# Launch the app with CLI arguments
open -a "$APP_PATH" --args \
    --socket "/Users/rmpel/Library/Application Support/Local/run/EqiyRCcBh/mysql/mysqld.sock" \
    --user root \
    --password root \
    --database local \
    --type mysql
