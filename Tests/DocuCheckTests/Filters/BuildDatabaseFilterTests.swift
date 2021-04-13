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

import XCTest

@testable import DocuCheckLib

class BuildDatabaseFilterTests: XCTestCase {

    // Regular document
    let document1 =
    """
    <!-- begin database table es_operation_template -->
    ### Enrollment Server Operations

    Lorem ipsum dolor sit amet...

    #### DDL

    ```sql
    create table es_operation_template (
      id bigint not null constraint es_operation_template_pkey primary key,
      placeholder varchar(255) not null,
      language varchar(8) not null,
      title varchar(255) not null,
      message text not null,
      attributes text
    );

    create unique index es_operation_template_placeholder on es_operation_template (placeholder, language);
    ```
    <!-- end -->
    """

    // Request + Request Body headers
    let document2 =
    """
    <!-- begin database table es_operation_template -->
    ### Enrollment Server Operations

    Stores definitions of operations presented via API towards the mobile token app.

    #### Columns

    | Name | Type | Default | Not Null | Key | Description |
    |---|---|---|---|---|---|
    | `id`          | `bigint`       |  | Y |  Primary  | Primary ID of the record |
    | `placeholder` | `varchar(255)` |  | Y |           | Localization placeholder |
    | `language`    | `varchar(8)`   |  | Y |           | Language (ISO 639-1) |
    | `title`       | `varchar(255)` |  | Y |           | Operation title |
    | `message`     | `text`         |  | Y |           | Operation message |
    | `attributes`  | `text`         |  | N |           | Operation attributes |

    #### Keys

    | Name | Primary | References | Description |
    |---|---|---|---|
    | `es_operation_template_pkey` | Y | `id` | Primary key for table records |

    #### Indexes

    | Name | Unique | Columns | Description |
    |---|---|---|---|
    | `es_operation_template_placeholder` | Y | `placeholder, language` | Index for faster localization placeholder lookup |

    #### Schema

    ```sql
    create table es_operation_template (
      id bigint not null constraint es_operation_template_pkey primary key,
      placeholder varchar(255) not null,
      language varchar(8) not null,
      title varchar(255) not null,
      message text not null,
      attributes text
    );

    create unique index es_operation_template_placeholder on es_operation_template (placeholder, language);
    ```
    <!-- end -->
    """
    
    override func setUp() {
        super.setUp()
        Console.exitOnError = false
    }

    func testApiGenerator() {
        let filter = BuildApiDocFilter()
        var doc = MarkdownDocument(source: StringDocument(name: "Test1.md", string: document1), repoIdentifier: "test1")
        XCTAssertTrue(doc.load())
        var result = filter.applyFilter(to: doc)
        XCTAssertTrue(result)
        
        doc = MarkdownDocument(source: StringDocument(name: "Test2.md", string: document2), repoIdentifier: "test2")
        XCTAssertTrue(doc.load())
        result = filter.applyFilter(to: doc)
        XCTAssertTrue(result)
    }
}
