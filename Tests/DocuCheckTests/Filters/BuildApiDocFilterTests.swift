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

class BuildApiDocFilterTests: XCTestCase {

    // Regular document
    let document1 =
    """
    <!-- begin API POST /note/edit -->
    ### Edit Note
    Edit an exisiting note.
    #### Request
    ```
    {
        "id": "12",
        "text": "Updated text"
    }
    ```
    #### Response 200
    ```
    {
        "status": "OK"
    }
    ```
    #### Response 401
    ```
    {
        "status": "ERROR",
        "message": "401 Unauthorized"
    }
    ```
    <!-- end -->

    <!-- begin API POST /note/remove -->
    ### Remove Note
    Remove an existing note
    #### Request
    ```
    {
        "id": "12"
    }
    ```
    #### Response 200
    ```
    {
        "status": "OK"
    }
    ```
    <!-- end -->
    """

    // Request + Request Body headers
    let document2 =
    """
    <!-- begin api PUT /push/campaign/${id}/user/add -->
    ### Add Users To Campaign
    Associate users to a specific campaign. Users are identified in request body as an array of strings.
    #### Request
    ##### Query Parameters
    <table>
        <tr>
            <td>id</td>
            <td>Campaign identifier</td>
        </tr>
    </table>
    ##### Request Body
    ```json
    {
      "requestObject": [
        "1234567890",
        "1234567891",
        "1234567893"
      ]
    }
    ```
    - list of users
    #### Response 200
    ```json
    {
      "status": "OK"
    }
    ```
    <!-- end -->
    """
    
    // Optional request section
    let document3 =
    """
    <!-- begin api GET /push/service/status -->
    ### Service Status
    Send a system status response, with basic information about the running application.
    #### Response 200
    ```json
    {
      "status": "OK",
      "responseObject": {
        "applicationName": "powerauth-push",
        "applicationDisplayName": "PowerAuth Push Server",
        "applicationEnvironment": "",
        "version": "0.21.0",
        "buildTime": "2019-01-22T14:59:14.954+0000",
        "timestamp": "2019-01-22T15:00:28.399+0000"
      }
    }
    ```
    - `applicationName` - Application name.
    - `applicationDisplayName` - Application display name.
    - `applicationEnvironment` - Application environment.
    - `version` - Version of Push server.
    - `buildTime` - Timestamp when the powerauth-push-server.war file was built.
    - `timestamp` - Current time on application.
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
        
        doc = MarkdownDocument(source: StringDocument(name: "Test3.md", string: document3), repoIdentifier: "test3")
        XCTAssertTrue(doc.load())
        result = filter.applyFilter(to: doc)
        XCTAssertTrue(result)
    }
}
