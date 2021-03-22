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
    
    /// Mixed entity identifier, calculated from `beginLine` and `beginInlineCommentId`.
    /// Be aware that this identifier may be altered with changes in document. This is due
    /// to fact, that each change in document cause update of array of metedata objects.
    let identifier: EntityId

    /// Optional mixed identifier of parent metadata object.
    let parentIdentifier: EntityId?

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


// This extension adds various search capability to array of `MarkdownMetadata` objects.

extension Array where Element == MarkdownMetadata {

    /// Returns all occurences of metadata objects with given name in the array.
    ///
    /// - Parameter name: Name of metadata tag to be found
    /// - Returns: Array of objects with metadata information.
    func allMetadata(withName name: String) -> [MarkdownMetadata] {
        let lowercasedName = name.lowercased()
        return filter { $0.nameForSearch == lowercasedName }
    }
    
    /// Returns all occurences of metadata objects with given name in the array.
    ///
    /// - Parameter name: Name of metadata tag to be found
    /// - Parameter multiline: Specifies whether metadata should be multiline or not.
    /// - Returns: Array of objects with metadata information.
    func allMetadata(withName name: String, multiline: Bool) -> [MarkdownMetadata] {
        let lowercasedName = name.lowercased()
        return filter { $0.isMultiline == multiline && $0.nameForSearch == lowercasedName }
    }
    
    /// Returns first metadata object with given name or nil if no such information is in array.
    ///
    /// - Parameter name: Name of metadata tag to be found
    /// - Returns: Object representing metadata information or nil if no such information is in array.
    func firstMetadata(withName name: String) -> MarkdownMetadata? {
        let lowercasedName = name.lowercased()
        return first { $0.nameForSearch == lowercasedName }
    }
    
    /// Returns first metadata object with given name or nil if no such information is in array.
    ///
    /// - Parameter name: Name of metadata tag to be found
    /// - Parameter multiline: Specifies whether metadata should be multiline or not.
    /// - Returns: Object representing metadata information or nil if no such information is in array.
    func firstMetadata(withName name: String, multiline: Bool) -> MarkdownMetadata? {
        let lowercasedName = name.lowercased()
        return first { $0.isMultiline == multiline && $0.nameForSearch == lowercasedName }
    }
    
    /// Returns metadata object with given identifier or nil if no such object exist in array.
    ///
    /// - Parameter identifier: Metadata identifier
    /// - Returns: Object representing metadata information or nil if no such information is in array.
    func getMetadata(withIdentifier identifier: EntityId) -> MarkdownMetadata? {
        return first { $0.identifier == identifier }
    }
    
    /// Returns index to metadata array for given metadata with identifier or nil if no such object exist in array.
    ///
    /// - Parameter identifier: Metadata identifier
    /// - Returns: Index of metadata information or nil if no such information is in array.
    func getMetadataIndex(withIdentifier identifier: EntityId) -> Int? {
        return firstIndex { $0.identifier == identifier }
    }
}
