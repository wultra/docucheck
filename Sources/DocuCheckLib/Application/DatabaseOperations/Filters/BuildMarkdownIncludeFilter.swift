//
// Copyright 2024 Wultra s.r.o.
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

/// Transform all `include` metadata objects in document.
class BuildMarkdownIncludeFilter: DocumentFilter {
    
    func setUpFilter(dataProvider: DocumentFilterDataProvider) -> Bool {
        Console.info("Building markdown includes...")
        return true
    }
        
    func applyFilter(to document: MarkdownDocument) -> Bool {
        var result = true
        // Process all <!-- include ... --> metadata objects
        document.allMetadata(withName: "include", multiline: false).forEach { metadata in
            let partialResult = self.updateMarkdownInclude(document: document, metadata: metadata)
            result = result && partialResult
        }
        return result
    }
        
    func tearDownFilter() -> Bool {
        // Does nothing...
        return true
    }
    
    /// Transform `<!-- include Installation.md "Installation" -->` into `<h1>Installation</h1> {% capture cpt %}{% include_relative Installation.md %}{% endcapture %} {{ cpt  | split: "---" | last }}`.
    /// - Parameters:
    ///   - document: Current document
    ///   - metadata: Metadata object that contains include content.
    /// - Returns: `true` in case of success.
    private func updateMarkdownInclude(document: MarkdownDocument, metadata: MarkdownMetadata) -> Bool {
        
        // Check metadata looks valid
        if (metadata.parameters?.count != 2) {
            Console.warning(document, metadata.beginLine, "Metadata marker must have exactly two parameters.")
            return false
        }
        
        // Get include from the 2nd parameter
        guard let include = metadata.parameters?[0] else {
            Console.warning(document, metadata.beginLine, "'\(metadata.name)' marker has no include specified.")
            return false
        }
        
        // Get heading from first parameter
        guard let heading = metadata.parameters?[1] else {
            Console.warning(document, metadata.beginLine, "'\(metadata.name)' marker has no heading specified.")
            return false
        }
        
        // Get all include content
        guard var newLines = document.getLinesForMetadata(metadata: metadata, includeMarkers: false, removeLines: false) else {
            Console.error(document, metadata.beginLine, "updateMarkdownInclude: Failed to acquire lines for '\(metadata.name)' metadata marker.")
            return false
        }
        // Prepare markers for jekyll plugin
        let inclBeginEnd = document.prepareLinesForAdd(lines: ["<h1>\(heading)</h1> {% capture cpt %}{% include_relative \(include) %}{% endcapture %} {{ cpt  | split: \"---\" | last }}"])
        newLines.insert(inclBeginEnd[0], at: 0)
        newLines.append(inclBeginEnd[1])
        
        // Apply changes to document
        guard let startLine = document.lineNumber(forLineIdentifier: metadata.beginLine) else {
            Console.error(document, metadata.beginLine, "updateMarkdownInclude: Failed to acquire start line number.")
            return false
        }
        document.removeLinesForMetadata(metadata: metadata, includeMarkers: true)
        document.add(lines: newLines, at: startLine)
        return true
    }
}
