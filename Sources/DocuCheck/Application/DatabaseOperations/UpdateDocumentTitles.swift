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

extension DocumentationDatabase {
    
    /// Updates all document titles to format required by our documentation portal.
    ///
    /// - Returns: true if operation succeeded
    func updateDocumentTitles() -> Bool {
        Console.info("Patching document titles...")
        allDocuments().forEach { document in
            guard let repo = repositoryContent(for: document.repoIdentifier) else {
                Console.fatalError("Document whith invalid repository identifier.")
            }
            let fileName = document.source.name.fileNameFromPath()
            if repo.params.auxiliaryDocuments?.contains(fileName) ?? false {
                self.updateAuxiliaryDocument(document: document, repo: repo)
            } else {
                self.updateRegularPage(document: document, repo: repo)
            }
        }
        return true
    }
    
    /// Updates all page titles in documents.
    ///
    /// - Parameters:
    ///   - document: Document to be processed
    ///   - repo: Repository containing that document.
    private func updateRegularPage(document: MarkdownDocument, repo: RepositoryContent) {
        guard let title = document.allHeaders.first else {
            Console.warning(document, "Document has no title defined.")
            return
        }
        if title.level != 1 {
            Console.warning(document, title, "First header should be level-1 heading (like `# Page title`)")
        }
        guard let line = document.line(of: title) else {
            Console.fatalError("Cannot determine line from entity.")
        }
        if line > 0 {
            Console.warning(document, title, "Header with page title is not located at first line of document.")
        }
        // Prepare link to original source
        var pageFileName = document.source.name.fileNameFromPath()
        if pageFileName == config.effectiveGlobalParameters.targetHomeFile! {
            pageFileName = repo.params.homeFile!
        }
        var baseSourcesPath = repo.repository.baseSourcesPath
        baseSourcesPath.appendPathComponent(repo.params.docsFolder!)
        baseSourcesPath.appendPathComponent(pageFileName)
        
        // Modify document
        document.remove(linesFrom: 0, count: line + 1)
        let newLines = [
            "---",
            "layout: page",
            "title: \(title.title)",
            "source: \(baseSourcesPath.absoluteString)",
            "---",
        ]
        document.add(lines: newLines, at: 0)
    }
    
    private func updateAuxiliaryDocument(document: MarkdownDocument, repo: RepositoryContent) {
        // Do nothing now...
    }
}
