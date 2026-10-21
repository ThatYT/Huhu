import AppKit
import QuartzCore
import ServiceManagement

let cellSize = NSSize(width: 192, height: 208)
let frameCounts = [6, 8, 8, 4, 5, 8, 6, 6, 6, 8, 8]
let durations: [[Double]] = [
    [0.28, 0.11, 0.11, 0.14, 0.14, 0.32],
    Array(repeating: 0.12, count: 7) + [0.22],
    Array(repeating: 0.12, count: 7) + [0.22],
    [0.14, 0.14, 0.14, 0.28],
    [0.14, 0.14, 0.14, 0.14, 0.28],
    Array(repeating: 0.14, count: 7) + [0.24],
    Array(repeating: 0.15, count: 5) + [0.26],
    Array(repeating: 0.12, count: 5) + [0.22],
    Array(repeating: 0.15, count: 5) + [0.28]
]

func lookDirection(dx: Double, dy: Double) -> Int {
    let radians = atan2(dx, dy)
    let turn = (radians + 2 * .pi).truncatingRemainder(dividingBy: 2 * .pi)
    return Int((turn / (.pi / 8)).rounded()) % 16
}

// Uses the same entry/cooldown policy as Windows, driven by monotonic seconds.
struct Behavior {
    var inside = false
    var nextGreeting = 0.0, nextThink = 0.0
    mutating func update(now: Double, over: Bool, enabled: Bool, busy: Bool,
                         delay: Double, jump: Bool) -> Int? {
        let entered = over && !inside
        inside = over
        if nextThink == 0 || !enabled || busy || over { nextThink = now + delay }
        guard enabled && !busy else { return nil }
        if entered && now >= nextGreeting {
            nextGreeting = now + 8; nextThink = now + delay
            return jump ? 4 : 3
        }
        if !over && now >= nextThink { nextThink = now + delay; return 7 }
        return nil
    }
}

final class Artwork {
    let sheet: CGImage
    let cells: [[NSImage]]
    let restingMask: NSBitmapImageRep
    init(url: URL) throws {
        guard let image = NSImage(contentsOf: url),
              let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              cg.width == 1536, cg.height == 2288 else {
            throw NSError(domain: "Huhu", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Huhu’s artwork is missing or damaged."])
        }
        restingMask = NSBitmapImageRep(cgImage: cg.cropping(to: CGRect(x: 0, y: 0, width: 192, height: 208))!)
        sheet = cg
        cells = frameCounts.enumerated().map { row, count in
            (0..<count).map { column in
                let tile = cg.cropping(to: CGRect(x: column * 192, y: row * 208, width: 192, height: 208))!
                return NSImage(cgImage: tile, size: cellSize)
            }
        }
    }
}

final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class PetView: NSView {
    weak var companion: Companion?
    var sprite: NSImage? { didSet { needsDisplay = true } }
    var pressPoint = NSPoint.zero
    var originalOrigin = NSPoint.zero
    var hasDragged = false
    override var acceptsFirstResponder: Bool { false }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill(using: .copy)
        sprite?.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1,
                     respectFlipped: false, hints: [.interpolation: NSImageInterpolation.high])
    }
    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        pressPoint = NSEvent.mouseLocation
        originalOrigin = window.frame.origin
        hasDragged = false
    }
    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        let dx = mouse.x - pressPoint.x, dy = mouse.y - pressPoint.y
        guard hasDragged || hypot(dx, dy) > 3 else { return }
        hasDragged = true
        companion?.dragging = true
        companion?.dragRow = event.deltaX < 0 ? 2 : 1
        window.setFrameOrigin(NSPoint(x: originalOrigin.x + dx, y: originalOrigin.y + dy))
    }
    override func mouseUp(with event: NSEvent) {
        guard let companion else { return }
        companion.dragging = false
        if hasDragged {
            companion.keepOnScreen()
            companion.savePosition()
        } else {
            companion.play(row: event.clickCount >= 2 ? 4 : 3)
        }
    }
    override func rightMouseDown(with event: NSEvent) {
        guard let menu = companion?.makeMenu() else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
}

