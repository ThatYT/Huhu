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

// Uses the same queued hover sequence as Windows, driven by monotonic seconds.
struct Behavior {
    var inside = false, thinkPending = false
    var jumpsPending = 0
    var nextGreeting = 0.0, nextThink = 0.0
    mutating func cancel() { jumpsPending = 0; thinkPending = false }
    mutating func update(now: Double, over: Bool, enabled: Bool, busy: Bool,
                         delay: Double, jumps: Int, interacting: Bool = false) -> Int? {
        let entered = over && !inside
        inside = over
        if nextThink == 0 || !enabled || busy || interacting || over { nextThink = now + delay }
        if !enabled || interacting || !over { cancel() }
        guard enabled && !busy && !interacting else { return nil }
        if entered && now >= nextGreeting {
            nextGreeting = now + 8; nextThink = now + delay
            jumpsPending = jumps == 3 ? 2 : 1; thinkPending = true
            return 4
        }
        if jumpsPending > 0 { jumpsPending -= 1; return 4 }
        if thinkPending { thinkPending = false; return 7 }
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
        companion?.behavior.cancel()
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
        behavior.cancel()
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
            busy: busy, delay: Double.random(in: 20...45), jumps: Int.random(in: 2...3),
            interacting: dragging || (NSEvent.pressedMouseButtons & 1 != 0)) {
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
    func menuWillOpen(_ menu: NSMenu) { behavior.cancel(); menuOpen = true }
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
        behavior.cancel()
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
        behavior.cancel()
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
        alert.informativeText = "Drag me to move. Click to wave, or double-click to jump.\n\nHover over me for two or three jumps followed by thinking. I occasionally think while idle and look toward nearby pointers. Right-click me or use the paw in your menu bar for animations, size, pause, and quit.\n\nI run entirely on your Mac. No ChatGPT, login, internet, or API key needed."
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
    do { var behavior = Behavior()
        if behavior.update(now: 100, over: true, enabled: true, busy: false, delay: 20, jumps: 2, interacting: false) != 4 { failures.append("Two jumps then think at 100") }
        if behavior.update(now: 100.2, over: true, enabled: true, busy: true, delay: 20, jumps: 3, interacting: false) != nil { failures.append("Two jumps then think at 100.2") }
        if behavior.update(now: 100.85, over: true, enabled: true, busy: false, delay: 20, jumps: 3, interacting: false) != 4 { failures.append("Two jumps then think at 100.85") }
        if behavior.update(now: 101.1, over: true, enabled: true, busy: true, delay: 20, jumps: 3, interacting: false) != nil { failures.append("Two jumps then think at 101.1") }
        if behavior.update(now: 101.7, over: true, enabled: true, busy: false, delay: 20, jumps: 3, interacting: false) != 7 { failures.append("Two jumps then think at 101.7") }
        if behavior.update(now: 130, over: true, enabled: true, busy: false, delay: 20, jumps: 3, interacting: false) != nil { failures.append("Two jumps then think at 130") }
        if behavior.update(now: 131, over: false, enabled: true, busy: false, delay: 20, jumps: 2, interacting: false) != nil { failures.append("Two jumps then think at 131") }
        if behavior.update(now: 132, over: true, enabled: true, busy: false, delay: 20, jumps: 2, interacting: false) != 4 { failures.append("Two jumps then think at 132") }
    }
    do { var behavior = Behavior()
        if behavior.update(now: 100, over: true, enabled: true, busy: false, delay: 20, jumps: 3, interacting: false) != 4 { failures.append("Three jumps then think at 100") }
        if behavior.update(now: 100.85, over: true, enabled: true, busy: false, delay: 20, jumps: 2, interacting: false) != 4 { failures.append("Three jumps then think at 100.85") }
        if behavior.update(now: 101.7, over: true, enabled: true, busy: false, delay: 20, jumps: 2, interacting: false) != 4 { failures.append("Three jumps then think at 101.7") }
        if behavior.update(now: 102.55, over: true, enabled: true, busy: false, delay: 20, jumps: 2, interacting: false) != 7 { failures.append("Three jumps then think at 102.55") }
        if behavior.update(now: 130, over: true, enabled: true, busy: false, delay: 20, jumps: 2, interacting: false) != nil { failures.append("Three jumps then think at 130") }
    }
    do { var behavior = Behavior()
        if behavior.update(now: 100, over: true, enabled: true, busy: false, delay: 20, jumps: 3, interacting: false) != 4 { failures.append("Leave cancels and cooldown holds at 100") }
        if behavior.update(now: 100.2, over: false, enabled: true, busy: true, delay: 20, jumps: 3, interacting: false) != nil { failures.append("Leave cancels and cooldown holds at 100.2") }
        if behavior.update(now: 101, over: false, enabled: true, busy: false, delay: 20, jumps: 3, interacting: false) != nil { failures.append("Leave cancels and cooldown holds at 101") }
        if behavior.update(now: 102, over: true, enabled: true, busy: false, delay: 20, jumps: 3, interacting: false) != nil { failures.append("Leave cancels and cooldown holds at 102") }
        if behavior.update(now: 103, over: true, enabled: true, busy: false, delay: 20, jumps: 3, interacting: false) != nil { failures.append("Leave cancels and cooldown holds at 103") }
    }
    do { var behavior = Behavior()
        if behavior.update(now: 100, over: true, enabled: true, busy: false, delay: 20, jumps: 3, interacting: false) != 4 { failures.append("Disable cancels at 100") }
        if behavior.update(now: 100.2, over: true, enabled: false, busy: true, delay: 20, jumps: 3, interacting: false) != nil { failures.append("Disable cancels at 100.2") }
        if behavior.update(now: 101, over: true, enabled: true, busy: false, delay: 20, jumps: 3, interacting: false) != nil { failures.append("Disable cancels at 101") }
    }
    do { var behavior = Behavior()
        if behavior.update(now: 100, over: true, enabled: true, busy: false, delay: 20, jumps: 3, interacting: false) != 4 { failures.append("Drag cancels at 100") }
        if behavior.update(now: 100.2, over: true, enabled: true, busy: true, delay: 20, jumps: 3, interacting: true) != nil { failures.append("Drag cancels at 100.2") }
        if behavior.update(now: 101, over: true, enabled: true, busy: false, delay: 20, jumps: 3, interacting: false) != nil { failures.append("Drag cancels at 101") }
    }
    do { var behavior = Behavior()
        if behavior.update(now: 100, over: false, enabled: true, busy: false, delay: 20, jumps: 2, interacting: false) != nil { failures.append("Idle and resume at 100") }
        if behavior.update(now: 119, over: false, enabled: true, busy: false, delay: 20, jumps: 2, interacting: false) != nil { failures.append("Idle and resume at 119") }
        if behavior.update(now: 120, over: false, enabled: true, busy: false, delay: 20, jumps: 2, interacting: false) != 7 { failures.append("Idle and resume at 120") }
        if behavior.update(now: 121, over: false, enabled: true, busy: true, delay: 20, jumps: 2, interacting: false) != nil { failures.append("Idle and resume at 121") }
        if behavior.update(now: 140, over: false, enabled: true, busy: false, delay: 20, jumps: 2, interacting: false) != nil { failures.append("Idle and resume at 140") }
        if behavior.update(now: 141, over: false, enabled: true, busy: false, delay: 20, jumps: 2, interacting: false) != 7 { failures.append("Idle and resume at 141") }
        if behavior.update(now: 142, over: false, enabled: false, busy: false, delay: 20, jumps: 2, interacting: false) != nil { failures.append("Idle and resume at 142") }
        if behavior.update(now: 200, over: false, enabled: false, busy: false, delay: 20, jumps: 2, interacting: false) != nil { failures.append("Idle and resume at 200") }
        if behavior.update(now: 201, over: false, enabled: true, busy: false, delay: 20, jumps: 2, interacting: false) != nil { failures.append("Idle and resume at 201") }
        if behavior.update(now: 220, over: false, enabled: true, busy: false, delay: 20, jumps: 2, interacting: false) != 7 { failures.append("Idle and resume at 220") }
    }
    do { var behavior = Behavior()
        if behavior.update(now: 100, over: true, enabled: true, busy: false, delay: 20, jumps: 3) != 4 { failures.append("Manual override setup") }
        behavior.cancel()
        if behavior.update(now: 101, over: true, enabled: true, busy: false, delay: 20, jumps: 3) != nil { failures.append("Manual override cancels queued moves") }
    }
    let report: [String: Any] = ["ok": failures.isEmpty, "frames": art.cells.reduce(0) { $0 + $1.count },
                                "gazeDirectionsChecked": 16, "behaviorScenariosChecked": 36, "errors": failures]
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
