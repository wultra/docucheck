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

enum MarkdownParserState {
    case none
    case code
    case codeBlock(regular: Bool)
}

extension MarkdownParserState {
    /// Returns true if state of parser can affect next lines
    var isMultiline: Bool {
        return isCodeBlock
    }
    
    /// Returns true if state is any type of codeBlock state
    var isCodeBlock: Bool {
        return self == .codeBlock(regular: true) || self == .codeBlock(regular: false)
    }
    
    /// Returns true if state of parser is forbidden at the end of line. For example, if you
    /// don't close opened inline code at the end of line.
    var isForbiddenAtEnd: Bool {
        return self == .code
    }
    
    /// Returns character that can mark escape from this state. This is valid only for
    /// multiline states.
    var stateEscapeCharacter: Character {
        switch self {
        case let .codeBlock(type):
            return type ? "`" : "~"
        default:
            return "\0"
        }
    }
    
    /// Returns string that mark escape from this state. This is valid only for
    /// multiline states.
    var stateEscapeString: String {
        switch self {
        case let .codeBlock(type):
            return type ? "```" : "~~~"
        default:
            return ""
        }
    }
    
    /// Compare two MarkdownParserStates
    static func ==(lhs: MarkdownParserState, rhs: MarkdownParserState) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case (.code, .code):
            return true
        case (let .codeBlock(type1), let .codeBlock(type2)):
            return type1 == type2
        default:
            return false
        }
    }
    
    /// Compare two MarkdownParserStates
    static func !=(lhs: MarkdownParserState, rhs: MarkdownParserState) -> Bool {
        return !(lhs == rhs)
    }
}

class MarkdownParser {
    
    enum WarningLevel: Int {
        case all = 3
        case minor = 2
        case serious = 1
        case off = 0
    }
    
    static var showWarnings = WarningLevel.serious
    
    let entityIdGenerator: EntityIdGenerator
    let documentSource: DocumentSource
    
    /// Contains information about currently processed line number. Note that its 1-based, instead
    /// of zero based index, used in MarkdownDocument for line
    var currentLine: Int = 0
    
    /// Initializes parser with EntityId generator
    ///
    /// - Parameter entityIdGenerator: Generator to be used for all entities found in the lines
    init(entityIdGenerator: EntityIdGenerator, documentSource: DocumentSource) {
        self.entityIdGenerator = entityIdGenerator
        self.documentSource = documentSource
    }
    
    /// Parses a multiple lines and adds all entities found in lines.
    ///
    /// - Parameters:
    ///   - lines: Lines to parse
    ///   - initialState: Initial state of the parser
    /// - Returns: Last state of the parser
    func parse(lines: [MarkdownLine], initialState: MarkdownParserState, initialLine: Int) -> MarkdownParserState {
        var state = initialState
        currentLine = initialLine
        for lineObject in lines {
            state = parseLine(lineObject, initialState: state)
            currentLine += 1
        }
        return state
    }
    
