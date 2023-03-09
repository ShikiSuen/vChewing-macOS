// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa
import CocoaExtension
import Shared
import SwiftExtension
import SwiftUI

private extension NSUserInterfaceLayoutOrientation {
  var layoutTDK: CandidatePool.LayoutOrientation {
    switch self {
    case .horizontal:
      return .horizontal
    case .vertical:
      return .vertical
    @unknown default:
      return .horizontal
    }
  }
}

public class CtlCandidateTDK: CtlCandidate, NSWindowDelegate {
  public var maxLinesPerPage: Int = 0
  public var useCocoa: Bool = false
  public var useMouseScrolling: Bool = true
  private static var thePool: CandidatePool = .init(candidates: [])
  private static var currentView: NSView = .init()

  @available(macOS 10.15, *)
  private var theView: some View {
    VwrCandidateTDK(
      controller: self, thePool: Self.thePool
    ).edgesIgnoringSafeArea(.top)
  }

  private var theViewCocoa: NSStackView {
    VwrCandidateTDKCocoa(controller: self, thePool: Self.thePool)
  }

  // MARK: - Constructors

  public required init(_ layout: NSUserInterfaceLayoutOrientation = .horizontal) {
    var contentRect = NSRect(x: 128.0, y: 128.0, width: 0.0, height: 0.0)
    let styleMask: NSWindow.StyleMask = [.nonactivatingPanel]
    let panel = NSPanel(
      contentRect: contentRect, styleMask: styleMask, backing: .buffered, defer: false
    )
    panel.level = NSWindow.Level(Int(max(CGShieldingWindowLevel(), kCGPopUpMenuWindowLevel)) + 2)
    panel.hasShadow = true
    panel.backgroundColor = NSColor.clear
    contentRect.origin = NSPoint.zero

    super.init(layout)
    window = panel
    window?.delegate = self
    currentLayout = layout
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Public functions

  override public func reloadData() {
    CandidateCellData.unifiedSize = candidateFont.pointSize
    guard let delegate = delegate else { return }
    Self.thePool = .init(
      candidates: delegate.candidatePairs(conv: true), lines: maxLinesPerPage,
      selectionKeys: delegate.selectionKeys, layout: currentLayout.layoutTDK, locale: locale
    )
    Self.thePool.tooltip = tooltip
    Self.thePool.reverseLookupResult = reverseLookupResult
    Self.thePool.highlight(at: 0)
    updateDisplay()
  }

  override open func updateDisplay() {
    guard let window = window else { return }
    if let currentCandidateText = Self.thePool.currentSelectedCandidateText {
      reverseLookupResult = delegate?.reverseLookup(for: currentCandidateText) ?? []
      Self.thePool.reverseLookupResult = reverseLookupResult
    }
    delegate?.candidatePairHighlightChanged(at: highlightedIndex)
    DispatchQueue.main.async { [self] in
      window.isOpaque = false
      window.backgroundColor = .clear
      viewCheck: if #available(macOS 10.15, *) {
        if useCocoa {
          Self.currentView = theViewCocoa
          break viewCheck
        }
        Self.currentView = NSHostingView(rootView: theView)
      } else {
        Self.currentView = theViewCocoa
      }
      window.contentView = Self.currentView
      window.setContentSize(Self.currentView.fittingSize)
    }
  }

  override public func scrollWheel(with event: NSEvent) {
    guard useMouseScrolling else { return }
    handleMouseScroll(deltaX: event.deltaX, deltaY: event.deltaY)
  }

  func handleMouseScroll(deltaX: CGFloat, deltaY: CGFloat) {
    switch (deltaX, deltaY, Self.thePool.layout) {
    case (1..., 0, .horizontal), (0, 1..., .vertical): highlightNextCandidate()
    case (..<0, 0, .horizontal), (0, ..<0, .vertical): highlightPreviousCandidate()
    case (0, 1..., .horizontal), (1..., 0, .vertical): showNextLine()
    case (0, ..<0, .horizontal), (..<0, 0, .vertical): showPreviousLine()
    case (_, _, _): break
    }
  }

  // Already implemented in CandidatePool.
  @discardableResult override public func showNextPage() -> Bool {
    defer { updateDisplay() }
    return Self.thePool.flipPage(isBackward: false)
  }

  // Already implemented in CandidatePool.
  @discardableResult override public func showPreviousPage() -> Bool {
    defer { updateDisplay() }
    return Self.thePool.flipPage(isBackward: true)
  }

  // Already implemented in CandidatePool.
  @discardableResult override public func showPreviousLine() -> Bool {
    defer { updateDisplay() }
    return Self.thePool.consecutivelyFlipLines(isBackward: true, count: 1)
  }

  // Already implemented in CandidatePool.
  @discardableResult override public func showNextLine() -> Bool {
    defer { updateDisplay() }
    return Self.thePool.consecutivelyFlipLines(isBackward: false, count: 1)
  }

  // Already implemented in CandidatePool.
  @discardableResult override public func highlightNextCandidate() -> Bool {
    defer { updateDisplay() }
    return Self.thePool.highlightNeighborCandidate(isBackward: false)
  }

  // Already implemented in CandidatePool.
  @discardableResult override public func highlightPreviousCandidate() -> Bool {
    defer { updateDisplay() }
    return Self.thePool.highlightNeighborCandidate(isBackward: true)
  }

  // Already implemented in CandidatePool.
  override public func candidateIndexAtKeyLabelIndex(_ id: Int) -> Int? {
    Self.thePool.calculateCandidateIndex(subIndex: id)
  }

  // Already implemented in CandidatePool.
  override public var highlightedIndex: Int {
    get { Self.thePool.highlightedIndex }
    set {
      Self.thePool.highlight(at: newValue)
      updateDisplay()
    }
  }
}
