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

@testable import DocuCheckLib

class SimpleEntity: MarkdownEditableEntity, CustomStringConvertible {
    
    var content: String {
        didSet {
            isModified = true
        }
    }
    
    var isModified: Bool = false
    
    func clearModifiedFlag() {
        isModified = false
    }
    
    let type: EntityType = .header
    
    let identifier: EntityId = DefaultEntityIdGenerator.default.entityId()
    
    var range: StringRange
    
    init(content: String, range: StringRange) {
        self.content = content
        self.range = range
    }
    
    func toString() -> String {
        return content
    }
    
    var description: String {
        return "id: \(identifier): `\(toString())`\(isModified ? ", mod" : "")"
    }
}

extension MarkdownLine {
    func debugDump() {
        print("`\(lineContent)`")
        entities.forEach { (entity) in
            let range = entity.range
            var str = String(repeating: " ", count: lineContent.count)
            let substr = lineContent[range.lowerBound..<range.upperBound]
            str.replaceSubrange(range, with: String(repeating: "^", count: substr.count))
            let info = "   <-- \(entity)"
            print("`\(str)` \(info)")
        }
    }
}

class MarkdownLineTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Console.exitOnError = false
    }
    
    func testEntityUpdate() {
        let originalLine = "The quick brown fox jumps over the lazy dog"
        let line = MarkdownLine(id: DefaultEntityIdGenerator.default.entityId(), lineContent: originalLine)
        
        let lazy = SimpleEntity(content: "lazy", range: originalLine.range(of: "lazy")!)
        let quick = SimpleEntity(content: "quick", range: originalLine.range(of: "quick")!)
        let dog = SimpleEntity(content: "dog", range: originalLine.range(of: "dog")!)
        let fox = SimpleEntity(content: "fox", range: originalLine.range(of: "fox")!)
        
        line.add(entity: lazy)
        line.add(entity: fox)
        line.add(entity: dog)
        line.add(entity: quick)
        
        dog.content = "cat"
        lazy.content = "super fast"
        fox.content = "ox"
        
        XCTAssertTrue(line.toString() == "The quick brown ox jumps over the super fast cat")
        
        quick.content = "small, fast"
        lazy.content = "lazy"
        
        XCTAssertTrue(line.toString() == "The small, fast brown ox jumps over the lazy cat")
    }
}
