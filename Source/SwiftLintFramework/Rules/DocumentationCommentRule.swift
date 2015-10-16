//
//  DocumentationCommentRule.swift
//  SwiftLint
//
//  Created by Keith Smiley on 8/4/15.
//  Copyright (c) 2015 Realm. All rights reserved.
//

import SourceKittenFramework
import SwiftXPC

private enum ValidScope: String {
    case Public = "source.lang.swift.accessibility.public"
    case Internal = "source.lang.swift.accessibility.internal"
}

private struct ProtocolMember: Equatable {
    let name: String
    let type: SwiftDeclarationKind
}

private func ==(lhs: ProtocolMember, rhs: ProtocolMember) -> Bool {
    return lhs.type == rhs.type && lhs.name == rhs.name
}

public struct DocumentationCommentRule: Rule {
    private let cachePath: String?

    public init(cachePath: String?) {
        let path = cachePath ?? ".protocols_cache.json"
        self.cachePath = path.absolutePathRepresentation()
    }

    public init() {
        self.init(cachePath: nil)
    }

    private func protocolsToPaths() -> [String: String] {
        guard let cachePath = self.cachePath else {
            return [:]
        }

        let URL = NSURL(fileURLWithPath: cachePath)
        if let data = NSData(contentsOfURL: URL),
            let json: AnyObject = try? NSJSONSerialization.JSONObjectWithData(data, options: []),
            let protocols = json as? [String: String]
        {
            return protocols
        }

        return [:]
    }

    public let identifier = "documentation_comments"

    public func validateFile(file: File) -> [StyleViolation] {
        return validateFile(file, dictionary: file.structure.dictionary)
    }

    private func protocolMembersFromInheritedType(type: String, fromPaths paths: [String: String]) -> [ProtocolMember] {
        guard let path = paths[type],
            let file = File(path: path),
            let substructure = file.structure.dictionary["key.substructure"] as? XPCArray else
        {
            return []
        }

        let structure = self.structuresFromArray(substructure)
        var members = [ProtocolMember]()
        for element in self.protocolsFromStructure(structure) {
            guard let substructureArray = element["key.substructure"] as? XPCArray else {
                continue
            }

            let substructure = self.structuresFromArray(substructureArray)
            members += substructure.flatMap { element in
                if let name = element["key.name"] as? String,
                    let type = element["key.kind"] as? String,
                    let kind = SwiftDeclarationKind(rawValue: type)
                {
                    return ProtocolMember(name: name, type: kind)
                }

                return nil
            }
        }

        return members
    }

    private func structuresFromArray(array: XPCArray) -> [XPCDictionary] {
        var structures = [XPCDictionary]()
        for element in array {
            if let dictionary = element as? XPCDictionary {
                structures.append(dictionary)
            }
        }

        return structures
    }

    private func protocolsFromStructure(structure: [XPCDictionary]) -> [XPCDictionary] {
        return structure.flatMap { element in
            if let kind = element["key.kind"] as? String,
                let type = SwiftDeclarationKind(rawValue: kind)
                where type == .Protocol
            {
                return element
            }

            return nil
        }
    }

    public func validateFile(file: File, dictionary: XPCDictionary) -> [StyleViolation] {
        let substructure = dictionary["key.substructure"] as? XPCArray ?? []
        var violations = [StyleViolation]()
        for item in substructure {
            guard let element = item as? XPCDictionary else {
                continue
            }

            if self.isTopLevelCommentableType(element["key.kind"]) &&
                (self.scopeNeedsComment(element["key.accessibility"]) ||
                    self.isExtension(element["key.kind"]))
            {
                let inheritedTypes = element["key.inheritedtypes"] as? XPCArray ?? []
                let typeNames = inheritedTypes.map { $0 as? XPCDictionary }.map { $0?["key.name"] as? String }.flatMap { $0 }
                if self.inheritsFromBlacklist(typeNames) {
                    continue
                }

                let paths = self.protocolsToPaths()
                var excluded = [ProtocolMember]()
                for type in typeNames {
                    excluded.appendContentsOf(self.protocolMembersFromInheritedType(type, fromPaths: paths))
                }

                if self.isCommentableType(element["key.kind"]) &&
                    !self.attributesHasComment(element["key.attributes"] as? XPCArray),
                    let offset = element["key.offset"] as? Int64
                {
                    let location = Location(file: file, offset: Int(offset))
                    violations += [StyleViolation(type: .DocumentationComment,
                        location: location, reason: "Needs documentation comment")]
                }

                let elements = element["key.substructure"] as? XPCArray ?? []
                for subElement in elements {
                    guard let subElement = subElement as? XPCDictionary else {
                        continue
                    }

                    if self.scopeNeedsComment(subElement["key.accessibility"]) &&
                        self.shouldComment(subElement, excluded: excluded),
                        let offset = subElement["key.offset"] as? Int64
                    {
                        let location = Location(file: file, offset: Int(offset))
                        violations += [StyleViolation(type: .DocumentationComment,
                            location: location, reason: "Needs documentation comment")]
                    }
                }

            }
        }

        return violations
    }

