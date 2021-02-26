//
// Copyright 2020 Wultra s.r.o.
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

extension DocumentationDatabase {
    
    
    /// Transform all `codetabs` or `tabs` metadata objects in all documents.
    /// - Returns: true if everyghing was OK.
    func updateCodeTabs() -> Bool {
        Console.info("Building code tabs...")
        var result = true
        allDocuments().forEach { document in
            // Process all <!-- begin codetabs ... --> metadata objects
            document.allMetadata(withName: "codetabs", multiline: true).forEach { metadata in
                let partialResult = self.updateCodeTabs(document: document, metadata: metadata)
                result = result && partialResult
            }
            // Find all <!-- tab name --> metadata objects and create map with inline identifiers.
            let allTabMarkers: [EntityId:MarkdownMetadata] = document.allMetadata(withName: "tab", multiline: false).reduce(into: [:]) { $0[$1.beginInlineCommentId] = $1 }
            // Process all <!-- begin tabs --> metadata objects
            document.allMetadata(withName: "tabs", multiline: true).forEach { metadata in
                let partialResult = self.updateTabs(document: document, metadata: metadata, tabMarkers: allTabMarkers)
                result = result && partialResult
            }
        }
        return result
    }
    
    
    /// Transform `<!-- begin codetabs -->` metadata into `{% codetabs %}`.
    /// - Parameters:
    ///   - document: Current document
    ///   - metadata: Metadata object contains codetabs.
    /// - Returns: true in case of success.
    private func updateCodeTabs(document: MarkdownDocument, metadata: MarkdownMetadata) -> Bool {

        let tabNames = metadata.parameters ?? []
        if tabNames.isEmpty {
            Console.warning(document, metadata.beginLine, "'\(metadata.name)' marker has no tab names specified.")
        }

        // Acquire all lines
        guard let oldLines = document.getLinesForMetadata(metadata: metadata, includeMarkers: false, removeLines: false) else {
            Console.error(document, metadata.beginLine, "updateCodeTabs: Failed to acquire lines for '\(metadata.name)' metadata marker.")
            return false
        }
        var codeBlocks = [[MarkdownLine]]()
        var currentBlock = [MarkdownLine]()
        var isInCodeBlock = false
        for line in oldLines {
            let isCodeBlockAtEnd = line.parserStateAtEnd.isCodeBlock
            currentBlock.append(line)
            if isInCodeBlock != isCodeBlockAtEnd {
                // State has changed for this line
                if !isCodeBlockAtEnd {
                    codeBlocks.append(currentBlock)
                    currentBlock.removeAll()
                }
                isInCodeBlock = isCodeBlockAtEnd
            }
        }
        if !currentBlock.isEmpty {
            codeBlocks.append(currentBlock)
        }

        return applyCodeTabs(document: document, metadata: metadata, tabNames: tabNames, tabContent: codeBlocks)
    }
    
    
    /// Transform `<!-- begin tabs -->` metadata into `{% codetabs %}`.
    /// - Parameters:
    ///   - document: Document
    ///   - metadata: Metadata object
    ///   - tabMarkers: Dictionary with mapping from entity identifier to `<!-- tab -->` metadata object
    /// - Returns: true in case of success.
    private func updateTabs(document: MarkdownDocument, metadata: MarkdownMetadata, tabMarkers: [EntityId:MarkdownMetadata]) -> Bool {
        
        // Acquire all lines
        guard let oldLines = document.getLinesForMetadata(metadata: metadata, includeMarkers: false, removeLines: false) else {
            Console.error(document, metadata.beginLine, "updateTabs: Failed to acquire lines for '\(metadata.name)' metadata marker.")
            return false
        }
        
        var tabNames = [String]()
        var tabBlocks = [[MarkdownLine]]()
        var currentBlock = [MarkdownLine]()
        
        for line in oldLines {
            let copyLine: Bool
            if let tabMetadata = findTabInLine(line: line, tabMarkers: tabMarkers) {
                // It's also "tab" metadata marker
                if let tabName = tabMetadata.parameters?.first {
                    tabNames.append(tabName)
                } else {
                    Console.warning(document, tabMetadata.beginLine, "'\(tabMetadata.name)' marker must contain tab name. Using placeholder name.")
                    tabNames.append("Tab_\(tabNames.count + 1)")
                }
                if !currentBlock.isEmpty {
                    tabBlocks.append(currentBlock)
                    currentBlock.removeAll()
                }
                copyLine = false
            } else {
                // Unknown inline comment, just copy this line
                copyLine = true
            }
            if copyLine {
                if !tabNames.isEmpty {
                    currentBlock.append(line)
                } else {
                    Console.warning(document, line.identifier, "'\(metadata.name)' marker contains lines without tab name specified. Use '<!-- tab NAME -->' before this content.")
                }
            }
        }
        if !currentBlock.isEmpty {
            tabBlocks.append(currentBlock)
        }
        return applyCodeTabs(document: document, metadata: metadata, tabNames: tabNames, tabContent: tabBlocks)
    }
    
    
    /// Find metadata object matching one of inline comments available in the line.
    /// - Parameters:
    ///   - line: Line containing inline comments.
    ///   - tabMarkers: All tab metadata objects.
    /// - Returns: Metadata object or nil if no such object has been matched.
    private func findTabInLine(line: MarkdownLine, tabMarkers: [EntityId:MarkdownMetadata]) -> MarkdownMetadata? {
        for comment in line.allEntities(withType: .inlineComment) {
            if let metadata = tabMarkers[comment.identifier] {
                return metadata
            }
        }
        return nil
    }
    
    
    /// Apply `codetabs` or `tabs` changes to the document.
    /// - Parameters:
    ///   - document: Current document
    ///   - metadata: Metadata object containing `codetabs` or `tabs`
    ///   - names: Tab names
    ///   - tabContent: Content of tabs.
    /// - Returns: true in case of success.
    private func applyCodeTabs(document: MarkdownDocument, metadata: MarkdownMetadata, tabNames names: [String], tabContent: [[MarkdownLine]]) -> Bool {
        
        var tabNames = names
        
        if tabContent.count != tabNames.count {
            if tabContent.count > tabNames.count {
                Console.warning(document, metadata.beginLine, "'\(metadata.name)' meta tag contains more code blocks than tab names. Using placeholder names.")
                tabNames.append(contentsOf: (tabNames.count...tabContent.count).map { "Tab_\($0)" })
            } else {
                Console.warning(document, metadata.beginLine, "'\(metadata.name)' meta tag contains less code blocks than tab names. Ignoring remaining tab names.")
            }
        }
        
        // Prepare markers
        let codeTabsMarkers = document.prepareLinesForAdd(lines: ["{% codetabs %}", "{% endcodetabs %}"])
        let partialTabsMarkers = document.prepareLinesForAdd(lines: tabNames.flatMap { tabName -> [String] in
            return [ "{% codetab \(tabName) %}", "{% endcodetab %}" ]
        })
        var newLines = [MarkdownLine]()
        
        // Leading marker
        newLines.append(codeTabsMarkers[0])
        
        for (index, codeBlock) in tabContent.enumerated() {
            newLines.append(partialTabsMarkers[index * 2])      // {% codetab XX %}
            newLines.append(contentsOf: codeBlock)              // code block lines
            newLines.append(partialTabsMarkers[index * 2 + 1])  // {% codetab XX %}
        }

        // Trailing marker
        newLines.append(codeTabsMarkers[1])
        
        // Make modifications in document
        guard let startLine = document.lineNumber(forLineIdentifier: metadata.beginLine) else {
            Console.error(document, metadata.beginLine, "applyCodeTabs: Failed to acquire start line number.")
            return false
        }
        
        document.removeLinesForMetadata(metadata: metadata, includeMarkers: true)
        document.add(lines: newLines, at: startLine)
        
        return true
    }
}
