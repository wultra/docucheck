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

typealias StringRange = Range<String.Index>
typealias EntityId = Int64

enum EntityType {
    case error
    case header
    case link
    case inlineComment
}

protocol MarkdownEntity {
    
    /// Contains type of entity
    var type: EntityType { get }

    /// Unique entity's identifier
    var identifier: EntityId { get }
    
    /// Defines range of string, covered by the entity
    var range: StringRange { get set }
    
    /// Creates a string representation from the entity
    func toString() -> String
}

protocol MarkdownEditableEntity: MarkdownEntity {
    
    /// Contains true if content of entity has been changed and not reflected to the backing
    /// string representation.
    var isModified: Bool { get }
    
    /// Clears modified flag
    func clearModifiedFlag()
}

class MarkdownBaseEntity: MarkdownEntity, MarkdownEditableEntity {
    
    let type: EntityType
    let identifier: EntityId
    var range: StringRange
    
    private var isModifiedFlag = false
    
    var isModified: Bool {
        return isModifiedFlag
    }
    
    init(type: EntityType, id: EntityId, range: StringRange) {
        self.type = type
        self.identifier = id
        self.range = range
    }
    
    func toString() -> String {
        Console.fatalError("Subclass must override this function.")
    }
    
    func clearModifiedFlag() {
        self.isModifiedFlag = false
    }
    
    fileprivate func setModifiedFlag() {
        self.isModifiedFlag = true
    }
}

class MarkdownHeader: MarkdownBaseEntity {

    /// Level of header (1...6)
    var level: Int {
        didSet { setModifiedFlag() }
    }
    
    /// Title of the header
    var title: String {
        didSet { setModifiedFlag() }
    }

    init(id: EntityId, range: StringRange, level: Int, title: String) {
        self.level = level
        self.title = title
        super.init(type: .header, id: id, range: range)
    }
    
    override func toString() -> String {
        let hashes = String(repeating: "#", count: level)
        return "\(hashes) \(title)"
    }
}

class MarkdownLink: MarkdownBaseEntity {
    
    /// Title for link (e.g. part in squared brackets)
    var title: String {
        didSet { setModifiedFlag() }
    }
    
    /// Path for link (e.g. part in round brackets)
    var path: String {
        didSet { setModifiedFlag() }
    }
    
    /// If true, then this is a link to inline image.
    let isImageLink: Bool
    
    init(id: EntityId, range: StringRange, title: String, path: String, isImageLink: Bool = false) {
        self.title = title
        self.path = path
        self.isImageLink = isImageLink
        super.init(type: .link, id: id, range: range)
    }
    
    override func toString() -> String {
        if isImageLink {
            return "![\(title)](\(path))"
        }
        return "[\(title)](\(path))"
    }
}

class MarkdownError: MarkdownBaseEntity {
    
    /// Contains error message
    let errorMessage: String
    /// Contains errorneous content (basically capture from range)
    let originalContent: String
    
    init(id: EntityId, range: StringRange, message: String, content: String) {
        self.errorMessage = message
        self.originalContent = content
        super.init(type: .error, id: id, range: range)
    }
    
    override func toString() -> String {
        return originalContent
    }
}

class MarkdownInlineComment: MarkdownBaseEntity {
    
    /// Content encapsulated in comment.
    /// Inline comment is a comment which begins and ends on the same line.
    var content: String {
        didSet { setModifiedFlag() }
    }
    
    init(id: EntityId, range: StringRange, content: String) {
        self.content = content
        super.init(type: .inlineComment, id: id, range: range)
    }
    
    override func toString() -> String {
        return "<!-- \(content) -->"
    }
}
