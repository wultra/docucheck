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

class DocuCheckApplication {
    
    private let arguments: [String]
    private let applicationName: String
    private let executableDirectory: String
    
    private var configPath: String?
    private var repoDir: String?
    private var outputDir: String?
    
    private var config: Config!
    private var database: DocumentationDatabase!
    
    private var optReleaseName: String?
    private var optShowExternalLinks = false
    private var optShowUnusedDocs = false
    private var optFastMode = false
    private var optFetchRepo = [String]()
    
    /// Name of release determined by `optReleaseName` or path to config file.
    private var releaseName: String {
        if let name = optReleaseName {
            return name
        }
        guard let path = configPath else {
            Console.fatalError("Missing config path.")
        }
        return path.fileNameWithoutExtensionFromPath()
    }
    
    /// Initializes application with command line arguments.
    ///
    /// - Parameter arguments: Array with command line arguments
    init(with arguments: [String]) {
        self.arguments = arguments
        guard let executablePath = arguments.first else {
            Console.exitError("Cannot determine path to the executable.")
        }
        self.applicationName = executablePath.fileNameFromPath()
        self.executableDirectory = executablePath.directoryFromPath()
    }
    
    /// Runs an application
    func run() {
        
        // Initial setup
        Console.exitOnError = true
        Console.logPrefix = "\(applicationName):"
        Console.onExitCallback = { self.onExit(exitWithError: true) }
        
        // Validate arguments
        validateArguments()
        // Load configuration file
        let config = loadConfiguration()
        // Load repositories to an output directory
        loadDocumentation(release: releaseName, config: config)
    }
    
    /// Function validates arguments provided to the application.
    private func validateArguments() {
        
        CommandArguments()
            .add(option: "--help", alias: "-h") {
                self.printUsage(exitWithError: false)
            }
            .add(option: "--verbose", alias: "-v2") {
                Console.setVerboseLevel(.all)
                MarkdownParser.showWarnings = .all
            }
            .add(option: "--quiet", alias: "-v0") {
                Console.setVerboseLevel(.off)
                MarkdownParser.showWarnings = .off
            }
            .add(option: "--config", shortcut: "-c") { (option) in
                self.configPath = option
            }
            .add(option: "--repoDir", shortcut: "-r") { (option) in
                self.repoDir = option
            }
            .add(option: "--outputDir", shortcut: "-o") { (option) in
                self.outputDir = option
            }
            .add(option: "--releaseName", shortcut: "-n") { (option) in
                self.optReleaseName = option
            }
            .add(option: "--showExternalLinks", alias: "-sel") {
                self.optShowExternalLinks = true
            }
            .add(option: "--showUnusedDocs", alias: "-sud") {
                self.optShowUnusedDocs = true
            }
            .add(option: "--failOnWarning") {
                Console.exitWithErrorOnWarning = true
            }
            .add(option: "--fast") {
                self.optFastMode = true
            }
            .add(option: "--fetch", shortcut: "-f") { (option) in
                self.optFetchRepo.append(option)
            }
            .afterAll {
                guard self.configPath != nil else {
                    Console.exitError("You have to specify path to a configuration file.")
                }
            }
            .process(arguments: arguments)
    }
    
    /// Function loads JSON configuration
    private func loadConfiguration() -> Config {
        guard let configPath = configPath else {
            Console.fatalError("Configuration path should be known.")
        }
        guard let config = Config.load(fromFile: configPath) else {
            exit(1)
        }
        let fixedPaths = config.paths(configPath: configPath.removingLastPathComponent())
        if outputDir == nil {
            outputDir = fixedPaths.outputPath
        }
        if repoDir == nil {
            repoDir = fixedPaths.repositoriesPath
        }
        return config
    }
    
    /// Loads repositories from remote sources to destination path
    ///
    /// - Parameter config: Application configuration
    private func loadDocumentation(release: String, config: Config) {
        guard let repositoriesDir = repoDir else {
            Console.exitError("You have to specify path to directory, where repositories will be cloned.")
        }
        guard let outputDir = outputDir else {
            Console.exitError("You have to specify path to directory, where output documentation will be stored.")
        }
        let loader = DocumentationLoader(
			release: release,
			config: config,
			destinationDir: outputDir,
			repositoryDir: repositoriesDir,
			fastMode: optFastMode,
			fetchRepos: optFetchRepo)
        guard let database = loader.loadDocumentation() else {
            onExit(exitWithError: true)
        }
        self.database = database
        
        _ = database.patchSingleFileDocumentation()
        _ = database.removeUnwantedSections()
        _ = database.updateRepositoryLinks()
        _ = database.updateDocumentTitles()
        _ = database.saveAllChanges()
        
        if optShowExternalLinks {
            Console.doWithVerboseLevel(.all) { database.printAllExternalLinks() }
        }
        if optShowUnusedDocs {
            Console.doWithVerboseLevel(.all) { database.printAllUnreferencedFiles() }
        }
        Console.exitWithErrorWhenWarningOccured()
    }
    
    /// Prints usage help for the application and exits the application with success, or failure.
    ///
    /// - Parameter exitWithError: If true, application will exit with an error code.
    private func printUsage(exitWithError: Bool) -> Never {
        
        Console.doWithVerboseLevel(.all) {
    
            Console.messageLine()
            
            Console.message("Usage:  \(applicationName)  options")
            Console.message("")
            Console.message("options:")
            Console.message("")
            Console.message(" --config=path  | -c path       To set path to JSON configuration file.")
            Console.message("                                  This is required parameter.")
            Console.message(" --repoDir=path | -r path       To set path to directory, where documentation")
            Console.message("                                  will be cloned. This is required parameter")
            Console.message("                                  in case that config doesn't specify repo dir.")
            Console.message(" --outputDir=path | -o path     To set path to directory, where all markdown")
            Console.message("                                  files will be copied. This is required in case")
            Console.message("                                  that config doesn't specify output dir.")
            Console.message(" --releaseName=name | -n name   To set name of release, for example '2020.05'")
            Console.message("                                  If parameter is not used, then the name is")
            Console.message("                                  derived from JSON config path.")
            Console.message("")
            Console.message(" --showExternalLinks | -sel     Prints all external links found in docs")
            Console.message(" --showUnusedDocs | -sud        Prints all unreferenced documents")
            Console.message(" --failOnWarning                Process will fail when warning is reported")
            Console.message(" --fast                           if used, then some slow tasks will be ommited,")
            Console.message("                                  like pulling changes from git branch.")
            Console.message(" --fetch=repo | -f repo         If used, only specified repo will be updated")
            Console.message("                                  from remote repository. Can be used for multiple")
            Console.message("                                  repo identifiers.")
            Console.message("")
            Console.message(" --help    | -h                 Prints this help information")
            Console.message(" --verbose | -v2                Turns on more information printed to the console")
            Console.message(" --quiet   | -v0                Turns off all information printed to the console")
            Console.message("")
            
            Console.messageLine()
        }
        // Exit the application
        onExit(exitWithError: exitWithError)
    }
    
    /// Called internally, when application wants to exit
    ///
    /// - Parameter exitWithError: If true, then exits with an error param
    private func onExit(exitWithError: Bool) -> Never {
        exit(exitWithError ? 1 : 0)
    }
}
