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

/// The `DocumentationLoader` is responsible to clone all git repositories from
/// configuration and put it to the destination directory.
class DocumentationLoader {
    
    let config: Config
    let destinationDir: String
    let repositoryDir: String
    
    /// Initializes object with configuration and directories required for operation.
    ///
    /// - Parameters:
    ///   - config: `Config` structure
    ///   - destinationDir: folder where all "repo/docs" folders will be placed
    ///   - repositoryDir: folder where all required git repositories will be placed
    init(config: Config, destinationDir: String, repositoryDir: String) {
        self.config = config
        self.destinationDir = destinationDir
        self.repositoryDir = repositoryDir
    }
    
    /// Loads documentation from remote sources and copies all "docs" folders to destination
    /// directory.
    ///
    /// - Returns: true in case of success
    func loadDocumentation() -> DocumentationDatabase? {
        guard
            prepareDirs() &&
            downloadAllRepos() &&
            copyDocumentationDirs() &&
            removeIgnoredFiles() &&
            patchHomeFiles() else {
                return nil
            }
        let database = DocumentationDatabase(config: config, sourcePath: destinationDir)
        if !database.loadDatabase() {
            return nil
        }
        return database
    }
    
    /// Prepares all required directories
    ///
    /// - Returns: true in case of success
    private func prepareDirs() -> Bool {
        if FS.fileExists(at: destinationDir) {
            Console.warning("Destination directory exists. Removing all content at: \(destinationDir)")
            FS.remove(at: destinationDir)
        }
        if FS.fileExists(at: repositoryDir) {
            Console.warning("Directory for repositories exists. Removing all content at: \(repositoryDir)")
            FS.remove(at: repositoryDir)
        }
        FS.makeDir(at: destinationDir)
        FS.makeDir(at: repositoryDir)
        return true
    }
    
    /// Downloads all repos from remote sources
    ///
    /// - Returns: true if operation succeeds
    private func downloadAllRepos() -> Bool {
        // Clone all repos
        let git = Cmd("git")
        config.repositories.forEach { repoIdentifier, repoConfig in
            Console.info("Downloading \"\(repoIdentifier)\"...")
            let fullRepoPath = config.path(repo: repoIdentifier, basePath: repositoryDir)
            if FS.fileExists(at: fullRepoPath) {
                Console.warning("Removing previous content of repository: \"\(repoIdentifier)\"")
                FS.remove(at: fullRepoPath)
            }
            if let localPath = repoConfig.localFiles {
                // Just copy files from local directory
                FS.copy(from: localPath, to: repositoryDir.addingPathComponent(repoIdentifier))
            } else {
                // Clone repository
                let cloneParams = config.gitCloneCommandParameters(repoIdentifier: repoIdentifier, reposPath: repositoryDir)
                git.run(with: cloneParams)
            }
        }
        return true
    }
    
    /// Copies all files from repository's "docs" folder to the output folder.
    ///
    /// - Returns: true if operation succeeds
    private func copyDocumentationDirs() -> Bool {
        config.repositories.forEach { repoIdentifier, repoConfig in
            Console.info("Copying content for \"\(repoIdentifier)\"...")
            // Prepare destination folder in output directory
            let fullOutPath = destinationDir.addingPathComponent(repoIdentifier)
            // Prepare repo paths
            let repoParams = config.parameters(repo: repoIdentifier)
            let fullDocsPath = config.path(repo: repoIdentifier, basePath: repositoryDir).addingPathComponent(repoParams.docsFolder!)
            FS.copy(from: fullDocsPath, to: fullOutPath)
        }
        return true
    }
    
    /// Removes all files listed in "globalProperties.ignoredFiles" list.
    ///
    /// - Returns: true if operation succeeds
    private func removeIgnoredFiles() -> Bool {
        Console.info("Removing ignored files...")
        let effectiveGP = config.effectiveGlobalParameters
        let ignored = effectiveGP.parameters?.ignoredFiles ?? Config.Parameters.default.ignoredFiles!
        var lastRepoIdentifier: String?
        var repoIgnored = Set<String>()
        
        // Now iterate all over files. Ignored subpaths fixes a problem, when a whole
        // direcotry was removed, but all its content is still in "allFiles" array of paths.
        var ignoredSubpaths = [String]()
        FS.directoryList(at: destinationDir)?.forEach { path in
            let repoId: String
            if let range = path.range(of: "/") {
                // Substring up to first slash is repo identifier
                repoId = String(path[path.startIndex..<range.lowerBound])
            } else {
                repoId = path   // full path is repo identifier
            }
            // Update list of ignored files if repo identifier has been changed
            if lastRepoIdentifier != repoId {
                lastRepoIdentifier = repoId
                repoIgnored.removeAll(keepingCapacity: true)
                repoIgnored.formUnion(ignored)
                if let repoList = config.parameters(repo: repoId).ignoredFiles {
                    repoIgnored.formUnion(repoList)
                }
                
            }
            
            let fullPath = destinationDir.addingPathComponent(path)
            if ignoredSubpaths.filter({ path.hasPrefix($0) }).isEmpty {
                // Path is not ignored yet
                if DocumentationLoader.isIgnored(path, inList: repoIgnored) {
                    let wasDirectory = FS.isDirectory(at: fullPath)
                    Console.debug(" - removing ignored \(wasDirectory ? "directory" : "file"): \(path)")
                    FS.remove(at: fullPath)
                    if wasDirectory {
                        // If item at path is a directory, then we should ignore validation of all files
                        // in that directory
                        ignoredSubpaths.append(path)
                    }
                }
            }
        }
        return true
    }
    
