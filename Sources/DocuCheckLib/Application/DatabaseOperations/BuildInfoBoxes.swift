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

extension DocumentationDatabase {
    
    /// Transform all `box` metadata objects in all documents.
    /// - Returns: true if everyghing was OK.
    func updateInfoBoxes() -> Bool {
        Console.info("Building info boxes...")
        var result = true
        allDocuments().forEach { document in
            // Process all <!-- begin box ... --> metadata objects
            document.allMetadata(withName: "box", multiline: true).forEach { metadata in
                let partialResult = self.updateInfoBox(document: document, metadata: metadata)
                result = result && partialResult
            }
        }
        return result
    }
    
    
    /// Transform `<!-- begin box info -->` into `{% box info %}`.
    /// - Parameters:
    ///   - document: Current document
    ///   - metadata: Metadata object that contains box content.
    /// - Returns: `true` in case of success.
    private func updateInfoBox(document: MarkdownDocument, metadata: MarkdownMetadata) -> Bool {
        // Get box style name from first parameter
        guard let boxStyle = metadata.parameters?.first else {
            Console.warning(document, metadata.beginLine, "'\(metadata.name)' marker has no style specified.")
            return false
        }
        
        if boxStyle != "info" && boxStyle != "warning" && boxStyle != "success" {
            // This is not critical, but we should print a warning.
            Console.warning(document, metadata.beginLine, "'\(metadata.name)' marker has unknown style '\(boxStyle)'. Use 'info', 'warning' or 'success' as style parameter.")
        }
        
        // Get all box content
        guard var newLines = document.getLinesForMetadata(metadata: metadata, includeMarkers: false, removeLines: false) else {
            Console.error(document, metadata.beginLine, "updateInfoBoxes: Failed to acquire lines for '\(metadata.name)' metadata marker.")
            return false
        }
        // Prepare markers for jekyll plugin
        let boxBeginEnd = document.prepareLinesForAdd(lines: ["{% box \(boxStyle) %}", "{% endbox %}"])
        newLines.insert(boxBeginEnd[0], at: 0)
        newLines.append(boxBeginEnd[1])
        
        // Apply changes to document
        guard let startLine = document.lineNumber(forLineIdentifier: metadata.beginLine) else {
            Console.error(document, metadata.beginLine, "updateInfoBoxes: Failed to acquire start line number.")
            return false
        }
        document.removeLinesForMetadata(metadata: metadata, includeMarkers: true)
        document.add(lines: newLines, at: startLine)
        return true
    }
}
