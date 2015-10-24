//
//  TypeNameMinLengthRule.swift
//  SwiftLint
//
//  Created by David Potter on 10/22/15.
//  Copyright © 2015 Realm. All rights reserved.
//

import SourceKittenFramework
import SwiftXPC

public struct TypeNameMinLengthRule: ASTRule {
    public let identifier = "type_name_min_length"

    public struct Constants {
        public static let defaultMinimum = 3
    }

    public let parameters: [RuleParameter<Int>]

    public init() {
        self.init(
            parameters: [RuleParameter(severity: .Warning, value: Constants.defaultMinimum)])
    }

    public init(parameters: [RuleParameter<Int>]) {
        self.parameters = parameters
    }

    public func validateFile(file: File) -> [StyleViolation] {
        return validateFile(file, dictionary: file.structure.dictionary)
    }

    public func validateFile(file: File, dictionary: XPCDictionary) -> [StyleViolation] {
        let substructure = dictionary["key.substructure"] as? XPCArray ?? []
        return substructure.flatMap { subItem -> [StyleViolation] in
            var violations = [StyleViolation]()
            if let subDict = subItem as? XPCDictionary,
                let kindString = subDict["key.kind"] as? String,
                let kind = SwiftDeclarationKind(rawValue: kindString) {
                    violations.appendContentsOf(
                        self.validateFile(file, dictionary: subDict) +
                            self.validateFile(file, kind: kind, dictionary: subDict)
                    )
            }
            return violations
        }
    }

    public func validateFile(file: File,
        kind: SwiftDeclarationKind,
        dictionary: XPCDictionary) -> [StyleViolation] {
            let typeKinds: [SwiftDeclarationKind] = [
                .Class,
                .Struct,
                .Typealias,
                .Enum,
                .Enumelement
            ]
            if !typeKinds.contains(kind) {
                return []
            }
            var violations = [StyleViolation]()
            if let name = dictionary["key.name"] as? String,
                let offset = (dictionary["key.offset"] as? Int64).flatMap({ Int($0) }) {
                    let location = Location(file: file, offset: offset)
                    let name = name.nameStrippingLeadingUnderscoreIfPrivate(dictionary)
                    for parameter in parameters {
                        if name.characters.count < parameter.value {
                            violations.append(
                                StyleViolation(name: identifier,
                                    type: .NameFormat,
                                    location: location,
                                    severity: .Warning,
                                    reason: "Type name should be at least \(parameter.value) characters in length: " +
                                    "'\(name)', currently \(name.characters.count) characters"))
                        }
                    }
            }
            return violations
    }

    public let example = RuleExample(
        ruleName: "Type Name Min Length Rule",
        ruleDescription: "Type name should be at least \(Constants.defaultMinimum) characters in length.",
        nonTriggeringExamples: [
            "struct MyStruct {}"
        ],
        triggeringExamples: [
            "struct My {}"
        ],
        showExamples: false
    )
}
