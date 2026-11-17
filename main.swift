// MouseButtons — mouse side-button clicks and hold-and-move gestures for macOS.
// Built and installed by install.sh. Needs Accessibility permission.
// Settings live in ~/.local/share/mouse-buttons/config.json (no rebuild needed to change them;
// run reload.sh afterwards).
import Cocoa
import ApplicationServices

let baseDir = NSString(string: "~/.local/share/mouse-buttons").expandingTildeInPath

// ---------- Actions ----------

func run(_ path: String, _ args: [String]) -> Bool {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: path)
    p.arguments = args
    do { try p.run(); p.waitUntilExit(); return p.terminationStatus == 0 } catch { return false }
}

func openFirstExisting(_ paths: [String], fallbackBundleIDs: [String] = []) {
    for path in paths where FileManager.default.fileExists(atPath: path) {
        if run("/usr/bin/open", ["-a", path]) { return }
    }
    for id in fallbackBundleIDs where run("/usr/bin/open", ["-b", id]) { return }
    NSLog("MouseButtons: could not open any of %@", paths.joined(separator: ", "))
}

let missionControlApp = "/System/Applications/Mission Control.app"

// Mission Control's own binary accepts 1 = show desktop, 2 = app windows (App Exposé).
func missionControlMode(_ arg: String?) {
    let bin = missionControlApp + "/Contents/MacOS/Mission Control"
    if let a = arg, FileManager.default.fileExists(atPath: bin) {
        _ = run(bin, [a])
    } else {
        openFirstExisting([missionControlApp, "/Applications/Mission Control.app"],
                          fallbackBundleIDs: ["com.apple.exposelauncher"])
    }
}

func pressKey(_ keyCode: CGKeyCode, flags: CGEventFlags) {
    let src = CGEventSource(stateID: .hidSystemState)
    for down in [true, false] {
        if let e = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: down) {
            e.flags = flags
            e.post(tap: .cghidEventTap)
        }
    }
}

// Arrow keys carry the fn + numeric-pad flags on real keyboards; macOS expects them for ⌃← / ⌃→.
let arrowFlags: CGEventFlags = [.maskControl, .maskSecondaryFn, .maskNumericPad]

func perform(_ action: String) {
    switch action {
    case "missionControl": missionControlMode(nil)
    case "appExpose":      missionControlMode("2")
    case "showDesktop":    missionControlMode("1")
    case "launchpad":
        // macOS 15 and earlier: Launchpad. macOS 26: the "Apps" launcher replaced it.
        openFirstExisting(["/System/Applications/Launchpad.app", "/Applications/Launchpad.app",
                           "/System/Applications/Apps.app"],
                          fallbackBundleIDs: ["com.apple.launchpad.launcher", "com.apple.apps.launcher"])
    case "desktopLeft":    pressKey(123, flags: arrowFlags)   // ⌃←
    case "desktopRight":   pressKey(124, flags: arrowFlags)   // ⌃→
    case "none", "":       break
    default:
        if action.hasPrefix("shell:") {
            _ = run("/bin/bash", ["-c", String(action.dropFirst("shell:".count))])
        } else {
            NSLog("MouseButtons: unknown action '%@'", action)
        }
    }
}

// ---------- Config ----------

// button number -> (click/up/down/left/right -> action)
var buttons: [Int64: [String: String]] = [
    3: ["click": "missionControl", "up": "missionControl", "down": "appExpose",
        "left": "desktopLeft", "right": "desktopRight"],
    4: ["click": "launchpad", "up": "missionControl", "down": "showDesktop",
        "left": "desktopLeft", "right": "desktopRight"],
]
var threshold: Double = 30   // pixels of movement before a hold counts as a gesture

