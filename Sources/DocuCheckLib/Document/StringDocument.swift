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

/// The `StringDocument` class implements `DocumentSource` protocol and allows you
/// to initialize document with given string content. It's expected that such document
/// will be used for string operations. If the raw data is requested from the object, then
/// the conversion to UTF-8 string is performed.
class StringDocument: DocumentSource {
    
    let name: String
    
    let fileName: String?
    
    let contentString: String
    
    lazy var contentData: Data = {
        if let data = contentString.data(using: .utf8) {
            return data
        }
        Console.fatalError("Cannot convert string document \"\(name)\" to UTF-8 encoded data.")
    }()
    
    let isValid: Bool = true
    
    /// Initializes document with given name and string content.
    ///
    /// - Parameters:
    ///   - name: String with formal name of the document.
    ///   - string: String with document's content.
    init(name: String, string: String, fileName: String? = nil) {
        self.name = name
        self.contentString = string
        self.fileName = fileName
    }
    
}
