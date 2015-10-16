//
//  BlanklineFunctionRule.swift
//  SwiftLint
//
//  Created by Keith Smiley on 8/19/15.
//  Copyright (c) 2015 Realm. All rights reserved.
//

import SourceKittenFramework

public struct BlanklineFunctionRule: Rule {
    public init() {}

    public let identifier = "blankline_function"

    private static let regex = try! NSRegularExpression(pattern: "(struct|protocol|class|enum|extension)[^\\{]*\\{\\n[^\\n]*func\\s",
        options: [])

    public func validateFile(file: File) -> [StyleViolation] {
        let range = NSRange(location: 0, length: file.contents.utf16.count)
        let matches = BlanklineFunctionRule.regex.matchesInString(file.contents,
            options: [], range: range)

        return matches.map { match in
            return StyleViolation(type: .BlanklineFunction,
                location: Location(file: file, offset: match.range.location),
                reason: "There should be a blankline after a type definition before the first function")
        }
    }

    public let example = RuleExample(ruleName: "Blankline function",
        ruleDescription: "There should be a blankline after a type definition before the first function",
        nonTriggeringExamples: [
            "class Foo {\n\nfunc bar() {}}",
            "class Foo {\nvar foo: String?}",
            "struct Foo {\n// Foo\nfunc bar() {}}",
        ],
        triggeringExamples: [
            "class Foo: Bar {\nfunc bar() {}}",
            "struct Foo {\nfunc bar() {}}",
            "enum Foo {\nfunc bar() {}}",
            "extension Foo {\nfunc bar() {}}",
            "extension Foo {\nprivate func bar() {}}",
            "protocol Foo {\n func bar() }",
        ]
    )
}
