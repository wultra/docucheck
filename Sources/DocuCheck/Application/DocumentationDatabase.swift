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



class DocumentationDatabase {
    
    let config: Config
    let sourcePath: String
    let effectiveGlobalParameters: Config.GlobalParameters
    
    var fileItems = [String: DocumentationItem]()
    var repositories = [String: RepositoryContent]()
    
    var externalLinks = [(document: MarkdownDocument, link: MarkdownLink)]()
    var amgiguousLinks = [(document: MarkdownDocument, link: MarkdownLink)]()
    
    /// Initializes database with given configuration and path
    /// where all documentation files are stored
    ///
    /// - Parameters:
    ///   - config: DocuCheck tool configuration
    ///   - sourcePath: Path to documentation files
    init(config: Config, sourcePath: String) {
        self.config = config
        self.sourcePath = sourcePath
        self.effectiveGlobalParameters = config.effectiveGlobalParameters
    }
    
    /// Loads documentation database
    ///
    /// - Returns: true in case of success
    func loadDatabase() -> Bool {
        
        Console.info("Searching for documentation files...")
        
        // Prepare various file extensions
        let effectiveGP = config.effectiveGlobalParameters
        let markdownExtensions = effectiveGP.markdownExtensions!
        let imageExtensions    = effectiveGP.imageExtensions!
        
        // Create all repositories
        var allFilesCount = 0
        for (repoId, repoConfig) in config.repositories {
            Console.info("- Scanning \"\(repoId)\"...")
            let params = config.parameters(repo: repoId)
            let content = RepositoryContent(repoIdentifier: repoId, repository: repoConfig, params: params)
            if !content.loadFileNames(config: config, basePath: sourcePath, markdownExtensions: markdownExtensions) {
                return false
            }
            allFilesCount += 1
            // RepositoryContent can be reached by its repoId, or by full remote path.
            repositories[repoId] = content
            repositories[content.fullRemotePath.absoluteString] = content
        }
        
        // Acquire list of all files in "sourcePath"
        guard allFilesCount > 0 else {
            Console.exitError("Directory with documentation is empty: \(sourcePath)")
        }
        
        Console.info("Loading documents...")
        
        // Put all files to the database
        for (repoId, _) in config.repositories {
            guard let repo = self.repositoryContent(for: repoId) else {
                Console.fatalError("Cannot find repository \(repoId).")
            }
            repo.allFiles.forEach { filePath in
                // For all files in repo
                let ext = filePath.fileExtensionFromPath().lowercased()
                var item: DocumentationItem
                if markdownExtensions.contains(ext) {
                    item = MarkdownDocument.documentationItem(repoIdentifier: repoId, localPath: filePath, basePath: sourcePath)
                    Console.debug("   * doc: \(filePath)")
                    let fileName = filePath.fileNameFromPath()
                    if repo.params.auxiliaryDocuments?.contains(fileName) ?? false {
                        item.referenceCount += 1
                    }
                } else {
                    let fullPath = sourcePath.addingPathComponent(filePath)
                    if FS.isDirectory(at: fullPath) {
                        item = DirItem(repoIdentifier: repoId, localPath: filePath)
                        Console.debug("     dir: \(filePath)")
                    } else {
                        item = FileItem(repoIdentifier: repoId, localPath: filePath)
                        if imageExtensions.contains(ext) {
                            Console.debug("     img: \(filePath)")
                        } else {
                            Console.debug("        : \(filePath)")
                        }
                        
                    }
                }
                fileItems[filePath] = item
            }
        }
        
        // Try to load all markdown documents
        for document in allDocuments() {
            if !document.load() {
                return false
            }
        }
        
        return true
    }
}

extension DocumentationDatabase {
    
    /// Returns all markdown documents in the database
    ///
    /// - Returns: Array of `MarkdownDocument` objects
    func allDocuments() -> [MarkdownDocument] {
        return fileItems.filter { $0.value.document != nil } .map { $0.value.document! } .sorted(by: { $0.source.name < $1.source.name })
    }
    
    /// Returns all documentation items with no reference (e.g. no document makes link to those)
    ///
    /// - Returns: Array of unreferenced documentation items.
    func allUnreferencedItems() -> [DocumentationItem] {
        return fileItems.filter { $0.value.referenceCount == 0 } .map { $0.value } .sorted(by: { $0.localPath < $1.localPath })
    }
    
    
    /// Returns RepositoryContent object for given repository identifier or full base path.
    ///
    /// - Parameter repoIdOrFullPath: R
    /// - Returns: `RepositoryContent` object or nil, if no such file exists
    func repositoryContent(for repoIdOrFullPath: String) -> RepositoryContent? {
        return repositories[repoIdOrFullPath]
    }
    
    
    /// Returns documentation item at given path.
    ///
    /// - Parameter path: Path to item object to be returned
    /// - Returns: DocumentationItem object at given path or nil if such item doesn't exist.
    func findDocumentationItem(path: String) -> DocumentationItem? {
        return fileItems[path]
    }
    

    /// Adds a new documentation item into the repository.
    ///
    /// - Parameters:
    ///   - item: Item to be added
    ///   - repo: RepositoryContent object where item belongs to
    func add(item: DocumentationItem, intoRepo repo: RepositoryContent) {
        let path = item.localPath
        if fileItems[path] != nil {
            Console.exitError("Item at path `\(path)` is already in the documentation database.")
        }
        fileItems[path] = item
        repo.allFiles.append(path)
        repo.allFilesSet.insert(path)
    }
}
