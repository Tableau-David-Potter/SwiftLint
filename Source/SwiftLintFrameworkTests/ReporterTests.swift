//
//  ReporterTests.swift
//  SwiftLint
//
//  Created by JP Simard on 9/19/15.
//  Copyright © 2015 Realm. All rights reserved.
//

import SwiftLintFramework
import XCTest

class ReporterTests: XCTestCase {
    func generateViolations() -> [StyleViolation] {
        return [
            StyleViolation(name: "violation",
                type: .Length,
                location: Location(file: "filename", line: 1, character: 2),
                severity: .Warning,
                reason: "Violation Reason."),
            StyleViolation(name: "violation",
                type: .Length,
                location: Location(file: "filename", line: 1, character: 2),
                severity: .Error,
                reason: "Violation Reason.")
        ]
    }

    func testXcodeReporter() {
        XCTAssertEqual(
            XcodeReporter.generateReport(generateViolations()),
            "filename:1:2: warning: Length Violation (violation): Violation Reason.\n" +
            "filename:1:2: error: Length Violation (violation): Violation Reason."
        )
    }

    func testJSONReporter() {
        XCTAssertEqual(
            JSONReporter.generateReport(generateViolations()),
            "[\n" +
                "  {\n" +
                "    \"reason\" : \"Violation Reason.\",\n" +
                "    \"character\" : 2,\n" +
                "    \"file\" : \"filename\",\n" +
                "    \"line\" : 1,\n" +
                "    \"severity\" : \"Warning\",\n" +
                "    \"name\" : \"violation\",\n" +
                "    \"type\" : \"Length\"\n" +
                "  },\n" +
                "  {\n" +
                "    \"reason\" : \"Violation Reason.\",\n" +
                "    \"character\" : 2,\n" +
                "    \"file\" : \"filename\",\n" +
                "    \"line\" : 1,\n" +
                "    \"severity\" : \"Error\",\n" +
                "    \"name\" : \"violation\",\n" +
                "    \"type\" : \"Length\"\n" +
                "  }\n" +
            "]"
        )
    }

    func testCSVReporter() {
        XCTAssertEqual(
            CSVReporter.generateReport(generateViolations()),
            "file,line,character,severity,name,type,reason," +
            "filename,1,2,Warning,violation,Length,Violation Reason.," +
            "filename,1,2,Error,violation,Length,Violation Reason."
        )
    }
}