    /// Returns true if path is ignored, according to list of ignored files.
    ///
    /// - Parameters:
    ///   - path: Path to investigate
    ///   - ignored: List of ignored files ("filename", "*.extension")
    /// - Returns: true if file or directory at path is ignored
    private static func isIgnored(_ path: String, inList ignored:Set<String>) -> Bool {
        let fileName = path.fileNameFromPath()
        for match in ignored {
            if match.first == "*" {
                // Try to match only the extension
                let suffix = match[match.index(after: match.startIndex) ..< match.endIndex]
                if fileName.hasSuffix(suffix) {
                    // Ignored due to file extension
                    return true
                }
            } else {
                if fileName == match {
                    // Full file name is ignored
                    return true
                }
            }
        }
        return false
    }
    
    /// Patches home files in repositories. This step typically moves "Home.md" (or any other form of home file)
    /// to common name defined in configuration.
    ///
    /// - Returns: true if operation succeeds
    private func patchHomeFiles() -> Bool {
        Console.info("Patching home files...")
        let targetName = config.globalParameters?.targetHomeFile ?? Config.GlobalParameters.default.targetHomeFile!
        config.repositories.forEach { repoIdentifier, repoConfig in
            let repoParams = config.parameters(repo: repoIdentifier)
            let repoPath = config.path(repo: repoIdentifier, basePath: destinationDir)
            let homeFilePath = repoPath.addingPathComponent(repoParams.homeFile!)
            if !FS.fileExists(at: homeFilePath) {
                Console.exitError("Repository \"\(repoIdentifier)\" has no home file. File \"\(repoParams.homeFile!)\" is expected.")
            }
            if repoParams.homeFile == targetName {
                return
            }
            let newHomeFilePath = repoPath.addingPathComponent(targetName)
            if FS.fileExists(at: newHomeFilePath) {
                Console.exitError("Repository \"\(repoIdentifier)\" contains two home files: \"\(repoParams.homeFile!)\" and \"\(targetName)\".")
            }
            FS.copy(from: homeFilePath, to: newHomeFilePath)
            FS.remove(at: homeFilePath)

            // Patch all home files in repo
            FS.directoryList(at: repoPath)?.filter({ $0.fileNameFromPath() == repoParams.homeFile! }).forEach { oldHomeFilePath in
                let newHomeFilePath = oldHomeFilePath.removingLastPathComponent().addingPathComponent(targetName)
                if FS.fileExists(at: newHomeFilePath) {
                    Console.exitError("Repository \"\(repoIdentifier)\" contains two home files: \"\(oldHomeFilePath)\" and \"\(newHomeFilePath)\".")
                }
                FS.copy(from: oldHomeFilePath, to: newHomeFilePath)
                FS.remove(at: oldHomeFilePath)
            }
        }
        return true
    }
}


fileprivate extension Config {
    
    /// Returns parameters for "git clone" command, based on the content stored in the `Repository`
    /// structure.
    ///
    /// - Parameter repoIdentifier: Repository identifier
    /// - Returns: Array of strings, representing parameters for "git" command
    func gitCloneCommandParameters(repoIdentifier: String, reposPath: String) -> [String] {
        guard let repoConfig = repositories[repoIdentifier] else {
            Console.fatalError("Unknown repository identifier \"\(repoIdentifier)\".")
        }
        var params = ["clone"]
        
        if Console.verboseLevel != .all {
            params.append("--quiet")
        }
        // Configure tag or branch
        if let tagOrBranch = repoConfig.tag ?? repoConfig.branch {
            params.append(contentsOf: ["--branch", tagOrBranch])
        }
        // "shallow" clone
        params.append(contentsOf: ["--depth", "1"])
        // URL
        params.append(repoConfig.downloadSourcesPath.absoluteString)
        // Destination folder
        params.append(path(repo: repoIdentifier, basePath: reposPath))
        
        return params
    }
}
