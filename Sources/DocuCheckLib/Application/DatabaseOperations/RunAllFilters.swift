//
// Copyright 2021 Wultra s.r.o.
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

extension DocumentationDatabase {
    
    var documentFilters: [DocumentFilter] {
        return [
            RemoveUnwantedSectionsFilter(),
            BuildCodeTabsFilter(),
            BuildInfoBoxesFilter(),
            BuildApiDocFilter(),
            BuildDatabaseFilter(),
            UpdateRepositoryLinksFilter(),
            UpdateDocumentTitlesFilter()
        ]
    }
    
    /// Apply all filters to all documents.
    /// - Returns: true if everything's OK.
    func runAllFilters() -> Bool {
        var result = true
        documentFilters.forEach { filter in
            guard filter.setUpFilter(dataProvider: self) else {
                return
            }
            // For each filter acquire all documents. This is due to fact, that
            // filter may produce a new document in the database.
            allDocuments().forEach { document in
                if !filter.applyFilter(to: document) {
                    result = false
                }
            }
            if !filter.tearDownFilter() {
                result = false
            }
        }
        return result
    }
}

extension DocumentationDatabase: DocumentFilterDataProvider {
    var database: DocumentationDatabase {
        return self
    }
}
