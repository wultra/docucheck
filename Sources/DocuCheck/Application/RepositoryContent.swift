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

class RepositoryContent {
    
    /// Repository identifier
    let repoIdentifier: String
    /// Repository configuration
    let repository: Config.Repository
    /// Effective parameters (e.g. with resolved optional values)
    let params: Config.Parameters
    
    var allFiles = [String]()
    var allFilesSet = Set<String>()
    
    /// Full path to remote repository. For example: `https://github.com/wultra/powerauth-mobile-sdk`
    let fullRemotePath: URL
    /// Full path to local documents copy. For example: `/Users/you/temp/repos/powerauth-mobile-sdk`
    var fullRepositoryPath: String
    
    
    init(repoIdentifier: String, repository: Config.Repository, params: Config.Parameters) {
        self.repoIdentifier = repoIdentifier
        self.repository = repository
        self.params = params
        self.fullRepositoryPath = ""
        self.fullRemotePath = repository.remoteProvider.basePath(forRemote: repository.remote)
    }
    
    func loadFileNames(config: Config, basePath: String, markdownExtensions: [String]) -> Bool {
        self.fullRepositoryPath = config.path(repo: repoIdentifier, basePath: basePath)
        guard let allFiles = FS.directoryList(at: fullRepositoryPath)?.filter({ !FS.isDirectory(at: $0) }) else {
            return false
        }
        self.allFiles = allFiles.map { repoIdentifier.addingPathComponent($0) }
        self.allFilesSet = Set(self.allFiles)
        
        self.allFiles.forEach { path in
            let fileName = path.fileNameFromPath()
            if fileName.range(of: "(") != nil || fileName.range(of: ")") != nil {
                let ext = fileName.fileExtensionFromPath()
                if markdownExtensions.contains(ext) {
                    Console.warning("\(path): Path contains brackets. You should rename that document.")
                } else {
                    Console.warning("\(path): Path contains brackets. You should rename that file in case it's linked from markdown.")
                }
            }
        }
        
        return true
    }
    
    func containsLocalFile(path: String) -> Bool {
        if path.hasPrefix(repoIdentifier) {
            return allFilesSet.contains(path)
        }
        return allFilesSet.contains(repoIdentifier.addingPathComponent(path))
    }
}

