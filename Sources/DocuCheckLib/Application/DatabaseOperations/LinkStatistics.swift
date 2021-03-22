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

    /// Clear variables keeping link statistics.
    func clearLinksStatistics() {
        externalLinks.removeAll()
        amgiguousLinks.removeAll()
    }
    
    /// Add link to list of external links.
    /// - Parameter link: Tuple with document and external link.
    func addExternalLink(link: (MarkdownDocument, MarkdownLink)) {
        externalLinks.append(link)
    }
    
    /// Add link to list of ambiguous links.
    /// - Parameter link: Tuple with document and ambiguous link.
    func addAmbiguousLink(link: (MarkdownDocument, MarkdownLink)) {
        amgiguousLinks.append(link)
    }
    
    /// Prints all external links detected in the documentation. You must call
    /// updateRepositoryLinks() to update the list of external links.
    ///
    /// - Parameter repoIdentifier: Optional repo identifier. If used, only links from repository will be printed.
    func printAllExternalLinks(inRepo repoIdentifier: String? = nil) {
        
        guard externalLinks.count > 0 else {
            Console.info("There are no external links in the documentation.")
            return
        }
        Console.info("Printing all detected external links...")
        var lastDocumentName: String?
        for item in externalLinks {
            let documentName = item.document.source.name
            if let repoIdentifier = repoIdentifier {
                if !documentName.hasPrefix(repoIdentifier) {
                    continue
                }
            }
            if documentName != lastDocumentName {
                Console.info(" + \(documentName)")
                lastDocumentName = documentName
            }
            Console.info("    - \(item.link.path)")
        }
    }
    
    
    func printAllUnreferencedFiles(inRepo repoIdentifier: String? = nil) {
        let unreferenced = allUnreferencedItems()
        guard unreferenced.count > 0 else {
            Console.info("There are no unreferenced files in the documentation.")
            return
        }
        Console.info("Printing all unreferenced documentation files...")
        var lastRepoId: String?
        for item in unreferenced {
            let repoId = item.repoIdentifier
            if let wantedRepoId = repoIdentifier {
                if repoId == wantedRepoId {
                    continue
                }
            }
            if lastRepoId != repoId {
                Console.info(" + \(repoId)")
                lastRepoId = repoId
            }
            var localPath = item.localPath
            localPath.removeSubrange(Range(uncheckedBounds: (localPath.startIndex, localPath.index(offsetBy: repoId.count + 1))))
            Console.info("    - \(localPath)")
        }
    }
}
