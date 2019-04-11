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

import XCTest

@testable import DocuCheck

class MarkdownDocumentTests: XCTestCase {
    let source1 =
"""

# This is header1
 ## This should produce warning
###   This is header 3

- [Google](https://google.com) & [Wultra's github](https://github.com/wultra)
- [Link to header](#this-is-header1), `another code # xxx`
#  Another header
- [Local link](File.md) & [Another Link](./Another.md) & `inline code` ![Image](some-image.png)
- Example of code: ```swift
  func testuj(parne valce: String) {
      return "[Test](http://value)"
  }
  ```
- [File and anchor](File.md#some-anchor)


In next chapter, we will try to escape characters
\\#\\`\\_\\\\\\*\\{\\}\\[\\]\\(\\)\\+\\-\\.\\!
"""
    
    var documentSource1: DocumentSource {
        return StringDocument(name: "Test1.md", string: self.source1)
    }
   
    override func setUp() {
        super.setUp()
        Console.exitOnError = false
    }
    
    func testHeaders() {
        let doc = MarkdownDocument(source: self.documentSource1, repoIdentifier: "test")
        XCTAssertTrue(doc.load())
        
        let allHeaders = doc.allEntities(ofType: .header)
        XCTAssertEqual(allHeaders.count, 4)
        
        guard let hdr1 = allHeaders[0] as? MarkdownHeader else {
            XCTFail()
            return
        }
        XCTAssertTrue(hdr1.level == 1)
        XCTAssertTrue(hdr1.title == "This is header1")
        XCTAssertTrue(doc.line(of: hdr1) == 1)

        guard let hdr2 = allHeaders[1] as? MarkdownHeader else {
            XCTFail()
            return
        }
        XCTAssertTrue(hdr2.level == 2)
        XCTAssertTrue(hdr2.title == "This should produce warning")
        XCTAssertTrue(doc.line(of: hdr2) == 2)
        
        guard let hdr3 = allHeaders[2] as? MarkdownHeader else {
            XCTFail()
            return
        }
        XCTAssertTrue(hdr3.level == 3)
        XCTAssertTrue(hdr3.title == "This is header 3")
        XCTAssertTrue(doc.line(of: hdr3) == 3)
        
        guard let hdr4 = allHeaders[3] as? MarkdownHeader else {
            XCTFail()
            return
        }
        XCTAssertTrue(hdr4.level == 1)
        XCTAssertTrue(hdr4.title == "Another header")
    }
    
    func testLinks() {
        let doc = MarkdownDocument(source: self.documentSource1, repoIdentifier: "test")
        XCTAssertTrue(doc.load())
        
        let links = doc.allEntities(ofType: .link)
        XCTAssertEqual(links.count, 7)
        
        guard let link1 = links[0] as? MarkdownLink else {
            XCTFail()
            return
        }
        XCTAssertTrue(link1.title == "Google")
        XCTAssertTrue(link1.path  == "https://google.com")
        XCTAssertFalse(link1.isImageLink)
        
        guard let link2 = links[1] as? MarkdownLink else {
            XCTFail()
            return
        }
        XCTAssertTrue(link2.title == "Wultra's github")
        XCTAssertTrue(link2.path  == "https://github.com/wultra")
        XCTAssertFalse(link2.isImageLink)
        
        guard let link3 = links[2] as? MarkdownLink else {
            XCTFail()
            return
        }
        XCTAssertTrue(link3.title == "Link to header")
        XCTAssertTrue(link3.path  == "#this-is-header1")
        XCTAssertFalse(link3.isImageLink)
        
        guard let link4 = links[3] as? MarkdownLink else {
            XCTFail()
            return
        }
        XCTAssertTrue(link4.title == "Local link")
        XCTAssertTrue(link4.path  == "File.md")
        XCTAssertFalse(link4.isImageLink)
        
        guard let link5 = links[4] as? MarkdownLink else {
            XCTFail()
            return
        }
        XCTAssertTrue(link5.title == "Another Link")
        XCTAssertTrue(link5.path  == "./Another.md")
        XCTAssertFalse(link5.isImageLink)
        
        guard let link6 = links[5] as? MarkdownLink else {
            XCTFail()
            return
        }
        XCTAssertTrue(link6.title == "Image")
        XCTAssertTrue(link6.path  == "some-image.png")
        XCTAssertTrue(link6.isImageLink)
        
        guard let link7 = links[6] as? MarkdownLink else {
            XCTFail()
            return
        }
        XCTAssertTrue(link7.title == "File and anchor")
        XCTAssertTrue(link7.path  == "File.md#some-anchor")
        XCTAssertFalse(link7.isImageLink)
    }
}
