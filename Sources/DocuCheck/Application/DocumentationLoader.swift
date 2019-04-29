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
    let fastMode: Bool
    
    private var cmdGit: Cmd!
    private var repoCache: RepoCache!
    
    /// Structure representing information about cached repositories
    private struct RepoCache: Codable {
        
        /// Version of RepoCache manager
        let version: Int
        
        /// Returns instance of default `RepoCache` structure
        static var `default`: RepoCache {
            return RepoCache(version: 1)
        }
    }
    
    /// Contains path to RepoCache file
    private var repoCachePath: String {
        return repositoryDir.addingPathComponent("docucheck.json")
    }
    
    /// Initializes object with configuration and directories required for operation.
    ///
    /// - Parameters:
    ///   - config: `Config` structure
    ///   - destinationDir: folder where all "repo/docs" folders will be placed
    ///   - repositoryDir: folder where all required git repositories will be placed
    init(config: Config, destinationDir: String, repositoryDir: String, fastMode: Bool) {
        self.config = config
        self.destinationDir = destinationDir
        self.repositoryDir = repositoryDir
        self.fastMode = fastMode
    }
    
    
    // MARK: - Main task
    
    /// Loads documentation from remote sources and copies all "docs" folders to destination
    /// directory.
    ///
    /// - Returns: true in case of success
    func loadDocumentation() -> DocumentationDatabase? {
        guard
            prepareDirs() &&
            loadRepoCache() &&
            downloadAllRepos() &&
            copyDocumentationDirs() &&
            removeIgnoredFiles() &&
            patchHomeFiles() &&
            storeRepoCache() else {
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
            Console.info("Destination directory exists. Removing all content at: \(destinationDir)")
            FS.remove(at: destinationDir)
        }
        FS.makeDir(at: destinationDir)
        return true
    }
    
    /// Function loads and validates information about repository cache
    private func loadRepoCache() -> Bool {
        var removeCache = true
        let path = repoCachePath
        if FS.fileExists(at: path) {
            if let document = FS.document(at: path, description: "Repository cache") {
                let cacheInfo: RepoCache
                do {
                    let decoder = JSONDecoder()
                    cacheInfo = try decoder.decode(RepoCache.self, from: document.contentData)
                    if cacheInfo.version == RepoCache.default.version {
                        removeCache = false
                    }
                    repoCache = cacheInfo
                } catch {
                    // Do nothing
                }
            }
        }
        let hasRepoDir = FS.isDirectory(at: repositoryDir)
        if hasRepoDir {
            if removeCache {
                Console.info("Removing repository cache at: \(repositoryDir)")
                FS.remove(at: repositoryDir)
                FS.makeDir(at: repositoryDir)
            }
        } else {
            FS.makeDir(at: repositoryDir)
        }
        if repoCache == nil {
            repoCache = RepoCache.default
        }
        return storeRepoCache()
    }
    
    /// Stores `RepoCache` into predefined file
    private func storeRepoCache() -> Bool {
        guard let info = repoCache else {
            Console.fatalError("RepoCache structure is missing.")
        }
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(info)
            try data.write(to: URL(fileURLWithPath: repoCachePath), options: .atomicWrite)
        } catch {
            Console.exitError("Failed to write RepoCache information. Error: \(error)")
        }
        return true
    }
    
    /// Downloads all repos from remote sources
    ///
    /// - Returns: true if operation succeeds
    private func downloadAllRepos() -> Bool {
        // Clone all repos
        if cmdGit == nil {
            cmdGit = Cmd("git")
        }
        config.repositories.forEach { repoIdentifier, repoConfig in
            let fullRepoPath = config.path(repo: repoIdentifier, basePath: repositoryDir)
            if let localPath = repoConfig.localFiles {
                // Just copy files from local directory
                Console.info("Copying local \"\(repoIdentifier)\"...")
                if FS.fileExists(at: fullRepoPath) {
                    FS.remove(at: fullRepoPath)
                }
                FS.copy(from: localPath, to: repositoryDir.addingPathComponent(repoIdentifier))
            } else {
                // Download repository
                self.cloneOrUpdateGitRepository(repoIdentifier: repoIdentifier, repoConfig: repoConfig, fullRepoPath: fullRepoPath)
            }
        }
        return true
    }
    
    // MARK: - Clone or Update
    
    /// Clones or updates a git repository.
    private func cloneOrUpdateGitRepository(repoIdentifier: String, repoConfig: Config.Repository, fullRepoPath: String) {
        var doClone = true
        if FS.isDirectory(at: fullRepoPath) {
            if FS.isDirectory(at: fullRepoPath.addingPathComponent(".git")) {
                // git directory exists
                doClone = false
            } else {
                // Some unknown copy, just remove data and clone from scratch
                FS.remove(at: fullRepoPath)
            }
        }
        if doClone {
            cloneGitRepository(repoIdentifier: repoIdentifier, repoConfig: repoConfig, fullRepoPath: fullRepoPath)
        } else {
            updateGitRepository(repoIdentifier: repoIdentifier, repoConfig: repoConfig, fullRepoPath: fullRepoPath)
        }
    }
    
    /// Clones git repository
    private func cloneGitRepository(repoIdentifier: String, repoConfig: Config.Repository, fullRepoPath: String) {
        // Clone the repository
        Console.info("Downloading \"\(repoIdentifier)\"...")
        let cloneParams = config.gitCloneCommandParameters(repoIdentifier: repoIdentifier, reposPath: repositoryDir)
        cmdGit.run(with: cloneParams, exitOnError: true)
        if repoConfig.hasTag {
            // Checkout to one specific tag
            let checkoutParams = config.gitCheckoutCommandParameters(repoIdentifier: repoIdentifier, reposPath: repositoryDir, createLocalBranch: true)
            cmdGit.run(with: checkoutParams, exitOnError: true)
        }
    }
    
    /// Updates git repository
    private func updateGitRepository(repoIdentifier: String, repoConfig: Config.Repository, fullRepoPath: String) {
        // Fetch changes, or just change branch
        Console.info("Updating \"\(repoIdentifier)\"...")
        if repoConfig.hasTag {
            updateForTagInGitRepository(repoIdentifier: repoIdentifier, repoConfig: repoConfig, fullRepoPath: fullRepoPath)
        } else {
            updateBranchInGitRepository(repoIdentifier: repoIdentifier, repoConfig: repoConfig, fullRepoPath: fullRepoPath)
        }
    }
    
    /// Updates repository and checkouts to a given tag.
    private func updateForTagInGitRepository(repoIdentifier: String, repoConfig: Config.Repository, fullRepoPath: String) {
        // Update for tag
        let localBranchName = repoConfig.localBranchForTag
        let verifyBranchParams = config.gitVerifyBranchCommandParameters(repoIdentifier: repoIdentifier, reposPath: repositoryDir, ref: localBranchName)
        if cmdGit.run(with: verifyBranchParams, exitOnError: false, ignoreOutput: true) {
            // Tag's branch exists, just checkout
            let checkoutParams = config.gitCheckoutCommandParameters(repoIdentifier: repoIdentifier, reposPath: repositoryDir, createLocalBranch: false)
            cmdGit.run(with: checkoutParams, exitOnError: true)
            return
        }
        let verifyTagParams = config.gitVerifyBranchCommandParameters(repoIdentifier: repoIdentifier, reposPath: repositoryDir, ref: repoConfig.tag!)
        if cmdGit.run(with: verifyTagParams, exitOnError: false, ignoreOutput: true) {
            // Tag exists, but has no local branch
            let checkoutParams = config.gitCheckoutCommandParameters(repoIdentifier: repoIdentifier, reposPath: repositoryDir, createLocalBranch: true)
            cmdGit.run(with: checkoutParams, exitOnError: true)
            return
        }
        let fetchParams = config.gitFetchCommandParameters(repoIdentifier: repoIdentifier, reposPath: repositoryDir)
        cmdGit.run(with: fetchParams, exitOnError: true)
        let checkoutParams = config.gitCheckoutCommandParameters(repoIdentifier: repoIdentifier, reposPath: repositoryDir, createLocalBranch: true)
        cmdGit.run(with: checkoutParams, exitOnError: true)
    }
    
    /// Updates branch in git repository
    private func updateBranchInGitRepository(repoIdentifier: String, repoConfig: Config.Repository, fullRepoPath: String) {
        // Update for branch
        let branchName = repoConfig.branchName
        let verifyBranchParams = config.gitVerifyBranchCommandParameters(repoIdentifier: repoIdentifier, reposPath: repositoryDir, ref: branchName)
        if !cmdGit.run(with: verifyBranchParams, exitOnError: false, ignoreOutput: true) {
            // Branch doesn't exist locally, fetch changes
            let fetchParams = config.gitFetchCommandParameters(repoIdentifier: repoIdentifier, reposPath: repositoryDir, branch: branchName)
            cmdGit.run(with: fetchParams, exitOnError: true)
            // Checkout and create branch
            let checkoutParams = config.gitCheckoutCommandParameters(repoIdentifier: repoIdentifier, reposPath: repositoryDir, createLocalBranch: true)
            cmdGit.run(with: checkoutParams, exitOnError: true)
        } else {
            // Branch exists locally, just checkout the branch and pull changes
            let checkoutParams = config.gitCheckoutCommandParameters(repoIdentifier: repoIdentifier, reposPath: repositoryDir, createLocalBranch: false)
            cmdGit.run(with: checkoutParams, exitOnError: true)
            // Pull changes
            if !fastMode {
                let pullParams = config.gitPullCommandParameters(repoIdentifier: repoIdentifier, reposPath: repositoryDir)
                cmdGit.run(with: pullParams, exitOnError: true)
            }
        }
    }
    
    // MARK: - Copy documentation
    
    /// Copies all files from repository's "docs" folder to the output folder.
    ///
    /// - Returns: true if operation succeeds
    private func copyDocumentationDirs() -> Bool {
        let effectiveGP = config.effectiveGlobalParameters
        config.repositories.forEach { repoIdentifier, repoConfig in
            Console.info("Copying content for \"\(repoIdentifier)\"...")
            // Prepare destination folder in output directory
            let fullOutPath = destinationDir.addingPathComponent(repoIdentifier)
            // Prepare repo paths
            let repoParams = config.parameters(repo: repoIdentifier)
            if repoParams.hasSingleDocument {
                // Documentation in single markdown file.
                // We need to copy that file and optionaly, copy content of "docs" folder in case that there are
                // image resources or other files referenced from the main documentation file.
                guard let singleDocument = repoParams.singleDocumentFile else {
                    Console.fatalError("hasSingleDocument is true, but singleDocumentFile is not set")
                }
                let sourcePath = config.path(repo: repoIdentifier, basePath: repositoryDir).addingPathComponent(singleDocument)
                let destinationPath = fullOutPath.addingPathComponent(effectiveGP.targetHomeFile!)
                FS.makeDir(at: fullOutPath)
                FS.copy(from: sourcePath, to: destinationPath)
            } else {
                // Documentation in "docs" folder, copy that folder
                let sourcePath = config.path(repo: repoIdentifier, basePath: repositoryDir).addingPathComponent(repoParams.docsFolder!)
                FS.copy(from: sourcePath, to: fullOutPath)
            }
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
            // Ignore hidden files (typically ".DS_Store"
            if repoId.hasPrefix(".") {
                return
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
    
    // MARK: - Patch Home files
    
    /// Patches home files in repositories. This step typically moves "Home.md" (or any other form of home file)
    /// to common name defined in configuration.
    ///
    /// - Returns: true if operation succeeds
    private func patchHomeFiles() -> Bool {
        Console.info("Patching home files...")
        let targetName = config.globalParameters?.targetHomeFile ?? Config.GlobalParameters.default.targetHomeFile!
        config.repositories.forEach { repoIdentifier, repoConfig in
            let repoParams = config.parameters(repo: repoIdentifier)
            if repoParams.hasSingleDocument {
                return
            }
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

// MARK: - Private extensions -

fileprivate extension Config.Repository {
    
    /// Returns true if Repository structure doesn't points to specific tag or branch, so
    /// it has to download default branch.
    var hasDefaultBranch: Bool {
        return branch == nil && tag == nil
    }
    
    /// Contains true if Repository stucture points to a branch.
    var hasBranch: Bool {
        return tag == nil
    }
    
    /// Contains true if Repository structure points to a tag
    var hasTag: Bool {
        return tag != nil
    }
    
    /// Returns name of local branch for tag
    var localBranchForTag: String {
        guard let tag = tag else {
            Console.fatalError("Wrong usage of 'localBranchForTag'")
        }
        return "localBranchForTag_\(tag)"
    }
    
    /// Returns branch name, defaulting to "develop"
    var branchName: String {
        guard hasBranch else {
            Console.fatalError("Wrong usage of 'branchName'")
        }
        return branch ?? "develop"
    }
    
}

fileprivate extension Config {

    /// Returns parameters for "git clone" command, based on the content stored in the `Repository`
    /// structure.
    ///
    /// - Parameter repoIdentifier: Repository identifier
    /// - Parameter reposPath: Path to all repositories
    /// - Returns: Array of strings, representing parameters for "git" command
    func gitCloneCommandParameters(repoIdentifier: String, reposPath: String) -> [String] {
        guard let repoConfig = repositories[repoIdentifier] else {
            Console.fatalError("Unknown repository identifier \"\(repoIdentifier)\".")
        }
        var params = ["clone"]
        
        if Console.verboseLevel != .all {
            params.append("--quiet")
        }
        // Configure specific branch
        if repoConfig.hasBranch {
            params.append(contentsOf: [ "--branch", repoConfig.branchName ])
        }
        // URL
        params.append(repoConfig.downloadSourcesPath.absoluteString)
        // Destination folder
        params.append(path(repo: repoIdentifier, basePath: reposPath))
        
        return params
    }
    
    /// Returns parameters for "git rev-parse" command to verify whether tag or branch exists locally.
    ///
    /// - Parameters:
    ///   - repoIdentifier: Repository identifier
    ///   - reposPath: Path to all repositories
    ///   - ref: Branch or tag to verify
    /// - Returns: Array of strings, representing parameters for "git" command
    func gitVerifyBranchCommandParameters(repoIdentifier: String, reposPath: String, ref: String) -> [String] {
        let repoPath = path(repo: repoIdentifier, basePath: reposPath)
        var params = [ "-C", repoPath, "rev-parse", "--verify", ref ]
        if Console.verboseLevel != .all {
            params.append("--quiet")
        }
        return params
    }

    
    /// Returns parameters for "git checkout" command, based on the content stored in the `Repository`
    /// structure.
    ///
    /// - Parameters:
    ///   - repoIdentifier: Repository identifier
    ///   - reposPath: Path to all repositories
    ///   - createLocalBranchForTag: If Repository points to a tag and this parameter is true, then creates a new local branch for that tag.
    /// - Returns: Array of strings, representing parameters for "git" command
    func gitCheckoutCommandParameters(repoIdentifier: String, reposPath: String, createLocalBranch: Bool) -> [String] {
        guard let repoConfig = repositories[repoIdentifier] else {
            Console.fatalError("Unknown repository identifier \"\(repoIdentifier)\".")
        }
        let repoPath = path(repo: repoIdentifier, basePath: reposPath)
        var params = [ "-C", repoPath, "checkout" ]
        if repoConfig.hasBranch {
            // Points to a branch
            if createLocalBranch {
                let branchName = repoConfig.branchName
                params.append(contentsOf: [ "-b", branchName, "--track", "origin/\(branchName)" ])
            } else {
                params.append(repoConfig.branchName)
            }
        } else {
            // Points to a tag
            if createLocalBranch {
                params.append(contentsOf: [ repoConfig.tag!, "-b", repoConfig.localBranchForTag ])
            } else {
                params.append(repoConfig.localBranchForTag)
            }
        }
        if Console.verboseLevel != .all {
            params.append("--quiet")
        }
        return params
    }
    
    /// Returns parameters for "git pull" command, based on the content stored in the `Repository`
    /// structure.
    ///
    /// - Parameter repoIdentifier: Repository identifier
    /// - Parameter reposPath: Path to all repositories
    /// - Returns: Array of strings, representing parameters for "git" command
    func gitPullCommandParameters(repoIdentifier: String, reposPath: String) -> [String] {
        let repoPath = path(repo: repoIdentifier, basePath: reposPath)
        var params = [ "-C", repoPath, "pull" ]
        
        if Console.verboseLevel != .all {
            params.append("--quiet")
        }
        return params
    }
    
    /// Returns parameters for "git fetch" command, based on the content stored in the `Repository`
    /// structure.
    ///
    /// - Parameter repoIdentifier: Repository identifier
    /// - Parameter reposPath: Path to all repositories
    /// - Parameter branch: If used, then fetches exact branch.
    /// - Returns: Array of strings, representing parameters for "git" command
    func gitFetchCommandParameters(repoIdentifier: String, reposPath: String, branch: String? = nil) -> [String] {
        let repoPath = path(repo: repoIdentifier, basePath: reposPath)
        var params = [ "-C", repoPath, "fetch", "--tags" ]
        
        if Console.verboseLevel != .all {
            params.append("--quiet")
        }
        if let branch = branch {
            params.append(contentsOf: [ "origin", branch ])
        }
        return params
    }
}
