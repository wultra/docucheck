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

/// The `MarkdownLine` object represents one line in markdown document.
class MarkdownLine {
    
    /// Unique line identifier
    let identifier: EntityId
    
    /// Content of line
    var lineContent: String
    
    /// Entities found in the line
    var entities = [MarkdownEditableEntity]()
     
    /// Contains parser's state at the end of line
    var parserStateAtStart = MarkdownParserState.none

    /// Contains parser's state at the end of line
    var parserStateAtEnd = MarkdownParserState.none
    
    
    /// Initializes line with given identifier and line content.
    ///
    /// - Parameters:
    ///   - id: Unique line identifier
    ///   - lineContent: String with content of line
    init(id: EntityId, lineContent: String) {
        self.identifier = id
        self.lineContent = lineContent
    }
    
    /// Returns string representation of line. If line is modified,
    /// then updates line content before is returned.
    ///
    /// - Returns: String representation of line.
    func toString() -> String {
        update()
        return lineContent
    }
    
    /// Contains true if line is modified.
    var isModified: Bool {
        return !allModifiedEntities.isEmpty
    }
}

// Entities management

extension MarkdownLine {
    
    /// Returns entity with given identifier.
    ///
    /// - Parameter entityId: Entity to be found
    /// - Returns: Entity object or nil if line doesn't contain object with given identifier.
    func entity(entityId: EntityId) -> MarkdownEditableEntity? {
        return entities.first { $0.identifier == entityId }
    }
    
    /// Adds entity to the line
    ///
    /// - Parameter entity: entity to be added
    func add(entity: MarkdownEditableEntity) {
        // Validate added entity's range
        let overlappedEntities = entities.filter({ entity.range.overlaps($0.range) })
        guard overlappedEntities.isEmpty else {
            let fooId = overlappedEntities.first?.identifier ?? -1
            Console.warning("Inserting entity (id:\(entity.identifier)) which overlaps with some other entity (id:\(fooId).")
            return
        }
        entities.append(entity)
    }
    
    /// Removes entity with identifier
    ///
    /// - Parameter entityId: Identifier of entity to be removed
    func remove(entityId: EntityId) {
        guard let index = entities.firstIndex(where: { $0.identifier == entityId }) else {
            return
        }
        entities.remove(at: index)
    }
    
    /// Removes entity from the line
    ///
    /// - Parameter entity: Entity to be removed from the line
    func remove(entity: MarkdownEntity) {
        remove(entityId: entity.identifier)
    }
    
    /// Returns true if line contains entity with given identifier
    ///
    /// - Parameter entityId: Entity to be found
    /// - Returns: true, if line contains entity with given identifier.
    func contains(entityId: EntityId) -> Bool {
        return entities.firstIndex(where: { $0.identifier == entityId }) != nil
    }
}

// Content update

fileprivate extension MarkdownLine {
    
    /// Contains all editable entities with modified flag equal to true
    var allModifiedEntities: [MarkdownEditableEntity] {
        return entities.filter { $0.isModified }
    }
    
    /// Updates content of line.
    func update() {
        entities.forEach { entity in
            if entity.isModified {
                self.updateEntity(entity: entity)
            }
        }
    }
    
    /// Updates content of line depending on one particular entity.
    ///
    /// - Parameter entity: Entity to be update.
    private func updateEntity(entity: MarkdownEditableEntity) {
        // Get old and new content and calculate size difference between new and old text
        let newContent = entity.toString()
        let oldContent = lineContent[entity.range.lowerBound ..< entity.range.upperBound]
        let difference = newContent.count - oldContent.count
        
        // Replace old content with new one. Must be applied before we update entity ranges
        let oldRange = entity.range
        if difference > 0 {
            lineContent.replaceSubrange(oldRange, with: newContent)
        }
        // Iterate over all entities and update ranges for all entities affected by the change
        for (index, _) in entities.enumerated() {
            // We need to get mutable entity, otherwise object modification is not possible
            var other = entities[index]
            if other.identifier == entity.identifier {
                // For original entity, only upper bound must be updated
                let lower = other.range.lowerBound
                let upper = self.lineContent.index(other.range.upperBound, offsetBy: difference)
                other.range = Range(uncheckedBounds: (lower, upper))
            } else if other.range.lowerBound >= oldRange.upperBound {
                // Other entity, located behind the original one
                let lower = self.lineContent.index(other.range.lowerBound, offsetBy: difference)
                let upper = self.lineContent.index(other.range.upperBound, offsetBy: difference)
                other.range = Range(uncheckedBounds: (lower, upper))
            }
        }
        if difference <= 0 {
            lineContent.replaceSubrange(oldRange, with: newContent)
        }
        entity.clearModifiedFlag()
    }
}
