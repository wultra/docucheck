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
        document.allMetadata(withName: "INCLUDE", multiline: false).forEach { metadata in
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
        if (metadata.parameters?.count ?? 0 < 2) {
            Console.warning(document, metadata.beginLine, "Metadata marker must have exactly two parameters.")
            return false
        }
        
        // Get include from the 1st parameter
        guard let include = metadata.parameters?[0] else {
            Console.warning(document, metadata.beginLine, "'\(metadata.name)' marker has no include specified.")
            return false
        }
        
        // Get heading from remaining parameters
        let headingWords = metadata.parameters?.dropFirst()
        let heading = headingWords?.joined(separator: " ")
        
        // Prepare markers for jekyll plugin
        let inclLine = document.prepareLinesForAdd(lines: ["<h1>\(heading ?? "")</h1> {% capture cpt %}{% include_relative \(include) %}{% endcapture %} {% assign res = cpt | split: "---" %} {% if res[0] == '' %} {{ res | slice: 2, 1000 }} {% else %} {{ cpt }} {% endif %}"])
        
        // Apply changes to document
        guard let startLine = document.lineNumber(forLineIdentifier: metadata.beginLine) else {
            Console.error(document, metadata.beginLine, "updateMarkdownInclude: Failed to acquire start line number.")
            return false
        }
        document.remove(linesFrom: startLine, count: 1)
        document.add(lines: inclLine, at: startLine)
        return true
    }
}
