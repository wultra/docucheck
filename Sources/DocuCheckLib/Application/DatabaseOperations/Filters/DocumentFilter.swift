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

/// The `DocumentFilterDataProvider` protocol defines interface that allows
/// `DocumentFilter` to get an additional information required to filter's execution.
protocol DocumentFilterDataProvider {
    
    /// Contains instance of `DocumentationDatabase` class.
    var database: DocumentationDatabase { get }
}

/// The `DocumentFilter` protocol declares interface for filter applied to `MarkdownDocument`.
protocol DocumentFilter {
    
    /// Configures filter with given data provider interface. The setup step is
    /// executed before `DocumentationDatabase` apply filter to all its documents.
    ///
    /// - Parameter dataProvider: Data provider.
    /// - Returns: true if everything's OK.
    func setUpFilter(dataProvider: DocumentFilterDataProvider) -> Bool
    
    /// Apply filter to a single document.
    ///
    /// - Parameter document: Document to modify.
    /// - Returns: true if everything's OK.
    func applyFilter(to document: MarkdownDocument) -> Bool
    
    /// Deinitializes filter after `DocumentationDatabase` apply this filter to all its documents.
    /// - Returns: true if everything's OK.
    func tearDownFilter() -> Bool
}
