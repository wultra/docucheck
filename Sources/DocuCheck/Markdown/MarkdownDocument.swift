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

/// The `MarkdownDocument` object represents a markdown file, parsed for DocuCheck purposes.
class MarkdownDocument {
    
    /// Identifier for parent's repository.
    let repoIdentifier: String
    
    /// Source of document
    let source: DocumentSource
    
    /// Generator to be used for generate of identifiers for new entities detected in the document.
    let entityIdGenerator: EntityIdGenerator
    
    /// Lines in the document
    var lines: [MarkdownLine] = []
    
    /// Number of files containing reference to this document
    var referenceCount: Int = 0
    
    /// Contains mapping from anchor to header title.
    fileprivate var anchors = [String:Int]()
    
    /// Initializes document with document source and optional generator for entity identifiers.
    ///
    /// - Parameters:
    ///   - source: Source of document
    ///   - repoIdentifier: Identifier for parent's repository.
    ///   - entityIdGenerator: Entity identifier generator
    init(source: DocumentSource, repoIdentifier: String, entityIdGenerator: EntityIdGenerator? = nil) {
        self.repoIdentifier = repoIdentifier
        self.source = source
        self.entityIdGenerator = entityIdGenerator ?? DefaultEntityIdGenerator.default
    }
    
    /// Internal flag marking that document needs to be saved.
    private var isModifiedFlag: Bool = false
    
    /// Contains true if document has been modified and has to be saved.
    var isModified: Bool {
        return isModifiedFlag || lines.filter({ $0.isModified }).count > 0
    }
    
    /// Returns a new instance of MarkdownParser object.
    fileprivate var markdownParser: MarkdownParser {
        return MarkdownParser(entityIdGenerator: entityIdGenerator, documentSource: source)
    }
}

// MARK: - Load & Save

extension MarkdownDocument {
    
    /// Loads markdown document from given document source.
    ///
    /// - Returns: true if document has been successfully loaded
    func load() -> Bool {
        guard source.isValid else {
            return false
        }
        // Split source string into lines
        let sourceString = source.contentString.replacingOccurrences(of: "\r\n", with: "\n")
        let sourceLines = sourceString.split(separator: "\n", omittingEmptySubsequences: false)
        // Create MarkdownLine() objects
        lines = sourceLines.map { (line) -> MarkdownLine in
            return MarkdownLine(id: entityIdGenerator.entityId(), lineContent: String(line))
        }
        let lastState = markdownParser.parse(lines: lines, initialState: .none, initialLine: 0)
        if lastState.isMultiline {
            Console.warning("\(source.name): Document ended in multiline state (\(lastState)).")
        }
        updateAnchors()
        return true
    }
    
    /// Saves document to underlying file. The DocumentSource must contain a valid file name.
    ///
    /// - Returns: true if document has been successfully saved
    func save() -> Bool {
        guard isModified else {
            Console.debug("\(source.name): No save is required, because document is not modified.")
            return true
        }
        guard let fileName = source.fileName else {
            Console.error("\(source.name): Cannot save document without associated file.")
            return false
        }
        let destinationString = lines.map { $0.toString() }.joined(separator: "\n")
        do {
            try destinationString.write(toFile: fileName, atomically: true, encoding: .utf8)
        } catch {
            Console.error("Failed to write document to file: \(fileName)")
            Console.error(error)
            return false
        }
        isModifiedFlag = false
        return true
    }
}

// MARK: - Lines management

extension MarkdownDocument {
    
    /// Adds multiple lines at given position
    ///
    /// - Parameters:
    ///   - sourceLines: Lines to be added
    ///   - at: Starting position for first line
    func add(lines sourceLines: [String], at: Int)  {
        guard !sourceLines.isEmpty else {
            return
        }
        let lineObjects = sourceLines.map { line -> MarkdownLine in
            return MarkdownLine(id: entityIdGenerator.entityId(), lineContent: line)
        }
        let prevState = lineObject(at: at - 1)?.parserStateAtEnd ?? .none
        let lastState = markdownParser.parse(lines: lineObjects, initialState: prevState, initialLine: at)
        if lastState != prevState {
            if lastState.isMultiline || prevState.isMultiline {
                // You should not insert lines into a multiline entity, unless you end in the same state
                Console.warning("\(source.name): Inserted lines changed multiline state (from \(prevState) to \(lastState)).")
            }
        }
        lines.insert(contentsOf: lineObjects, at: at)
        isModifiedFlag = true
        updateAnchors()
    }
    
