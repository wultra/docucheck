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
    
    func loadDocumentation() -> Bool {
        return true
    }
}


fileprivate extension Config.Repository {
    
    /// Returns parameters for "git clone" command, based on the content stored in the `Repository`
    /// structure.
    ///
    /// - Parameter repoIdentifier: Repository identifier
    /// - Returns: Array of strings, representing parameters for "git" command
    func gitCloneCommandParameters(repoIdentifier: String) -> [String] {
        var params = ["clone"]
        
        // Configure tag or branch
        if let tagOrBranch = tag ?? branch {
            params.append(contentsOf: ["--branch", tagOrBranch])
        }
        // "shallow" clone
        params.append(contentsOf: ["--depth", "1"])
        // URL
        params.append(url.absoluteString)
        // Destination folder
        params.append(path ?? repoIdentifier)
        
        return params
    }
}
