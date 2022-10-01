// (c) 2022 and onwards Shaps Benkau (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

// (c) 2022 and onwards Shaps Benkau (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import SwiftUI

/*
 The following code is for debugging purposes only!
 */

#if DEBUG
  @available(macOS 10.15, *)
  extension EnvironmentValues: CustomDebugStringConvertible {
    public var debugDescription: String {
      "\(self)"
        .trimmingCharacters(in: .init(["[", "]"]))
        .replacingOccurrences(of: "EnvironmentPropertyKey", with: "")
        .replacingOccurrences(of: ", ", with: "\n")
    }
  }

  @available(macOS 10.15, *)
  struct EnvironmentOutputModifier: ViewModifier {
    @Environment(\.self) private var environment

    func body(content: Content) -> some View {
      content
        .onAppear {
          print(environment.debugDescription)
        }
    }
  }

  @available(macOS 10.15, *)
  extension View {
    func printEnvironment() -> some View {
      modifier(EnvironmentOutputModifier())
    }
  }
#endif
