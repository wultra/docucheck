// Copyright 2026 Wultra s.r.o.
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

import XCTest

@testable import DocuCheckLib

/// Tests for `UpdateRepositoryLinksFilter`, focusing on the correct rewriting of relative links
/// that cross directory boundaries within the same repository.
class UpdateRepositoryLinksFilterTests: XCTestCase {

    // MARK: - Setup helpers

    private let repoIdentifier = "documentation"

    private func makeConfig() throws -> Config {
        let json = """
        {
            "repositories": {
                "documentation": {
                    "remote": "wultra/enrollment-server",
                    "branch": "releases/2.2.x"
                }
            }
        }
        """
        return try JSONDecoder().decode(Config.self, from: Data(json.utf8))
    }

    private func makeDatabase(config: Config) -> DocumentationDatabase {
        let origins = DocumentOriginRegister(config: config, destinationDir: "")
        let cache = RepositoryCache(release: "test", path: "/tmp/docucheck-test-cache.json")
        return DocumentationDatabase(config: config, sourcePath: "", documentOrigins: origins, repositoryCache: cache)
    }

    private func makeRepositoryContent(config: Config) -> RepositoryContent {
        let params = config.parameters(repo: repoIdentifier)
        let repoConfig = config.repositories[repoIdentifier]!
        let globalParams = config.effectiveGlobalParameters
        return RepositoryContent(repoIdentifier: repoIdentifier, repository: repoConfig, params: params, globalParams: globalParams)
    }

    /// Registers a `FileItem` in both the database's `fileItems` map and the repository's file sets.
    private func add(filePath: String, to db: DocumentationDatabase, repo: RepositoryContent) {
        let item = FileItem(repoIdentifier: repoIdentifier, localPath: filePath)
        db.fileItems[filePath] = item
        repo.allFiles.append(filePath)
        repo.allFilesSet.insert(filePath)
    }

    /// Registers a `MarkdownDocument` backed by `StringDocument` in both the database and the repository.
    private func add(document: MarkdownDocument, path: String, to db: DocumentationDatabase, repo: RepositoryContent) {
        db.fileItems[path] = document
        repo.allFiles.append(path)
        repo.allFilesSet.insert(path)
    }

    override func setUp() {
        super.setUp()
        Console.exitOnError = false
    }

    // MARK: - Tests

    /// A link from a document inside a subdirectory (`onboarding/`) to a non-markdown file in a sibling
    /// directory (`sql/`) must be rewritten as a proper relative path (`../sql/...`), not as an
    /// absolute-looking repo-prefixed path (`documentation/sql/...`).
    ///
    /// This is a regression test for the fix in `patchLocalLink` that adds the `else if !currentDocumentParentDir.isEmpty`
    /// branch calling `relativePath(fromDocument:toDocument:)`.
    func testLinkFromSubdirectoryToSiblingDirectoryIsRelative() throws {
        let config = try makeConfig()
        let db = makeDatabase(config: config)
        let repo = makeRepositoryContent(config: config)
        db.repositories[repoIdentifier] = repo
        db.repositories[repo.fullRemotePath.absoluteString] = repo

        // The SQL target file that the migration document links to.
        let sqlPath = "documentation/sql/oracle/onboarding/migration_2.1.0_2.2.0.sql"
        add(filePath: sqlPath, to: db, repo: repo)

        // A migration guide document in the onboarding subdirectory, linking to the SQL file
        // via a relative `../` path — the typical cross-directory link pattern.
        let docPath = "documentation/onboarding/PowerAuth-Enrollment-Onboarding-Server-2.2.0.md"
        let docContent = "- [Oracle script](../sql/oracle/onboarding/migration_2.1.0_2.2.0.sql)"
        let doc = MarkdownDocument(
            source: StringDocument(name: docPath, string: docContent),
            repoIdentifier: repoIdentifier
        )
        XCTAssertTrue(doc.load(), "Document must load successfully")
        add(document: doc, path: docPath, to: db, repo: repo)

        // Run the filter.
        let filter = UpdateRepositoryLinksFilter()
        XCTAssertTrue(filter.setUpFilter(dataProvider: db))
        XCTAssertTrue(filter.applyFilter(to: doc))

        // Verify the rewritten link.
        let links = doc.allLinks
        XCTAssertEqual(links.count, 1, "Expected exactly one link in the document")
        let linkPath = links[0].path

        XCTAssertFalse(
            linkPath.hasPrefix("\(repoIdentifier)/"),
            "Link must not start with the repo identifier — got: \(linkPath)"
        )
        XCTAssertFalse(
            linkPath.hasPrefix("\(repoIdentifier)"),
            "Link must not be an absolute-looking repo-prefixed path — got: \(linkPath)"
        )
        XCTAssertTrue(
            linkPath.hasPrefix("../") || linkPath == "../sql/oracle/onboarding/migration_2.1.0_2.2.0.sql",
            "Link must remain a relative path — got: \(linkPath)"
        )
        XCTAssertEqual(
            linkPath,
            "../sql/oracle/onboarding/migration_2.1.0_2.2.0.sql",
            "Link must be the correct relative path from the onboarding subdirectory to the sql file"
        )
    }

