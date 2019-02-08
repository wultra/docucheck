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

/// The `FileDocument` implements a `DocumentSource` protocol where the source of the document
/// is an actual file, stored on the local file system.
class FileDocument: DocumentSource {
    
    /// Name of the document. The last component from file path is used to set this variable.
    let name: String
    
    /// A path to the document file.
    let fileName: String?
    
    var contentString: String {
        loadContent()
        return realContentString ?? ""
    }
    
    var contentData: Data {
        loadContent()
        return realContentData ?? Data()
    }
    
    var isValid: Bool {
        loadContent()
        return realContentData != nil
    }
    
    /// If true, then file content has been already processed.
    private var isProcessed: Bool = false
    
    /// Contains decoded string if document loading did not fail.
    private var realContentString: String?
    
    /// Contains a raw data of document if loading did not fail.
    private var realContentData: Data?
    
    
    /// Initializes `FileDocument`
    ///
    /// - Parameter path: A path to file
    init(path: String) {
        self.fileName = path
        self.name = (path as NSString).lastPathComponent
    }
    
    
    /// Loads content of document from file. Only one attempt is performed, so when the loading fails,
    /// then the document will be invalid for the rest of lifetime of the object.
    private func loadContent() {
        // Test whether document was already processed or not.
        if isProcessed {
            return
        }
        // Load content of the document
        do {
            // Markd document as processed even before we try to do that.
            isProcessed = true
            
            let fileURL = URL(fileURLWithPath: fileName!)
            // Load content to raw data and string representation
            realContentData = try Data(contentsOf: fileURL)
            realContentString = try String(contentsOf: fileURL, encoding: .utf8)
            
        } catch {
            Console.error("Failed to load document at: \"\(fileName!)\". Error: \(error)")
        }
    }
}
