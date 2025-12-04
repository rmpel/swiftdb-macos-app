# SwiftDB CLI Testing

SwiftDB now supports command-line arguments for automated testing and debugging of database connections.

## Available CLI Arguments

| Argument | Description | Example |
|----------|-------------|---------|
| `--socket` | Unix socket path | `--socket /tmp/mysql.sock` |
| `--host` | TCP host address | `--host localhost` |
| `--port` | TCP port number | `--port 3306` |
| `--user` or `--username` | Database username | `--user root` |
| `--password` | Database password | `--password secret` |
| `--database` or `--db` | Database name | `--database mydb` |
| `--type` | Database type (mysql, postgresql, sqlite) | `--type mysql` |

## Manual Testing

To manually test a connection, build the app in Xcode, then run from terminal:

```bash
# For socket connection
open -a SwiftDB.app --args \
    --socket "/path/to/mysql.sock" \
    --user root \
    --password secret \
    --database mydb \
    --type mysql

# For TCP connection
open -a SwiftDB.app --args \
    --host localhost \
    --port 3306 \
    --user root \
    --password secret \
    --database mydb \
    --type mysql
```

## Debugging

When CLI arguments are provided:

1. The app will automatically attempt to connect on launch
2. The **Activity Log** panel will show detailed connection information:
   - Socket file existence check
   - File type verification
   - Socket address creation
   - Connection attempt details
   - Full error messages if connection fails

3. The connection manager will be skipped (app goes directly to connection attempt)

## Viewing Activity Log

The Activity Log is always visible at the bottom of the app window. It shows:
- **Info** (blue): General information
- **Success** (green): Successful operations
- **Warning** (yellow): Non-critical issues
- **Error** (red): Connection failures and errors

Look for the section starting with `=== MySQL Socket Connection Attempt ===` to see detailed socket connection debugging information.

## Common Issues

### Socket file not found
If you see "Socket file does not exist at path!", verify:
1. The socket path is correct
2. The MySQL/PostgreSQL server is running
3. You have permission to access the socket file

### Permission denied
If you see permission errors:
1. Check file permissions: `ls -la /path/to/socket`
2. Ensure your user has read/write access to the socket
3. Verify App Sandbox permissions in Xcode (should have Network Client enabled)

### Connection refused
If the socket exists but connection fails:
1. Verify credentials are correct
2. Check server logs for authentication errors
3. Try connecting with `mysql` CLI tool to confirm server is responding
