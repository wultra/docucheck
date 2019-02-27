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

protocol EntityIdGenerator {
    /// Returns a new, unique, entity identifier.
    func entityId() -> EntityId
}


// MARK: - Entity identifier generator

/// The `DefaultEntityIdGenerator` provides
class DefaultEntityIdGenerator: EntityIdGenerator {
    
    /// Default, shared instance of entity identifier generator
    static let `default` = DefaultEntityIdGenerator()
    
    /// Contains next entity identifier
    private var nextIdentifier: EntityId = 1
    
    /// Generates a new identifier for entity.
    func entityId() -> EntityId {
        let id = nextIdentifier
        nextIdentifier += 1
        return id
    }
}