    /// Same scenario as above but using the `./../` prefix variant that routes directly through
    /// `patchLocalLink` (bypasses `patchLocalSourceLink`) — confirming the fix works for both forms.
    func testLinkWithDotSlashPrefixFromSubdirectoryToSiblingDirectoryIsRelative() throws {
        let config = try makeConfig()
        let db = makeDatabase(config: config)
        let repo = makeRepositoryContent(config: config)
        db.repositories[repoIdentifier] = repo
        db.repositories[repo.fullRemotePath.absoluteString] = repo

        let sqlPath = "documentation/sql/postgresql/onboarding/migration_2.1.0_2.2.0.sql"
        add(filePath: sqlPath, to: db, repo: repo)

        let docPath = "documentation/onboarding/PowerAuth-Enrollment-Onboarding-Server-2.2.0.md"
        // `./../` form — used in the original bug report for the PostgreSQL link.
        let docContent = "- [PostgreSQL script](./../sql/postgresql/onboarding/migration_2.1.0_2.2.0.sql)"
        let doc = MarkdownDocument(
            source: StringDocument(name: docPath, string: docContent),
            repoIdentifier: repoIdentifier
        )
        XCTAssertTrue(doc.load(), "Document must load successfully")
        add(document: doc, path: docPath, to: db, repo: repo)

        let filter = UpdateRepositoryLinksFilter()
        XCTAssertTrue(filter.setUpFilter(dataProvider: db))
        XCTAssertTrue(filter.applyFilter(to: doc))

        let links = doc.allLinks
        XCTAssertEqual(links.count, 1)
        let linkPath = links[0].path

        XCTAssertFalse(
            linkPath.hasPrefix(repoIdentifier),
            "Link must not be repo-prefixed — got: \(linkPath)"
        )
        XCTAssertFalse(
            linkPath.hasPrefix("./"),
            "Link must not retain the './' prefix — got: \(linkPath)"
        )
        XCTAssertEqual(
            linkPath,
            "../sql/postgresql/onboarding/migration_2.1.0_2.2.0.sql",
            "Link must be normalised to a clean relative path"
        )
    }

    /// Links that point to a file in the SAME directory must still work correctly after the fix —
    /// no regression in the happy path.
    func testLinkWithinSameDirectoryRemainsUnchanged() throws {
        let config = try makeConfig()
        let db = makeDatabase(config: config)
        let repo = makeRepositoryContent(config: config)
        db.repositories[repoIdentifier] = repo
        db.repositories[repo.fullRemotePath.absoluteString] = repo

        let targetPath = "documentation/onboarding/Events.md"
        let targetDoc = MarkdownDocument(
            source: StringDocument(name: targetPath, string: "# Events"),
            repoIdentifier: repoIdentifier
        )
        XCTAssertTrue(targetDoc.load())
        add(document: targetDoc, path: targetPath, to: db, repo: repo)

        let sourcePath = "documentation/onboarding/Migration.md"
        let sourceContent = "See [Events Documentation](./Events.md)."
        let sourceDoc = MarkdownDocument(
            source: StringDocument(name: sourcePath, string: sourceContent),
            repoIdentifier: repoIdentifier
        )
        XCTAssertTrue(sourceDoc.load())
        add(document: sourceDoc, path: sourcePath, to: db, repo: repo)

        let filter = UpdateRepositoryLinksFilter()
        XCTAssertTrue(filter.setUpFilter(dataProvider: db))
        XCTAssertTrue(filter.applyFilter(to: sourceDoc))

        let links = sourceDoc.allLinks
        XCTAssertEqual(links.count, 1)
        let linkPath = links[0].path

        XCTAssertFalse(
            linkPath.hasPrefix(repoIdentifier),
            "Same-directory link must not become repo-prefixed — got: \(linkPath)"
        )
        // After filter, `Events.md` has its `.md` stripped and the link stays in the same dir.
        XCTAssertEqual(linkPath, "Events", "Same-directory link should be normalised to filename without extension")
    }
}
