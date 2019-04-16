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
import Darwin

/// The Console class provides simple logging facility to textual console (stderr, stdout)
class Console {
    
    /// Defines verbose level for this simple debugging facility.
    enum VerboseLevel: Int {
        /// Silences all messages.
        case off = 0
        /// Only errors will be printed to the debug console.
        case errors = 1
        /// Errors and warnings will be printed to the debug console.
        case warnings = 2
        /// All messages will be printed to the debug console.
        case all = 3
    }
    
    /// Prefix to all log messages.
    static var logPrefix: String = "DocuCheck:"
    
    /// If true, then most of sub-commands will exit on error immediately.
    static var exitOnError: Bool = false

    /// If true, then at the end of process execution, application will exit with error code, when warning occured.
    static var exitWithErrorOnWarning: Bool = false
    
    /// Closure called when Console exits on error.
    static var onExitCallback: (()->Never)?

    /// If true, then the last log was dashed line. The flag is used to prevent printing
    /// two or more dashed lines consecutively.
    private static var lastWasLine: Bool = false
    
    /// Prints two double-dashed (using equals sign) lines with message inbetween to the stdout. The header is printed
    /// only if verboseLevel is not "off"
    static func messageHeader(_ message: @autoclosure ()->String) {
        if verboseLevel != .off {
            if !lastWasLine {
                fputs("================================================================================\n", stdout)
            }
            fputs("\(message())\n", stdout)
            fputs("================================================================================\n", stdout)
            lastWasLine = true
        }
    }
    
    /// Prints dashed line to the stdout. The line is printed only if verboseLevel is not "off"
    static func messageLine() {
        if verboseLevel != .off {
            if !lastWasLine {
                fputs("--------------------------------------------------------------------------------\n", stdout)
                lastWasLine = true
            }
        }
    }

    /// Prints simple message to the stdout.
    static func message(_ message: @autoclosure ()->String) {
        if verboseLevel != .off {
            fputs("\(message())\n", stdout)
            lastWasLine = false
        }
    }

    /// Prints simple message to the stdout, but only if verboseLevel is not "off"
    static func info(_ message: @autoclosure ()->String) {
        if verboseLevel != .off {
            fputs("\(logPrefix) \(message())\n", stdout)
            lastWasLine = false
        }
    }
    
    /// Prints simple message to the stdout, but only if verboseLevel is "all"
    static func debug(_ message: @autoclosure ()->String) {
        if verboseLevel == .all {
            fputs("\(logPrefix) \(message())\n", stdout)
            lastWasLine = false
        }
    }
    
    /// Tracks number of warnings occured during the process execution
    private static var warningCount: Int = 0
    
    /// Prints warning message to the stderr, but only if verboseLevel is greater or equal to "warnings"
    static func warning(_ message: @autoclosure ()->String) {
        if verboseLevel.rawValue >= VerboseLevel.warnings.rawValue {
            fputs("\(logPrefix) WARNING: \(message())\n", stderr)
            lastWasLine = false
        }
        warningCount += 1
    }
    
    /// Exits with error when some warning occured and this behavior is requested.
    static func exitWithErrorWhenWarningOccured() {
        if warningCount > 0 && exitWithErrorOnWarning {
            exitError("'\(warningCount)' warnings occured. Exiting process with error as requested.")
        }
    }
    
    /// Prints error message to the stderr, but only if verboseLevel is not "off"
    static func error(_ message: @autoclosure ()->String) {
        if verboseLevel != .off {
            fputs("\(logPrefix) ERROR: \(message())\n", stderr)
            lastWasLine = false
        }
    }
    
    /// Prints given Error exception to the stderr, but only if verboseLevel is set to "all".
    static func error(_ exception: Error) {
        if verboseLevel != .all {
            fputs("\(logPrefix) ERROR Exception: \(exception)\n", stderr)
            lastWasLine = false
        }
    }
    
    /// Prints error message to the stderr, but only if verboseLevel is not "off". Exits application immediately.
    static func exitError(_ message: @autoclosure ()->String) -> Never {
        error(message())
        onExit()
    }
    
    /// Prints given Error exception to the stderr, but only if verboseLevel is set to "all". Exits application immediately.
    static func exitError(_ exception: Error) -> Never {
        error(exception)
        onExit()
    }
    
    /// Function is called from "exit...()" methods, to exit the application.
    static func onExit() -> Never {
        onExitCallback?()
        exit(1)
    }
    
    /// Unconditionally prints a given message and stops execution
    ///
    /// - Parameters:
    ///   - message: The string to print.
    ///   - file: The file name to print with message. The default is file path where fatalError is called for DEBUG configuration, empty string for other
    ///   - line: The line number to print along with message. The default is the line number where fatalError is called.
    static func fatalError(_ message: @autoclosure () -> String, file: StaticString = #file, line: UInt = #line) -> Never {
        Swift.fatalError(message(), file: file, line: line)
    }
    
    /// Contains stack of verbose levels
    private static var verboseLevelStack = [ VerboseLevel.warnings ]
    
    /// Contains current verbose level
    public static var verboseLevel: VerboseLevel {
        return verboseLevelStack.last ?? .warnings
    }
    
    /// Sets verbose level to desired value. The value is changed on the top of verbose level stack.
    ///
    /// - Parameter level: Verbose level to be set.
    public static func setVerboseLevel(_ level: VerboseLevel) {
        _ = verboseLevelStack.popLast()
        verboseLevelStack.append(level)
    }
    
    /// Pushes a new value to the verbose level stack.
    ///
    /// - Parameter level: Level to be pushed to verbose level stack.
    public static func pushVerboseLevel(_ level: VerboseLevel) {
        verboseLevelStack.append(verboseLevel)
    }
    
    /// Pops verbose level from the stack.
    /// If number of push-pop operations doesn't match, then raises a fatal exception.
    public static func popVerboseLevel() {
        if verboseLevelStack.popLast() == nil {
            Console.fatalError("Verbose level stack is empty.")
        }
    }
    
    /// Executes block with log verbose level temporarily changed to a given value.
    ///
    /// - Parameters:
    ///   - level: Verbose level to be set during the block execution
    ///   - block: Block to be executed with required verbose log level
    public static func doWithVerboseLevel(_ level: VerboseLevel, block: ()->Void) {
        pushVerboseLevel(level)
        block()
        popVerboseLevel()
    }
}

