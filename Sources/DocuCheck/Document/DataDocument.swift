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

/// The `DataDocument` class implements `DocumentSource` protocol and allows you
/// to initialize document with given data content. It's expected that such document
/// will be used for binary operations (like conversion to JSON representation).
/// If the string representation is requested from the object, then the conversion
/// from UTF-8 binary representation, to String, is performed.
class DataDocument: DocumentSource {
    
    let name: String
    
    let fileName: String? = nil
    
    lazy var contentString: String = {
        if let string = String(bytes: contentData, encoding: .utf8) {
            return string
        }
        Console.fatalError("Cannot convert document \"\(name)\" from UTF-8 encoded data into string.")
    }()
    
    let contentData: Data
    
    let isValid: Bool = true
    
    /// Initializes document with given name and data.
    ///
    /// - Parameters:
    ///   - name: String with formal name of the document.
    ///   - data: Data with document's content.
    init(name: String, data: Data) {
        self.name = name
        self.contentData = data
    }
    
}
