//
// Copyright 2020 Wultra s.r.o.
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

/// Structure contains information about renamed file.
struct DocumentOrigin {
	let repoIdentifier: String
	let originalLocalPath: String
	let currentLocalPath: String
}

/// The `DocumentOriginRegister` tracks various file name changes across the repositories.
class DocumentOriginRegister {
	
	let destinationDir: String
	let config: Config
	
	private var register: [String:DocumentOrigin] = [:]
	
	init(config: Config, destinationDir: String) {
		self.config = config
		self.destinationDir = destinationDir
	}
		
	func findDocumentOrigin(fullPath: String) -> DocumentOrigin? {
		return register[fullPath]
	}
	
	func findDocumentOrigin(localPath: String) -> DocumentOrigin? {
		let fullPath = destinationDir.addingPathComponent(localPath)
		return register[fullPath]
	}
	
	func findDocumentOrigin(repoIdentifier: String, localPath: String) -> DocumentOrigin? {
		let fullPath = config.path(repo: repoIdentifier, basePath: destinationDir).addingPathComponent(localPath)
		return register[fullPath]
	}
	
	func registerRename(repoIdentifier: String, originalLocalPath source: String, newLocalPath destination: String) {
		let baseRepoPath = config.path(repo: repoIdentifier, basePath: "")
		let originalLocalPath = baseRepoPath.addingPathComponent(source)
		let newLocalPath = baseRepoPath.addingPathComponent(destination)
		let newFullPath = destinationDir.addingPathComponent(newLocalPath)
		register[newFullPath] = DocumentOrigin(
			repoIdentifier: repoIdentifier,
			originalLocalPath: originalLocalPath,
			currentLocalPath: newLocalPath)
	}
	
}
