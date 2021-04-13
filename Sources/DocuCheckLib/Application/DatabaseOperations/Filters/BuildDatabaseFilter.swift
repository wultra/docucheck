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

/// Transform all `DATABASE` metadata objects in document.
///
/// Example for DATABASE metadata annotations:
/// ~~~
/// <!-- begin database table es_operation_template -->
/// ### Enrollment Server Operations
/// Lorem ipsum dolor sit amet...
/// #### DDL
/// ```sql
/// create table es_operation_template (
///   id bigint not null constraint es_operation_template_pkey primary key,
///   placeholder varchar(255) not null,
///   language varchar(8) not null,
///   title varchar(255) not null,
///   message text not null,
///   attributes text
/// );
///
/// create unique index es_operation_template_placeholder on es_operation_template (placeholder, language);
/// ```
///<!-- end -->
/// ~~~
class BuildDatabaseFilter: DocumentFilter {
    
    func setUpFilter(dataProvider: DocumentFilterDataProvider) -> Bool {
        Console.info("Building database docs...")
        return true
    }
        
    func applyFilter(to document: MarkdownDocument) -> Bool {
        var result = true
        // Process all <!-- database ... --> metadata objects
        document.allMetadata(withName: "database", multiline: true)
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
                    Console.error(document, metadata.beginLine, "updateDatabaseDocs: Failed to acquire start line number.")
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
        
    /// Transform `DATABASE` metadata hierarchy into jekyll plugin syntax. The function only prepares
    /// future changes to the document.
    ///
    /// - Parameters:
    ///   - document: Current document
    ///   - metadata: Metadata object wrapping database documentation.
    /// - Returns: Array of new lines or nil in case of failure.
    private func prepareDocumentChanges(document: MarkdownDocument, metadata: MarkdownMetadata) -> [MarkdownLine]? {
        // Acquire original lines
        guard let oldLines = document.getLinesForMetadata(metadata: metadata, includeMarkers: false, removeLines: false) else {
            Console.error(document, metadata.beginLine, "updateDatabaseDocs: Failed to acquire lines for '\(metadata.name)' metadata marker.")
            return nil
        }
        // Get parameters for API
        guard let dbParams = metadata.parameters, dbParams.count >= 2 else {
            Console.warning(document, metadata.beginLine, "'\(metadata.name)' marker has insufficient number of parameters.")
            return nil
        }
        guard let firstHeader = oldLines.firstHeader(), firstHeader.level == 3 else {
            Console.warning(document, metadata.beginLine, "'\(metadata.name)' marker must contain Level-3 header with title of API endpoint.")
            return nil
        }
        
        // Get API parameters
        let dbObjectType = dbParams[0]
        let dbObjectName = dbParams[1]
        let dbObjectTitle = firstHeader.title
        
        // Prepare array for new lines
        var newLines = [MarkdownLine]()
        newLines.reserveCapacity(oldLines.count + 10)

        // Generator state
        var state = [BuildDatabaseFilterState]()
        
        var linesInDescription = 0
        var hasDefinition = false
        
        // The `openState` closure adds a new state to state stack and appends jekyll begin-tag
        // syntax to newLines.
        let openState = { (newState: BuildDatabaseFilterState) in
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
        // Open "database" block
        openState(.database(dbObjectType, dbObjectName, dbObjectTitle))
        
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
                    // #### Response XXX
                    if state.last == .description {
                        // Close previous description
                        closeState()
                    }
                    if case .definitionTab(_) = state.last {
                        // Close previously opened response tab.
                        closeState()
                    }
                    if case .database(_,_,_) = state.last {
                    } else if state.last == .definition {
                    } else {
                        Console.warning(document, header, "Definition header is not allowed in this context.")
                        return nil
                    }
                    if header.level != 4 {
                        Console.warning(document, header, "Definition header must be Level-4 header.")
                    }
                    if !hasDefinition {
                        // This is first definition tag, so open whole response wrapping element.
                        openState(.definition)
                        hasDefinition = true
                    }
                    openState(.definitionTab(header.title))
                    copyLine = false
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
        guard hasDefinition else {
            Console.warning(document, metadata.beginLine, "Database docs has no definition section. Use one or more `#### XXX` headers to declare it. XXX is name of the tab to display in the definition.")
            return nil
        }
        if linesInDescription == 0 {
            Console.warning(document, metadata.beginLine, "Database docs has no description. You should write few lines between title header and the definition.")
        }
        return newLines
    }
}

/// State of API generator
fileprivate enum BuildDatabaseFilterState: Equatable {
    
    case database(String, String, String)
    case description
    case definition
    case definitionTab(String)
    
    /// Compare two state enumerations.
    static func == (lhs: BuildDatabaseFilterState, rhs: BuildDatabaseFilterState) -> Bool {
        switch (lhs, rhs) {
        case (.database(let a1, let a2, let a3), .database(let b1, let b2, let b3)):
            return a1 == b1 && a2 == b2 && a3 == b3
        case (.description, .description): return true
        case (.definition, .definition): return true
        case (.definitionTab(let a), .definitionTab(let b)):
            return a == b
        default:
            return false
        }
    }
    
    /// Returns begin jekyll tag for state.
    var beginTag: String {
        switch self {
        case .database(let dbObjType, let dbObjName, let title):
            return "{% database \(dbObjType) \(dbObjName) \"\(title)\" %}"
        case .description:
            return "{% databasedescription %}"
        case .definition:
            return "{% databasetabs %}"
        case .definitionTab(let value):
            return "{% databasetab \(value) %}"
        }
    }

    /// Returns end jekyll tag for state.
    var endTag: String {
        switch self {
        case .database(_, _, _):
            return "{% enddatabase %}"
        case .description:
            return "{% enddatabasedescription %}"
        case .definition:
            return "{% endenddatabasetabs %}"
        case .definitionTab(_):
            return "{% endenddatabasetab %}"
        }
    }
}
