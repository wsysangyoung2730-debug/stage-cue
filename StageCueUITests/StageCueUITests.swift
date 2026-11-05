import XCTest

@MainActor
final class StageCueUITests: XCTestCase {
    func testSampleRequiresManualAdvanceAndCanRestart() {
        let app = launchFreshApp()
        tap(app.buttons["samplePlan"], in: app)
        let progress = app.staticTexts["stepProgress"]
        let instruction = app.staticTexts["currentInstruction"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        XCTAssertEqual(progress.label, "4단계 중 1단계")
        XCTAssertEqual(instruction.label, "오른쪽으로 돌아주세요.")
        attachScreenshot(app, named: "화이트·인디고 예시 연습")

        tap(app.buttons["listenInstruction"], in: app)
        let automaticAdvance = expectation(for: NSPredicate(format: "label != %@", "4단계 중 1단계"), evaluatedWith: progress)
        automaticAdvance.isInverted = true
        wait(for: [automaticAdvance], timeout: 3)
        XCTAssertEqual(instruction.label, "오른쪽으로 돌아주세요.")

        let expectedInstructions = ["세 걸음 이동하세요.", "관객 쪽을 바라보세요.", "대사를 시작하세요."]
        for (offset, expected) in expectedInstructions.enumerated() {
            tap(app.buttons["nextStep"], in: app)
            XCTAssertEqual(progress.label, "4단계 중 \(offset + 2)단계")
            XCTAssertEqual(instruction.label, expected)
        }
        tap(app.buttons["nextStep"], in: app)
        XCTAssertTrue(app.staticTexts["한 장면을 연습했어요"].waitForExistence(timeout: 5))
        attachScreenshot(app, named: "예시 연습 완료")
        tap(app.buttons["처음부터 다시 연습"], in: app)
        XCTAssertEqual(progress.label, "4단계 중 1단계")
        XCTAssertEqual(instruction.label, "오른쪽으로 돌아주세요.")
    }

    func testManualPlanRequiresApprovalAndPersistsAfterRelaunch() {
        let app = launchFreshApp()
        tap(app.buttons["createPlan"], in: app)
        let title = app.textFields["sceneTitle"]
        tap(title, in: app)
        title.typeText("저장 확인 장면")
        dismissKeyboard(in: app)
        tap(app.buttons["insertExample"], in: app)
        tap(app.buttons["manualSteps"], in: app)

        let save = app.buttons["savePlan"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertFalse(save.isEnabled, "조력자의 내용 확인 전에는 저장할 수 없어야 합니다.")
        let approval = app.switches["approveSteps"]
        tap(approval, in: app)
        if approval.value as? String != "1" {
            approval.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        }
        attachScreenshot(app, named: "조력자 확인 토글 후 저장 상태")
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "조력자 확인 이후 접근성 계층"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        XCTAssertEqual(approval.value as? String, "1", "실제 확인 스위치가 켜져 있어야 합니다.")
        let saveEnabled = expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: save)
        wait(for: [saveEnabled], timeout: 5)
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.buttons["createPlan"].waitForExistence(timeout: 5))

        app.terminate()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        tap(app.tabBars.buttons["연습 폴더"], in: app)
        tap(app.staticTexts["미분류"], in: app)
        tap(app.staticTexts["저장 확인 장면"], in: app)
        XCTAssertTrue(app.staticTexts["currentInstruction"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["stepProgress"].label, "1단계 중 1단계")
        XCTAssertEqual(
            app.staticTexts["currentInstruction"].label,
            "오른쪽으로 돌아 세 걸음 이동한 다음, 관객을 보고 대사를 시작하세요."
        )
    }

    func testCreatedFolderAppearsInLibraryAndSurvivesRelaunch() {
        let app = launchFreshApp()
        tap(app.tabBars.buttons["연습 폴더"], in: app)
        tap(app.buttons["manageFolders"], in: app)
        tap(app.buttons["createFolderButton"], in: app)
        let name = app.alerts.textFields.firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("단독 공연")
        app.alerts.buttons["만들기"].tap()
        XCTAssertTrue(app.staticTexts["단독 공연"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["완료"].tap()
        tap(app.staticTexts["단독 공연"], in: app)
        XCTAssertTrue(app.buttons["createPlanInEmptyFolder"].waitForExistence(timeout: 5))

        app.terminate()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        tap(app.tabBars.buttons["연습 폴더"], in: app)
        tap(app.staticTexts["단독 공연"], in: app)
        XCTAssertTrue(app.buttons["createPlanInEmptyFolder"].waitForExistence(timeout: 5))
    }

    func testTabsSeparateHomeAndFoldersAndPreserveFolderNavigation() {
        let app = launchFreshApp()
        let homeTab = app.tabBars.buttons["홈"]
        let foldersTab = app.tabBars.buttons["연습 폴더"]
        XCTAssertTrue(homeTab.isSelected)
        XCTAssertTrue(app.buttons["createPlan"].isHittable)
        XCTAssertTrue(app.buttons["samplePlan"].exists)
        attachScreenshot(app, named: "홈 탭")

        tap(foldersTab, in: app)
        XCTAssertTrue(foldersTab.isSelected)
        XCTAssertTrue(app.buttons["manageFolders"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["createPlan"].isHittable)
        XCTAssertFalse(app.buttons["samplePlan"].isHittable)
        attachScreenshot(app, named: "연습 폴더 탭")
        tap(app.staticTexts["미분류"], in: app)
        XCTAssertTrue(app.buttons["createPlanInEmptyFolder"].waitForExistence(timeout: 5))

        tap(homeTab, in: app)
        XCTAssertTrue(app.buttons["createPlan"].waitForExistence(timeout: 5))
        tap(foldersTab, in: app)
        XCTAssertTrue(app.navigationBars["미분류"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["createPlanInEmptyFolder"].exists, "탭을 왕복해도 열어둔 폴더가 유지되어야 합니다.")
    }

    private func launchFreshApp() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-data", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        XCTAssertTrue(app.buttons["createPlan"].waitForExistence(timeout: 10))
        return app
    }

    private func dismissKeyboard(in app: XCUIApplication) {
        let done = app.buttons["입력 완료"]
        if done.waitForExistence(timeout: 2), done.isHittable { done.tap() }
    }

    private func tap(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        _ = element.waitForExistence(timeout: 2)
        for _ in 0..<8 {
            if element.exists && element.isHittable { element.tap(); return }
            scroll(in: app, upward: true)
        }
        for _ in 0..<8 {
            if element.exists && element.isHittable { element.tap(); return }
            scroll(in: app, upward: false)
        }
        XCTFail("화면에서 요소를 누를 수 없습니다: \(element)", file: file, line: line)
    }

    private func scroll(in app: XCUIApplication, upward: Bool) {
        let scrollView: XCUIElement
        if app.collectionViews.firstMatch.exists {
            scrollView = app.collectionViews.firstMatch
        } else if app.scrollViews.firstMatch.exists {
            scrollView = app.scrollViews.firstMatch
        } else {
            scrollView = app
        }
        if upward { scrollView.swipeUp() } else { scrollView.swipeDown() }
    }

    private func attachScreenshot(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
