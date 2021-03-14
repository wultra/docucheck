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
	
	/// Valid if document has been renamed in loading pass.
	let documentOrigin: DocumentOrigin?
	
	/// Time of last modification
	var timeOfLastModification: Date?
    
    /// Lines in the document
    var lines: [MarkdownLine] = []
    
    /// Number of files containing reference to this document
    var referenceCount: Int = 0
    
    /// Contains mapping from anchor to header title.
    fileprivate var anchors = [String:Int]()
    
    /// Contains array with metadata information found in the document.
    fileprivate var metadata = [MarkdownMetadata]()
    
    /// Initializes document with document source and optional generator for entity identifiers.
    ///
    /// - Parameters:
    ///   - source: Source of document
    ///   - repoIdentifier: Identifier for parent's repository.
    ///   - entityIdGenerator: Entity identifier generator.
	///   - documentOrigin: Information available only if document has a different original name.
	init(source: DocumentSource, repoIdentifier: String, entityIdGenerator: EntityIdGenerator? = nil, documentOrigin: DocumentOrigin? = nil) {
        self.repoIdentifier = repoIdentifier
        self.source = source
        self.entityIdGenerator = entityIdGenerator ?? DefaultEntityIdGenerator.default
		self.documentOrigin = documentOrigin
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
        updateMetadata()
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

// MARK: - Debug
extension MarkdownDocument {
    
    /// Returns content of document. The method should be used only for debug or testing purposes.
    ///
    /// - Returns: Flat string with current content of document.
    func debugDumpLines() {
        let content = lines.map { $0.lineContent }.joined(separator: "\n")
        print("\(content)")
    }
}

// MARK: - Lines management

extension MarkdownDocument {
    
    /// Converts strings into MarkdownLine objects.
    ///
    /// - Parameter sourceLines: Lines to be converted
    /// - Returns: Array of MarkdownLine objects.
    func prepareLinesForAdd(lines sourceLines: [String]) -> [MarkdownLine] {
        return sourceLines.map { line -> MarkdownLine in
            return MarkdownLine(id: entityIdGenerator.entityId(), lineContent: line)
        }
    }
    
    /// Adds multiple lines at given position
    ///
    /// - Parameters:
    ///   - sourceLines: Lines to be added
    ///   - at: Starting position for first line
    func add(lines sourceLines: [String], at: Int)  {
        add(lines: prepareLinesForAdd(lines: sourceLines), at: at)
    }
    
    /// Adds multiple lines at given position
    ///
    /// - Parameters:
    ///   - lineObjects: Lines to be added
    ///   - at: Starting position for first line
    func add(lines lineObjects: [MarkdownLine], at: Int) {
        guard !lineObjects.isEmpty else {
            return
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
        updateMetadata()
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
        updateMetadata()
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
    
    /// Returns line object for given entity identifier, or nil if such object doesn't exist.
    ///
    /// - Parameter identifier: Number identifying the requested line object
    /// - Returns: Object representing line in document or nil, if no such object was found.
    func lineObject(forLineIdentifier identifier: EntityId) -> MarkdownLine? {
        for lineObject in lines {
            if lineObject.identifier == identifier {
                return lineObject
            }
        }
        return nil
    }
    
    /// Translates line identifier into current line number, or nil if line with such identifier doesn't exist.
    ///
    /// - Parameter identifier: Number identifying the requested line object
    /// - Returns: 
    func lineNumber(forLineIdentifier identifier: EntityId) -> Int? {
        for (ln, lineObject) in lines.enumerated() {
            if lineObject.identifier == identifier {
                return ln
            }
        }
        return nil
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
        anchors.removeAll(keepingCapacity: true)
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

// MARK: - Metadata

extension MarkdownDocument {
    
    /// Returns all occurences of metadata objects with given name in the document.
    ///
    /// - Parameter name: Name of metadata tag to be found
    /// - Returns: Array of objects with metadata information.
    func allMetadata(withName name: String) -> [MarkdownMetadata] {
        return metadata.allMetadata(withName: name)
    }
    
    /// Returns all occurences of metadata objects with given name in the document.
    ///
    /// - Parameter name: Name of metadata tag to be found
    /// - Parameter multiline: Specifies whether metadata should be multiline or not.
    /// - Returns: Array of objects with metadata information.
    func allMetadata(withName name: String, multiline: Bool) -> [MarkdownMetadata] {
        return metadata.allMetadata(withName: name, multiline: multiline)
    }
    
    /// Returns first metadata object with given name or nil if no such information is in document.
    ///
    /// - Parameter name: Name of metadata tag to be found
    /// - Returns: Object representing metadata information or nil if no such information is in document.
    func firstMetadata(withName name: String) -> MarkdownMetadata? {
        return metadata.firstMetadata(withName: name)
    }
    
    /// Returns first metadata object with given name or nil if no such information is in document.
    ///
    /// - Parameter name: Name of metadata tag to be found
    /// - Parameter multiline: Specifies whether metadata should be multiline or not.
    /// - Returns: Object representing metadata information or nil if no such information is in document.
    func firstMetadata(withName name: String, multiline: Bool) -> MarkdownMetadata? {
        return metadata.firstMetadata(withName: name, multiline: multiline)
    }
    
    /// Returns metadata object with given identifier or nil if no such object exist in document.
    ///
    /// - Parameter identifier: Metadata identifier
    /// - Returns: Object representing metadata information or nil if no such information is in document.
    func getMetadata(withIdentifier identifier: EntityId) -> MarkdownMetadata? {
        return metadata.getMetadata(withIdentifier: identifier)
    }
    
    /// Returns all nested metadata objects for given metadata object.
    ///
    /// - Parameter metadata: Parent metadata object.
    /// - Returns: All nested metadata objects
    func allNestedMetadata(parent: MarkdownMetadata) -> [MarkdownMetadata] {
        return metadata.filter { $0.parentIdentifier == parent.identifier }
    }
    
    /// Returns parent metadata object or nil if given object has no parent.
    ///
    /// - Parameter metadata: Child metadata object
    /// - Returns: Parent metadata object or nil if given object has no parent.
    func getParentMetadata(to metadata: MarkdownMetadata) -> MarkdownMetadata? {
        if let parentId = metadata.parentIdentifier {
            return getMetadata(withIdentifier: parentId)
        }
        return nil
    }
    
    /// Returns MarkdownLine objects for all lines captured in metadata structure. Returns nil in following cases:
    /// - If provided metadata structure doesn't cover multiple lines
    /// - If line numbers cannot be determined from identifiers from metadata structure.
    ///
    /// - Parameters:
    ///   - metadata: Metadata information covering required lines
    ///   - includeMarkers: If true, then also begin-end HTML metadata markers will be included in the lines.
    ///   - removeLines: If true, then function also removes selected lines from document.
    /// - Returns: Array of lines or nil, in case that metadata is not multiline, or lines cannot be determined.
    func getLinesForMetadata(metadata: MarkdownMetadata, includeMarkers: Bool = true, removeLines: Bool = false) -> [MarkdownLine]? {
        guard metadata.isMultiline else {
            return nil
        }
        guard var begin = lineNumber(forLineIdentifier: metadata.beginLine),
            var end = lineNumber(forLineIdentifier: metadata.endLine) else {
                return nil
        }
        if !includeMarkers {
            begin += 1
            end -= 1
        }
        if begin > end {
            return nil
        }
        let result = Array(lines[begin ... end])
        if removeLines {
            remove(linesFrom: begin, count: end - begin + 1)
        }
        return result
    }
    
    /// Removes all lines defined in metadata object. Note that if metadata structure defines a non-multiline
    /// object, then fucntion does nothing.
    ///
    /// - Parameter metadata: Metadata information covering lines to remove
    func removeLinesForMetadata(metadata: MarkdownMetadata, includeMarkers: Bool = true) {
        guard metadata.isMultiline else {
            return
        }
        guard var begin = lineNumber(forLineIdentifier: metadata.beginLine),
            var end = lineNumber(forLineIdentifier: metadata.endLine) else {
                return
        }
        if !includeMarkers {
            begin += 1
            end -= 1
        }
        if begin > end {
            return
        }
        remove(linesFrom: begin, count: end - begin + 1)
    }
    
    /// Helper structure representing metadata information parsed from HTML comment.
    private struct MetadataInfo {
        /// Mixed identifier, calculated from `lineIdentifier` and `commentIdentifier`
        let identifier: EntityId
        /// Parent's mixed identifier.
        let parentIdentifier: EntityId?
        /// Name of metadata entity.
        let name: String
        /// Optional parameters
        let params: [String]?
        /// Is true if entity is multiline
        let isMultiline: Bool
        /// Is true if metadata information is multiline and this is the end of it.
        let isEnd: Bool
        /// Contains line identifier for metadata information
        let lineIdentifier: EntityId
        /// Contains identifier of inline comment identifier that defines begin for metadata information
        let commentIdentifier: EntityId
        
        /// Is true if metadata information is multiline and this is the begin of it.
        var isBegin: Bool { return !isEnd }
        
        /// Converts this information structure into public MarkdownMetadata structure
        func toMetadata(endLineIdentifier: EntityId? = nil, endCommentIdentifier: EntityId? = nil) -> MarkdownMetadata {
            return MarkdownMetadata(
                identifier: identifier,
                parentIdentifier: parentIdentifier,
                name: name,
                nameForSearch: name.lowercased(),
                parameters: params,
                beginLine: lineIdentifier,
                endLine: endLineIdentifier ?? lineIdentifier,
                beginInlineCommentId: commentIdentifier,
                endInlineCommentId: endCommentIdentifier ?? commentIdentifier
            )
        }
    }
    
    /// Function updates all metadata information in the document
    fileprivate func updateMetadata() {
        // Remove all entries from metadata array
        metadata.removeAll(keepingCapacity: true)
        
        // Keeping stack of opened multiline metadata
        var stack = [MetadataInfo]()

        lines.forEach { lineObject in
            lineObject.entities.forEach { entity in
                // Skip other than "inline comments" entity
                guard let comment = entity as? MarkdownInlineComment else { return }
                // Try to parse HTML comment into metadata information
                guard let info = self.parseMetadataString(fromComment: comment, lineId: lineObject.identifier, parentId: stack.last?.identifier) else { return }
                if info.isMultiline {
                    if info.isBegin {
                        // Opening multiline metadata. Push that value to the stack.
                        stack.append(info)
                        //
                    } else {
                        // Closing multiline metadata
                        guard let onTop = stack.last else {
                            Console.warning(self, entity, "Ending metadata without the beginning comment.")
                            return
                        }
                        if !info.name.isEmpty && info.name != onTop.name {
                            Console.warning(self, entity, "Ending metadata comment is closing different metadata information. HTML comment `<!-- end \(onTop.name) -->` is expected.")
                            return
                        }
                        _ = stack.popLast()
                        if onTop.lineIdentifier == info.lineIdentifier {
                            Console.warning(self, entity, "Beginning and ending metadata comment should be placed on different lines.")
                            return
                        }
                        // Multiline metadata has been successfully closed
                        metadata.append(onTop.toMetadata(endLineIdentifier: info.lineIdentifier, endCommentIdentifier: comment.identifier))
                    }
                } else {
                    // Simple metadata, without begin - end marking
                    metadata.append(info.toMetadata())
                }
            }
        }
        
        if let onTop = stack.last {
            Console.warning("\(source.name): Metadata entity `<!-- begin \(onTop.name) -->` was not closed at the end of document.")
        }
    }
    
    /// Parses metadata from given inline comment entity.
    ///
    /// - Parameter comment: Comment to parse
    /// - Parameter lineId: Current line's identifier
    /// - Returns: Metadata information structure or nil in case of failure.
    private func parseMetadataString(fromComment comment: MarkdownInlineComment, lineId: EntityId, parentId: EntityId?) -> MetadataInfo? {
        let components = comment.content.split(separator: " ")
        if components.count > 0 {
            let firstComponent = components[0].lowercased()
            if firstComponent == "!!" {
                // Not an error, just ignore metadata comments which begins with "!!"
                return nil
            }
            if firstComponent == "end" {
                let name = components.count > 1 ? components[1] : ""
                return MetadataInfo(
                    identifier: entityIdGenerator.mixedEntityId(id1: lineId, id2: comment.identifier),
                    parentIdentifier: parentId,
                    name: String(name),
                    params: nil,
                    isMultiline: true,
                    isEnd: true,
                    lineIdentifier: lineId,
                    commentIdentifier: comment.identifier)
            }
            let isMultiline = firstComponent == "begin"
            let nameOffset = isMultiline ? 1 : 0
            let paramOffset = isMultiline ? 2 : 1
            if components.count < nameOffset + 1 {
                Console.warning(self, comment, "Insufficient information in HTML comment to create a metadata.")
                return nil
            }
            let name = String(components[nameOffset])
            let params: [String]?
            if components.count >= paramOffset + 1 {
                params = components[paramOffset..<components.endIndex].map { String($0) }
            } else {
                params = nil
            }
            return MetadataInfo(
                identifier: entityIdGenerator.mixedEntityId(id1: lineId, id2: comment.identifier),
                parentIdentifier: parentId,
                name: name,
                params: params,
                isMultiline: isMultiline,
                isEnd: false,
                lineIdentifier: lineId,
                commentIdentifier: comment.identifier)
        }
        Console.warning(self, comment, "Cannot parse metadata information.")
        return nil
    }
}


extension MarkdownHeader {
    
    /// Returns anchor name from header's title.
    var anchorName: String {
        var anchor = ""
        var lastWasDash = true  // Ignore dast at the beginning
        title.lowercased().forEach { (c) in
            let destC: Character
            if c == "." || c == "`" {
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
            warning("\(doc.originalLocalPath):\(line + 1): \(message)")
        } else {
            warning(doc, message)
        }
    }
    /// Prints warning about entity, stored in the document, in form "FileName:Line: message"
    ///
    /// - Parameters:
    ///   - doc: Document containing issue
    ///   - lineId: Line identifier
    ///   - message: Message about the problem.
    static func warning(_ doc: MarkdownDocument, _ lineId: EntityId, _ message: String) {
        if let line = doc.lineNumber(forLineIdentifier: lineId) {
            warning("\(doc.originalLocalPath):\(line + 1): \(message)")
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
        warning("\(doc.originalLocalPath): \(message)")
    }
    
    /// Prints error about entity, stored in the document, in form "FileName:Line: message"
    ///
    /// - Parameters:
    ///   - doc: Document containing issue
    ///   - entity: Related markdown element causing the issue
    ///   - message: Message about the problem.
    static func error(_ doc: MarkdownDocument, _ entity: MarkdownEntity, _ message: String) {
        if let line = doc.line(of: entity) {
            error("\(doc.originalLocalPath):\(line + 1): \(message)")
        } else {
            error(doc, message)
        }
    }
    
    /// Prints error about entity, stored in the document, in form "FileName:Line: message"
    ///
    /// - Parameters:
    ///   - doc: Document containing issue
    ///   - lineId: Line identifier
    ///   - message: Message about the problem.
    static func error(_ doc: MarkdownDocument, _ lineId: EntityId, _ message: String) {
        if let line = doc.lineNumber(forLineIdentifier: lineId)  {
            error("\(doc.originalLocalPath):\(line + 1): \(message)")
        } else {
            error(doc, message)
        }
    }
    
    /// Prints error related to document, in form "FileName: message"
    ///
    /// - Parameters:
    ///   - doc: Document containing issue
    ///   - message: Message about the problem.
    static func error(_ doc: MarkdownDocument, _ message: String) {
        error("\(doc.originalLocalPath): \(message)")
    }
}
