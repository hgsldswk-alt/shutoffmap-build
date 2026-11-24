import Foundation
import XCTest

final class CoreTests: XCTestCase {
    private let jpeg = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46])

    private func sampleHome() -> HomeData {
        var home = HomeData()
        var water = Spot(kind: .water)
        water.location = "Under the stairs"
        water.route = ["Open the closet", "  ", "Right wall"]
        water.photos = ["a.jpg", "b.jpg"]
        home.spots.append(water)
        var gas = Spot(kind: .gas, caution: "Call the gas company to turn it back on")
        gas.location = "Outside by the meter"
        home.spots.append(gas)
        home.panel.circuits[0].label = "Main"
        home.panel.circuits[0].isMain = true
        home.panel.circuits[1].label = "Fridge"
        home.panel.circuits[1].template = "room.fridge"
        home.panel.circuits[2].label = "Kitchen outlets"
        home.panel.photo = "p.jpg"
        return home
    }

    func testSpotRecordingAndSteps() {
        var spot = Spot(kind: .water)
        XCTAssertFalse(spot.isRecorded)
        XCTAssertEqual(spot.method, .clockwise)
        spot.location = "   "
        XCTAssertFalse(spot.isRecorded)
        spot.photos = ["x.jpg"]
        XCTAssertTrue(spot.isRecorded)
        spot.route = [" A ", "", "B"]
        XCTAssertEqual(spot.steps, ["A", "B"])
        XCTAssertEqual(Spot(kind: .gas).method, .leverCross)
        XCTAssertEqual(Spot(kind: .power).method, .pullMain)
    }

    func testPanelResizeKeepsLabelsAndClamps() {
        var panel = Panel()
        panel.circuits[3].label = "AC"
        panel.resize(to: 30)
        XCTAssertEqual(panel.circuits.count, 30)
        XCTAssertEqual(panel.circuits.last?.id, 30)
        XCTAssertEqual(panel.circuits[3].label, "AC")
        panel.resize(to: 2)
        XCTAssertEqual(panel.circuits.map(\.id), [1, 2])
        panel.resize(to: 999)
        XCTAssertEqual(panel.circuits.count, Panel.maxCircuits)
        panel.resize(to: 0)
        XCTAssertEqual(panel.circuits.count, 1)
    }

    func testPanelSearchByLabelAndGroup() {
        let panel = sampleHome().panel
        let translate: (String) -> String = { $0 == "group.kitchen" ? "Kitchen" : $0 }
        XCTAssertEqual(panel.matches("kitchen", translate: translate), [2, 3])
        XCTAssertEqual(panel.matches("FRIDGE", translate: translate), [2])
        XCTAssertEqual(panel.matches("  ", translate: translate), [])
        XCTAssertEqual(panel.matches("garage", translate: translate), [])
        XCTAssertEqual(panel.matches("main breaker", translate: translate), [1])
    }

    func testHomeProgressAndUpsert() {
        var home = sampleHome()
        XCTAssertEqual(home.recordedBig, 3)
        XCTAssertTrue(home.allThree)
        home.panel = Panel()
        XCTAssertFalse(home.isRecorded(.power))
        XCTAssertEqual(home.recordedBig, 2)
        var water = home.spot(.water)!
        water.location = "Garage"
        home.upsert(water)
        XCTAssertEqual(home.spots.count, 2)
        XCTAssertEqual(home.spot(.water)?.location, "Garage")
    }

    func testCoreReviewRequiresThreeActionsOnTwoLocalDates() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        let firstDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 23)))
        let nextDay = firstDay.addingTimeInterval(2 * 3600)
        let empty = try JSONDecoder().decode(CoreReviewProgress.self, from: Data("{}".utf8))
        XCTAssertFalse(empty.isEligible)
        var progress = CoreReviewProgress.recording(empty, at: firstDay, calendar: calendar)
        var twoDays = progress
        twoDays.record(at: nextDay, calendar: calendar)
        XCTAssertFalse(twoDays.isEligible)
        progress.record(at: firstDay, calendar: calendar)
        XCTAssertFalse(progress.isEligible)

        var sameDay = progress
        sameDay.record(at: firstDay, calendar: calendar)
        XCTAssertFalse(sameDay.isEligible)

        let data = try JSONEncoder().encode(progress)
        progress = try JSONDecoder().decode(CoreReviewProgress.self, from: data)
        progress.record(at: nextDay, calendar: calendar)
        XCTAssertTrue(progress.isEligible)
    }

    func testReviewOnlyOnceAfterAllThreeAndShare() {
        var gate = ReviewGate()
        gate.arm(allThree: false, shared: true)
        XCTAssertFalse(gate.consumeOnLaunch())
        gate.arm(allThree: true, shared: true)
        XCTAssertTrue(gate.consumeOnLaunch())
        gate.arm(allThree: true, shared: true)
        XCTAssertFalse(gate.consumeOnLaunch())
    }

    func testShareCodeRoundTripDropsPhotos() throws {
        let home = sampleHome()
        let code = ShareCode.make(home)
        XCTAssertTrue(code.hasPrefix(ShareCode.prefix))
        let payload = try XCTUnwrap(ShareCode.decode("Our home card:\n\(code)\nsaved!"))
        XCTAssertEqual(payload.spots.count, 2)
        XCTAssertEqual(payload.spots.first?.location, "Under the stairs")
        XCTAssertTrue(payload.spots.allSatisfy { $0.photos.isEmpty })
        XCTAssertNil(payload.panel.photo)
        XCTAssertEqual(payload.panel.circuits[1].label, "Fridge")
        XCTAssertNotEqual(payload.spots.first?.id, home.spots.first?.id)
    }

    func testShareCodeRejectsGarbage() {
        XCTAssertNil(ShareCode.decode("hello"))
        XCTAssertNil(ShareCode.decode("SHUT1:"))
        XCTAssertNil(ShareCode.decode("SHUT1:!!!notbase64"))
        var many = HomeData()
        many.spots = (0..<41).map { _ in var s = Spot(kind: .other); s.location = "x"; return s }
        XCTAssertNil(ShareCode.decode(ShareCode.make(many)))
    }

    func testHomeCardRoundTripRenamesPhotos() throws {
        let home = sampleHome()
        let data = try HomeCardFile.encode(home: home) { _ in self.jpeg }
        let contents = try HomeCardFile.decode(data)
        XCTAssertEqual(contents.photoCount, 3)
        let water = try XCTUnwrap(contents.payload.spots.first { $0.kind == .water })
        XCTAssertEqual(water.photos.count, 2)
        XCTAssertFalse(water.photos.contains("a.jpg"))
        XCTAssertTrue(water.photos.allSatisfy { contents.photos[$0] == jpeg })
        XCTAssertNotNil(contents.payload.panel.photo)
        XCTAssertNotEqual(contents.payload.panel.photo, "p.jpg")
    }

    func testHomeCardMissingPhotoIsSkipped() throws {
        let data = try HomeCardFile.encode(home: sampleHome()) { $0 == "a.jpg" ? self.jpeg : nil }
        let contents = try HomeCardFile.decode(data)
        XCTAssertEqual(contents.payload.spots.first { $0.kind == .water }?.photos.count, 1)
        XCTAssertNil(contents.payload.panel.photo)
    }

    func testHomeCardValidation() throws {
        XCTAssertThrowsError(try HomeCardFile.decode(Data("nope".utf8))) {
            XCTAssertEqual($0 as? HomeCardFile.Failure, .badFormat)
        }
        let png = try HomeCardFile.encode(home: sampleHome()) { _ in Data([0x89, 0x50, 0x4E, 0x47, 0x0D]) }
        XCTAssertThrowsError(try HomeCardFile.decode(png)) {
            XCTAssertEqual($0 as? HomeCardFile.Failure, .badFormat)
        }
        let newer = try JSONEncoder().encode(HomeCardFile.Document(version: 99, spots: [], panel: Panel(), photos: [:]))
        XCTAssertThrowsError(try HomeCardFile.decode(newer)) {
            XCTAssertEqual($0 as? HomeCardFile.Failure, .newerVersion)
        }
        XCTAssertThrowsError(try HomeCardFile.decode(Data(count: HomeCardFile.maxBytes + 1))) {
            XCTAssertEqual($0 as? HomeCardFile.Failure, .tooLarge)
        }
        let badColumns = try JSONEncoder().encode(HomeCardFile.Document(version: 1, spots: [],
                                                                        panel: { var p = Panel(); p.columns = 9; return p }(), photos: [:]))
        XCTAssertThrowsError(try HomeCardFile.decode(badColumns))
    }

    func testTemplatesAreLocalized() {
        for template in CircuitTemplate.all {
            XCTAssertNotEqual(L.t(template.key), template.key, template.key)
            XCTAssertNotEqual(L.t(template.group), template.group, template.group)
        }
        for kind in SpotKind.allCases {
            XCTAssertNotEqual(L.t(kind.titleKey), kind.titleKey)
            for key in kind.locationTemplates { XCTAssertNotEqual(L.t(key), key, key) }
        }
        for method in ShutoffMethod.allCases {
            XCTAssertNotEqual(L.t(method.key), method.key)
            XCTAssertNotEqual(L.t(method.key + ".short"), method.key + ".short")
        }
    }
}
