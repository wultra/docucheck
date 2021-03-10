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


struct MarkdownMetadata {
    
    /// Contains metadata name.
    let name: String
    
    /// A lowercased name
    let nameForSearch: String
    
    /// Contains optional metadata parameters
    let parameters: [String]?
    
    /// Line identifier where metadata information begins
    let beginLine: EntityId
    
    /// Line identifier where metadata information ends
    let endLine: EntityId
    
    /// Inline comment entity identifier where metadata information begins
    let beginInlineCommentId: EntityId
    
    /// Inline comment entity identifier where metadata information ends.
    let endInlineCommentId: EntityId
    
    /// Contains true if metadata information is stored at multiple lines
    var isMultiline: Bool {
        return beginLine != endLine
    }
}
