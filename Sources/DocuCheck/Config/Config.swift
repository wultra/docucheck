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

/// The `Config` structure is a model object for configuration loaded from JSON configuration file.
struct Config: Decodable {
    
    /// The `Repository` structure is a model object for git repository
    struct Repository: Decodable {
        /// Defines remote providers supported in the tool
        enum Provider: String, Decodable {
            /// (default) github provider. The "remote" value must contain path
            /// to github project, in "organization/repository" format.
            case github = "github"
            /// gitlab repository. The "remote" value must contain path
            /// to gitlab project, in "organization/repository" format.
            case gitlab = "gitlab"
        }
        /// Defines path to remote repository. The parameter depends on type of "provider".
        let remote: String
        
        /// Defines provider for remote repository.
        let provider: Provider?
        
        /// Defines optional branch, which has to be cloned to acquire the documentation.
        /// If not used, then the "default" branch will be cloned (typically "develop" in Wultra's project)
        let branch: String?
        
        /// Defines optional tag, which has to be cloned to acquire the documentation.
        /// If used, then it has a higher priority than "branch" parameter.
        let tag: String?
        
        /// Defines optional path where the repository will be cloned. If not used, then the key from `Config.repositories`
        /// will be used as a local path to this repository.
        let path: String?
        
        /// Defines optional folder with already cloned repository. You can use this option for DEBUG or development
        /// purposes, to save time, required for clone all repositories. 
        let localFiles: String?
    }

    /// The `Parameters` structure defines an additional parameters describing how
    /// the documentation should be processed.
    struct Parameters: Decodable {
        /// Defines where, the "docs" folder is located.
        /// If not present in the configuration, then `"docs"` will be used.
        let docsFolder: String?
        
        /// Defines filename in "docsFolder", which contains a root page of the documentation.
        /// If not present in the configuration, then `"Readme.md"` will be used.
        let homeFile: String?
        
        /// Property contains list of supporting markdown documents. Such documents should not be processed as a regular pages.
        let auxiliaryDocuments: [String]?
        
        /// Contains list of ignored files. Examples:
        ///  - `.git` - full file / directory name to be ignored
        ///  - `*.bin` - file or directory name ending with ".bin" extension
        let ignoredFiles: [String]?
        
        /// If set, then the documentation is composed from a single markdown document. The documentation
        /// processing is little bit different than usual, for this case.
        let singleDocumentFile: String?
        
        /// Default values for "Parameters" structure
        static let `default` = Parameters(
            docsFolder: "docs",
            homeFile: "Readme.md",
            auxiliaryDocuments: [ "_Footer.md", "_Sidebar.md" ],
            ignoredFiles: [ ".git", ".gitignore", ".DS_Store" ],
            singleDocumentFile: nil
        )
    }
    
    /// The `Paths` structure contains various configurable paths required for DocuCheck tool.
    struct Paths: Decodable {
        /// Path to output folder, where all collected documentation will be stored.
        let outputPath: String?
        
        /// Path to folder, where all documentation repositories will be cloned
        let repositoriesPath: String?
    }
    
    /// The `GlobalParameters` structure contains various configurations affecting a global behavior
    /// of DocuCheck tool.
    struct GlobalParameters: Decodable {
        /// Defines global parameters valid for all repositories. You can override those values
        /// on per-repository basis in `repositoryParameters` dictionary.
        let parameters: Parameters?
        
        /// Defines various paths used by the tool.
        let paths: Paths?
        
        /// Contains list of extensions for markdown files.
        let markdownExtensions: [String]?
        
        /// Contains list of extensions for image file types.
        let imageExtensions: [String]?
        
        /// Target home file. If not set, then defaulting to "Home.md"
        let targetHomeFile: String?
        
        /// Default values for "GlobalParameters" structure. The default structure contains safe values for all properties,
        /// except for "paths" and "ignoredFiles".
        static let `default` = GlobalParameters(
            parameters: .default,
            paths: nil,
            markdownExtensions: ["md", "markdown"],
            imageExtensions: ["png", "jpg", "jpeg", "gif"],
            targetHomeFile: "index.md"
        )
    }
    
    /// Dictionary with definition of git repositories with the documentation.
    ///
    /// The dictionary key defines in which folder the repository will be cloned.
    let repositories: [String: Repository]

    /// Defines per-repository parameters. The key in this dictionary must match an appropriate
    /// key from `repositories` dictionary.
    let repositoryParameters: [String: Parameters]?
    
    /// Defines global parameters valid for all repositories. You can override those values
    /// on per-repository basis in `repositoryParameters` dictionary.
    let globalParameters: GlobalParameters?
}


extension Config {
    
    /// Returns relative path where the repository with given identifier was cloned.
    ///
    /// - Parameter identifier: Identifier of repository (e.g. key to "parameters" configuration)
    /// - Parameter basePath: Path where all repositories are cloned
    /// - Returns: String with a relative path to requested repository
    func path(repo identifier: String, basePath: String) -> String {
        guard let repo = repositories[identifier] else {
            Console.fatalError("Unknown repository identifier `\(identifier)`.")
        }
        return basePath.addingPathComponent(repo.path ?? identifier)
    }
    