    /// Parses and adds all markdown entities found in line
    ///
    /// - Parameters:
    ///   - line: Line object to parse
    ///   - initialState: Initial state of the parser
    /// - Returns: Last state of the parser
    private func parseLine(_ line: MarkdownLine, initialState: MarkdownParserState) -> MarkdownParserState {
        var state = initialState
        
        line.parserStateAtStart = state
        
        var nextValidOffset: Int?
        let lc = line.lineContent
        
        // Exit from codeblock
        var codeBlockEscapeChar = state.stateEscapeCharacter
        var codeBlockEscapeString = state.stateEscapeString
        
        // Iterate over all characters
        for (offset, c) in lc.enumerated() {
            // Skip characters already matched
            if let nextValid = nextValidOffset {
                if offset < nextValid {
                    continue
                }
                nextValidOffset = nil
            }
            // Analyse character based on state
            switch state {
            case .none:
                // Initial state, test all possible state changes
                switch c {
                case "\\":
                    // String escape
                    if isEscapedCharacter(lc.safeCharacter(at: offset + 1)) {
                        nextValidOffset = offset + 2
                        state = .none
                    }
                case "`":
                    // Switch to regular code or codeBlock
                    if lc.hasSubstring("```", at: offset) {
                        nextValidOffset = offset + 3
                        state = .codeBlock(regular: true)
                        codeBlockEscapeChar = state.stateEscapeCharacter
                        codeBlockEscapeString = state.stateEscapeString
                    } else {
                        state = .code
                    }
                case "~":
                    // Switch to alternate codeblock
                    if lc.hasSubstring("~~~", at: offset) {
                        nextValidOffset = offset + 3
                        state = .codeBlock(regular: false)
                        codeBlockEscapeChar = state.stateEscapeCharacter
                        codeBlockEscapeString = state.stateEscapeString
                    }
                case "[":
                    // Ignore checkboxes
                    if lc.hasSubstring("[ ]", at: offset) || lc.hasSubstring("[x]", at: offset) {
                        nextValidOffset = offset + 3
                        continue
                    }
                    // Match link
                    if let link = matchLink(in: lc, at: offset, isImage: false) {
                        line.add(entity: link)
                        nextValidOffset = lc.offset(toIndex: link.range.upperBound)
                    }
                case "!":
                    // Match image link
                    if lc.hasSubstring("![", at: offset) {
                        if let link = matchLink(in: lc, at: offset, isImage: true) {
                            line.add(entity: link)
                            nextValidOffset = lc.offset(toIndex: link.range.upperBound)
                        }
                    }
                case "#":
                    // Match header
                    if let header = matchHeader(in: lc, at: offset) {
                        line.add(entity: header)
                        // The rest of the line is not important
                        line.parserStateAtEnd = .none
                        return .none
                    }
                case "<":
                    // Match inline comment
                    if let comment = matchInlineComment(in: lc, at: offset) {
                        line.add(entity: comment)
                        nextValidOffset = lc.offset(toIndex: comment.range.upperBound)
                    }
                    
                default:
                    continue
                }
                
            case .code:
                // Inline code sequence
                if c == "`" {
                    state = .none
                }
                
            case .codeBlock:
                // Multiline code block end
                if c == codeBlockEscapeChar {
                    if lc.hasSubstring(codeBlockEscapeString, at: offset) {
                        nextValidOffset = offset + 3
                        state = .none
                    }
                }
            }
        }
        line.parserStateAtEnd = state
        return state
    }
    
    /// Matches header in given string, beginning at given offset.
    ///
    /// - Parameters:
    ///   - lc: Line content
    ///   - offset: Offset in line
    /// - Returns: Header entity or nil, if there's no header at given offset.
    private func matchHeader(in lc: String, at offset: Int) -> MarkdownEditableEntity? {
        if offset > 0 {
            let leading = lc[lc.startIndex ..< lc.index(offsetBy: offset)].trimmingCharacters(in: .whitespaces)
            if !leading.isEmpty {
                printWarning(.minor, "Invalid markdown header. You should escape hash character in text.")
                return nil
            }
            printWarning(.serious, "Markdown header should start at the beginning of line.")
        }
        let level: Int
        if lc.hasSubstring("######", at: offset) {
            level = 6
        } else if lc.hasSubstring("#####", at: offset) {
            level = 5
        } else if lc.hasSubstring("####", at: offset) {
            level = 4
        } else if lc.hasSubstring("###", at: offset) {
            level = 3
        } else if lc.hasSubstring("##", at: offset) {
            level = 2
        } else {
            level = 1
        }
        // Create a title
        let title = lc[lc.index(offsetBy: level + offset)..<lc.endIndex].trimmingCharacters(in: .whitespaces)
        // Return entity (capture a whole line)
        let range = Range(uncheckedBounds: (lc.startIndex, lc.endIndex))
        return MarkdownHeader(id: entityIdGenerator.entityId(), range: range, level: level, title: title)
    }
    
