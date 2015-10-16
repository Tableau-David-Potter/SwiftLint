//
//  ObjcIdentifierRule.swift
//  SwiftLint
//
//  Created by Keith Smiley on 8/18/15.
//  Copyright (c) 2015 Realm. All rights reserved.
//

import SourceKittenFramework

public struct ObjcIdentifierRule: Rule {
    public init() {}

    public let identifier = "objc_identifier"

    private static let regex = try! NSRegularExpression(pattern: "(^[^\\s]+\\s+@objc|@objc[^\\n_])", options: [])

    public func validateFile(file: File) -> [StyleViolation] {
        let range = NSRange(location: 0, length: file.contents.utf16.count)
        let matches = ObjcIdentifierRule.regex.matchesInString(file.contents, options: [], range: range)

        return matches.map { match in
            return StyleViolation(type: .ObjcIdentifier,
                location: Location(file: file, offset: match.range.location),
                severity: .Warning,
                reason: "@objc should be on its own line")
        }
    }

    public let example = RuleExample(ruleName: "ObjC Identifier",
        ruleDescription: "@objc should be on its own line",
        nonTriggeringExamples: [
            "    @objc\n",
            "let foo: @objc_block () -> Void = {",
        ],
        triggeringExamples: [
            "    private @objc func",
            "@objc func",
        ]
    )
}
