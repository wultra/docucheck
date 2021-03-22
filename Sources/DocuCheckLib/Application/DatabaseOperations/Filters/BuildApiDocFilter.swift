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
/// <!-- begin API POST /note/edit -->
/// ### Edit note
/// Edit an exisiting note.
/// #### Request
/// ```json
/// {
///    "id": "12",
///    "text": "Updated text"
/// }
/// ```
/// #### Response 200
/// ```json
/// {
///    "status": "OK"
/// }
/// ```
/// #### Response 401
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
                guard let newLines = self.prepareDocumentChanges(document: document, metadata: metadata) else {
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
        
    /// Transform `API` metadata hierarchy into jekyll plugin syntax. The function only prepares
    /// future changes to the document.
    ///
    /// - Parameters:
    ///   - document: Current document
    ///   - metadata: Metadata object wrapping API documentation.
    /// - Returns: Array of new lines or nil in case of failure.
    private func prepareDocumentChanges(document: MarkdownDocument, metadata: MarkdownMetadata) -> [MarkdownLine]? {
        // Acquire original lines
        guard let oldLines = document.getLinesForMetadata(metadata: metadata, includeMarkers: false, removeLines: false) else {
            Console.error(document, metadata.beginLine, "updateApiDocs: Failed to acquire lines for '\(metadata.name)' metadata marker.")
            return nil
        }
        // Get parameters for API
        guard let apiParams = metadata.parameters, apiParams.count >= 2 else {
            Console.warning(document, metadata.beginLine, "'\(metadata.name)' marker has insufficient number of parameters.")
            return nil
        }
        guard let firstHeader = oldLines.firstHeader(), firstHeader.level == 3 else {
            Console.warning(document, metadata.beginLine, "'\(metadata.name)' marker must contain Level-3 header with title of API endpoint.")
            return nil
        }
        
        // Get API parameters
        let apiHttpMethod = apiParams[0]
        let apiUri = apiParams[1]
        let apiTitle = firstHeader.title
        
        // Prepare array for new lines
        var newLines = [MarkdownLine]()
        newLines.reserveCapacity(oldLines.count + 10)

        // Generator state
        var state = [BuildApiDocFilterState]()
        
        var linesInDescription = 0
        var hasRequest = false
        var hasResponse = false
        
        // The `openState` closure adds a new state to state stack and appends jekyll begin-tag
        // syntax to newLines.
        let openState = { (newState: BuildApiDocFilterState) in
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
        // Open "api" block
        openState(.api(apiHttpMethod, apiUri, apiTitle))
        
        // Iterate over all original lines
        for line in oldLines {
            let copyLine: Bool
            if let header = line.firstEntity(withType: .header) as? MarkdownHeader {
                if header.identifier == firstHeader.identifier {
                    // This is the title header, copy line now and then open the description section
                    newLines.append(line)
                    openState(.description)
                    copyLine = false
                } else {
                    let lowercasedTitle = header.title.lowercased()
                    if lowercasedTitle == "request" {
                        // #### Request
                        if state.last == .description {
                            closeState()
                        }
                        guard case .api(_,_,_) = state.last else {
                            Console.warning(document, header, "API request header is not allowed in this context.")
                            return nil
                        }
                        guard !hasRequest else {
                            Console.warning(document, header, "Only one API request header is allowed in API.")
                            return nil
                        }
                        if header.level != 4 {
                            Console.warning(document, header, "API request header must be Level-4 header.")
                        }
                        hasRequest = true
                        openState(.request)
                        copyLine = false
                    } else if lowercasedTitle.hasPrefix("response") {
                        // #### Response XXX
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
                            Console.warning(document, header, "API response header is not allowed in this context.")
                            return nil
                        }
                        if header.level != 4 {
                            Console.warning(document, header, "API response header must be Level-4 header.")
                        }
                        let titleComponents = header.title.split(separator: " ")
                        guard titleComponents.count >= 2 else {
                            Console.warning(document, header, "API response header must contain a status code in its title.")
                            return nil
                        }
                        if !hasResponse {
                            // This is first response tag, so open whole response wrapping element.
                            openState(.response)
                            hasResponse = true
                        }
                        openState(.responseTab(String(titleComponents[1])))
                        copyLine = false
                    } else {
                        // Unknown header, print warning only if level is less or equal to 3.
                        if header.level <= 3 {
                            Console.warning(document, header, "Unrecognized header in API declaration.")
                        }
                        copyLine = true
                    }
                }
            } else {
                // Nothing interesting here, just copy this line
                if state.last == .description && !line.lineContent.isEmpty {
                    // If current state is description and line is not empty, then increase counter
                    linesInDescription += 1
                }
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
        
        // Post process validations
        guard hasResponse else {
            Console.warning(document, metadata.beginLine, "API has no response section. Use one or more `#### Response XXX` headers to declare it. XXX is numeric HTTP response status code.")
            return nil
        }
        if linesInDescription == 0 {
            Console.warning(document, metadata.beginLine, "API has no description. You should write few lines between title header and request header.")
        }
        return newLines
    }
}

/// State of API generator
fileprivate enum BuildApiDocFilterState: Equatable {
    
    case api(String, String, String)
    case description
    case request
    case response
    case responseTab(String)
    
    /// Compare two state enumerations.
    static func == (lhs: BuildApiDocFilterState, rhs: BuildApiDocFilterState) -> Bool {
        switch (lhs, rhs) {
        case (.api(let a1, let a2, let a3), .api(let b1, let b2, let b3)):
            return a1 == b1 && a2 == b2 && a3 == b3
        case (.description, .description): return true
        case (.request, .request): return true
        case (.response, .response): return true
        case (.responseTab(let a), .responseTab(let b)):
            return a == b
        default:
            return false
        }
    }
    
    /// Returns begin jekyll tag for state.
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

    /// Returns end jekyll tag for state.
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
