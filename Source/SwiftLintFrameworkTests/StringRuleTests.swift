//
//  StringRuleTests.swift
//  SwiftLint
//
//  Created by JP Simard on 5/28/15.
//  Copyright (c) 2015 Realm. All rights reserved.
//

import SwiftLintFramework
import XCTest

class StringRuleTests: XCTestCase {
    func testLineLengths() {
        let longLine = Repeat(count: 100, repeatedValue: "/").joinWithSeparator("") + "\n"
        XCTAssertEqual(violations(longLine), [])
        let testCases: [(String, Int, ViolationSeverity)] = [
            ("/", 101, .Warning),
            (Repeat(count: 101, repeatedValue: "/").joinWithSeparator(""), 201, .Error)
        ]
        for testCase in testCases {
            XCTAssertEqual(violations(testCase.0 + longLine), [StyleViolation(name: "line_length",
                type: .Length,
                location: Location(file: nil, line: 1),
                severity: testCase.2,
                reason: "Line should be 100 characters or less: " +
                "currently \(testCase.1) characters")])
        }
    }

    func testTrailingNewlineAtEndOfFile() {
        XCTAssertEqual(violations("//\n"), [])
        XCTAssertEqual(violations(""), [StyleViolation(name: "trailing_newline",
            type: .TrailingNewline,
            location: Location(file: nil, line: 1),
            severity: .Warning,
            reason: "File should have a single trailing newline")])
        XCTAssertEqual(violations("//\n\n"), [StyleViolation(name: "trailing_newline",
            type: .TrailingNewline,
            location: Location(file: nil, line: 2),
            severity: .Warning,
            reason: "File should have a single trailing newline")])
    }

    func testFileLengths() {
        XCTAssertEqual(
            violations(Repeat(count: 400, repeatedValue: "//\n").joinWithSeparator("")),
            []
        )
        let testCases: [(String, Int, ViolationSeverity)] = [
            (Repeat(count: 401, repeatedValue: "//\n").joinWithSeparator(""), 401, .Warning),
            (Repeat(count: 1001, repeatedValue: "//\n").joinWithSeparator(""), 1001, .Error)
        ]
        for testCase in testCases {
            XCTAssertEqual(violations(testCase.0), [StyleViolation(name: "file_length",
                type: .Length,
                location: Location(file: nil, line: testCase.1),
                severity: testCase.2,
                reason: "File should contain 400 lines or less: currently contains \(testCase.1)")])
        }
    }

    func testFileShouldntStartWithWhitespace() {
        verifyRule(LeadingWhitespaceRule(),
            type: .LeadingWhitespace,
            caller: "testFileShouldntStartWithWhitespace",
            commentDoesntViolate: false)
    }

    func testLinesShouldntContainTrailingWhitespace() {
        verifyRule(TrailingWhitespaceRule(),
            type: .TrailingWhitespace,
            caller: "testLinesShouldntContainTrailingWhitespace",
            commentDoesntViolate: false)
    }

    func testLinesShouldContainReturnArrowWhitespace() {
        verifyRule(ReturnArrowWhitespaceRule(),
            type: .ReturnArrowWhitespace,
            caller: "testLinesShouldContainReturnArrowWhitespace")
    }

    func testForceCasting() {
        verifyRule(ForceCastRule(), type: .ForceCast, caller: "testForceCasting")
    }

    func testOperatorFunctionWhitespace() {
        verifyRule(OperatorFunctionWhitespaceRule(),
            type: .OperatorFunctionWhitespace,
            caller: "testOperatorFunctionWhitespace")
    }

    func testTodoOrFIXME() {
        verifyRule(TodoRule(), type: .TODO, caller: "testTodoOrFIXME", commentDoesntViolate: false)
    }

    func testColon() {
        verifyRule(ColonRule(), type: .Colon, caller: "testColon")
    }
}
