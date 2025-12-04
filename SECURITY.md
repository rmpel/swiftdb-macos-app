# Security & Password Storage

## Important Security Notice

⚠️ **CONNECTION CREDENTIALS ARE STORED IN PLAIN TEXT**

SwiftDB currently stores all connection settings, including passwords, using Apple's SwiftData framework in an **unencrypted SQLite database**.

### Storage Location

Connection data is stored at:
```
~/Library/Containers/com.[your-team-id].SwiftDB/Data/Library/Application Support/default.store
```

### What's Stored (Unencrypted)

- Database usernames and passwords
- SSH usernames and passwords
- SSH key passphrases
- Connection hostnames and ports
- Database names
- All connection metadata

### Security Implications

1. **Plain Text Storage**: Anyone with access to your Mac user account can read the SQLite database and extract all stored credentials
2. **No Encryption**: The database file is not encrypted at rest
3. **File System Access**: Backup systems, cloud sync services, or malware could access the credentials
4. **Shared Computers**: Other users with admin access can read the container directory

## Recommended Security Practices

### 1. Use SSH Key-Based Authentication (Most Secure)

Instead of storing SSH passwords, use public key authentication:

```bash
# Generate SSH key if you don't have one
ssh-keygen -t ed25519 -C "your_email@example.com"

# Copy public key to server
ssh-copy-id user@hostname

# Configure in SwiftDB
# Select "SSH Agent" or "Public Key" authentication
# No password storage required!
```

### 2. Use System SSH Config

Store your SSH credentials in `~/.ssh/config`:

```
# ~/.ssh/config
Host myserver
    HostName example.com
    User myuser
    Port 22
    IdentityFile ~/.ssh/id_ed25519
```

In SwiftDB:
- Select "System SSH Config" as authentication method
- Enter "myserver" as SSH host
- SwiftDB will use your existing SSH configuration
- No passwords stored in SwiftDB

### 3. Don't Store Production Credentials

- Only save connections for local development databases
- Use the "Connect" button without "Save" for production servers
- Re-enter passwords each time for sensitive connections

### 4. Protect SQLite Database Files

If connecting to SQLite databases:
- SQLite files themselves are not encrypted by SwiftDB
- Protect SQLite files with filesystem permissions:
  ```bash
  chmod 600 /path/to/database.sqlite
  ```
- Don't store sensitive data in unencrypted SQLite files

### 5. Use Local-Only Connections

- Use Unix sockets instead of TCP where possible
- Connect to localhost databases only
- Use SSH tunnels for remote connections (more secure than direct TCP)

### 6. Limit Access to Your Mac

- Enable FileVault (full disk encryption)
- Use a strong user password
- Lock your Mac when away
- Don't share your user account

## Safer Connection Workflows

### Option A: Don't Save Passwords
1. Create connection with all details EXCEPT password
2. Click "Save" to save connection metadata only
3. When connecting, the app will prompt for password
4. Password is used once and not stored

**Note**: This feature is planned but not yet implemented (see TODO.md)

### Option B: Use Environment Variables
Store credentials in environment variables and reference them:

**Note**: This feature is planned but not yet implemented (see TODO.md)

### Option C: Use Read-Only Accounts
For databases that support it:
- Create database users with read-only permissions
- Store credentials for read-only accounts
- Reduces risk if credentials are compromised

## Future Security Improvements

The following security enhancements are planned (see TODO.md):

### High Priority
- **macOS Keychain Integration**: Store passwords in macOS Keychain instead of plain text
  - Keychain is encrypted and managed by macOS
  - Passwords protected by user's login password
  - Secure credential storage with OS-level protection

- **Optional Password Storage**: Add checkbox to "Remember password"
  - Unchecked: prompt for password on each connection
  - Checked: store in Keychain (when implemented)

### Medium Priority
- **Master Password**: Encrypt all stored credentials with a master password
- **SSL/TLS Support**: Secure database connections with encryption
- **Certificate Validation**: Verify server certificates for encrypted connections
- **Connection Timeouts**: Automatic disconnect after inactivity

## Comparing to Other Database Tools

### TablePlus, Sequel Pro, etc.
Most database management tools store passwords using macOS Keychain, which is encrypted and protected by the OS. SwiftDB will implement this in a future update.

### Current State
SwiftDB is an open-source project under active development. Security features are being added progressively. For production use, please follow the recommended security practices above.

## Reporting Security Issues

If you discover a security vulnerability in SwiftDB, please:
1. Do NOT open a public GitHub issue
2. Email the maintainer privately with details
3. Allow time for a patch before public disclosure

## Contributing

Security improvements are welcome! See TODO.md for planned features. Pull requests for:
- Keychain integration
- Password encryption
- Secure credential storage
- Security audit improvements

are highly encouraged.

---

**Last Updated**: December 2025
**Status**: Passwords stored in plain text (Keychain integration planned)
