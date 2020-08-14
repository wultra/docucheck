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

class RepositoryCache {
    
    let release: String
    let path: String
	let repositoryDir: String
		
    /// Structure representing information about cached repositories
    private struct CachedData: Codable {
        
        /// Version of RepoCache manager
        let version: Int
		
        /// Returns instance of default `RepoCache` structure
        static var `default`: CachedData {
			return CachedData(version: 1)
        }
    }
	
	private var data: CachedData!
    
    /// RepoCache object constructor
    ///
    /// - Parameters:
    ///   - release: Release identifier, for example `2020.05`.
    ///   - path: Path to cache file.
    init(release: String, path: String) {
        self.release = release
        self.path = path
		self.repositoryDir = path.directoryFromPath()
    }
	
	/// Loads repository cache data.
	/// - Returns: true in case that operation succeeds
    func load() -> Bool {
		var removeCache = true
		if FS.fileExists(at: path) {
			if let document = FS.document(at: path, description: "Repository cache") {
				let cacheInfo: CachedData
				do {
					let decoder = JSONDecoder()
					cacheInfo = try decoder.decode(CachedData.self, from: document.contentData)
					if cacheInfo.version == CachedData.default.version {
						removeCache = false
					}
					data = cacheInfo
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
		if data == nil {
			data = CachedData.default
		}
		return save()
	}
    
	
	/// Saves repository cache data.
	/// - Returns: true in case that operation succeeds
    func save() -> Bool {
		guard let info = data else {
			Console.fatalError("RepoCache structure is missing.")
		}
		do {
			let encoder = JSONEncoder()
			let data = try encoder.encode(info)
			try data.write(to: URL(fileURLWithPath: path), options: .atomicWrite)
		} catch {
			Console.exitError("Failed to write RepoCache information. Error: \(error)")
		}
		return true
    }
}
