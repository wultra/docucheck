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

protocol DocumentationItem {
    
    /// Repository identifier
    var repoIdentifier: String { get }
    
    /// Contans a local path to the documentation item
    var localPath: String { get }
    
    /// Contains a file type, in form of lowercase extension (e.g. "md" for markdown, "png" for picture, etc...)
    var type: String { get }
    
    /// Returns associated MarkdownDocument if this is a markdown item
    var document: MarkdownDocument? { get }
    
    /// Contains a reference couter, which is increased when other documentation item links this item.
    var referenceCount: Int { get set }
    
    /// Contains true if item represents a directory.
    var isDirectory: Bool { get }
	
	/// Contains time of last modification.
	var timeOfLastModification: Date? { get set }
}

/// The FileItem representing any file in the documentation.
class FileItem: DocumentationItem {
    let repoIdentifier: String
    let localPath: String
    let type: String
    var referenceCount: Int = 0
    let isDirectory: Bool = false
	var timeOfLastModification: Date?
    let document: MarkdownDocument? = nil
    
    init(repoIdentifier: String, localPath: String) {
        self.repoIdentifier = repoIdentifier
        self.localPath = localPath
        self.type = localPath.fileExtensionFromPath()
    }
}

/// The DirItem representing any directory in the documentation.
class DirItem: DocumentationItem {
    let repoIdentifier: String
    let localPath: String
    // Type of directory is not defined
    let type: String = ""
    // Directory is implicitly referenced, we don't need to warning about missing link to it.
    var referenceCount: Int = 1
    let isDirectory: Bool = true
	var timeOfLastModification: Date?
    let document: MarkdownDocument? = nil
    
    init(repoIdentifier: String, localPath: String) {
        self.repoIdentifier = repoIdentifier
        self.localPath = localPath
    }
}

// MARK: - MarkdownDocument + DocumentationItem

extension MarkdownDocument: DocumentationItem {
    
    /// Returns document source's name
    var localPath: String {
        return self.source.name
    }
	
	/// Returns original local path which may be different to `localPath` if document has been renamed.
	var originalLocalPath: String {
		return documentOrigin?.originalLocalPath ?? localPath
	}
    
    /// Returns file type of document, extracted from `localPath`
    var type: String {
        return localPath.fileExtensionFromPath()
    }
    
    /// Contains self, because `MarkdownDocument` fulfil `DocumentationItem` protocol.
    var document: MarkdownDocument? {
        return self
    }
    
    var isDirectory: Bool {
        return false
    }
    
    /// Helper function creates a documentation item stored at given path. If file at `basePath/localPath`
    /// exists, then creates a `MarkdownDocument()` object, otherwise the `FileItem()`is created.
    ///
    /// - Parameters:
    ///   - repoIdentifier: Repository identifier
    ///   - localPath: Local relative path to `basePath`
    ///   - basePath: Base path, where all documents suppose to be stored
	///   - origin: Valid in case that document was renamed from different file.
    /// - Returns: DocumentationItem object
	static func documentationItem(repoIdentifier: String, localPath: String, basePath: String, origin: DocumentOrigin?) -> DocumentationItem {
        let fullPath = basePath.addingPathComponent(localPath)
        guard let fileDocument = FS.document(at: fullPath, name: localPath) else {
            return FileItem(repoIdentifier: repoIdentifier, localPath: localPath)
        }
        return MarkdownDocument(source: fileDocument, repoIdentifier: repoIdentifier, documentOrigin: origin)
    }
    
    
    
    var localParentDir: String {
        let dir = source.name.directoryFromPath()
        if dir == repoIdentifier {
            return ""
        }
        return dir
    }
    
}
