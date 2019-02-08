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

class DataDocument: DocumentSource {
    
    let name: String
    
    let fileName: String? = nil
    
    lazy var contentString: String = {
        if let string = String(bytes: contentData, encoding: .utf8) {
            return string
        }
        Console.fatalError("Cannot convert data document \"\(name)\" to UTF-8 encoded string.")
    }()
    
    let contentData: Data
    
    let isValid: Bool = true
    
    init(name: String, data: Data) {
        self.name = name
        self.contentData = data
    }
    
}
