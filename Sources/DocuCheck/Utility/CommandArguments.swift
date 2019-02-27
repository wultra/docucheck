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

/// The `CommandArguments` is a helper class providing interface for validating
/// and processing a command line parameters.
class CommandArguments {
    
    /// Process all command line arguments. The first item in the array is ignored as path to this executable.
    ///
    /// - Parameter arguments: Array of strings to be processed
    func process(arguments: [String]) {
        var nextValidIndex = 1  // skipping first param, which is path to the process
        for (index, option) in arguments.enumerated() {
            // Check whether this option was already processed
            if index < nextValidIndex {
                continue
            }
            // Try to parse complex options, like --option=value
            let parsedOption = parseOption(option: option)
            let optionToFind = parsedOption?.option ?? option
            // Find option in map
            if let validator = optionsMap[optionToFind] {
                // We have a known option
                if validator.hasParam {
                    // The option requires a parameter
                    if validator.isShortcut {
                        let paramIndex = index + 1
                        if paramIndex >= arguments.count {
                            Console.exitError("Command line option \"\(optionToFind)\" requires parameter.")
                        }
                        validator.validate(param: arguments[paramIndex])
                        // Skip enxt string in arguments
                        nextValidIndex = paramIndex + 1
                    } else {
                        // This is not a shortcut, so it was processed by option parser.
                        if let parsedOption = parsedOption {
                            validator.validate(param: parsedOption.param)
                        } else {
                            Console.exitError("Command line option \"\(optionToFind)\" requires parameter.")
                        }
                    }
                } else {
                    // The option doesn't require parameter
                    validator.validate(param: "")
                }
            } else {
                // This option is not defined. Try to handle it as a parameter
                if let onUnknownOption = onUnknownOption {
                    if onUnknownOption(option) {
                        // successfully processed unknown param
                        continue
                    }
                }
                Console.exitError("Unknown command line option \"\(optionToFind)\".")
            }
        }
        if let afterAll = afterAll {
            afterAll()
        }
    }
    
    /// Function try to parse string as complex option in "--option=value" format.
    ///
    /// - Parameter option: String to parse
    /// - Returns: Collection of option and parameter when provided string contains a complex option, otherwise nil.
    private func parseOption(option: String) -> (option: String, param: String)? {
        if option.hasPrefix("--") {
            // Supported formats are:
            //   --param=value
            var components = option.split(separator: "=")
            if components.count == 2 {
                return (String(components[0]), String(components[1]))
            }
            if components.count > 2 {
                let option = String(components.removeFirst())
                let value = components.joined(separator: "=")
                return (option, value)
            }
        }
        return nil
    }
    

    /// Adds validation handler for option with parameter. You can provide full option and its optional shortcut variant.
    ///
    /// - Parameters:
    ///   - option: Name of the full option, for example "--path"
    ///   - shortcut: Optional shortcut, for example "-p"
    ///   - validation: Closure called when option needs to be validated
    /// - Returns: Instance of this `CommandArguments` class
    @discardableResult
    func add(option: String, shortcut: String? = nil, validation: @escaping (String)->Void) -> CommandArguments {
        guard optionsMap[option] == nil else {
            Console.fatalError("Duplicit CLI parameter \(option).")
        }
        optionsMap[option] = ParamOption(callback: validation, shortcut: false)
        if let shortcut = shortcut {
            guard optionsMap[shortcut] == nil else {
                Console.fatalError("Duplicit CLI parameter \(shortcut).")
            }
            optionsMap[shortcut] = ParamOption(callback: validation, shortcut: true)
        }
        return self
    }
    
    /// Adds validation handler for option with no parameter. You can provide full option and its optional shortcut variant.
    ///
    /// - Parameters:
    ///   - option: Name of the full option, for example "--help"
    ///   - alias: Optional shortcut, for example "-h"
    ///   - validation: Closure called when option is found in arguments
    /// - Returns: Instance of this `CommandArguments` class
    @discardableResult
    func add(option: String, alias: String? = nil, validation: @escaping ()->Void) -> CommandArguments {
        guard optionsMap[option] == nil else {
            Console.fatalError("Duplicit CLI parameter \(option).")
        }
        optionsMap[option] = SimpleOption(callback: validation)
        if let alias = alias {
            guard optionsMap[alias] == nil else {
                Console.fatalError("Duplicit CLI parameter \(alias).")
            }
            optionsMap[alias] = SimpleOption(callback: validation)
        }
        return self
    }
    
    /// Specifies closure called after all command arguments are processed.
    ///
    /// - Parameter validation: Validation closure called after all command arguments are processed
    /// - Returns: Instance of this `CommandArguments` class
    @discardableResult
    func afterAll(validation: @escaping ()->Void) -> CommandArguments {
        self.afterAll = validation
        return self
    }
    
    
    /// Specifies validation handler called when unknown option is detected in command arguments.
    ///
    /// - Parameter validation: Validation closure in case that unknown option is found. The closure gets that option
    ///                         as a parameter and must decide whether it's valid situation or not.
    /// - Returns: Instance of this `CommandArguments` class
    @discardableResult
    func onUnknownOption(validation: @escaping (String)->Bool) -> CommandArguments {
        self.onUnknownOption = validation
        return self
    }
    
    // Private classes and variables
    
    /// Internal class implementing simple option validator.
    private class SimpleOption: ValidationProtocol {
        let callback: ()->Void
        let isShortcut: Bool = false
        let hasParam: Bool = false
        init(callback: @escaping ()->Void) {
            self.callback = callback
        }
        func validate(param: String) {
            callback()
        }
    }
    
    /// Internal class implementing a parametrized option validator.
    private class ParamOption: ValidationProtocol {
        let callback: (String)->Void
        let isShortcut: Bool
        let hasParam: Bool = true
        
        init(callback: @escaping (String)->Void, shortcut: Bool) {
            self.callback = callback
            self.isShortcut = shortcut
        }
        func validate(param: String) {
            callback(param)
        }
    }
    
    /// Map from option to validator implementation
    private var optionsMap = [String: ValidationProtocol]()
    
    /// Called after all parameters are processed
    private var afterAll: (()->Void)?
    
    /// Called when unknown option is found.
    private var onUnknownOption: ((String)->Bool)?
}


/// Protocol defines validation interface used in `CommandArguments` class
fileprivate protocol ValidationProtocol {
    
    /// Called to validate parameter. If this validator doesn't require parameter, then the empty
    /// string is provided to "param"
    func validate(param: String)
    
    /// Implementation must declare whether this validator has a parameter
    var hasParam: Bool { get }
    
    /// Implementation must declare whether this validator is a shortcut. The difference between shortcut and normal
    /// option is that shortcut uses next item in arguments as a parameter. For example:
    /// - `-c config.txt` - is a shortcut option
    /// - `--config=config.txt` - is not a shortcut option
    var isShortcut: Bool { get }
}
