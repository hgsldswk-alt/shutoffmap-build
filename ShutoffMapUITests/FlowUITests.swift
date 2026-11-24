import XCTest

final class FlowUITests: XCTestCase {
    private enum Language: String, CaseIterable {
        case en
        case simplified = "zh-Hans"
        case traditional = "zh-Hant"

        var locale: String {
            switch self {
            case .en: "en_US"
            case .simplified: "zh_CN"
            case .traditional: "zh_TW"
            }
        }

        var kitchen: String {
            switch self {
            case .en: "Kitchen"
            case .simplified: "厨房"
            case .traditional: "廚房"
            }
        }
    }

    private let app = XCUIApplication()
    private let namespace = UUID().uuidString

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ fixture: String?, language: Language = .en, env: [String: String] = [:], search: String? = nil) {
        app.launchArguments = ["-ui-testing", "-reset", "-data-id", namespace,
                               "-AppleLanguages", "(\(language.rawValue))", "-AppleLocale", language.locale]
            + (fixture.map { ["-fixture", $0] } ?? []) + (search.map { ["-search", $0] } ?? [])
        app.launchEnvironment = env
        app.launch()
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func tap(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(id)
        XCTAssertTrue(target.waitForExistence(timeout: 8), id, file: file, line: line)
        for _ in 0..<5 where !target.isHittable { app.swipeUp() }
        target.tap()
    }

    private func exists(_ id: String, timeout: TimeInterval = 8, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element(id).waitForExistence(timeout: timeout), id, file: file, line: line)
    }

    private func screenshot(_ name: String) {
        let image = app.screenshot()
        let attachment = XCTAttachment(screenshot: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let path = ProcessInfo.processInfo.environment["TEST_RUNNER_SHOTS_DIR"] ?? ProcessInfo.processInfo.environment["SHOTS_DIR"] {
            let folder = URL(fileURLWithPath: path, isDirectory: true)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try? image.pngRepresentation.write(to: folder.appendingPathComponent(name + ".png"))
        }
    }

    func testWaterIsOneTap() {
        launch("full")
        tap("home.water")
        exists("spot.where")
        exists("spot.how")
    }

    func testRecordWaterFromEmpty() {
        launch("empty")
        tap("home.water")
        tap("editor.photo.0")
        tap("editor.photo.1")
        tap("editor.place.stairs")
        tap("editor.done")
        exists("spot.where")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(element("home.progress").label.contains("1"))
    }

    func testMilestoneAfterAllThree() {
        launch("partial")
        tap("home.gas")
        tap("editor.photo.0")
        tap("editor.done")
        exists("milestone.send", timeout: 8)
        tap("milestone.send")
        exists("card.send")
    }

    func testPanelSearchHighlights() {
        launch("full", search: "Kitchen")
        tap("home.power")
        exists("panel.hits")
        XCTAssertEqual(element("panel.cell.2").value as? String, "hit")
        XCTAssertEqual(element("panel.cell.10").value as? String, "hit")
        XCTAssertNotEqual(element("panel.cell.3").value as? String, "hit")
    }

    func testLabelCircuitsOneTapEach() {
        launch("empty")
        tap("home.power")
        tap("panel.cell.1")
        tap("label.room.main")
        tap("label.room.kitchen-outlets")
        tap("label.done")
        XCTAssertTrue(element("panel.cell.2").label.contains("Kitchen"))
        XCTAssertTrue(element("panel.cell.1").label.contains("Main"))
    }

    func testImportCode() {
        let code = "SHUT1:" + Data(#"{"spots":[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","kind":"water","name":"","location":"Basement door","route":[],"method":"clockwise","customMethod":"","caution":"","photos":[]}],"panel":{"location":"","columns":2,"circuits":[{"id":1,"label":"Main","isMain":true,"isGFCI":false}]}}"#.utf8)
            .base64EncodedString().replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
        launch("empty", env: ["UITEST_CODE": code])
        tap("home.card")
        tap("card.paste-code")
        tap("import.save")
        exists("toast")
        tap("home.water")
        XCTAssertTrue(element("spot.where").waitForExistence(timeout: 6))
    }

    func testReviewDemo() {
        launch("empty")
        sleep(3)
        tap("home.water"); sleep(2)
        tap("editor.photo.0"); sleep(1)
        tap("editor.photo.1"); sleep(1)
        tap("editor.place.stairs"); sleep(2)
        tap("editor.done")
        exists("spot.where"); sleep(3)
        app.navigationBars.buttons.firstMatch.tap(); sleep(2)
        tap("home.power"); sleep(2)
        tap("panel.cell.1"); sleep(1)
        tap("label.room.main"); sleep(1)
        tap("label.room.kitchen-outlets"); sleep(1)
        tap("label.done"); sleep(3)
        app.navigationBars.buttons.firstMatch.tap(); sleep(2)
        tap("home.card")
        exists("card.preview"); sleep(4)
        if element("card.send").waitForExistence(timeout: 3) { tap("card.send"); sleep(3) }
    }

    func testStoreScreenshots() {
        for language in Language.allCases {
            launch("full", language: language, search: language.kitchen)
            exists("home.water")
            screenshot("store-\(language.rawValue)-01-home")

            tap("home.water")
            exists("spot.how")
            screenshot("store-\(language.rawValue)-02-water")
            app.navigationBars.buttons.firstMatch.tap()

            tap("home.power")
            exists("panel.hits")
            screenshot("store-\(language.rawValue)-03-panel")
            app.navigationBars.buttons.firstMatch.tap()

            tap("home.card")
            exists("card.preview")
            screenshot("store-\(language.rawValue)-04-card")
            app.navigationBars.buttons.firstMatch.tap()

            tap("home.gas")
            tap("spot.edit")
            exists("editor.done")
            screenshot("store-\(language.rawValue)-05-edit")
            app.terminate()
        }
    }
}
