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

<!--   comment1 -->

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

<!--
 this comment should be ignored
 -->

<!-- comment with spaces -->
In next chapter, we will try to escape characters
\\#\\`\\_\\\\\\*\\{\\}\\[\\]\\(\\)\\+\\-\\.\\!
<!--comment2-->
"""
    var documentSource1: DocumentSource {
        return StringDocument(name: "Test1.md", string: self.source1)
    }

    let source2 =
    """
# This is header1
###   This is header 3

<!-- begin TOC -->
This is simple table of content
- Content 1
- Content 2
<!-- begin inner-toc with params -->
<!-- end -->
<!-- end TOC -->
In next chapter, we will try to escape characters
\\#\\`\\_\\\\\\*\\{\\}\\[\\]\\(\\)\\+\\-\\.\\!
<!-- document-id   543  -->
"""
    var documentSource2: DocumentSource {
        return StringDocument(name: "Test2.md", string: self.source2)
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
    
    func testInlineComments() {
        let doc = MarkdownDocument(source: self.documentSource1, repoIdentifier: "test")
        XCTAssertTrue(doc.load())
        
        let comments = doc.allEntities(ofType: .inlineComment)
        XCTAssertTrue(comments.count == 3)
        
        guard let comment1 = comments[0] as? MarkdownInlineComment else {
            XCTFail()
            return
        }
        XCTAssertTrue(comment1.content == "comment1")
        
        guard let comment2 = comments[1] as? MarkdownInlineComment else {
            XCTFail()
            return
        }
        XCTAssertTrue(comment2.content == "comment with spaces")

        guard let comment3 = comments[2] as? MarkdownInlineComment else {
            XCTFail()
            return
        }
        XCTAssertTrue(comment3.content == "comment2")
    }
    
    func testMetadataComments() {
        
        let doc = MarkdownDocument(source: self.documentSource2, repoIdentifier: "test")
        XCTAssertTrue(doc.load())
        
        guard let toc = doc.firstMetadata(withName: "TOC") else {
            XCTFail()
            return
        }
        XCTAssertTrue(toc.isMultiline)
        guard let toc_lines = doc.getLinesForMetadata(metadata: toc, includeMarkers: false)?.map({ $0.toString() }) else {
            XCTFail()
            return
        }
        XCTAssertTrue(toc_lines.count == 5)
        XCTAssertTrue(toc_lines[0] == "This is simple table of content")
        XCTAssertTrue(toc_lines[1] == "- Content 1")
        XCTAssertTrue(toc_lines[2] == "- Content 2")
        XCTAssertTrue(toc_lines[3] == "<!-- begin inner-toc with params -->")
        XCTAssertTrue(toc_lines[4] == "<!-- end -->")
  
        guard let inner_toc = doc.firstMetadata(withName: "inner-toc") else {
            XCTFail()
            return
        }
        XCTAssertTrue(inner_toc.isMultiline)
        XCTAssertTrue(inner_toc.parameters?.count == 2)
        XCTAssertTrue(inner_toc.parameters?[0] == "with")
        XCTAssertTrue(inner_toc.parameters?[1] == "params")
        
        guard let doc_id = doc.firstMetadata(withName: "document-id") else {
            XCTFail()
            return
        }
        XCTAssertFalse(doc_id.isMultiline)
        XCTAssertTrue(doc_id.parameters?[0] == "543")
    }
}
