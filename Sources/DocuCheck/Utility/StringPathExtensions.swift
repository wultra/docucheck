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
    
    static let pathSeparatorString: String = "/"
    static let pathSeparatorCharacter: Character = "/"
    
    /// Returns file name part from path, stored in the string. If string ends with "/", then returns empty string.
    func fileNameFromPath() -> String {
        guard let rpos = self.range(of: String.pathSeparatorString, options:.backwards) else {
            // forward slash not found
            return self
        }
        return String(self[rpos.upperBound..<self.endIndex])
    }
    
    
    /// Returns file extension from path, stored in the string. If "dot" character is not found in the string,
    /// then returns an empty string.
    func fileExtensionFromPath() -> String {
        let name = self.fileNameFromPath()
        guard let rpos = name.range(of: ".", options:.backwards) else {
            // forward slash not found
            return ""
        }
        return String(name[rpos.upperBound..<name.endIndex])
    }
    
    /// Returns file item name part from path, stored in the string. Unline `fileNameFromPath()`, this function can return
    /// also a directory name, if path ends with "/"
    func fileItemNameFromPath() -> String {
        let stringEnd = self.last == String.pathSeparatorCharacter ? self.index(before: self.endIndex) : self.endIndex
        let range = Range(uncheckedBounds: (self.startIndex, stringEnd))
        guard let rpos = self.range(of: String.pathSeparatorString, options:.backwards, range: range) else {
            // forward slash not found
            return self
        }
        return String(self[rpos.upperBound..<self.endIndex])
    }
    
    /// Returns directory part from path, stored in the string.
    func directoryFromPath() -> String {
        let path = self.removingLastPathComponent()
        return path.isEmpty ? "." : path
    }
    
    /// Returns path with added given component.
    func addingPathComponent(_ component: String) -> String {
        if self.last == String.pathSeparatorCharacter {
            if component.first == String.pathSeparatorCharacter {
                // Last is slash, first in component is slash
                let componentWithoutSlash = component[component.index(after: component.startIndex)..<component.endIndex]
                return "\(self)\(componentWithoutSlash)"
            } else {
                // Last is slash, component has no first slash
                return "\(self)\(component)"
            }
        } else {
            // Last is no slash, but string is empty
            if component.first == String.pathSeparatorCharacter {
                // Last is no slash, first in component is slash
                if self.isEmpty {
                    return String(component[component.index(after: component.startIndex)..<component.endIndex])
                }
                return "\(self)\(component)"
            } else {
                // Last is no slash, first in coponent has no first slash
                if self.isEmpty {
                    return component
                }
                return "\(self)\(String.pathSeparatorCharacter)\(component)"
            }
        }
    }
    
    /// Returns string where last path component is removed.
    func removingLastPathComponent() -> String {
        if self == String.pathSeparatorString {
            return self
        }
        let stringEnd = self.last == String.pathSeparatorCharacter ? self.index(before: self.endIndex) : self.endIndex
        let range = Range(uncheckedBounds: (self.startIndex, stringEnd))
        guard let rpos = self.range(of: String.pathSeparatorString, options:.backwards, range: range) else {
            // forward slash not found
            return ""
        }
        if rpos.lowerBound == self.startIndex {
            return String.pathSeparatorString
        }
        return String(self[self.startIndex..<rpos.lowerBound])
    }
}
