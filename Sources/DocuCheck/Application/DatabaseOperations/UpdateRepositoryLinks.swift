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
    
    /// Validates and updates all cross repository links
    ///
    /// - Returns: true if operation succeeded
    func updateRepositoryLinks() -> Bool {
        Console.info("Validating links in documents...")
        
        externalLinks.removeAll()
        amgiguousLinks.removeAll()
        
        allDocuments().forEach { document in
            document.allLinks.forEach { (link) in
                self.patchLink(document: document, link: link)
            }
        }
        return true
    }
    
    
    /// Validates and updates link, from given document.
    ///
    /// - Parameters:
    ///   - document: Currently processed document
    ///   - link: Link to be patched.
    private func patchLink(document: MarkdownDocument, link: MarkdownLink) {
        let path = link.path
        if path.hasPrefix("https://") || link.path.hasPrefix("http://") {
            patchExternalLink(document: document, link: link)
        } else if path.hasPrefix("#") {
            patchDocumentLink(document: document, link: link)
        } else if path.hasPrefix("../") {
            patchLocalSourceLink(document: document, link: link)
        } else {
            patchLocalLink(document: document, link: link)
        }
    }
    
    // MARK: - External link
    
    /// Structure contains information about documentation link pointing
    /// from one to another repository.
    private struct LinkInfo {
        /// Destination repository identifier
        let repoIdentifier: String
        /// Path to the document in repository. If ommited, then repository itself is referenced.
        let documentPath: String?
        /// Anchor in the document. If ommited, then there's no anchor.
        let anchorName: String?
    }
    
    /// Function parses provided path and extracts various components, if the path points to
    /// a documentation in another repository.
    ///
    /// - Parameter originalPath: Path to parse
    /// - Returns: LinkInfo if link points to a known repository, or nil, if it's link to some other internet resource.
    private func parseLink(link: String) -> LinkInfo? {
        // At first, extract anchor from the original path
        var documentPath = link
        var anchorName: String?
        if let range = documentPath.range(of: "#", options: .backwards) {
            anchorName = String(documentPath[range.upperBound ..< documentPath.endIndex])
            documentPath.removeSubrange(range.lowerBound ..< documentPath.endIndex)
        }
        // For first search, try to look for a direct links to a whole repository
        if let (repoIdentifier, _) = config.repositories.first(where: { (key, repoConfig) in
            let promoPath = repoConfig.mainRepositoryPromoPath.absoluteString
            return documentPath == promoPath || documentPath == "\(promoPath)/"
        }) {
            return LinkInfo(repoIdentifier: repoIdentifier, documentPath: nil, anchorName: anchorName)
        }
        // Now try to find cross reference links (e.g. path which begins with expected full URL to repository docs)
        guard let (repoIdentifier, repoConfig) = config.repositories.first(where: { (key, repoConfig) in
            return documentPath.hasPrefix(repoConfig.baseCrossReferencePath.absoluteString + "/")
        }) else {
            return nil
        }
        
        let baseCrossRefPath = repoConfig.baseCrossReferencePath.absoluteString + "/"
        // Now cut base path
        documentPath.removeSubrange(Range(uncheckedBounds: (documentPath.startIndex, documentPath.index(offsetBy: baseCrossRefPath.count))))
        return LinkInfo(repoIdentifier: repoIdentifier, documentPath: documentPath, anchorName: anchorName)
    }

    /// Validates and patches link to an external document (e.g. document in another documentation repository)
    ///
    /// - Parameters:
    ///   - document: Currently processed document
    ///   - link: Link to be patched.
    private func patchExternalLink(document: MarkdownDocument, link: MarkdownLink) {
        
        // We matched another repository
        guard let linkInfo = parseLink(link: link.path) else {
            // Do nothing, it's link to another internet resource.
            externalLinks.append((document, link))
            return
        }
        guard let repo = repositoryContent(for: linkInfo.repoIdentifier) else {
            Console.fatalError("Invalid repository identifier.")
        }
        // If document is not used, then use target home file
        let targetHomeFile = self.effectiveGlobalParameters.targetHomeFile!
        var documentPath = linkInfo.documentPath ?? targetHomeFile
        // Now try to remove "docs" folder from the path
        let docsFolder = repo.params.docsFolder! + "/"
        if documentPath.hasPrefix(docsFolder) {
            documentPath.removeSubrange(Range(uncheckedBounds: (documentPath.startIndex, documentPath.index(offsetBy: docsFolder.count))))
        }
        if linkInfo.repoIdentifier == document.repoIdentifier {
            if linkInfo.documentPath == nil &&  linkInfo.anchorName == "docucheck-keep-link" {
                link.path = repo.repository.mainRepositoryPromoPath.absoluteString
                return
            }
            Console.warning(document, link, "Link \(link.toString()) is using full URL, but points to the same repository. Use relative path or `#docucheck-keep-link` to keep original URL.")
        }
        
        // First check only tests whether the file exists in the destination repository
        if !repo.containsLocalFile(path: documentPath) {
            if linkInfo.documentPath == nil {
                Console.warning(document, link, "Link \(link.toString()) points directly to repository, but \"\(repo.params.homeFile!)\" is missing.")
            } else {
                Console.warning(document, link, "Link \(link.toString()) points to unknown file in the repository.")
            }
            return
        }
        // Now look more closely to the target file
        var linkedItemPath = repo.repoIdentifier.addingPathComponent(documentPath)
        guard var linkedItem = self.findDocumentationItem(path: linkedItemPath) else {
            Console.fatalError("Cannot find linked item: \(linkedItemPath)")
        }
        if linkedItem.isDirectory {
            linkedItemPath = linkedItemPath.addingPathComponent(targetHomeFile)
            if !repo.containsLocalFile(path: linkedItemPath) {
                Console.warning(document, link, "Link \(link.toString()) point to folder in repository, but \"\(repo.params.homeFile!)\" is missing in that folder.")
                return
            }
            // Find another item pointing to document
            guard let updateItem = self.findDocumentationItem(path: linkedItemPath) else {
                Console.fatalError("Cannot find linked item: \(linkedItemPath)")
            }
            linkedItem = updateItem
        }
        
        var anchorName = linkInfo.anchorName
        
        if let linkedDocument = linkedItem.document {
            if let linkedAnchor = linkInfo.anchorName {
                // Validate anchor
                if !validateAnchor(linkedDocument: linkedDocument, sourceDocument: document, link: link, anchorName: linkedAnchor) {
                    anchorName = nil
                }
            }
        } else {
            // Regular file
            if linkInfo.anchorName != nil {
                Console.warning(document, link, "Link \(link.toString()) contains anchor, but points to a non-markdown file.")
                anchorName = nil
            }
        }
        
        // Increase ref count
        linkedItem.referenceCount += 1
        
        // Now finally calculate relative path to another repository
        if linkedItemPath.fileExtensionFromPath() == "md" {
            linkedItemPath.removeSubrange(Range(uncheckedBounds: (linkedItemPath.index(offsetBy: linkedItemPath.count - 3), linkedItemPath.endIndex)))
        }
        var newRelativePath = relativePath(fromDocument: document.source.name, toDocument: linkedItemPath)
        if let anchorName = anchorName {
            newRelativePath.append("#\(anchorName)")
        }
        link.path = newRelativePath
    }
    
    private func relativePath(fromDocument: String, toDocument: String) -> String {
        var fromComponents = fromDocument.split(separator: "/").map { String($0) }
        var toComponents = toDocument.split(separator: "/").map { String($0) }
        // Look for common path components, in case that link goes to the same repo
        let minCount = min(fromComponents.count, toComponents.count)
        var commonCount = 0
        for index in 0..<minCount {
            if fromComponents[index] == toComponents[index] {
                commonCount = index + 1
            } else {
                break
            }
        }
        if commonCount > 0 {
            fromComponents.removeSubrange(0..<commonCount)
            toComponents.removeSubrange(0..<commonCount)
        }
        let fromFoldersCount = fromComponents.count - 1
        if fromFoldersCount > 0 {
            // There are some folders, which has to be eliminated
            let upperFolders = [String](repeating: "..", count: fromFoldersCount)
            toComponents.insert(contentsOf: upperFolders, at: 0)
        }
        return toComponents.joined(separator: "/")
    }
    
    // MARK: - Document anchor
    
    /// Patches and validates link inside of the same document.
    ///
    /// - Parameters:
    ///   - document: Document which suppose to have anchor
    ///   - link: Link object containing only the anchor link
    private func patchDocumentLink(document: MarkdownDocument, link: MarkdownLink) {
        let anchorName = String(link.path[link.path.index(offsetBy: 1)..<link.path.endIndex])
        validateAnchor(linkedDocument: document, link: link, anchorName: anchorName)
    }
    
    
    /// Validates whether document contains anchor
    ///
    /// - Parameters:
    ///   - linkedDocument: Document which suppose to contain an anchor
    ///   - sourceDocument: Document which contains link pointing to linked document. If nil, then linkedDocument is used for produced warning.
    ///   - link: original link, which points to document
    ///   - anchorName: Name of anchor, to be found
    @discardableResult
    private func validateAnchor(linkedDocument: MarkdownDocument, sourceDocument: MarkdownDocument? = nil, link: MarkdownLink, anchorName: String) -> Bool {
        let doc = sourceDocument ?? linkedDocument
        if let headersCount = linkedDocument.containsAnchor(anchorName) {
            if headersCount > 1 {
                Console.warning(doc, link, "Link \(link.toString()) points to multiple headers in the document.")
                return false
            }
        } else {
            Console.warning(doc, link, "Link \(link.toString()) points to an unknown header in the document.")
            return false
        }
        return true
    }
    
    
    // MARK: - Same repo link
    
    /// Patches link to a local document, located in the same repository.
    ///
    /// - Parameters:
    ///   - document: Currently processed document
    ///   - link: Link to be patched.
    private func patchLocalLink(document: MarkdownDocument, link: MarkdownLink) {
        var path = link.path
        var anchorName: String?
        if let range = path.range(of: "#", options: .backwards) {
            anchorName = String(path[range.upperBound ..< path.endIndex])
            path.removeSubrange(range.lowerBound ..< path.endIndex)
        }
        let pathURL = URL(fileURLWithPath: document.localParentDir).appendingPathComponent(path).standardized
        var destinationFile = pathURL.relativeString
        guard let repo = repositoryContent(for: document.repoIdentifier) else {
            Console.fatalError("Document whith invalid repository identifier.")
        }
        let pathFileName = destinationFile.fileNameFromPath()
        let targetHomeFile = config.effectiveGlobalParameters.targetHomeFile!
        if pathFileName == repo.params.homeFile && pathFileName != targetHomeFile {
            destinationFile = destinationFile.removingLastPathComponent().addingPathComponent(targetHomeFile)
        }

        if !repo.containsLocalFile(path: destinationFile) {
            Console.warning(document, link, "Link \(link.toString()) points to unknown document in repository.")
            return
        }
        if var referencedItem = self.findDocumentationItem(path: document.repoIdentifier.addingPathComponent(destinationFile)) {
            referencedItem.referenceCount += 1
            if let linkedDocument = referencedItem.document, let anchorName = anchorName {
                validateAnchor(linkedDocument: linkedDocument, sourceDocument: document, link: link, anchorName: anchorName)
            }
        }
        if destinationFile.fileExtensionFromPath() == "md" {
            destinationFile.removeSubrange(Range(uncheckedBounds: (destinationFile.index(offsetBy: destinationFile.count - 3), destinationFile.endIndex)))
        }
        let finalNewPath = destinationFile + (anchorName == nil ? "" : "#\(anchorName!)")
        if finalNewPath != link.path {
            link.path = finalNewPath
        }
    }
    
    
    /// Patches link to a local document, located in the same repository. Unlike `patchLocalLink()`
    /// this function handles links pointing to the same repository, but destination file is outside of "docs" folder.
    /// This is useful for situations, when documentation points to source codes in the same repository.
    ///
    /// - Parameters:
    ///   - document: Currently processed document
    ///   - link: Link to be patched.
    private func patchLocalSourceLink(document: MarkdownDocument, link: MarkdownLink) {
        // TODO: this is kind of shaky. We should do a better test whether link goes outside of "docs" folder.
        if !document.localParentDir.isEmpty {
            // Relative link, but not from "docs" folder. We should process the link as usual.
            patchLocalLink(document: document, link: link)
            return
        }
        // This is really a top level document (located in docs folder), but links is relative
        // and goes to an upper folder. We should construct a full link github repository.
        guard let repo = repositoryContent(for: document.repoIdentifier) else {
            Console.fatalError("Document whith invalid repository identifier.")
        }
        
        var path = link.path
        var anchorName: String?
        if let range = path.range(of: "#", options: .backwards) {
            anchorName = String(path[range.upperBound ..< path.endIndex])
            path.removeSubrange(range.lowerBound ..< path.endIndex)
        }
        
        var sourcesPath = repo.repository.baseSourcesPath
        sourcesPath.appendPathComponent(repo.params.docsFolder!)
        sourcesPath.appendPathComponent(path)
        sourcesPath.standardize()
        path = sourcesPath.absoluteString
        if let anchorName = anchorName {
            path.append("#\(anchorName)")
        }
        link.path = path
    }
}
