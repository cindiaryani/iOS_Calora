//
//  Cindi_FitnessCoach_L25020008UITestsLaunchTests.swift
//  Cindi_FitnessCoach_L25020008UITests
//
//  Created by 20 on 2026/5/8.
//

import XCTest

final class Cindi_FitnessCoach_L25020008UITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
