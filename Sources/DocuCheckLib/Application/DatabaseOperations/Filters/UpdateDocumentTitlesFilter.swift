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

/// Updates all document titles to format required by our documentation portal.
class UpdateDocumentTitlesFilter: DocumentFilter {
    
    var db: DocumentationDatabase!
    
    func setUpFilter(dataProvider: DocumentFilterDataProvider) -> Bool {
        Console.info("Patching document titles...")
        db = dataProvider.database
        return true
    }
        
    func applyFilter(to document: MarkdownDocument) -> Bool {
        guard let repo = db.repositoryContent(for: document.repoIdentifier) else {
            Console.fatalError("Document whith invalid repository identifier.")
        }
        let fileName = document.source.name.fileNameFromPath()
        if repo.params.auxiliaryDocuments?.contains(fileName) ?? false {
            self.updateAuxiliaryDocument(document: document, repo: repo)
        } else {
            self.updateRegularPage(document: document, repo: repo)
        }
        return true
    }
        
    func tearDownFilter() -> Bool {
        // Does nothing...
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
        // Prepare link to original source and source repository
        let originalSourcesUrl = repo.getOriginalSourceUrl(for: document.originalLocalPath)
        let originalSourceRepoUrl = repo.fullRemotePath
        
        // Time of last modification
        if document.timeOfLastModification == nil {
            Console.warning(document, "Missing time of last modification. Using midnight as a fallback.")
        }
        let timestampDate = document.timeOfLastModification ?? Calendar.current.startOfDay(for: Date())
        let timestampValue = (Int64)(timestampDate.timeIntervalSince1970)
        
        // Modify document
        document.remove(linesFrom: 0, count: line + 1)
        
        // Check if there is a template override
        var layout = "page"
        if let template = document.firstMetadata(withName: "TEMPLATE") {
            if let layoutName = template.parameters?.first {
                layout = layoutName
            } else {
                Console.warning(document, template.beginLine, "Missing template name in TEMPLATE metadata tag.")
            }
        }

        // Add common attributes
        var newLines = [
            "---",
            "layout: \(layout)",
            "title: \(title.title)",
            "timestamp: \(timestampValue)",
            "repoIdentifier: \(repo.repoIdentifier)"
        ]
        
        // Add the repository branch or tag
        if let tag = repo.repository.tag {
            newLines += [
                "tag: \(tag)",
                "version: \(tag)"
            ]
        } else if let branch = repo.repository.branch {
            newLines += [
                "branch: \(branch)",
                "version: \(branch)"
            ]
        }
        
        // Store a mark if this documentation is composed completely of a single document,
        // typically a single Readme.md file.
        if repo.params.hasSingleDocument {
            newLines += [
                "singleDocument: true"
            ]
        }
        
        // If private product URL is available, then use it as a "source" replacement.
        // Otherwise use just "source" and "sourceRepo", that points to original git source.
        if let privateProductUrl = repo.params.privateProductWebsite {
            newLines += [
                "productUrl: \(privateProductUrl)"
            ]
        } else {
            newLines += [
                "source: \(originalSourcesUrl.absoluteString)",
                "sourceRepo: \(originalSourceRepoUrl.absoluteString)",
            ]
        }
        
        // Add the release identifier in the document
        if let releaseIdentifier = repo.globalParams.releaseIdentifier {
            newLines += [
                "releaseIdentifier: \(releaseIdentifier)"
            ]
        }

        // Get the post author
        if let author = document.firstMetadata(withName: "AUTHOR") {
            if let params = author.parameters {
                if (params.count == 2) {
                    let authorName = params[0];
                    let publishDate = params[1];
                    newLines += [
                        "author: \(authorName)",
                        "published: \(publishDate)"
                    ]
                }
            }
        }
        
        // Allow overriding the sidebar file on a per file basis
        if let sidebar = document.firstMetadata(withName: "SIDEBAR") {
            if let params = sidebar.parameters {
                if (params.count >= 1) {
                    let sidebarFile = params[0];
                    newLines += [
                        "sidebar: \(sidebarFile)"
                    ]
                }
                if (params.count == 2) {
                    let sidebarPosition = params[1]; // absolute, sticky
                    newLines += [
                        "sidebarPosition: \(sidebarPosition)"
                    ]
                }
            }
        }

        // Close the Front Matter
        newLines += [
            "---"
        ]
        
        // Add the new lines
        document.add(lines: newLines, at: 0)
    }
    
    private func updateAuxiliaryDocument(document: MarkdownDocument, repo: RepositoryContent) {
        // Do nothing now...
    }
}
