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

/// Protocol defines arbitrary source of the document.
protocol DocumentSource {
    
    /// Name of the document
    var name: String { get }
    
    /// File name, valid only when the source is a file name based.
    var fileName: String? { get }
    
    /// Content of the document converted to the String
    var contentString: String { get }
    
    /// Content of the document converted to Data
    var contentData: Data { get }
    
    /// Returns `true` if document's content is valid. The file based documents can use access to this
    /// variable to load the content.
    var isValid: Bool { get }
}

extension DocumentSource {
    
    /// Returns source identifier, which can be defined by `fileName` or `name` property.
    var sourceIdentifier: String {
        return fileName ?? name
    }
}
