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

extension DocumentationDatabase {
    
    /// Function removes all unwanted sections from all documents. The implementation
    /// simply looks for "remove" metadata in documents and removes all that blocks of
    /// documentation.
    ///
    /// - Returns: true if operation succeeds
    func removeUnwantedSections() -> Bool {
        allDocuments().forEach { document in
            document.allMetadata(withName: "remove", multiline: true).forEach { metadata in
                document.removeLinesForMetadata(metadata: metadata)
            }
        }
        return true
    }
    
}
