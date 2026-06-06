import XCTest

/// Automated screenshot + GIF-frame capture for the README media assets.
///
/// Run once, then `make-gifs.sh` stitches the frames. Tests are numbered so they
/// execute in a deterministic order (each relaunches the app for a clean state).
@MainActor
final class DemoCapture: XCTestCase {

    private let app = XCUIApplication()

    // Output directory on the host machine — frames land here, ffmpeg runs after.
    nonisolated(unsafe) private static let imagesDir = URL(
        fileURLWithPath: "/Users/sothea007/Desktop/CambodianAddressSDK/docs/images"
    )

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(
            at: Self.imagesDir, withIntermediateDirectories: true
        )
    }

    // MARK: - 01 · Picker-in-Form screenshot

    func test01_PickerFormScreenshot() throws {
        app.launch()
        waitForPicker()
        sleep(1)
        savePNG(XCUIScreen.main.screenshot(), name: "picker-screenshot")
    }

    // MARK: - 02 · Standalone sheet GIF

    func test02_StandaloneSheetGIF() throws {
        app.launch()
        waitForPicker()
        sleep(1)

        var frames: [Data] = [screenshot()]

        let openBtn = app.buttons["Open standalone screen"]
        XCTAssertTrue(openBtn.waitForExistence(timeout: 5))
        openBtn.tap()

        // Capture sheet sliding up
        for _ in 0..<8 {
            Thread.sleep(forTimeInterval: 0.12)
            frames.append(screenshot())
        }
        sleep(2)                        // let picker load inside sheet
        frames.append(screenshot())
        frames.append(screenshot())
        frames.append(screenshot())     // hold final frame 3×

        saveFrames(frames, name: "standalone-demo")
    }

    // MARK: - 03 · UIKit screenshot

    func test03_UIKitScreenshot() throws {
        app.launch()
        app.tabBars.buttons["UIKit"].tap()
        sleep(1)
        savePNG(XCUIScreen.main.screenshot(), name: "uikit-screenshot")
    }

    // MARK: - 04 · Search "krang leav" GIF

    func test04_SearchGIF() throws {
        app.launch()
        app.tabBars.buttons["Search"].tap()
        sleep(1)

        var frames: [Data] = [screenshot()]  // empty state

        // Reveal + activate the search bar
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        Thread.sleep(forTimeInterval: 0.3)
        frames.append(screenshot())

        // Type "krang leav" — capture a frame after each character
        for char in "krang leav" {
            searchField.typeText(String(char))
            Thread.sleep(forTimeInterval: 0.22)
            frames.append(screenshot())
        }

        // Hold on the final results
        Thread.sleep(forTimeInterval: 0.4)
        frames.append(screenshot())
        frames.append(screenshot())
        frames.append(screenshot())     // 3× hold

        saveFrames(frames, name: "search-demo")
    }

    // MARK: - 05 · Hero: full picker flow GIF

    func test05_HeroPickerGIF() throws {
        app.launch()
        waitForPicker()
        sleep(1)

        var frames: [Data] = [screenshot()]  // initial empty state

        // -- Province --
        tapLevel("Province")
        captureSlide(&frames, count: 6, interval: 0.12)  // sheet opening
        sleep(1)
        frames.append(screenshot())

        // Type "Phnom" in level search to quickly reach Phnom Penh
        let levelSearch = app.searchFields.firstMatch
        if levelSearch.waitForExistence(timeout: 3) {
            levelSearch.tap()
            levelSearch.typeText("Phnom")
            Thread.sleep(forTimeInterval: 0.5)
            frames.append(screenshot())
        }
        selectCell("Phnom Penh", frames: &frames)

        // Back on main — District row now enabled
        Thread.sleep(forTimeInterval: 0.5)
        frames.append(screenshot())

        // -- District --
        tapLevel("District")
        captureSlide(&frames, count: 6, interval: 0.12)
        sleep(1)
        frames.append(screenshot())
        selectCell("Doun Penh", frames: &frames)

        Thread.sleep(forTimeInterval: 0.5)
        frames.append(screenshot())

        // -- Commune --
        tapLevel("Commune")
        captureSlide(&frames, count: 6, interval: 0.12)
        sleep(1)
        frames.append(screenshot())
        // Pick first commune in list (Voat Phnum for Doun Penh)
        let firstCommune = app.cells.firstMatch
        if firstCommune.waitForExistence(timeout: 5) {
            firstCommune.tap()
        }
        Thread.sleep(forTimeInterval: 0.5)
        frames.append(screenshot())

        // -- Village --
        tapLevel("Village")
        captureSlide(&frames, count: 6, interval: 0.12)
        sleep(1)
        frames.append(screenshot())
        let firstVillage = app.cells.firstMatch
        if firstVillage.waitForExistence(timeout: 5) {
            firstVillage.tap()
        }
        Thread.sleep(forTimeInterval: 0.5)
        frames.append(screenshot())

        // Final complete address
        sleep(1)
        frames.append(screenshot())
        frames.append(screenshot())
        frames.append(screenshot())     // hold 3×

        saveFrames(frames, name: "picker-demo")
    }

    // MARK: - 06 · GPS & Map tab screenshot (GPS lookup result)

    func test06_GeoMapScreenshot() throws {
        app.launch()
        let mapTab = app.tabBars.buttons["Map"]
        XCTAssertTrue(mapTab.waitForExistence(timeout: 10))
        mapTab.tap()
        sleep(1)

        // Trigger the GPS lookup button (resolves Phnom Penh coordinate offline)
        let gpsBtn = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Phnom Penh")
        ).firstMatch
        if gpsBtn.waitForExistence(timeout: 5) {
            gpsBtn.tap()
            sleep(3)    // wait for async commune lookup
        }

        savePNG(XCUIScreen.main.screenshot(), name: "geo-map-screenshot")
    }

    // MARK: - 07 · Map picker sheet screenshot

    func test07_MapPickerSheetScreenshot() throws {
        app.launch()
        let mapTab = app.tabBars.buttons["Map"]
        XCTAssertTrue(mapTab.waitForExistence(timeout: 10))
        mapTab.tap()
        sleep(1)

        let openBtn = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Open map picker")
        ).firstMatch
        XCTAssertTrue(openBtn.waitForExistence(timeout: 5))
        openBtn.tap()
        sleep(2)    // wait for map to render

        savePNG(XCUIScreen.main.screenshot(), name: "map-picker-screenshot")
    }

    // MARK: - 08 · Validation tab GIF (pick → issues → resolve)

    func test08_ValidationGIF() throws {
        app.launch()
        let validateTab = app.tabBars.buttons["Validate"]
        XCTAssertTrue(validateTab.waitForExistence(timeout: 10))
        validateTab.tap()
        sleep(1)

        var frames: [Data] = [screenshot()]    // initial empty state

        // Pick a province
        tapLevel("Province")
        captureSlide(&frames, count: 6, interval: 0.12)
        sleep(1)
        frames.append(screenshot())

        let levelSearch = app.searchFields.firstMatch
        if levelSearch.waitForExistence(timeout: 3) {
            levelSearch.tap()
            levelSearch.typeText("Phnom")
            Thread.sleep(forTimeInterval: 0.5)
            frames.append(screenshot())
        }
        selectCell("Phnom Penh", frames: &frames)

        // Back — validation should show missingDistrict
        Thread.sleep(forTimeInterval: 0.5)
        frames.append(screenshot())
        frames.append(screenshot())

        // Pick district
        tapLevel("District")
        captureSlide(&frames, count: 6, interval: 0.12)
        sleep(1)
        frames.append(screenshot())
        selectCell("Doun Penh", frames: &frames)

        Thread.sleep(forTimeInterval: 0.5)
        frames.append(screenshot())    // missingCommune shown

        // Pick commune
        tapLevel("Commune")
        captureSlide(&frames, count: 6, interval: 0.12)
        sleep(1)
        frames.append(screenshot())
        let firstCommune = app.cells.firstMatch
        if firstCommune.waitForExistence(timeout: 5) { firstCommune.tap() }
        Thread.sleep(forTimeInterval: 0.5)
        frames.append(screenshot())    // missingVillage shown (postal code appears)

        // Pick village
        tapLevel("Village")
        captureSlide(&frames, count: 6, interval: 0.12)
        sleep(1)
        frames.append(screenshot())
        let firstVillage = app.cells.firstMatch
        if firstVillage.waitForExistence(timeout: 5) { firstVillage.tap() }
        Thread.sleep(forTimeInterval: 0.5)
        frames.append(screenshot())    // ✅ Valid
        frames.append(screenshot())
        frames.append(screenshot())    // hold 3×

        saveFrames(frames, name: "validation-demo")
    }

    // MARK: - Helpers

    private func waitForPicker() {
        // Province label appears once the async data load completes.
        let province = app.staticTexts["Province"]
        XCTAssertTrue(province.waitForExistence(timeout: 15))
    }

    /// Tap a level row button by matching its label (contains Province/District/Commune/Village).
    private func tapLevel(_ name: String) {
        let btn = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", name)
        ).firstMatch
        XCTAssertTrue(btn.waitForExistence(timeout: 5))
        btn.tap()
    }

    /// Select a named cell in the current sheet and append a frame.
    private func selectCell(_ name: String, frames: inout [Data]) {
        // Try static text first (most reliable in SwiftUI List)
        let cell = app.staticTexts[name].firstMatch
        if cell.waitForExistence(timeout: 5) {
            cell.tap()
            Thread.sleep(forTimeInterval: 0.3)
            frames.append(screenshot())
        } else {
            // Fallback: first visible cell
            let first = app.cells.firstMatch
            if first.waitForExistence(timeout: 5) { first.tap() }
            Thread.sleep(forTimeInterval: 0.3)
            frames.append(screenshot())
        }
    }

    /// Capture `count` frames spaced by `interval` seconds (good for sheet-slide animation).
    private func captureSlide(_ frames: inout [Data], count: Int, interval: TimeInterval) {
        for _ in 0..<count {
            Thread.sleep(forTimeInterval: interval)
            frames.append(screenshot())
        }
    }

    private func screenshot() -> Data {
        XCUIScreen.main.screenshot().pngRepresentation
    }

    private func savePNG(_ shot: XCUIScreenshot, name: String) {
        let url = Self.imagesDir.appendingPathComponent("\(name).png")
        try? shot.pngRepresentation.write(to: url)
    }

    /// Write numbered PNG frames that ffmpeg will stitch into a GIF.
    private func saveFrames(_ frames: [Data], name: String) {
        let dir = Self.imagesDir.appendingPathComponent("\(name)-frames")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (i, png) in frames.enumerated() {
            let url = dir.appendingPathComponent(String(format: "frame-%03d.png", i))
            try? png.write(to: url)
        }
    }
}
