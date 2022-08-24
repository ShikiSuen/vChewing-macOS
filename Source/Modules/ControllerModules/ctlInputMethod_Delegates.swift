// Copyright (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa

// MARK: - KeyHandler Delegate

extension ctlInputMethod: KeyHandlerDelegate {
  var clientBundleIdentifier: String {
    guard let client = client() else { return "" }
    return client.bundleIdentifier() ?? ""
  }

  func ctlCandidate() -> ctlCandidateProtocol { ctlInputMethod.ctlCandidateCurrent }

  func keyHandler(
    _: KeyHandler, didSelectCandidateAt index: Int,
    ctlCandidate controller: ctlCandidateProtocol
  ) {
    ctlCandidate(controller, didSelectCandidateAtIndex: index)
  }

  func keyHandler(_ keyHandler: KeyHandler, didRequestWriteUserPhraseWith state: InputStateProtocol, addToFilter: Bool)
    -> Bool
  {
    guard let state = state as? InputState.Marking else { return false }
    if state.bufferReadingCountMisMatch { return false }
    let refInputModeReversed: InputMode =
      (keyHandler.inputMode == InputMode.imeModeCHT)
      ? InputMode.imeModeCHS : InputMode.imeModeCHT
    if !mgrLangModel.writeUserPhrase(
      state.userPhrase, inputMode: keyHandler.inputMode,
      areWeDuplicating: state.chkIfUserPhraseExists,
      areWeDeleting: addToFilter
    )
      || !mgrLangModel.writeUserPhrase(
        state.userPhraseConverted, inputMode: refInputModeReversed,
        areWeDuplicating: false,
        areWeDeleting: addToFilter
      )
    {
      return false
    }
    return true
  }
}

// MARK: - Candidate Controller Delegate

extension ctlInputMethod: ctlCandidateDelegate {
  var isAssociatedPhrasesState: Bool { state is InputState.AssociatedPhrases }

  /// 完成 handle() 函式本該完成的內容，但去掉了與 IMK 選字窗有關的判斷語句。
  /// 這樣分開處理很有必要，不然 handle() 函式會陷入無限迴圈。
  /// 該函式僅由 IMK 選字窗來存取，且對接給 commonEventHandler()。
  /// - Parameter event: 由 IMK 選字窗接收的裝置操作輸入事件。
  /// - Returns: 回「`true`」以將該案件已攔截處理的訊息傳遞給 IMK；回「`false`」則放行、不作處理。
  @discardableResult func sharedEventHandler(_ event: NSEvent) -> Bool {
    commonEventHandler(event)
  }

  func candidateCountForController(_ controller: ctlCandidateProtocol) -> Int {
    _ = controller  // 防止格式整理工具毀掉與此對應的參數。
    if let state = state as? InputState.ChoosingCandidate {
      return state.candidates.count
    } else if let state = state as? InputState.AssociatedPhrases {
      return state.candidates.count
    }
    return 0
  }

  /// 直接給出全部的候選字詞的字音配對陣列
  /// - Parameter controller: 對應的控制器。因為有唯一解，所以填錯了也不會有影響。
  /// - Returns: 候選字詞陣列（字音配對）。
  func candidatesForController(_ controller: ctlCandidateProtocol) -> [(String, String)] {
    _ = controller  // 防止格式整理工具毀掉與此對應的參數。
    if let state = state as? InputState.ChoosingCandidate {
      return state.candidates
    } else if let state = state as? InputState.AssociatedPhrases {
      return state.candidates
    }
    return .init()
  }

  func ctlCandidate(_ controller: ctlCandidateProtocol, candidateAtIndex index: Int)
    -> (String, String)
  {
    _ = controller  // 防止格式整理工具毀掉與此對應的參數。
    if let state = state as? InputState.ChoosingCandidate {
      return state.candidates[index]
    } else if let state = state as? InputState.AssociatedPhrases {
      return state.candidates[index]
    }
    return ("", "")
  }

  func ctlCandidate(_ controller: ctlCandidateProtocol, didSelectCandidateAtIndex index: Int) {
    _ = controller  // 防止格式整理工具毀掉與此對應的參數。

    if let state = state as? InputState.SymbolTable,
      let node = state.node.children?[index]
    {
      if let children = node.children, !children.isEmpty {
        handle(state: InputState.Empty())  // 防止縱橫排選字窗同時出現
        handle(
          state: InputState.SymbolTable(node: node, previous: state.node, isTypingVertical: state.isTypingVertical)
        )
      } else {
        handle(state: InputState.Committing(textToCommit: node.title))
        handle(state: InputState.Empty())
      }
      return
    }

    if let state = state as? InputState.ChoosingCandidate {
      let selectedValue = state.candidates[index]
      keyHandler.fixNode(
        candidate: selectedValue, respectCursorPushing: true,
        preConsolidate: mgrPrefs.consolidateContextOnCandidateSelection
      )

      let inputting = keyHandler.buildInputtingState

      if mgrPrefs.useSCPCTypingMode {
        handle(state: InputState.Committing(textToCommit: inputting.composingBufferConverted))
        // 此時是逐字選字模式，所以「selectedValue.1」是單個字、不用追加處理。
        if mgrPrefs.associatedPhrasesEnabled,
          let associatePhrases = keyHandler.buildAssociatePhraseState(
            withPair: .init(key: selectedValue.0, value: selectedValue.1),
            isTypingVertical: state.isTypingVertical
          ), !associatePhrases.candidates.isEmpty
        {
          handle(state: associatePhrases)
        } else {
          handle(state: InputState.Empty())
        }
      } else {
        handle(state: inputting)
      }
      return
    }

    if let state = state as? InputState.AssociatedPhrases {
      let selectedValue = state.candidates[index]
      handle(state: InputState.Committing(textToCommit: selectedValue.1))
      // 此時是聯想詞選字模式，所以「selectedValue.1」必須只保留最後一個字。
      // 不然的話，一旦你選中了由多個字組成的聯想候選詞，則連續聯想會被打斷。
      guard let valueKept = selectedValue.1.last else {
        handle(state: InputState.Empty())
        return
      }
      if mgrPrefs.associatedPhrasesEnabled,
        let associatePhrases = keyHandler.buildAssociatePhraseState(
          withPair: .init(key: selectedValue.0, value: String(valueKept)),
          isTypingVertical: state.isTypingVertical
        ), !associatePhrases.candidates.isEmpty
      {
        handle(state: associatePhrases)
        return
      }
      handle(state: InputState.Empty())
    }
  }
}