    /// Removes multiple lines from document
    ///
    /// - Parameters:
    ///   - from: First line to be removed
    ///   - count: Number of lines to be removed
    func remove(linesFrom from: Int, count: Int) {
        guard count > 0 else {
            return
        }
        let stateBefore = lineObject(at: from)?.parserStateAtEnd ?? .none
        let range = Range<Int>(uncheckedBounds: (from, from + count))
        lines.removeSubrange(range)
        let stateAfter = lineObject(at: from)?.parserStateAtEnd ?? .none
        if stateBefore != stateAfter {
            if stateBefore.isMultiline || stateAfter.isMultiline {
                Console.warning("\(source.name): Removed lines changed multiline state (from \(stateBefore) to \(stateAfter)).")
            }
        }
        isModifiedFlag = true
        updateAnchors()
    }
    
    /// Returns line object at given position, or nil if position is out of bounds.
    ///
    /// - Parameter at: Line to be returned
    /// - Returns: Object representing line in document or nil, if `at` is out of bounds.
    func lineObject(at: Int) -> MarkdownLine? {
        guard at >= 0 && at < lines.count else {
            return nil
        }
        return lines[at]
    }
}

// MARK: - Entities management

extension MarkdownDocument {
    
    /// Returns all entities in document with requested type
    ///
    /// - Parameter type: Type of entity, to be searched
    /// - Returns: array with all entities with requested type
    func allEntities(ofType type: EntityType) -> [MarkdownEditableEntity] {
        var result = [MarkdownEditableEntity]()
        lines.forEach { line in
            line.entities.forEach { entity in
                if entity.type == type {
                    result.append(entity)
                }
            }
        }
        return result
    }

    /// Returns line where the entity with given identifier belongs to.
    ///
    /// - Parameter entityId: Entity identifier
    /// - Returns: Line number or nil, if there's no such entity in the document.
    func line(of entityId: EntityId) -> Int? {
        for (line, lineObject) in lines.enumerated() {
            if lineObject.contains(entityId: entityId) {
                return line
            }
        }
        return nil
    }
    
    /// Returns line where the entity belongs to.
    ///
    /// - Parameter entity: Entity to be located
    /// - Returns: Line number or nil, if there's no such entity in the document.
    func line(of entity: MarkdownEntity) -> Int? {
        return line(of: entity.identifier)
    }
}

// MARK: - Specialized entities
extension MarkdownDocument {
    
    /// Returns all links in the document
    var allLinks: [MarkdownLink] {
        return allEntities(ofType: .link).map { $0 as! MarkdownLink }
    }
    
    /// Returns all headers in the document.
    var allHeaders: [MarkdownHeader] {
        return allEntities(ofType: .header).map { $0 as! MarkdownHeader }
    }
    
    /// Checks whether the document contains anchor with given name. Returns number
    /// of headers which leads to requested anchor name. Normally, there should be only one
    /// header for given anchor name.
    ///
    /// - Parameter anchorName: Name of anchor to look for
    /// - Returns: Number of headers for given anchor or nil, if document has no header leading to given anchor name
    func containsAnchor(_ anchorName: String) -> Int? {
        return anchors[anchorName]
    }
    
    /// Function updates all anchors in the document
    fileprivate func updateAnchors() {
        anchors.removeAll()
        allHeaders.forEach { (header) in
            let anchorName = header.anchorName
            if let count = self.anchors[anchorName] {
                self.anchors[anchorName] = count + 1
            } else {
                self.anchors[anchorName] = 1
            }
        }
    }
}

extension MarkdownHeader {
    
    /// Returns anchor name from header's title.
    var anchorName: String {
        var anchor = ""
        var lastWasDash = true  // Ignore dast at the beginning
        title.lowercased().forEach { (c) in
            let destC: Character
            if c == "." {
                return
            }
            if (c >= "a" && c <= "z") || (c >= "0" && c <= "9") {
                destC = c
            } else {
                destC = "-"
            }
            let isDash = destC == "-"
            if isDash && lastWasDash {
                return
            }
            lastWasDash = isDash
            anchor.append(destC)
        }
        if anchor.last == "-" {
            anchor.removeLast()
        }
        return anchor
    }
}


extension Console {
    
    /// Prints warning about entity, stored in the document, in form "FileName:Line: message"
    ///
    /// - Parameters:
    ///   - doc: Document containing issue
    ///   - entity: Related markdown element causing the issue
    ///   - message: Message about the problem.
    static func warning(_ doc: MarkdownDocument, _ entity: MarkdownEntity, _ message: String) {
        if let line = doc.line(of: entity) {
            warning("\(doc.source.name):\(line + 1): \(message)")
        } else {
            warning(doc, message)
        }
    }
    
    
    /// Prints warning related to document, in form "FileName: message"
    ///
    /// - Parameters:
    ///   - doc: Document containing issue
    ///   - message: Message about the problem.
    static func warning(_ doc: MarkdownDocument, _ message: String) {
        warning("\(doc.source.name): \(message)")
    }
}