    /// Matches link in given string, beginning at given offset.
    ///
    /// - Parameters:
    ///   - lc: Line content
    ///   - offset: Offset in line
    ///   - isImage: If true, link defines inline image
    /// - Returns: Link entity or nil, if link cannot be matched
    private func matchLink(in lc: String, at offset: Int, isImage: Bool) -> MarkdownEditableEntity? {
        
        var matchStart = offset + (isImage ? 2 : 1)
        
        // Capture title
        var nextValidOffset: Int?
        var title = ""
        for (i, c) in lc[lc.index(offsetBy: matchStart)..<lc.endIndex].enumerated() {
            if let validOffset = nextValidOffset {
                if i < validOffset {
                    continue
                }
                nextValidOffset = nil
            }
            let cOffset = matchStart + i
            if c == "\\" {
                if isEscapedCharacter(lc.safeCharacter(at: cOffset + 1)) {
                    nextValidOffset = cOffset + 2
                    continue
                }
            }
            if c == "]" {
                // Validate end of title
                if !lc.hasSubstring("](", at: cOffset) {
                    printWarning(.minor, "Invalid link detected (offset \(offset + 1)). You should escape opening and closing brackets.")
                    return nil
                }
                // Capture title
                title = lc[lc.index(offsetBy: matchStart)..<lc.index(offsetBy: cOffset)].trimmingCharacters(in: .whitespaces)
                matchStart = cOffset + 2
                break
            }
        }
        if title.isEmpty {
            printWarning(.serious, "Link has empty title.")
            return nil
        }
        
        // Capture link
        // TODO: implement escapes in link
        var path = ""
        nextValidOffset = nil
        for (i, c) in lc[lc.index(offsetBy: matchStart)..<lc.endIndex].enumerated() {
            if let validOffset = nextValidOffset {
                if i < validOffset {
                    continue
                }
                nextValidOffset = nil
            }
            let cOffset = matchStart + i
            if c == ")" {
                path = String(lc[lc.index(offsetBy: matchStart)..<lc.index(offsetBy: cOffset)])
                matchStart = cOffset + 1
                break
            }
        }
        if path.isEmpty {
            printWarning(.serious, "Link \"[\(title)]\" has empty URL or path.")
            return nil
        }
        
        // Construct entity
        let range = Range(uncheckedBounds: (lc.index(offsetBy: offset), lc.index(offsetBy: matchStart)))
        return MarkdownLink(id: entityIdGenerator.entityId(), range: range, title: title, path: path, isImageLink: isImage)
    }
    
    /// Matches inline comment in current line string. Ignores if comment is not terminated at the end of line.
    ///
    /// - Parameters:
    ///   - lc: Line content
    ///   - offset: Offset in line
    /// - Returns: Comment entity or nil, if inline comment cannot be matched
    private func matchInlineComment(in lc: String, at offset: Int) -> MarkdownEditableEntity? {
        if !lc.hasSubstring("<!--", at: offset) {
            return nil
        }
        let matchStart = offset + 4
        var matchEnd = 0
        // Capture content
        var content = ""
        for (i, c) in lc[lc.index(offsetBy: matchStart)..<lc.endIndex].enumerated() {
            let cOffset = matchStart + i
            if c == "-" {
                if lc.hasSubstring("-->", at: cOffset) {
                    matchEnd = cOffset
                    content = lc[lc.index(offsetBy: matchStart)..<lc.index(offsetBy: matchEnd)].trimmingCharacters(in: .whitespaces)
                    break
                }
            }
        }
        if matchEnd == 0 || content.isEmpty {
            return nil
        }
        // Construct entity
        let range = Range(uncheckedBounds: (lc.index(offsetBy: matchEnd), lc.index(offsetBy: matchStart)))
        return MarkdownInlineComment(id: entityIdGenerator.entityId(), range: range, content: content)
    }
    
    
    /// Returns true if given character can be escaped with backslash.
    ///
    /// - Parameter c: Optional character to test
    /// - Returns: true if given character can be escaped with backshlash
    private func isEscapedCharacter(_ c: Character?) -> Bool {
        guard let c = c else {
            return false
        }
        if c == "\\" || c == "`" || c == "*" || c == "_" {
            return true
        }
        if c == "{" || c == "}" || c == "[" || c == "]" || c == "(" || c == ")" {
            return true
        }
        if c == "#" || c == "+" || c == "-" || c == "." || c == "!" {
            return true
        }
        printWarning(.serious, "Invalid escape sequence '\\\(c)'.")
        return false
    }
    
    /// Prints simple warning to the console, with location to source of issue (file, line).
    private func printWarning(_ level: WarningLevel, _ message: String) {
        if MarkdownParser.showWarnings.rawValue >= level.rawValue {
            Console.warning("\(documentSource.name):\(currentLine + 1): \(message)")
        }
    }
}