final class Companion: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let artwork: Artwork
    let settings = UserDefaults.standard
    var panel: PetPanel!
    var petView: PetView!
    var status: NSStatusItem!
    var timer: Timer?
    var displayObserver: NSObjectProtocol?
    var started = CACurrentMediaTime()
    var actionStarted = CACurrentMediaTime()
    var actionRow: Int?
    var dragging = false
    var dragRow = 1
    var lastCell = (-1, -1)
    var followsPointer: Bool
    var paused = false
    var menuOpen = false
    var behavior = Behavior()
    var scale: Double

    init(artwork: Artwork) {
        self.artwork = artwork
        followsPointer = settings.object(forKey: "followPointer") as? Bool ?? true
        let saved = settings.double(forKey: "scale")
        scale = [0.85, 1.2, 1.6].contains(saved) ? saved : 1.2
        super.init()
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        panel = PetPanel(contentRect: NSRect(origin: .zero,
                         size: NSSize(width: 192 * scale, height: 208 * scale)),
                         styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "Huhu · 呼呼"
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        petView = PetView(frame: NSRect(origin: .zero, size: panel.frame.size))
        petView.companion = self
        petView.autoresizingMask = [.width, .height]
        petView.toolTip = "Huhu · 呼呼\nDrag to move · Click to wave · Double-click to jump · Right-click for options"
        petView.setAccessibilityElement(true)
        petView.setAccessibilityLabel("Huhu the plush white tiger. Drag to move, click to wave, or right-click for options.")
        panel.contentView = petView
        if settings.object(forKey: "positionX") != nil {
            panel.setFrameOrigin(NSPoint(x: settings.double(forKey: "positionX"), y: settings.double(forKey: "positionY")))
            keepOnScreen()
        } else { resetPosition() }
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = status.button {
            button.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Huhu")
            button.toolTip = "Huhu · 呼呼"
        }
        refreshMenu()
        panel.orderFrontRegardless()
        tick()
        let clock = Timer(timeInterval: 1 / 30, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(clock, forMode: .common)
        timer = clock
        displayObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in self?.keepOnScreen() }
    }
    func applicationWillTerminate(_ notification: Notification) {
        savePosition()
        timer?.invalidate()
        if let observer = displayObserver { NotificationCenter.default.removeObserver(observer) }
    }
    func play(row: Int) {
        paused = false
        actionRow = row
        actionStarted = CACurrentMediaTime()
        refreshMenu()
        tick()
    }
    func pointerOverBody() -> Bool {
        let mouse = NSEvent.mouseLocation
        let x = Int((mouse.x - panel.frame.minX) / panel.frame.width * 192)
        let y = Int((panel.frame.maxY - mouse.y) / panel.frame.height * 208)
        guard panel.frame.contains(mouse), x >= 0, y >= 0, x < 192, y < 208 else { return false }
        return (artwork.restingMask.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 32.0 / 255
    }
    func tick() {
        guard panel != nil else { return }
        let now = CACurrentMediaTime()
        let busy = dragging || (NSEvent.pressedMouseButtons & 1 != 0) ||
            (actionRow.map { now - actionStarted < durations[$0].reduce(0, +) } ?? false)
        if let automatic = behavior.update(now: now, over: pointerOverBody(),
            enabled: panel.isVisible && !paused && !menuOpen && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
            busy: busy, delay: Double.random(in: 20...45), jump: Bool.random()) {
            actionRow = automatic; actionStarted = now
        }
        guard panel.isVisible, !paused else { return }
        var row = 0, column = 0
        if dragging {
            row = dragRow
            column = frame(at: now - started, row: row)
        } else if let action = actionRow {
            let elapsed = now - actionStarted
            if elapsed < durations[action].reduce(0, +) {
                row = action
                column = frame(at: elapsed, row: row)
            } else { actionRow = nil }
        }
        if row == 0 {
            column = frame(at: now - started, row: 0)
            if followsPointer && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                let mouse = NSEvent.mouseLocation
                let center = NSPoint(x: panel.frame.midX, y: panel.frame.minY + panel.frame.height * 0.62)
                let dx = mouse.x - center.x, dy = mouse.y - center.y
                if hypot(dx, dy) > 65 * scale && hypot(dx, dy) < 650 * scale {
                    let direction = lookDirection(dx: dx, dy: dy)
                    row = 9 + direction / 8
                    column = direction % 8
                }
            }
        }
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { row = 0; column = 0 }
        if lastCell.0 != row || lastCell.1 != column {
            petView.sprite = artwork.cells[row][column]
            lastCell = (row, column)
        }
    }
    func frame(at elapsed: Double, row: Int) -> Int {
        var phase = elapsed.truncatingRemainder(dividingBy: durations[row].reduce(0, +))
        for (index, duration) in durations[row].enumerated() {
            if phase < duration { return index }
            phase -= duration
        }
        return 0
    }
    func keepOnScreen() {
        guard let screen = NSScreen.screens.max(by: {
            let a = $0.visibleFrame.intersection(panel.frame)
            let b = $1.visibleFrame.intersection(panel.frame)
            return (a.isNull ? 0 : a.width * a.height) < (b.isNull ? 0 : b.width * b.height)
        }) else { return }
        let area = screen.visibleFrame
        let x = min(max(panel.frame.minX, area.minX), max(area.minX, area.maxX - panel.frame.width))
        let y = min(max(panel.frame.minY, area.minY), max(area.minY, area.maxY - panel.frame.height))
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
    func savePosition() {
        guard panel != nil else { return }
        settings.set(panel.frame.minX, forKey: "positionX")
        settings.set(panel.frame.minY, forKey: "positionY")
    }
    @objc func resetPosition() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - panel.frame.width - 40,
                                     y: screen.visibleFrame.minY + 20))
        savePosition()
    }
    func item(_ title: String, action: Selector, tag: Int = 0) -> NSMenuItem {
        let result = NSMenuItem(title: title, action: action, keyEquivalent: "")
        result.target = self; result.tag = tag
        return result
    }
    func menuWillOpen(_ menu: NSMenu) { menuOpen = true }
    func menuDidClose(_ menu: NSMenu) { menuOpen = false }
    func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        let title = NSMenuItem(title: "Huhu · 呼呼", action: nil, keyEquivalent: "")
        title.isEnabled = false; menu.addItem(title)
        menu.addItem(item(panel.isVisible ? "Hide Huhu" : "Show Huhu", action: #selector(toggleVisible)))
        menu.addItem(.separator())
        menu.addItem(item("Wave", action: #selector(performAnimation(_:)), tag: 3))
        menu.addItem(item("Jump", action: #selector(performAnimation(_:)), tag: 4))
        let animations = NSMenu()
        for (title, row) in [("Think", 7), ("Check something", 8), ("Ask nicely", 6), ("Feeling shy", 5), ("Run right", 1), ("Run left", 2)] {
            animations.addItem(item(title, action: #selector(performAnimation(_:)), tag: row))
        }
        let more = NSMenuItem(title: "More animations", action: nil, keyEquivalent: "")
        more.submenu = animations; menu.addItem(more)
        menu.addItem(.separator())
        let follow = item("Follow pointer", action: #selector(toggleFollow))
        follow.state = followsPointer ? .on : .off; menu.addItem(follow)
        menu.addItem(item(paused ? "Resume animation" : "Pause animation", action: #selector(togglePause)))
        let sizeMenu = NSMenu()
        for (name, tag, value) in [("Small", 85, 0.85), ("Medium", 120, 1.2), ("Large", 160, 1.6)] {
            let size = item(name, action: #selector(changeSize(_:)), tag: tag)
            size.state = scale == value ? .on : .off; sizeMenu.addItem(size)
        }
        let size = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
        size.submenu = sizeMenu; menu.addItem(size)
        menu.addItem(item("Reset position", action: #selector(resetPosition)))
        menu.addItem(.separator())
        menu.addItem(item("Run at startup", action: #selector(toggleStartup), tag: 900))
        menu.addItem(item("Approve in Login Items…", action: #selector(openLoginItems), tag: 901))
        updateStartupMenu(menu)
        menu.addItem(.separator())
        menu.addItem(item("How to play", action: #selector(showHelp)))
        menu.addItem(item("Quit Huhu", action: #selector(quit)))
        return menu
    }
    func refreshMenu() { if status != nil { status.menu = makeMenu() } }
    func menuNeedsUpdate(_ menu: NSMenu) { updateStartupMenu(menu) }
    func updateStartupMenu(_ menu: NSMenu) {
        let state = SMAppService.mainApp.status
        menu.item(withTag: 900)?.state = state == .enabled ? .on : state == .requiresApproval ? .mixed : .off
        menu.item(withTag: 901)?.isHidden = state != .requiresApproval
    }
    @objc func toggleStartup() {
        do {
            switch SMAppService.mainApp.status {
            case .enabled, .requiresApproval:
                try SMAppService.mainApp.unregister()
            default:
                try SMAppService.mainApp.register()
                if SMAppService.mainApp.status == .requiresApproval {
                    let alert = NSAlert()
                    alert.messageText = "Allow Huhu to open at login"
                    alert.informativeText = "macOS needs your approval in System Settings → General → Login Items."
                    alert.addButton(withTitle: "Open Login Items")
                    alert.addButton(withTitle: "Later")
                    NSApp.activate(ignoringOtherApps: true)
                    if alert.runModal() == .alertFirstButtonReturn { openLoginItems() }
                }
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn’t change Run at startup"
            alert.informativeText = "\(error.localizedDescription)\n\nIf you’re running Huhu from a disk image, install it in Applications first."
            alert.addButton(withTitle: "OK")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
        refreshMenu()
    }
    @objc func openLoginItems() { SMAppService.openSystemSettingsLoginItems() }
    @objc func toggleVisible() {
        if panel.isVisible { panel.orderOut(nil) } else { panel.orderFrontRegardless() }
        refreshMenu()
    }
    @objc func performAnimation(_ sender: NSMenuItem) {
        panel.orderFrontRegardless(); play(row: sender.tag)
    }
    @objc func toggleFollow() {
        followsPointer.toggle(); settings.set(followsPointer, forKey: "followPointer"); refreshMenu()
    }
    @objc func togglePause() {
        paused.toggle(); if !paused { started = CACurrentMediaTime(); actionRow = nil }; refreshMenu()
    }
    @objc func changeSize(_ sender: NSMenuItem) {
        scale = Double(sender.tag) / 100
        let bottomCenter = NSPoint(x: panel.frame.midX, y: panel.frame.minY)
        panel.setFrame(NSRect(x: bottomCenter.x - 96 * scale, y: bottomCenter.y,
                              width: 192 * scale, height: 208 * scale), display: true)
        settings.set(scale, forKey: "scale"); keepOnScreen(); savePosition(); refreshMenu()
    }
    @objc func showHelp() {
        let alert = NSAlert()
        alert.messageText = "Hello, I’m Huhu · 呼呼"
        alert.informativeText = "Drag me to move. Click to wave, or double-click to jump.\n\nHover over me to wave or jump. I occasionally think while idle and look toward nearby pointers. Right-click me or use the paw in your menu bar for animations, size, pause, and quit.\n\nI run entirely on your Mac. No ChatGPT, login, internet, or API key needed."
        alert.addButton(withTitle: "Let’s play")
        NSApp.activate(ignoringOtherApps: true); alert.runModal()
    }
    @objc func quit() { NSApp.terminate(nil) }
}

func selfTest(_ art: Artwork) throws {
    var failures: [String] = []
    for (row, count) in frameCounts.enumerated() {
        for col in 0..<8 {
            let tile = art.sheet.cropping(to: CGRect(x: col * 192, y: row * 208, width: 192, height: 208))!
            var bytes = [UInt8](repeating: 0, count: 192 * 208 * 4)
            let context = CGContext(data: &bytes, width: 192, height: 208, bitsPerComponent: 8,
                                    bytesPerRow: 192 * 4, space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(tile, in: CGRect(x: 0, y: 0, width: 192, height: 208))
            let occupied = stride(from: 3, to: bytes.count, by: 4).filter { bytes[$0] > 16 }.count
            if (col < count && occupied < 400) || (col >= count && occupied != 0) {
                failures.append("Unexpected artwork at row \(row), column \(col)")
            }
        }
    }
    for direction in 0..<16 {
        let angle = Double(direction) * .pi / 8
        if lookDirection(dx: sin(angle) * 100, dy: cos(angle) * 100) != direction {
            failures.append("Gaze mapping failed at \(direction)")
        }
    }
    var behavior = Behavior()
    if behavior.update(now: 100, over: false, enabled: true, busy: false, delay: 20, jump: false) != nil { failures.append("Initial idle") }
    if behavior.update(now: 119, over: false, enabled: true, busy: false, delay: 20, jump: false) != nil { failures.append("No early thought") }
    if behavior.update(now: 120, over: false, enabled: true, busy: false, delay: 20, jump: false) != 7 { failures.append("Idle thought") }
    if behavior.update(now: 121, over: false, enabled: true, busy: true, delay: 20, jump: false) != nil { failures.append("Busy inhibits") }
    if behavior.update(now: 122, over: true, enabled: true, busy: false, delay: 20, jump: false) != 3 { failures.append("Hover waves") }
    if behavior.update(now: 140, over: true, enabled: true, busy: false, delay: 20, jump: true) != nil { failures.append("Stationary hover never repeats") }
    if behavior.update(now: 141, over: false, enabled: true, busy: false, delay: 20, jump: false) != nil { failures.append("Leave") }
    if behavior.update(now: 142, over: true, enabled: true, busy: false, delay: 20, jump: true) != 4 { failures.append("New entry jumps") }
    if behavior.update(now: 143, over: false, enabled: true, busy: false, delay: 20, jump: false) != nil { failures.append("Leave again") }
    if behavior.update(now: 144, over: true, enabled: true, busy: false, delay: 20, jump: true) != nil { failures.append("Cooldown inhibits") }
    if behavior.update(now: 145, over: false, enabled: false, busy: false, delay: 20, jump: false) != nil { failures.append("Hidden paused or reduced motion inhibits") }
    if behavior.update(now: 200, over: false, enabled: false, busy: false, delay: 20, jump: false) != nil { failures.append("Disabled time not idle") }
    if behavior.update(now: 201, over: false, enabled: true, busy: false, delay: 20, jump: false) != nil { failures.append("No catchup on resume") }
    if behavior.update(now: 220, over: false, enabled: true, busy: false, delay: 20, jump: false) != 7 { failures.append("Fresh idle after resume") }
    if behavior.update(now: 221, over: true, enabled: true, busy: true, delay: 20, jump: false) != nil { failures.append("Dragging does not greet") }
    if behavior.update(now: 222, over: true, enabled: true, busy: false, delay: 20, jump: false) != nil { failures.append("No delayed greeting after drag") }
    if behavior.update(now: 223, over: false, enabled: true, busy: true, delay: 20, jump: false) != nil { failures.append("Manual animation resets idle") }
    if behavior.update(now: 242, over: false, enabled: true, busy: false, delay: 20, jump: false) != nil { failures.append("No early thought after manual animation") }
    if behavior.update(now: 243, over: false, enabled: true, busy: false, delay: 20, jump: false) != 7 { failures.append("Think after fresh idle") }
    let report: [String: Any] = ["ok": failures.isEmpty, "frames": art.cells.reduce(0) { $0 + $1.count },
                                "gazeDirectionsChecked": 16, "behaviorScenariosChecked": 19, "errors": failures]
    let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
    print(String(data: data, encoding: .utf8)!)
    if !failures.isEmpty { exit(1) }
}

func startupSelfTest() throws {
    let service = SMAppService.mainApp
    let initial = service.status
    guard initial == .notRegistered || initial == .notFound else {
        print("{\"ok\":true,\"skipped\":\"Existing login preference left unchanged\"}")
        return
    }
    var needsCleanup = true
    defer { if needsCleanup { try? service.unregister() } }
    try service.register()
    let registered = service.status
    guard registered == .enabled || registered == .requiresApproval else {
        throw NSError(domain: "HuhuStartupTest", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Registration did not reach enabled or approval-pending state."])
    }
    try service.unregister()
    guard service.status == .notRegistered || service.status == .notFound else {
        throw NSError(domain: "HuhuStartupTest", code: 2,
                      userInfo: [NSLocalizedDescriptionKey: "Startup registration was not removed."])
    }
    needsCleanup = false
    print("{\"ok\":true,\"registration\":\"passed\",\"unregistration\":\"passed\",\"preferenceRestored\":true}")
}

let app = NSApplication.shared
do {
    let url = Bundle.main.url(forResource: "Huhu", withExtension: "png")
        ?? URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Huhu.png")
    let art = try Artwork(url: url)
    if CommandLine.arguments.contains("--startup-self-test") {
        try startupSelfTest()
    } else if CommandLine.arguments.contains("--self-test") {
        try selfTest(art)
    } else {
        let companion = Companion(artwork: art)
        app.delegate = companion
        withExtendedLifetime(companion) { app.run() }
    }
} catch {
    if CommandLine.arguments.contains("--self-test") || CommandLine.arguments.contains("--startup-self-test") {
        fputs("\(error.localizedDescription)\n", stderr); exit(1)
    }
    let alert = NSAlert(error: error); alert.runModal(); exit(1)
}
