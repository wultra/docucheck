//
// Copyright 2021 Wultra s.r.o.
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

/// Transform all `API` metadata objects in document.
///
/// Example for API metadata annotations:
/// ~~~
/// <!-- begin API POST /note/edit Edit Note -->
/// ### POST /note/edit
/// <!-- API-DESCRIPTION -->
/// Edit an exisiting note.
/// <!-- API-REQUEST -->
/// ```json
/// {
///    "id": "12",
///    "text": "Updated text"
/// }
/// ```
/// <!-- API-RESPONSE 200 -->
/// ```json
/// {
///    "status": "OK"
/// }
/// ```
/// <!-- API-RESPONSE 401 -->
/// ```json
/// {
///    "status": "ERROR",
///    "message": "401 Unauthorized"
/// }
/// ```
/// <!-- end -->
/// ~~~
class BuildApiDocFilter: DocumentFilter {
    
    func setUpFilter(dataProvider: DocumentFilterDataProvider) -> Bool {
        Console.info("Building API docs...")
        return true
    }
        
    func applyFilter(to document: MarkdownDocument) -> Bool {
        var result = true
        // Process all <!-- api ... --> metadata objects
        document.allMetadata(withName: "api", multiline: true)
            // Prepare all changes and filted failed ones
            .compactMap { metadata -> (MarkdownMetadata, [MarkdownLine])? in
                guard let newLines = self.prepareApiChanges(document: document, metadata: metadata) else {
                    result = false
                    return nil
                }
                return (metadata, newLines)
            }
            // Apply all changes to this document
            .forEach { metadata, newLines in
                guard let startLine = document.lineNumber(forLineIdentifier: metadata.beginLine) else {
                    Console.error(document, metadata.beginLine, "updateApiDocs: Failed to acquire start line number.")
                    result = false
                    return
                }
                document.removeLinesForMetadata(metadata: metadata, includeMarkers: true)
                document.add(lines: newLines, at: startLine)
            }
        return result
    }
        
    func tearDownFilter() -> Bool {
        // Does nothing...
        return true
    }    
    
    /// State of API generator
    fileprivate enum State: Equatable {
        case api(String, String, String)
        case description
        case request
        case response
        case responseTab(String)
    }
    
