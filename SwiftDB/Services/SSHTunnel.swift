//
//  SSHTunnel.swift
//  SwiftDB
//
//  Created by Remon Pel on 03/12/2025.
//

import Foundation

class SSHTunnel {
    let host: String
    let port: Int
    let username: String
    let authType: SSHAuthType
    let password: String?
    let keyPath: String?
    let keyPassphrase: String?
    let useSystemConfig: Bool
    let remoteHost: String
    let remotePort: Int

    private(set) var localPort: Int
    private var process: Process?

    // Helper function to find an available port
    private static func findAvailablePort(startingFrom: Int = 13306) -> Int {
        for port in startingFrom..<(startingFrom + 100) {
            let socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
            guard socket >= 0 else { continue }

            defer { Darwin.close(socket) }

            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = in_port_t(port).bigEndian
            addr.sin_addr.s_addr = INADDR_ANY

            let bindResult = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.bind(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }

            if bindResult == 0 {
                return port
            }
        }
        return startingFrom // Fallback to default
    }

    // Helper function to check if a port is accepting connections
    private func isPortReady(port: Int, maxAttempts: Int = 10) async -> Bool {
        for attempt in 1...maxAttempts {
            let socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
            guard socket >= 0 else {
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
                continue
            }

            defer { Darwin.close(socket) }

            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = in_port_t(port).bigEndian
            addr.sin_addr.s_addr = inet_addr("127.0.0.1")

            let connectResult = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.connect(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }

            if connectResult == 0 {
                print("✅ Tunnel port \(port) is ready (attempt \(attempt)/\(maxAttempts))")
                return true
            }

            print("⏳ Tunnel port \(port) not ready yet (attempt \(attempt)/\(maxAttempts))")
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms between attempts
        }
        return false
    }

    init(host: String, port: Int, username: String, authType: SSHAuthType,
         password: String?, keyPath: String?, keyPassphrase: String?,
         useSystemConfig: Bool, remoteHost: String, remotePort: Int) {
        self.host = host
        self.port = port
        self.username = username
        self.authType = authType
        self.password = password
        self.keyPath = keyPath
        self.keyPassphrase = keyPassphrase
        self.useSystemConfig = useSystemConfig
        self.remoteHost = remoteHost
        self.remotePort = remotePort

        // Dynamically find an available port
        self.localPort = SSHTunnel.findAvailablePort()
    }

    func start() async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")

        var arguments = [
            "-N", // No remote command
            "-L", "\(localPort):\(remoteHost):\(remotePort)", // Local port forwarding
            "-p", "\(port)", // SSH port
            "-v", // Verbose for debugging
        ]

        // Add authentication options
        if !useSystemConfig {
            arguments.append("-o")
            arguments.append("StrictHostKeyChecking=no")
        }

        if let keyPath = keyPath {
            arguments.append("-i")
            arguments.append(keyPath)
        }

        // Add host
        arguments.append("\(username)@\(host)")

        process.arguments = arguments

        print("🔧 SSH Tunnel Debug:")
        print("   Command: /usr/bin/ssh \(arguments.joined(separator: " "))")
        print("   Host: \(host)")
        print("   Port: \(port)")
        print("   Username: \(username)")
        print("   Auth Type: \(authType)")
        print("   Use System Config: \(useSystemConfig)")
        print("   Key Path: \(keyPath ?? "none")")
        print("   Local Port: \(localPort)")
        print("   Remote Host: \(remoteHost)")
        print("   Remote Port: \(remotePort)")

        // Setup pipes for output
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Read output asynchronously for debugging
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                print("📤 SSH STDOUT: \(output)")
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                print("📤 SSH STDERR: \(output)")
            }
        }

        // Handle password authentication if needed
        if authType == .password, let _ = password {
            // For password auth, we'd need to use expect or similar
            print("⚠️  Password authentication not yet implemented")
        }

        do {
            try process.run()
            self.process = process
            print("✅ SSH process started (PID: \(process.processIdentifier))")
        } catch {
            print("❌ Failed to start SSH process: \(error)")
            throw DatabaseError.connectionFailed("Failed to start SSH process: \(error.localizedDescription)")
        }

        // Wait for tunnel to establish and verify it's ready
        print("⏳ Waiting for tunnel to establish...")

        let isReady = await isPortReady(port: localPort)

        // Check if process is still running
        if !process.isRunning {
            print("❌ SSH process terminated unexpectedly")

            // Try to read any remaining output
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            if let output = String(data: outputData, encoding: .utf8), !output.isEmpty {
                print("   Final STDOUT: \(output)")
            }
            if let error = String(data: errorData, encoding: .utf8), !error.isEmpty {
                print("   Final STDERR: \(error)")
            }

            throw DatabaseError.connectionFailed("SSH tunnel failed to start - process terminated")
        }

        if !isReady {
            print("⚠️  Tunnel port not accepting connections after timeout")
            throw DatabaseError.connectionFailed("SSH tunnel port \(localPort) not ready")
        }

        print("✅ SSH tunnel established successfully on port \(localPort)")
    }

    func stop() {
        process?.terminate()
        process = nil
    }

    deinit {
        stop()
    }
}

class SSHConfigParser {
    static func parseConfig(for host: String) -> [String: String]? {
        let configPath = NSHomeDirectory() + "/.ssh/config"

        print("🔍 SSH Config Parser:")
        print("   Looking for host: \(host)")
        print("   Config path: \(configPath)")

        guard let configContent = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            print("   ❌ Could not read SSH config file")
            return nil
        }

        print("   ✅ Config file loaded (\(configContent.count) bytes)")

        var config: [String: String] = [:]
        var matchedHost = false

        for line in configContent.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            if trimmed.lowercased().hasPrefix("host ") {
                if matchedHost {
                    break // We've finished parsing our host
                }

                let hostPattern = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
                print("   Found Host entry: \(hostPattern)")
                if hostPattern == host {
                    matchedHost = true
                    print("   ✅ Matched host: \(host)")
                }
            } else if matchedHost {
                let components = trimmed.split(separator: " ", maxSplits: 1)
                if components.count == 2 {
                    let key = String(components[0]).lowercased()
                    let value = String(components[1])
                    config[key] = value
                    print("   Config: \(key) = \(value)")
                }
            }
        }

        if matchedHost {
            print("   ✅ Returning config with \(config.count) entries")
            return config
        } else {
            print("   ❌ Host '\(host)' not found in config")
            return nil
        }
    }
}
