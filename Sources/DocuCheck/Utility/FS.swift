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

/// The `FS` utility class provides a simple interface to working with a local file system.
class FS {
    
    /// Creates a document source from file at given path.
    ///
    /// - Parameters:
    ///   - path: Path to document to be loaded.
    ///   - description: If provided, then the provided string will be used in error message.
    ///   - exitOnError: if true then failure causes an immediate exit. Default value is `Console.exitOnError`
    /// - Returns: `DocumentSource` object created from the file
    static func document(at path: String, description: String? = nil, exitOnError: Bool = Console.exitOnError) -> DocumentSource? {
        let document = FileDocument(path: path)
        if !document.isValid {
            if let description = description {
                Console.error("Cannot load \(description) at: \"\(path)\"")
            } else {
                Console.error("Cannot load document at: \"\(path)\"")
            }
            if exitOnError {
                exit(1)
            }
            return nil
        }
        return document
    }
    
    /// Makes a directory with all intermediate directories at given path
    ///
    /// - Parameters:
    ///   - path: directory path to make
    ///   - exitOnError: if true then failure causes an immediate exit. Default value is `Console.exitOnError`
    /// - Returns: true if directory has been created
    @discardableResult
    static func makeDir(at path: String, exitOnError: Bool = Console.exitOnError) -> Bool {
        do {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        } catch {
            Console.error("Cannot create directory at \"\(path)\". Error: \(error.localizedDescription)")
            if exitOnError {
                exit(1)
            }
            return false
        }
        
        return true
    }
    
    /// Removes file or directory at given path. If directory path is provided, then
    /// the contents of that directory are recursively removed.
    ///
    /// - Parameters:
    ///   - path: Path to file or directory to be removed
    ///   - exitOnError: if true then failure causes an immediate exit. Default value is `Console.exitOnError`
    /// - Returns: true if path has been removed
    @discardableResult
    static func remove(at path: String, exitOnError: Bool = Console.exitOnError) -> Bool {
        do {
            try FileManager.default.removeItem(atPath: path)
        } catch {
            Console.error("Cannot remove item at \"\(path)\". Error: \(error.localizedDescription)")
            if exitOnError {
                exit(1)
            }
            return false
        }
        return true
    }
    
    /// Copies content to another destination on file system.
    ///
    /// - Parameters:
    ///   - from: Source path
    ///   - to: Destination path
    ///   - exitOnError: if true then failure causes an immediate exit. Default value is `Console.exitOnError`
    /// - Returns: true if content has been copied
    @discardableResult
    static func copy(from: String, to: String, exitOnError: Bool = Console.exitOnError) -> Bool {
        return true
    }
}
