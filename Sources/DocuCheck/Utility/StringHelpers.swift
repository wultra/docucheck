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

extension String {
    
    /// Compares substring starting at given offset to provided string
    ///
    /// - Parameters:
    ///   - needle: Substring to match in the string
    ///   - offset: Offset in the string where the substring is matched
    /// - Returns: true if current string has a substring at given offset
    func hasSubstring(_ needle: String, at offset: Int) -> Bool {
        guard offset + needle.count <= count && offset >= 0 else {
            return false
        }
        return self[index(offsetBy: offset)..<index(offsetBy: offset + needle.count)] == needle
    }
    
    /// Returns safe character at
    ///
    /// - Parameter offset: Offset to character
    /// - Returns: Character at given offset or nil if offset is out of bounds
    func safeCharacter(at offset: Int) -> Character? {
        guard offset < count && offset >= 0 else {
            return nil
        }
        return self[self.index(self.startIndex, offsetBy: offset)]
    }
    
    /// Returns offset from the beginning of the string to given index.
    ///
    /// - Parameter toIndex: Index to convert
    /// - Returns: Offset to given index
    func offset(toIndex: Index) -> Int {
        return distance(from: startIndex, to: toIndex)
    }
    
    /// Returns Index calculated from given offset
    ///
    /// - Parameter offset: Offset to convert to index
    /// - Returns: Index calculated from given offset
    func index(offsetBy offset: Int) -> Index {
        return index(startIndex, offsetBy: offset)
    }
}
