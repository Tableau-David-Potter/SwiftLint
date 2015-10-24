//
//  ASTRuleTests.swift
//  SwiftLint
//
//  Created by JP Simard on 5/28/15.
//  Copyright (c) 2015 Realm. All rights reserved.
//

import SwiftLintFramework
import XCTest

class ASTRuleTests: XCTestCase {
    let commentPrefix = "/// Comment\n"
    func testTypeNames() {
        for kind in ["class", "struct", "enum"] {
            XCTAssertEqual(violations("\(commentPrefix)\(kind) Abc {}\n"), [])

            XCTAssertEqual(violations("\(commentPrefix)\(kind) Ab_ {}\n"), [StyleViolation(name: "type_name",
                type: .NameFormat,
                location: Location(file: nil, line: 2, character: 1),
                severity: .Error,
                reason: "Type name should only contain alphanumeric characters: 'Ab_'")])

            XCTAssertEqual(violations("\(commentPrefix)\(kind) abc {}\n"), [StyleViolation(name: "type_name",
                type: .NameFormat,
                location: Location(file: nil, line: 2, character: 1),
                severity: .Error,
                reason: "Type name should start with an uppercase character: 'abc'")])

            XCTAssertEqual(violations("\(commentPrefix)\(kind) Ab {}\n"), [StyleViolation(name: "type_name_min_length",
                type: .NameFormat,
                location: Location(file: nil, line: 2, character: 1),
                severity: .Warning,
                reason: "Type name should be at least 3 characters in length: 'Ab', currently 2 characters")])

            let longName = Repeat(count: 40, repeatedValue: "A").joinWithSeparator("")
            XCTAssertEqual(violations(commentPrefix + "\(kind) \(longName) {}\n"), [])
            let longerName = longName + "A"
            XCTAssertEqual(violations("\(commentPrefix)\(kind) \(longerName) {}\n"), [
                StyleViolation(name: "type_name_max_length",
                    type: .NameFormat,
                    location: Location(file: nil, line: 2, character: 1),
                    severity: .Warning,
                    reason: "Type name should be no longer than 40 characters in length: " +
                    "'\(longerName)', currently 41 characters")
                ])
        }
    }

    func testNestedTypeNames() {
        XCTAssertEqual(violations("class Abc {\n    class Def {}\n}\n"), [])
        XCTAssertEqual(violations("class Abc {\n    class def\n}\n"),
            [
                StyleViolation(name: "type_name",
                    type: .NameFormat,
                    location: Location(file: nil, line: 2, character: 5),
                    severity: .Error,
                    reason: "Type name should start with an uppercase character: 'def'")
            ]
        )
    }

    func testVariableNames() {
        for kind in ["class", "struct"] {
            for varType in ["var", "let"] {
                let testCode = "\(commentPrefix)\(kind) Abc {\n\(commentPrefix)\(varType) def: Void }\n"
                XCTAssertEqual(violations(testCode), [])

                XCTAssertEqual(violations("\(commentPrefix)\(kind) Abc {\(commentPrefix)\(varType) de_: Void }\n"), [
                    StyleViolation(name: "variable_name",
                        type: .NameFormat,
                        location: Location(file: nil, line: 3, character: 1),
                        severity: .Error,
                        reason: "Variable name should only contain alphanumeric characters: 'de_'")
                    ])

                XCTAssertEqual(violations("\(commentPrefix)\(kind) Abc {\(commentPrefix)\(varType) Def: Void }\n"), [
                    StyleViolation(name: "variable_name",
                        type: .NameFormat,
                        location: Location(file: nil, line: 3, character: 1),
                        severity: .Error,
                        reason: "Variable name should start with a lowercase character: 'Def'")
                    ])

                XCTAssertEqual(violations("\(commentPrefix)\(kind) Abc {\n\(commentPrefix)\(varType) de: Void }\n"), [
                    StyleViolation(name: "variable_name_min_length",
                        type: .NameFormat,
                        location: Location(file: nil, line: 4, character: 1),
                        severity: .Warning,
                        reason: "Variable name should be at least 3 characters in length: " +
                        "'de', currently 2 characters")
                    ])

                let longName = Repeat(count: 40, repeatedValue: "d").joinWithSeparator("")
                XCTAssertEqual(violations(commentPrefix +
                    "\(kind) Abc {\(commentPrefix)\(varType) \(longName): Void }\n"), [])
                let longerName = longName + "d"
                XCTAssertEqual(violations(commentPrefix +
                    "\(kind) Abc {\n\(commentPrefix)\(varType) \(longerName): Void }\n"), [
                    StyleViolation(name: "variable_name_max_length",
                        type: .NameFormat,
                        location: Location(file: nil, line: 4, character: 1),
                        severity: .Warning,
                        reason: "Variable name should be no longer than 40 characters in length: " +
                        "'\(longerName)', currently 41 characters")
                    ])
            }
        }
    }

    func testFunctionBodyLengths() {
        let longFunctionBody = commentPrefix +
            "func abc() {" +
            Repeat(count: 40, repeatedValue: "\n").joinWithSeparator("") +
            "}\n"
        XCTAssertEqual(violations(longFunctionBody), [])
        let longerFunctionBody = commentPrefix +
            "func abc() {" +
            Repeat(count: 41, repeatedValue: "\n").joinWithSeparator("") +
            "}\n"
        XCTAssertEqual(violations(longerFunctionBody), [StyleViolation(name: "function_body_length",
            type: .Length,
            location: Location(file: nil, line: 2, character: 1),
            severity: .Warning,
            reason: "Function body should be span 40 lines or less: currently spans 41 lines")])
    }

    func testTypeBodyLengths() {
        for kind in ["class", "struct", "enum"] {
            let longTypeBody = commentPrefix +
                "\(kind) Abc {" +
                Repeat(count: 200, repeatedValue: "\n").joinWithSeparator("") +
                "}\n"
            XCTAssertEqual(violations(longTypeBody), [])
            let longerTypeBody = commentPrefix +
                "\(kind) Abc {" +
                Repeat(count: 201, repeatedValue: "\n").joinWithSeparator("") +
                "}\n"
            XCTAssertEqual(violations(longerTypeBody), [StyleViolation(name: "type_body_length",
                type: .Length,
                location: Location(file: nil, line: 2, character: 1),
                severity: .Warning,
                reason: "Type body should be span 200 lines or less: currently spans 201 lines")])
        }
    }

    func testTypeNamesVerifyRule() {
        verifyRule(TypeNameRule(), type: .NameFormat, caller: "testTypeNamesVerifyRule")
    }

    func testVariableNamesVerifyRule() {
        verifyRule(VariableNameRule(), type: .NameFormat, caller: "testVariableNamesVerifyRule")
    }

    func testNesting() {
        verifyRule(NestingRule(), type: .Nesting, caller: "testNesting", commentDoesntViolate: false)
    }

    func testControlStatements() {
        verifyRule(ControlStatementRule(), type: .ControlStatement, caller: "testControlStatements")
    }
}
