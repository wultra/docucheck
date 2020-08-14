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
	/// Contains `repoIdentifier + "/"`
	let repoIdentifierWithSlash: String
	
    /// Repository configuration
    let repository: Config.Repository
    /// Effective parameters (e.g. with resolved optional values)
    let params: Config.Parameters
	/// Effective global parameters
	let globalParams: Config.GlobalParameters
    
    var allFiles = [String]()
    var allFilesSet = Set<String>()
    
    /// Full path to remote repository. For example: `https://github.com/wultra/powerauth-mobile-sdk`
    let fullRemotePath: URL
    /// Full path to local documents copy. For example: `/Users/you/temp/repos/powerauth-mobile-sdk`
    var fullRepositoryPath: String
    
    
	init(repoIdentifier: String, repository: Config.Repository, params: Config.Parameters, globalParams: Config.GlobalParameters) {
        self.repoIdentifier = repoIdentifier
		self.repoIdentifierWithSlash = repoIdentifier + "/"
        self.repository = repository
        self.params = params
		self.globalParams = globalParams
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
    
	
	/// Test whetner this repository contains a documentation item at given local path.
	///
	/// - Parameter path: Path to local file. The path may contain a repository identifier as a prefix.
	/// - Returns: True if repository contains documentation item at given local path.
    func containsLocalFile(path: String) -> Bool {
        if path.hasPrefix(repoIdentifierWithSlash) {
            return allFilesSet.contains(path)
        }
        return allFilesSet.contains(repoIdentifier.addingPathComponent(path))
    }
	
	/// Return URL to github source code for given local file.
	///
	/// - Parameter localFilePath: Path to local file. The path may contain a repository identifier as a prefix.
	/// - Returns: URL to original github soruce codes.
	func getOriginalSourceUrl(for localFilePath: String) -> URL {
		// Ignore "repoIdentifier" part from local path
		let path: String
		if localFilePath.hasPrefix(repoIdentifierWithSlash) {
			path = String(localFilePath.suffix(from: localFilePath.index(offsetBy: repoIdentifierWithSlash.count)))
		} else {
			path = localFilePath
		}
        // Prepare link to original source. If requested file has target home file name (e.g. index.md), then the
		// name has to be translated to original file name (e.g. Readme.md)
        var pageFileName = path.fileNameFromPath()
        if pageFileName == globalParams.targetHomeFile! {
            pageFileName = params.homeFile!
        }
        var baseSourcesPath = repository.baseSourcesPath
        if !params.hasSingleDocument {
            // Regular documentation
            baseSourcesPath.appendPathComponent(params.docsFolder!)
			let intermediatePath = path.directoryFromPath()
			if intermediatePath != "." {
				baseSourcesPath.appendPathComponent(intermediatePath)
			}
            baseSourcesPath.appendPathComponent(pageFileName)
        } else {
            // Single file documentation
            baseSourcesPath.appendPathComponent(params.singleDocumentFile!)
        }
		return baseSourcesPath
	}
	
	/// Translate local path to document into couple, where first item contains a full path to cloned git repository and
	/// second item is relative path to the document.
	/// 
	/// - Parameter localFilePath: Path to local file. The path may contain a repository identifier as a prefix.
	/// - Parameter repositoryCachePath: Repository cache object.
	/// - Returns: Tuple with full path to cloned git repository and relative path to the requested file.
	func getGitRepositoryPath(for localFilePath: String, repositoryCache: RepositoryCache) -> (gitDirectory: String, localPath: String) {
		// Ignore "repoIdentifier" part from local path
		var path: String
		if localFilePath.hasPrefix(repoIdentifierWithSlash) {
			path = String(localFilePath.suffix(from: localFilePath.index(offsetBy: repoIdentifierWithSlash.count)))
		} else {
			path = localFilePath
		}
        // Prepare link to original source. If requested file has target home file name (e.g. index.md), then the
		// name has to be translated to original file name (e.g. Readme.md)
        var pageFileName = path.fileNameFromPath()
        if pageFileName == globalParams.targetHomeFile! {
            pageFileName = params.homeFile!
        }
		
		let gitLocalPath = repositoryCache.repositoryDir.addingPathComponent(repoIdentifier)
		let documentPath: String
		if !params.hasSingleDocument {
			// Regular document
			let intermediatePath = path.directoryFromPath()
			documentPath = params.docsFolder!
				.addingPathComponent(intermediatePath)
				.addingPathComponent(pageFileName)
		} else {
			documentPath = params.singleDocumentFile!
		}
		return (gitLocalPath, documentPath)
	}
}