    private func shouldComment(element: XPCDictionary, excluded: [ProtocolMember]) -> Bool {
        if !self.typeNeedsComment(element["key.kind"]) {
            return false
        }

        if let name = element["key.name"] as? String where self.isNameExcluded(name) {
            return false
        }

        let attributes = element["key.attributes"] as? XPCArray ?? []
        if self.attributesHasComment(attributes) {
            return false
        }

        if self.isOverride(attributes) {
            return false
        }

        if self.isIBOutlet(attributes) {
            return false
        }

        if self.isExcludedProtocolMember(element, excludedMembers: excluded) {
            return false
        }

        return true
    }

    private let blackListedRegexes = [
        "^ABKInAppMessageControllerDelegate$",
        "^CardIOPaymentViewControllerDelegate$",
        "^CLLocationManagerDelegate$",
        "^GMSMapViewDelegate$",
        "^TuneDelegate$",
        "^UI\\w+(Delegate|DataSource)\\w*$",
        "^UISearchResultsUpdating$",
    ]

    private func inheritsFromBlacklist(inheritedTypes: [String]) -> Bool {
        for regexString in blackListedRegexes {
            let regex = try! NSRegularExpression(pattern: regexString, options: [])
            for type in inheritedTypes {
                let range = NSRange(location: 0, length: type.utf16.count)
                if regex.firstMatchInString(type, options: [], range: range) != nil {
                    return true
                }
            }
        }

        return false
    }

    private func isExcludedProtocolMember(attributes: XPCDictionary, excludedMembers: [ProtocolMember]) -> Bool {
        if let name = attributes["key.name"] as? String,
            let type = attributes["key.kind"] as? String,
            let kind = SwiftDeclarationKind(rawValue: type)
        {
            let memberType = ProtocolMember(name: name, type: kind)
            for excluded in excludedMembers {
                if excluded == memberType {
                    return true
                }
            }
        }

        return false
    }

    private func isNameExcluded(name: String) -> Bool {
        if name.hasPrefix("init") {
            return true
        } else if name == "deinit" {
            return true
        } else if name == "hashValue" {
            return true
        }

        return false
    }

    private func isOverride(attributes: XPCArray?) -> Bool {
        return self.attributesContainString(attributes, string: "source.decl.attribute.override")
    }

    private func isIBOutlet(attributes: XPCArray?) -> Bool {
        return self.attributesContainString(attributes, string: "source.decl.attribute.iboutlet")
    }

    private func attributesHasComment(attributes: XPCArray?) -> Bool {
        return self.attributesContainString(attributes, string: "source.decl.attribute.__raw_doc_comment")
    }

    private func attributesContainString(attributes: XPCArray?, string: String) -> Bool {
        for attribute in attributes ?? [] {
            if let dict = attribute as? XPCDictionary, let value = dict["key.attribute"] {
                if value == string {
                    return true
                }
            }
        }

        return false
    }

    private func scopeNeedsComment(scope: XPCRepresentable?) -> Bool {
        if let scope = scope as? String {
            return ValidScope(rawValue: scope) != nil
        }

        return false
    }

    private func isCommentableType(t: XPCRepresentable?) -> Bool {
        if let type = t as? String, let kind = SwiftDeclarationKind(rawValue: type) {
            switch kind {
            case .Class, .Extension, .Struct:
                return false
            default:
                return true
            }
        }

        return true
    }

    private func isTopLevelCommentableType(t: XPCRepresentable?) -> Bool {
        if let type = t as? String, let kind = SwiftDeclarationKind(rawValue: type) {
            switch kind {
            case .Class, .Enum, .Struct, .Extension, .Protocol, .VarGlobal, .FunctionFree, .Typealias:
                return true
            default:
                return false
            }
        }

        return false
    }

    private func isExtension(t: XPCRepresentable?) -> Bool {
        if let type = t as? String, let kind = SwiftDeclarationKind(rawValue: type) {
            switch kind {
            case .Extension:
                return true
            default:
                return false
            }
        }

        return false
    }

    private func typeNeedsComment(type: XPCRepresentable?) -> Bool {
        if let type = type as? String, let kind = SwiftDeclarationKind(rawValue: type) {
            switch kind {
            case .VarInstance, .VarStatic, .VarClass, .FunctionMethodClass, .FunctionMethodInstance, .FunctionMethodStatic, .FunctionSubscript, .Typealias:
                return true
            default:
                return false
            }
        }

        return false
    }

    public let example = RuleExample(
        ruleName: "Documentation Comment Rule",
        ruleDescription: "This rule checks if you have documented public and internal properties and classes",
        nonTriggeringExamples: [
            "// foo\npublic class Foo {\n// bar\nvar foo}\n",
            "// bar\npublic class Foo {}\n",
            "/*foo*/\nclass Foo {}\n",
            "// foo\ninternal class Foo {}\n",
            "// foo\ninternal var foo\n",
            "private class Foo {\nvar foo}\n",
            "private class Foo {\nprivate let foo}\n",
            "class Foo {}\n",
            "public class Foo {}\n",
            "extension Foo {}\n",
            "struct Foo {}\n",
            "extension Foo: UITextFieldDelegate { var Foo: String }\n",
            "struct Bar { Struct Foo {}}\n",
        ],
        triggeringExamples: [
            "extension Foo { var foo: String }\n",
            "var foo: String\n",
            "let Bar\n",
            "class Bar { class var Foo: String }\n",
            "struct Bar {\nstatic var foo: String\n}\n",
            "func == () {}\n",
        ]
    )
}