    /// Returns `Parameters` object which has all its optional properties always configured. The function
    /// respects a chain of configuration, where parameters from `"repositoryParameters"` have higher priority
    /// than parameters from `"globalParameters"`. If no such objects are defined, then the default values are used.
    ///
    /// - Parameter identifier: Identifier of repository (e.g. key to "parameters" configuration)
    /// - Returns: `Parameters` object with all optional properties set to a valid values.
    func parameters(repo identifier: String) -> Parameters {
        guard repositories[identifier] != nil else {
            Console.fatalError("Unknown repository identifier `\(identifier)`.")
        }
        let p = repositoryParameters?[identifier]
        let gp = globalParameters?.parameters
        let dp = Parameters.default
        var ignoredFiles = Set<String>()
        ignoredFiles.safeInsert(contentsOf: gp?.ignoredFiles)
        ignoredFiles.safeInsert(contentsOf: p?.ignoredFiles)
        ignoredFiles.safeInsert(contentsOf: dp.ignoredFiles)
        return Parameters(
            docsFolder: p?.docsFolder ?? gp?.docsFolder ?? dp.docsFolder!,
            homeFile: p?.homeFile ?? gp?.homeFile ?? dp.homeFile!,
            auxiliaryDocuments: p?.auxiliaryDocuments ?? gp?.auxiliaryDocuments ?? dp.auxiliaryDocuments!,
            ignoredFiles: ignoredFiles.sorted(),
            singleDocumentFile: p?.singleDocumentFile
        )
    }
    
    /// Returns `Paths` object with fixed relative paths. If any structure's property contains
    /// a relative path, then it's translated to a full path. The provided path to configuration file
    /// is used as a base path for such conversion.
    ///
    /// - Parameter configPath: Path to configuration file
    /// - Returns: `Paths` strucutre with fixed relative paths
    func paths(configPath: String) -> Paths {
        var outputPath: String?
        var repositoriesPath: String?
        let paths = globalParameters?.paths
        if let path = paths?.outputPath {
            if path.hasPrefix("./") || path.hasPrefix("../") {
                outputPath = configPath.addingPathComponent(path)
            }
        }
        if let path = paths?.repositoriesPath {
            if path.hasPrefix("./") || path.hasPrefix("../") {
                repositoriesPath = configPath.addingPathComponent(path)
            }
        }
        return Paths(
            outputPath: outputPath,
            repositoriesPath: repositoriesPath
        )
    }
    
    ///
    var effectiveGlobalParameters: GlobalParameters {
        let gp = globalParameters
        let dp = GlobalParameters.default
        //
        var markdownExtensions = Set<String>()
        markdownExtensions.safeInsert(contentsOf: gp?.markdownExtensions)
        markdownExtensions.safeInsert(contentsOf: dp.markdownExtensions)
        //
        var imageExtensions = Set<String>()
        imageExtensions.safeInsert(contentsOf: gp?.imageExtensions)
        imageExtensions.safeInsert(contentsOf: dp.imageExtensions)
        
        return GlobalParameters(
            parameters: gp?.parameters ?? dp.parameters!,
            paths: gp?.paths,
            markdownExtensions: markdownExtensions.sorted(),
            imageExtensions: imageExtensions.sorted(),
            targetHomeFile: gp?.targetHomeFile ?? dp.targetHomeFile!
        )
    }
}

fileprivate extension Set {
    mutating func safeInsert<S>(contentsOf newElements: S?) where S : Sequence, Element == S.Element {
        if let newElements = newElements {
            self.formUnion(newElements)
        }
    }
}

extension Config.Repository.Provider {
    
    /// Contains provider's base path (e.g. https://github.com for "github")
    var basePath: String {
        switch self {
        case .github:
            return "https://github.com"
        case .gitlab:
            return "https://gitlab.com"
        }
    }
    
    ///
    func basePath(forRemote remote: String) -> URL {
        guard let url = URL(string: "\(basePath)/\(remote)") else {
            Console.fatalError("Failed to create URL for \(self) repository: \(remote)")
        }
        return url
    }
    
    func baseSourcesPath(forRemote remote: String, branch: String) -> URL {
        var url = basePath(forRemote: remote)
        url.appendPathComponent("blob")
        url.appendPathComponent(branch)
        return url
    }
    
    /// Returns path to remote source files. The returned string typically
    /// contains URL to a remote git repository.
    func remoteSourcesPath(forRemote remote: String) -> URL {
        guard let url = URL(string: "\(basePath)/\(remote).git") else {
            Console.fatalError("Failed to create URL for \(self) repository: \(remote)")
        }
        return url
    }
}

extension Config.Repository {
    
    /// Defaulting "remote" nullable property to "github"
    var remoteProvider: Provider {
        return provider ?? .github
    }
    
    /// Contains URL for downloading the repository content. The returned URL typocally points
    /// to a "git" repository (e.g. URL you can use to clone the repository)
    var downloadSourcesPath: URL {
        return remoteProvider.remoteSourcesPath(forRemote: remote)
    }
    
    /// Returns tag or branch required to clone this repository.
    var tagOrBranch: String {
        return tag ?? branch ?? "develop"
    }
    
    /// Returns base URL pointing to exact tag or branch.
    /// For example: "https://github.com/wultra/powerauth-mobile-sdk/blob/release/0.20.x"
    var baseSourcesPath: URL {
        return remoteProvider.baseSourcesPath(forRemote: remote, branch: tagOrBranch)
    }
    
    /// Returns base URL which can be used to derermine whether the another link points to this repository.
    /// The URL typically points to a "develop" branch.
    /// For example: "https://github.com/wultra/powerauth-mobile-sdk/blob/develop"
    var baseCrossReferencePath: URL {
        return remoteProvider.baseSourcesPath(forRemote: remote, branch: "develop")
    }

    /// Returns path to a repository, used for a promotional purposes.
    /// For example: "https://github.com/wultra/powerauth-mobile-sdk"
    var mainRepositoryPromoPath: URL {
        return remoteProvider.basePath(forRemote: remote)
    }
}

extension Config.Parameters {
    
    /// Contains true if repository's documentation is composed only from one single document.
    var hasSingleDocument: Bool {
        return singleDocumentFile != nil
    }
}
