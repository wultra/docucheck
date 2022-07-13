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
    ///   - name: If provided, then FileDocument will be created with given name.
    ///   - description: If provided, then the provided string will be used in error message.
    ///   - exitOnError: if true then failure causes an immediate exit. Default value is `Console.exitOnError`
    /// - Returns: `DocumentSource` object created from the file
    static func document(at path: String, name: String? = nil, description: String? = nil, exitOnError: Bool = Console.exitOnError) -> DocumentSource? {
        Console.debug("Loading \(description ?? "document") located at: \"\(path)\"")
        let document: FileDocument
        if let name = name {
            document = FileDocument(path: path, name: name)
        } else {
            document = FileDocument(path: path)
        }
        if !document.isValid {
            Console.error("Cannot load \(description ?? "document") at: \"\(path)\"")
            if exitOnError {
                exit(1)
            }
            return nil
        }
        return document
    }
    
    /// Validates whether file or directory exists at path.
    ///
    /// - Parameter path: String with path to validate
    /// - Returns: true if file exists on the path
    @discardableResult
    static func fileExists(at path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }
    
    /// Returns true if given path points to a directory.
    ///
    /// - Parameter path: String with path to investigate
    /// - Returns: true if path points to a directory
    static func isDirectory(at path: String) -> Bool {
        var isDirectory:ObjCBool = false
        let result = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        return result && isDirectory.boolValue
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
            Console.debug("Creating directory at \"\(path)\".")
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        } catch {
            Console.error("Cannot create directory at \"\(path)\".")
            Console.error(error)
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
            Console.debug("Removing item at \"\(path)\".")
            try FileManager.default.removeItem(atPath: path)
        } catch {
            Console.error("Cannot remove item at \"\(path)\".")
            Console.error(error)
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
        do {
            Console.debug("Copying item from \"\(from)\" to \"\(to)\".")
            try FileManager.default.copyItem(atPath: from, toPath: to)
        } catch {
            Console.error("Cannot copy item from \"\(from)\" to \"\(to)\".")
            Console.error(error)
            if exitOnError {
                exit(1)
            }
            return false
        }
        return true
    }
    
    
    /// Returns contents of directory at given path.
    ///
    /// - Parameters:
    ///   - path: Path to list the content
    ///   - exitOnError: if true then failure causes an immediate exit. Default value is `Console.exitOnError`
    /// - Returns: An array of strings, each of which identifies a file, directory, or symbolic link contained in path.
    ///            Returns an empty array if the directory exists but has no contents, or nil in case of error.
    static func directoryList(at path: String, exitOnError: Bool = Console.exitOnError) -> [String]? {
        do {
            return try FileManager.default.subpathsOfDirectory(atPath: path)
        } catch {
            Console.error("Cannot list content of directory at \"\(path)\".")
            Console.error(error)
            if exitOnError {
                exit(1)
            }
        }
        return nil
    }
}
