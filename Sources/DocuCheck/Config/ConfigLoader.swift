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

extension Config {
    
    /// Function loads Config object from a given file.
    ///
    /// - Parameter file: Path to a file with JSON configuration
    /// - Returns: Config structure or nil in case of failure
    static func load(fromFile path: String) -> Config? {
        guard let document = FS.document(at: path, description: "JSON configuration") else {
            return nil
        }
        return load(from: document)
    }
    
    /// Function loads a confing from given `DocumentSource` object
    ///
    /// - Parameter source: Document as source of configuration file
    /// - Returns: Config structure or nil in case of failure
    static func load(from source: DocumentSource) -> Config? {
        
        guard source.isValid else {
            Console.error("Config JSON file \"\(source.sourceIdentifier)\" is not valid.")
            return nil
        }
        
        let config: Config
        do {
            let decoder = JSONDecoder()
            config = try decoder.decode(Config.self, from: source.contentData)
        } catch {
            Console.error("Config JSON file \"\(source.sourceIdentifier)\" is not valid. Error: \(error)")
            return nil
        }
        let errors = config.validate()
        if !errors.isEmpty {
            Console.error("Config JSON file \"\(source.sourceIdentifier)\" contains following issues:")
            errors.forEach { (issue) in
                Console.error(" - \(issue)")
            }
        }
        return config
    }
    
    /// Validates whole Config structure whether it contains invalid data.
    ///
    /// - Returns: Array with error messages
    private func validate() -> [String] {
        var errors = [String]()
        // Validate repositories
        repositories.forEach { (repoIdentifier: String, repo: Config.Repository) in
            errors.append(contentsOf: repo.validate(repoIdentifier:  repoIdentifier))
        }
        // Validate global params
        if let globalParameters = globalParameters {
            errors.append(contentsOf: globalParameters.validate(inContext: "Config.globalParameters"))
        }
        // Validate params per repository
        repositoryParameters?.forEach { (repoIdentifier: String, param: Config.Parameters) in
            if repositories[repoIdentifier] == nil {
                errors.append("repositoryParameters has definition for \"\(repoIdentifier)\" which is not in Config.repositories.")
                return
            }
            errors.append(contentsOf: param.validate(inContext: "repositoryParameters[\(repoIdentifier)]"))
        }
        return errors
    }
}

//
// File private validators
//

fileprivate extension Config.Parameters {
    
    /// Validates `Parameters` structure whether it contains an invalid data.
    ///
    /// - Parameter inContext: String describing context of Parameters structure.
    //                         The context will be used in case of error, to construct a proper error message.
    /// - Returns: Array with error messages
    func validate(inContext: String) -> [String] {
        var errors = [String]()
        if let docsFolder = docsFolder {
            if docsFolder.isEmpty {
                errors.append("Parameters.docsFolder in \"\(inContext)\" is empty.")
            }
        }
        if let homeFile = homeFile {
            if homeFile.isEmpty {
                errors.append("Parameters.homeFile in \"\(inContext)\" is empty.")
            }
        }
        return errors
    }
}

fileprivate extension Config.Repository {
    
    /// Validates `Repository` structure whether it contains an invalid data.
    ///
    /// - Parameter repoIdentifier: Repository identifier.
    /// - Returns: Array with error messages
    func validate(repoIdentifier: String) -> [String] {
        var errors = [String]()
        // TODO: better validations for "branch", "tag" and "path"
        if let branch = branch {
            if branch.isEmpty {
                errors.append("Repository.branch parameter in repository \"\(repoIdentifier)\" is empty.")
            }
        }
        if let tag = branch {
            if tag.isEmpty {
                errors.append("Repository.tag parameter in repository \"\(repoIdentifier)\" is empty.")
            }
        }
        if let path = path {
            if path.isEmpty {
                errors.append("Repository.path parameter in repository \"\(repoIdentifier)\" is empty.")
            }
        }
        return errors
    }
}
