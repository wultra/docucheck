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
        /// Defines URL of git repository with a documentation
        let url: URL
        /// Defines optional branch, which has to be cloned to acquire the documentation.
        /// If not used, then the "default" branch will be cloned (typically "develop" in Wultra's project)
        let branch: String?
        /// Defines optional tag, which has to be cloned to acquire the documentation.
        /// If used, then it has a higher priority than "branch" parameter.
        let tag: String?
        /// Defines optional path where the repository will be cloned. If not used, then the key from `Config.repositories`
        /// will be used as a local path.
        let path: String?
    }

    /// The `Parameters` structure defines an additional parameters describing how
    /// the documentation should be processed.
    struct Parameters: Decodable {
        /// Defines where, the "docs" folder is located.
        /// If not present in the configuration, then `"docs"` will be used.
        let docsFolder: String?
        /// Defines filename in "docsFolder", which contains a root page of the documentation.
        /// If not present in the configuration, then `"Home.md"` will be used.
        let homeFile: String?
        
        /// Default values for "Parameters" structure
        static let `default` = Parameters(docsFolder: "docs", homeFile: "Home.md")
    }
    
    /// Dictionary with definition of git repositories with the documentation.
    ///
    /// The dictionary key defines in which folder the repository will be cloned.
    let repositories: [String: Repository]

    /// Defines global parameters valid for all repositories. You can override those values
    /// on per-repository basis in `repositoryParameters` dictionary.
    let globalParameters: Parameters?

    /// Defines per-repository parameters. The key in this dictionary must match an appropriate
    /// key from `repositories` dictionary.
    let repositoryParameters: [String: Parameters]?
    
}


extension Config {
    
    /// Returns relative path where the repository with given identifier was cloned.
    ///
    /// - Parameter identifier: Identifier of repository (e.g. key to "parameters" configuration)
    /// - Returns: String with a relative path to requested repository
    func path(repo identifier: String) -> String {
        guard let repo = repositories[identifier] else {
            Console.fatalError("Unknown repository identifier `\(identifier)`.")
        }
        return repo.path ?? identifier
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
        let gp = globalParameters
        return Parameters(
            docsFolder: p?.docsFolder ?? gp?.docsFolder ?? Parameters.default.docsFolder!,
            homeFile: p?.homeFile ?? gp?.homeFile ?? Parameters.default.homeFile!
        )
    }
    
}
