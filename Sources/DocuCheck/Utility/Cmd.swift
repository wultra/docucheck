//
// Copyright 2019 Wultra s.r.o.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions
// and limitations under the License.
//

import Foundation

/// The `Cmd` class helps with a simple external command execution. You can simply use following
/// code to launch a command: `Cmd("git").run(with: ["--version"])`
class Cmd {
    
    let commandPath: String
    let exitOnFailure: Bool
    
    fileprivate static let pathResolver = CmdPathResolver()
    
    /// Initialize command with path and exit on error configuration.
    ///
    /// - Parameters:
    ///   - command: Command to execute. You can simply use command without a full path.
    ///   - exitOnError: If true, then command execution will cause an immediate exit. The detault value is `Console.exitOnError`
    init(_ command: String, exitOnError: Bool = Console.exitOnError) {
        self.commandPath = Cmd.pathResolver.resolveCommandPath(command: command)
        self.exitOnFailure = exitOnError
    }

    /// Executes command with given arguments
    ///
    /// - Parameter arguments: Array with command arguments
    /// - Returns: true if execution succeeded
    @discardableResult
    func run(with arguments: [String]) -> Bool {
        
        Console.debug("Running: \(commandPath) \(arguments.joined(separator: " "))")
        
        let task = Process()
        task.launchPath = commandPath
        task.arguments = arguments
        task.launch()
        task.waitUntilExit()
        
        if task.terminationStatus != 0 {
            Console.error("Command \"\(commandPath)\" execution failed with error \(task.terminationStatus)")
            if exitOnFailure {
                exit(task.terminationStatus)
            }
            return false
        }
        return true
    }
}


/// The `CmdPathResolver` is a helper class which helps to translate command to a full path.
fileprivate class CmdPathResolver {
    
    // Thread lock
    private let lock = NSLock()
    
    // Dictionary with an already resolved commands
    private var resolvedPaths = [String:String]()
    
    /// Function resolves full path to the given command. For example, "git" may be resolved to "/usr/local/bin/git".
    /// Note that "/usr/bin/which" command is internally used to do the job.
    ///
    /// - Parameter command: Command executable for lookup. If string begins with a forward slash "/", then no lookup is performed
    ///                      and function returns command immediately.
    /// - Returns: Full path to the requested executable
    func resolveCommandPath(command: String) -> String {
        
        let whichCommand = "/usr/bin/which"
        
        // If command begins with forward slash, then return the command immediately.
        if command.first == "/" {
            return command
        }
        
        // Look for an already resolved value in the cache
        lock.lock()
        if let resolved = resolvedPaths[command] {
            lock.unlock()
            return resolved
        }
        lock.unlock()
        
        // Run "/usr/bin/which {command}" task
        let task = Process()
        task.launchPath = whichCommand
        task.arguments = [command]
        // Acquire stdout from command via Pipe
        let pipe = Pipe()
        task.standardOutput = pipe
        // Launch and get the result
        task.launch()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        let status = task.terminationStatus
        if status != 0 {
            Console.error("Cannot resolve path for command \"\(command)\". Command \(whichCommand) failed with error \(status)")
            exit(1)
        }
        // Convert result data to the string
        guard var resolved = String(data: data, encoding: .utf8) else {
            Console.error("Cannot convert path for command \"\(command)\" to UTF-8.")
            exit(1)
        }
        resolved = resolved.replacingOccurrences(of: "\n", with: "")

        // Store result to the cache        
        lock.lock()
        resolvedPaths[command] = resolved
        lock.unlock()
        
        return resolved
    }
}