if let data = FileManager.default.contents(atPath: baseDir + "/config.json"),
   let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
    if let t = json["threshold"] as? Double { threshold = t }
    if let b = json["buttons"] as? [String: [String: String]] {
        var parsed: [Int64: [String: String]] = [:]
        for (k, v) in b { if let n = Int64(k) { parsed[n] = v } }
        buttons = parsed
    }
    NSLog("MouseButtons: loaded config.json")
} else {
    NSLog("MouseButtons: config.json missing or invalid — using built-in defaults")
}

// ---------- Event tap ----------

var eventTap: CFMachPort?
var activeButton: Int64? = nil
var startLocation = CGPoint.zero
var dx: Double = 0, dy: Double = 0

let callback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
        return Unmanaged.passUnretained(event)
    }

    let button = event.getIntegerValueField(.mouseEventButtonNumber)

    switch type {
    case .otherMouseDown:
        guard buttons[button] != nil else { break }
        activeButton = button
        startLocation = event.location
        dx = 0; dy = 0
        return nil

    case .otherMouseDragged, .mouseMoved:
        // Depending on the mouse/driver, movement while a side button is held arrives as either type.
        guard activeButton != nil else { break }
        dx += Double(event.getIntegerValueField(.mouseEventDeltaX))
        dy += Double(event.getIntegerValueField(.mouseEventDeltaY))
        return Unmanaged.passUnretained(event)   // let the cursor move; it's put back on release

    case .otherMouseUp:
        guard let held = activeButton, held == button, let map = buttons[button] else { break }
        activeButton = nil
        // Also measure how far the cursor really moved; use whichever reading is larger.
        let lx = Double(event.location.x - startLocation.x), ly = Double(event.location.y - startLocation.y)
        if lx * lx + ly * ly > dx * dx + dy * dy { dx = lx; dy = ly }
        let kind: String
        if (dx * dx + dy * dy).squareRoot() < threshold {
            kind = "click"
        } else {
            kind = abs(dx) > abs(dy) ? (dx > 0 ? "right" : "left") : (dy > 0 ? "down" : "up")
            CGWarpMouseCursorPosition(startLocation)
            CGAssociateMouseAndMouseCursorPosition(1)
        }
        let action = map[kind] ?? "none"
        NSLog("MouseButtons: button %lld moved (%.0f, %.0f) -> %@ -> %@", button, dx, dy, kind, action)
        DispatchQueue.global(qos: .userInteractive).async { perform(action) }
        return nil

    default:
        break
    }
    return Unmanaged.passUnretained(event)
}

// ---------- Startup ----------

// A running process doesn't always notice when Accessibility is turned on, so if it's missing
// we exit and let launchd start a fresh copy ~10 s later. Prompt only once per install.
let markerPath = baseDir + "/.prompted"
let alreadyPrompted = FileManager.default.fileExists(atPath: markerPath)
let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
if !AXIsProcessTrustedWithOptions([promptKey: !alreadyPrompted] as CFDictionary) {
    FileManager.default.createFile(atPath: markerPath, contents: nil)
    NSLog("MouseButtons: no Accessibility permission yet (System Settings > Privacy & Security > Accessibility) — retrying shortly")
    sleep(5)
    exit(1)
}

let mask: CGEventMask = (1 << CGEventType.otherMouseDown.rawValue)
                      | (1 << CGEventType.otherMouseUp.rawValue)
                      | (1 << CGEventType.otherMouseDragged.rawValue)
                      | (1 << CGEventType.mouseMoved.rawValue)
guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                  place: .headInsertEventTap,
                                  options: .defaultTap,
                                  eventsOfInterest: mask,
                                  callback: callback,
                                  userInfo: nil) else {
    NSLog("MouseButtons: could not create event tap even though Accessibility looks granted — retrying shortly")
    sleep(5)
    exit(1)
}
eventTap = tap
let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)
NSLog("MouseButtons: running — buttons %@, threshold %.0f px",
      buttons.keys.sorted().map { String($0) }.joined(separator: ", "), threshold)
CFRunLoopRun()