    /// Transform `API` metadata hierarchy into jekyll plugin syntax. The function only prepares
    /// future changes to the document.
    ///
    /// - Parameters:
    ///   - document: Current document
    ///   - metadata: Metadata object wrapping API documentation.
    /// - Returns: Array of new lines or nil in case of failure.
    private func prepareApiChanges(document: MarkdownDocument, metadata: MarkdownMetadata) -> [MarkdownLine]? {
        // Acquire original lines
        guard let oldLines = document.getLinesForMetadata(metadata: metadata, includeMarkers: false, removeLines: false) else {
            Console.error(document, metadata.beginLine, "updateApiDocs: Failed to acquire lines for '\(metadata.name)' metadata marker.")
            return nil
        }
        // Get parameters for API
        guard let apiParams = metadata.parameters, apiParams.count >= 3 else {
            Console.warning(document, metadata.beginLine, "'\(metadata.name)' marker has insufficient number of parameters.")
            return nil
        }
        // Get all nested tags and filter API responses
        let apiTags = document.allNestedMetadata(parent: metadata)
        
        // Get API parameters
        let apiHttpMethod = apiParams[0]
        let apiUri = apiParams[1]
        let apiTitle = apiParams[2..<apiParams.count].joined(separator: " ")
        
        // Prepare map that provide quick lookup whether line contains metadata tag
        let apiTagsMap = apiTags.reduce(into: [:]) { $0[$1.beginInlineCommentId] = $1 }
        
        // Prepare array for new lines
        var newLines = [MarkdownLine]()
        newLines.reserveCapacity(oldLines.count + 4)

        // Generator state
        var state = [State]()
        
        var hasDescription = false
        var hasRequest = false
        var hasResponse = false
        
        // The `openState` closure adds a new state to state stack and appends jekyll begin-tag
        // syntax to newLines.
        let openState = { (newState: State) in
            newLines.append(contentsOf: document.prepareLinesForAdd(lines: [newState.beginTag]))
            state.append(newState)
        }
        
        // The `closeState` closure pops last state from state stack and appends jekyll end-tag
        // syntax to newLines.
        let closeState = {
            guard let topState = state.popLast() else { return }    // Do nothing, if stack is empty
            // Append closing jekyll syntax for the current state
            newLines.append(contentsOf: document.prepareLinesForAdd(lines: [topState.endTag]))
        }
        
        // Let's start!
        // Append "api" and "apipath"
        openState(.api(apiHttpMethod, apiUri, apiTitle))
        
        // Iterate over all original lines
        for line in oldLines {
            let copyLine: Bool
            if let tag = apiTagsMap.findTagInLine(line: line) {
                // This line contains some metadata tag.
                switch tag.nameForSearch {
                case "api-description":
                    guard case .api(_,_,_) = state.last else {
                        Console.warning(document, tag.beginLine, "'\(tag.name)' is not allowed in this context.")
                        return nil
                    }
                    guard !hasDescription else {
                        Console.warning(document, tag.beginLine, "'\(tag.name)' only one API-DESCRIPTION is allowed in API.")
                        return nil
                    }
                    hasDescription = true
                    openState(.description)
                    copyLine = false
                    
                case "api-request":
                    if state.last == .description {
                        closeState()
                    }
                    guard case .api(_,_,_) = state.last else {
                        Console.warning(document, tag.beginLine, "'\(tag.name)' is not allowed in this context.")
                        return nil
                    }
                    guard !hasRequest else {
                        Console.warning(document, tag.beginLine, "'\(tag.name)' only one API-REQUEST is allowed in API.")
                        return nil
                    }
                    hasRequest = true
                    openState(.request)
                    copyLine = false
                    
                case "api-response":
                    if state.last == .description || state.last == .request {
                        // Close previous description or request tag
                        closeState()
                    }
                    if case .responseTab(_) = state.last {
                        // Close previously opened response tab.
                        closeState()
                    }
                    if case .api(_,_,_) = state.last {
                    } else if state.last == .response {
                    } else {
                        Console.warning(document, tag.beginLine, "'\(tag.name)' is not allowed in this context.")
                        return nil
                    }
                    guard let statusCode = tag.parameters?.first else {
                        Console.warning(document, tag.beginLine, "'\(tag.name)' has no status code in first parameter.")
                        return nil
                    }
                    if !hasResponse {
                        // This is first response tag, so open whole response wrapping element.
                        openState(.response)
                        hasResponse = true
                    }
                    openState(.responseTab(statusCode))
                    copyLine = false
                    
                default:
                    // Unknown tag, just copy this line
                    copyLine = true
                }
            } else {
                // Ignore this meta tag and copy the whole line
                copyLine = true
            }
            if copyLine {
                newLines.append(line)
            }
        }
        // Close all opened states
        while !state.isEmpty {
            closeState()
        }
        return newLines
    }
}

fileprivate extension Dictionary where Key == EntityId, Value == MarkdownMetadata {
    /// Find metadata object matching one of inline comments available in the line.
    /// - Parameters:
    ///   - line: Line containing possible inline comments.
    /// - Returns: Metadata object or nil if no such object has been matched.
    func findTagInLine(line: MarkdownLine) -> MarkdownMetadata? {
        for comment in line.allEntities(withType: .inlineComment) {
            if let metadata = self[comment.identifier] {
                return metadata
            }
        }
        return nil
    }
}

fileprivate extension BuildApiDocFilter.State {
    static func == (lhs: BuildApiDocFilter.State, rhs: BuildApiDocFilter.State) -> Bool {
        switch (lhs, rhs) {
        case (.api, .api): return true
        case (.description, .description): return true
        case (.request, .request): return true
        case (.response, .response): return true
        case (.responseTab(let a), .responseTab(let b)):
            return a == b
        default:
            return false
        }
    }
        
    var beginTag: String {
        switch self {
        case .api(let method, let uri, let title):
            return "{% api \(method.uppercased()) \(uri) \"\(title)\" %}"
        case .description:
            return "{% apidescription %}"
        case .request:
            return "{% apirequest %}"
        case .response:
            return "{% apiresponse %}"
        case .responseTab(let statusCode):
            return "{% apiresponsetab \(statusCode) %}"
        }
    }

    var endTag: String {
        switch self {
        case .api(_, _, _):
            return "{% endapi %}"
        case .description:
            return "{% endapidescription %}"
        case .request:
            return "{% endapirequest %}"
        case .response:
            return "{% endapiresponse %}"
        case .responseTab(_):
            return "{% endapiresponsetab %}"
        }
    }
}
