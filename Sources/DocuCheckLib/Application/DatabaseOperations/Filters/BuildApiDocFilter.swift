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
    private enum State {
        case path
        case description
        case request
        case response(Int)
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
        let apiResponses = apiTags.allMetadata(withName: "api-response", multiline: false)
        
        // Validate order of nested tags and its parameters
        guard validateNestedTags(document: document, api: metadata, apiTags: apiTags, apiResponses: apiResponses) else {
            return nil
        }
        
        // Get API parameters
        let apiHttpMethod = apiParams[0]
        let apiUri = apiParams[1]
        let apiTitle = apiParams[2..<apiParams.count].joined(separator: " ")
        
        // Prepare jekyll plugin syntax strings
        let jekyllApiSyntax = [
            "{% api %}",                // 0
            "{% endapi %}",             // 1
            "{% apipath \(apiHttpMethod) \(apiUri) \"\(apiTitle)\" %}",
            "{% endapipath %}",         // 3
            "{% apidescription %}",     // 4
            "{% endapidescription %}",  // 5
            "{% apirequest %}",         // 6
            "{% endapirequest %}",      // 7
        ]
        let jekyllApiRespSyntax = apiResponses.flatMap { response -> [String] in
            let responseCode = response.parameters?.first ?? "-1"
            return [ "{% apiresponsetab \(responseCode) %}", "{% endapiresponsetab %}" ]
        }
        
        // Prepare markdown lines from jekyll syntax strings
        let jekyllApiSyntaxLines = document.prepareLinesForAdd(lines: jekyllApiSyntax)
        let jekyllApiRespSyntaxLines = document.prepareLinesForAdd(lines: jekyllApiRespSyntax)

        // Prepare map that provide quick lookup whether line contains metadata tag
        let apiTagsMap = apiTags.reduce(into: [:]) { $0[$1.identifier] = $1 }
        
        // Prepare array for new lines
        var newLines = [MarkdownLine]()
        newLines.reserveCapacity(oldLines.count + jekyllApiRespSyntax.count + jekyllApiSyntax.count)
        
        var currentBlock = [MarkdownLine]()     // Current collected lines between the tags
        var state: State?                       // Current generator state
        //var responseIndex = 0                   // Current index to jekyllApiRespSyntax
        
        // The `closeState` closure copies lines from `currentBlock` to `newLines` and adds
        // appropriate closing tag depending on the state
        let closeState = {
            guard let state = state else { return } // Do nothing, if state is not set yet
            // Append collected lines
            newLines.append(contentsOf: currentBlock)
            // Append closing jekyll syntax for the current state
            switch state {
            case .path:
                newLines.append(jekyllApiSyntaxLines[3])            // {% endapipath %}
            case .description:
                newLines.append(jekyllApiSyntaxLines[5])            // {% endapidescription %}
            case .request:
                newLines.append(jekyllApiSyntaxLines[7])            // {% endapirequest %}
            case .response(let index):
                newLines.append(jekyllApiRespSyntaxLines[index + 1])// {% endapiresponsetab %}
            }
        }
        
        // The `openState` closure will close the current state and appends leading marker
        // for the new state. The new state is then set to `state` variable.
        let openState = { (newState: State) in
            // Close any opened state before we switch the state
            closeState()
            // Append opening jekyll syntax for the new state
            switch newState {
            case .path:
                newLines.append(jekyllApiSyntaxLines[2])            // {% apipath METHOD URI TITLE %}
            case .description:
                newLines.append(jekyllApiSyntaxLines[4])            // {% apidescription %}
            case .request:
                newLines.append(jekyllApiSyntaxLines[6])            // {% apirequest %}
            case .response(let index):
                newLines.append(jekyllApiRespSyntaxLines[index])    // {% apiresponsetab RC %}
            }
            // Keep new state and flush collected lines
            state = newState
            currentBlock.removeAll()
        }
        
        // Let's start!
        // Append "api" and "apipath"
        newLines.append(jekyllApiSyntaxLines[0])    // {% api %}
        openState(.path)
        
        // Iterate over all original lines
        for line in oldLines {
            let copyLine: Bool
            if let tag = apiTagsMap.findTagInLine(line: line) {
                // This line contains some metadata tag.
                switch tag.nameForSearch {
                case "api-description":
                    openState(.description)
                    copyLine = false
                case "api-request":
                    openState(.request)
                    copyLine = false
                case "api-response":
                    guard let responseIndex = apiResponses.getMetadataIndex(withIdentifier: tag.identifier) else {
                        Console.error(document, tag.beginLine, "updateApiDocs: Failed to get index to response tag.")
                        return nil
                    }
                    openState(.response(responseIndex))
                    copyLine = false
                default:
                    copyLine = true
                }
            } else {
                // Ignore this meta tag and copy the whole line
                copyLine = true
            }
            if copyLine {
                currentBlock.append(line)
            }
        }
        // Close any opened state after for-loop
        closeState()
        // Final trailing marker
        newLines.append(jekyllApiRespSyntaxLines[1])    // {% endapi %}

        return newLines
    }
    
    private func validateNestedTags(document: MarkdownDocument, api: MarkdownMetadata, apiTags: [MarkdownMetadata], apiResponses: [MarkdownMetadata]) -> Bool {
        return true
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

