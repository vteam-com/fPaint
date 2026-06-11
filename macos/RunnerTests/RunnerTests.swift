import Cocoa
import FlutterMacOS
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {
  private let defaultTimestamp: TimeInterval = 0
  private let keyCodeY: UInt16 = 16
  private let keyCodeZ: UInt16 = 6
  private let windowNumber = 0
  private let keyEquivalentY = "y"
  private let keyEquivalentZ = "z"

  func testEditMethodReturnsUndoForCommandZ() {
    let event = makeKeyEvent(
      keyEquivalent: keyEquivalentZ,
      modifierFlags: [.command],
      keyCode: keyCodeZ
    )

    XCTAssertEqual(MainFlutterWindow.editMethod(forKeyEquivalentEvent: event), "undo")
  }

  func testEditMethodReturnsRedoForCommandShiftZ() {
    let event = makeKeyEvent(
      keyEquivalent: keyEquivalentZ,
      modifierFlags: [.command, .shift],
      keyCode: keyCodeZ
    )

    XCTAssertEqual(MainFlutterWindow.editMethod(forKeyEquivalentEvent: event), "redo")
  }

  func testEditMethodReturnsRedoForCommandY() {
    let event = makeKeyEvent(
      keyEquivalent: keyEquivalentY,
      modifierFlags: [.command],
      keyCode: keyCodeY
    )

    XCTAssertEqual(MainFlutterWindow.editMethod(forKeyEquivalentEvent: event), "redo")
  }

  func testEditMethodIgnoresPlainZ() {
    let event = makeKeyEvent(
      keyEquivalent: keyEquivalentZ,
      modifierFlags: [],
      keyCode: keyCodeZ
    )

    XCTAssertNil(MainFlutterWindow.editMethod(forKeyEquivalentEvent: event))
  }

  private func makeKeyEvent(
    keyEquivalent: String,
    modifierFlags: NSEvent.ModifierFlags,
    keyCode: UInt16
  ) -> NSEvent {
    return NSEvent.keyEvent(
      with: .keyDown,
      location: .zero,
      modifierFlags: modifierFlags,
      timestamp: defaultTimestamp,
      windowNumber: windowNumber,
      context: nil,
      characters: keyEquivalent,
      charactersIgnoringModifiers: keyEquivalent,
      isARepeat: false,
      keyCode: keyCode
    )!
  }
}
