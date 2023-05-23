/*
 *
 * AutoRaise Launcher
 *
 * Copyright (c) 2023 Stefan Post (sbmpost), Lothar Haeger
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import CoreServices
import Cocoa
import Foundation
import AppKit

class URLButton: NSButton {
    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    // Settings
    @IBOutlet weak var window: NSWindow!

    @IBOutlet weak var delaySliderLabel: NSTextField!
    @IBOutlet weak var focusDelaySliderLabel: NSTextField!
    @IBOutlet weak var delaySlider: NSSlider!
    @IBOutlet weak var focusDelaySlider: NSSlider!
    @IBOutlet weak var enableWarpButton: NSButton!
    @IBOutlet weak var enableCurserScalingButton: NSButton!
    @IBOutlet weak var enableAltTaskSwitcherButton: NSButton!
    @IBOutlet weak var enableOnLaunchButton: NSButton!
    @IBOutlet weak var shortcutView: MASShortcutView!
    @IBOutlet weak var ignoreAppsEdit: NSTextField!
    @IBOutlet weak var stayFocusedBundleIdsEdit: NSTextFieldCell!
    @IBOutlet weak var disableKeyBox: NSComboBox!
    @IBOutlet weak var ignoreSpaceChangedButton: NSButton!
    @IBOutlet weak var mouseDeltaEdit: NSTextField!
    @IBOutlet weak var pollMillisEdit: NSTextField!

    // About
    @IBOutlet weak var aboutText: NSTextField!
    @IBOutlet weak var homePage: URLButton!
    @IBOutlet weak var autoRaisePage: URLButton!
    
    let appVersionString: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    let buildNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String

    let appAbout =  "AutoRaise & Launcher\n" +
        "Version 3.8.2, 2023-05-23\n\n" +
        "©2023 Stefan Post, Lothar Haeger\n" +
        "Icons made by https://www.flaticon.com/authors/fr"

    let homePageUrl = "https://github.com/lhaeger/AutoRaise"
    let autoRaiseUrl = "https://github.com/sbmpost/AutoRaise"

    let prefs = UserDefaults.standard

    var statusBar = NSStatusBar.system
    var menuBarItem : NSStatusItem = NSStatusItem()
    var menu: NSMenu = NSMenu()
    var menuItemPrefs : NSMenuItem = NSMenuItem()
    var menuItemQuit : NSMenuItem = NSMenuItem()
    var autoRaiseService: Process = Process()

    var autoRaiseDelay : NSInteger = 0
    var autoFocusDelay : NSInteger = 0
    var mouseDelta : NSInteger = 0
    var pollMillis : NSInteger = 0
    var enableWarp = NSControl.StateValue.off
    var enableCursorScaling = NSControl.StateValue.off
    var enableAltTaskSwitcher = NSControl.StateValue.off
    var enableOnLaunch = NSControl.StateValue.off
    var ignoreSpaceChanged = NSControl.StateValue.off
    var ignoreApps: String = ""
    var stayFocusedBundleIds: String = ""
    var disableKey: String = "control"

    let icon = NSImage(named: "MenuIcon")
    let iconRunning = NSImage(named: "MenuIconRunning")

    override func awakeFromNib() {
        // Build status bar menu
        menuBarItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        menuBarItem.button?.title = ""

        if let button = menuBarItem.button {
            button.action = #selector(menuBarItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.image = icon
        }

        //"Preferences" menuItem
        menuItemPrefs.title = "Preferences"
        menuItemPrefs.action = #selector(Preferences(_:))
        menu.addItem(menuItemPrefs)
        
        // Separator
        menu.addItem(NSMenuItem.separator())
        
        // "Quit" menuItem
        menuItemQuit.title = "Quit"
        menuItemQuit.action = #selector(quitApplication(_:))
        menu.addItem(menuItemQuit)
    }

    func updateHotkey() { }

    func toggleService() {
        if autoRaiseService.isRunning {
            self.stopService(self)
        } else {
            self.startService(self)
        }
    }

    @objc func menuBarItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        if event.type == NSEvent.EventType.rightMouseUp {
            menuBarItem.menu = menu
            menuBarItem.button?.performClick(nil)
            menuBarItem.menu = nil
        } else {
            toggleService()
        }
    }

    @IBAction func enableOnLaunch(_ sender: NSButton) {
        enableOnLaunch = enableOnLaunchButton.state
        self.prefs.set(enableOnLaunch == NSControl.StateValue.on ? "1" : "0", forKey: "enableOnLaunch")
    }

    @IBAction func autoRaiseDelay(_ sender: Any) {
        autoRaiseDelay = delaySlider.integerValue
        if (autoRaiseDelay == 0) {
            delaySliderLabel.stringValue = "Window raise disabled"
        } else {
            delaySliderLabel.stringValue = "Delay window raise for " + String(
                pollMillis*(autoRaiseDelay/pollMillis - 1)) + " ms"
        }
        self.prefs.set(autoRaiseDelay, forKey: "autoRaiseDelay")
        if autoRaiseService.isRunning {
            self.stopService(self)
            self.startService(self)
        }
    }

    @IBAction func autoFocusDelay(_ sender: Any) {
        autoFocusDelay = focusDelaySlider.integerValue
        if (autoFocusDelay == 0) {
            focusDelaySliderLabel.stringValue = "Window focus disabled"
        } else {
            focusDelaySliderLabel.stringValue = "Delay window focus for " + String(
                pollMillis*(autoFocusDelay/pollMillis - 1)) + " ms"
        }
        self.prefs.set(autoFocusDelay, forKey: "autoFocusDelay")
        if autoRaiseService.isRunning {
            self.stopService(self)
            self.startService(self)
        }
    }

    @IBAction func mouseDelta(_ sender: Any) {
        mouseDelta = mouseDeltaEdit.integerValue
        if (mouseDelta < 0) {
            mouseDeltaEdit.integerValue = 0
            mouseDelta = mouseDeltaEdit.integerValue
        }
        self.prefs.set(mouseDelta, forKey: "mouseDelta")
        if autoRaiseService.isRunning {
            self.stopService(self)
            self.startService(self)
        }
    }

    @IBAction func enableWarp(_ sender: NSButton) {
        enableWarp = enableWarpButton.state
        enableCurserScalingButton.isEnabled = (enableWarp == NSControl.StateValue.on)
        enableAltTaskSwitcherButton.isEnabled = (enableWarp == NSControl.StateValue.on)
        self.prefs.set(enableWarp == NSControl.StateValue.on ? "1" : "0", forKey: "enableWarp")
        if autoRaiseService.isRunning {
            self.stopService(self)
            self.startService(self)
        }
    }

    @IBAction func enableCursorScaling(_ sender: NSButton) {
        enableCursorScaling = enableCurserScalingButton.state
        self.prefs.set(enableCursorScaling == NSControl.StateValue.on ? "1" : "0", forKey: "enableCursorScaling")
        if autoRaiseService.isRunning {
            self.stopService(self)
            self.startService(self)
        }
    }

    
    @IBAction func enableAltTaskSwitcher(_ sender: NSButton) {
        enableAltTaskSwitcher = enableAltTaskSwitcherButton.state
        self.prefs.set(enableAltTaskSwitcher == NSControl.StateValue.on ? "1" : "0", forKey: "enableAltTaskSwitcher")
        if autoRaiseService.isRunning {
            self.stopService(self)
            self.startService(self)
        }
    }
    
    @IBAction func ignoreApps(_ sender: Any) {
        ignoreApps = ignoreAppsEdit.stringValue
        self.prefs.set(ignoreApps, forKey: "ignoreApps")
        if autoRaiseService.isRunning {
            self.stopService(self)
            self.startService(self)
        }
    }

    @IBAction func stayFocusedBundleIds(_ sender: Any) {
        stayFocusedBundleIds = stayFocusedBundleIdsEdit.stringValue
        self.prefs.set(stayFocusedBundleIds, forKey: "stayFocusedBundleIds")
        if autoRaiseService.isRunning {
            self.stopService(self)
            self.startService(self)
        }
    }

    @IBAction func disableKey(_ sender: Any) {
        disableKey = disableKeyBox.stringValue
        self.prefs.set(disableKey, forKey: "disableKey")
        if autoRaiseService.isRunning {
            self.stopService(self)
            self.startService(self)
        }
    }

    @IBAction func ignoreSpaceChanged(_ sender: Any) {
        ignoreSpaceChanged = ignoreSpaceChangedButton.state
        self.prefs.set(ignoreSpaceChanged == NSControl.StateValue.on ? "1" : "0",
            forKey: "ignoreSpaceChanged")
        if autoRaiseService.isRunning {
            self.stopService(self)
            self.startService(self)
        }
    }

    @IBAction func pollMillis(_ sender: Any) {
        let oldPollMillis = pollMillis
        pollMillis = pollMillisEdit.integerValue
        if (pollMillis < 20) {
            pollMillisEdit.integerValue = 50
            pollMillis = pollMillisEdit.integerValue
        }
        self.prefs.set(pollMillis, forKey: "pollMillis")

        delaySlider.maxValue = Double((delaySlider.numberOfTickMarks - 1) * pollMillis)
        focusDelaySlider.maxValue = Double((focusDelaySlider.numberOfTickMarks - 1) * pollMillis)
        delaySlider.integerValue = pollMillis * autoRaiseDelay/oldPollMillis
        focusDelaySlider.integerValue = pollMillis * autoFocusDelay/oldPollMillis

        autoRaiseDelay(sender)
        autoFocusDelay(sender)
        if autoRaiseService.isRunning {
            self.stopService(self)
            self.startService(self)
        }
    }

    func readPreferences() {
        autoRaiseDelay = prefs.integer(forKey: "autoRaiseDelay")
        autoFocusDelay = prefs.integer(forKey: "autoFocusDelay")
        mouseDelta = prefs.integer(forKey: "mouseDelta")
        if (mouseDelta < 0) { mouseDelta = 0 }
        pollMillis = prefs.integer(forKey: "pollMillis")
        if (pollMillis < 20) { pollMillis = 50 }
        if let rawValue = prefs.string(forKey: "enableWarp") {
            enableWarp = NSControl.StateValue(rawValue: Int(rawValue) ?? 0)
        }
        if let rawValue = prefs.string(forKey: "enableCursorScaling") {
            enableCursorScaling = NSControl.StateValue(rawValue: Int(rawValue) ?? 0)
        }
        if let rawValue = prefs.string(forKey: "enableAltTaskSwitcher") {
            enableAltTaskSwitcher = NSControl.StateValue(rawValue: Int(rawValue) ?? 0)
        }
        if let rawValue = prefs.string(forKey: "enableOnLaunch") {
            enableOnLaunch = NSControl.StateValue(rawValue: Int(rawValue) ?? 0)
        }
        if let rawValue = prefs.string(forKey: "ignoreSpaceChanged") {
            ignoreSpaceChanged = NSControl.StateValue(rawValue: Int(rawValue) ?? 0)
        }
        ignoreApps = prefs.string(forKey: "ignoreApps") ?? ""
        stayFocusedBundleIds = prefs.string(forKey: "stayFocusedBundleIds") ?? ""
        disableKey = prefs.string(forKey: "disableKey") ?? "control"

        delaySlider.maxValue = Double(delaySlider.numberOfTickMarks * pollMillis)
        focusDelaySlider.maxValue = Double(focusDelaySlider.numberOfTickMarks * pollMillis)
        if (autoRaiseDelay == 0 && autoFocusDelay == 0 && enableWarp == NSControl.StateValue.off) {
            delaySlider.integerValue = pollMillis
            autoRaiseDelay(self)
        }

        if (autoRaiseDelay == 0) {
            delaySliderLabel.stringValue = "Window raise disabled"
        } else {
            delaySliderLabel.stringValue = "Delay window raise for " + String(
                pollMillis*(autoRaiseDelay/pollMillis - 1)) + " ms"
        }
        if (autoFocusDelay == 0) {
            focusDelaySliderLabel.stringValue = "Window focus disabled"
        } else {
            focusDelaySliderLabel.stringValue = "Delay window focus for " + String(
                pollMillis*(autoFocusDelay/pollMillis - 1)) + " ms"
        }

        enableOnLaunchButton.state = enableOnLaunch
        enableWarpButton.state = enableWarp
        enableCurserScalingButton.state = enableCursorScaling
        enableAltTaskSwitcherButton.state = enableAltTaskSwitcher
        ignoreAppsEdit.stringValue = ignoreApps
        stayFocusedBundleIdsEdit.stringValue = stayFocusedBundleIds
        disableKeyBox.stringValue = disableKey
        ignoreSpaceChangedButton.state = ignoreSpaceChanged
        if enableWarp == NSControl.StateValue.on {
            enableCurserScalingButton.isEnabled = true
            enableAltTaskSwitcherButton.isEnabled = true
        } else {
            enableCurserScalingButton.isEnabled = false
            enableAltTaskSwitcherButton.isEnabled = false
        }
        delaySlider.integerValue = autoRaiseDelay
        focusDelaySlider.integerValue = autoFocusDelay
        pollMillisEdit.integerValue = pollMillis
        mouseDeltaEdit.integerValue = mouseDelta
    }

    @IBAction func homePagePressed(_ sender: NSButton) {
        let url = URL(string: homePageUrl)!
        NSWorkspace.shared.open(url)
    }
    
    @IBAction func autoRaisePagePressed(_ sender: NSButton) {
        let url = URL(string: autoRaiseUrl)!
        NSWorkspace.shared.open(url)
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(CGWindowLevelKey.floatingWindow)))

        icon?.isTemplate = true
        iconRunning?.isTemplate = true
        menuBarItem.button?.image = icon

        readPreferences()

        let shortcut = shortcutView.shortcutValue
        shortcutView.associatedUserDefaultsKey = "HotKey"

        shortcutView.shortcutValueChange = { (sender) in
                MASShortcutMonitor.shared()?.unregisterAllShortcuts()
                if shortcut != nil {
                    MASShortcutMonitor.shared().register(shortcut, withAction:{
                        self.toggleService()
                    })
                }
        }

        if self.shortcutView.shortcutValue != nil {
            MASShortcutMonitor.shared().register(self.shortcutView.shortcutValue, withAction: toggleService)
        }

        if enableOnLaunch == NSControl.StateValue.on {
            self.startService(self)
        }

        // update about tab contents
        aboutText.stringValue = appAbout
        ignoreAppsEdit.placeholderString = "App1,App2,... (confirm with enter)"
        // homepage link
        let pstyle = NSMutableParagraphStyle()
        pstyle.alignment = NSTextAlignment.center
        let customColor = NSColor(red: 0.5, green: 0.5, blue: 0.9, alpha: 1.0)
        homePage.attributedTitle = NSAttributedString(
            string: homePageUrl,
            attributes: [ NSAttributedString.Key.font: NSFont.systemFont(ofSize: 13.0),
                          NSAttributedString.Key.foregroundColor: customColor,
                          NSAttributedString.Key.underlineStyle: 1,
                          NSAttributedString.Key.paragraphStyle: pstyle])
        autoRaisePage.attributedTitle = NSAttributedString(
            string: autoRaiseUrl,
            attributes: [ NSAttributedString.Key.font: NSFont.systemFont(ofSize: 13.0),
                          NSAttributedString.Key.foregroundColor: customColor,
                          NSAttributedString.Key.underlineStyle: 1,
                          NSAttributedString.Key.paragraphStyle: pstyle])
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        stopService(self)
        MASShortcutMonitor.shared().unregisterAllShortcuts()
    }

    func messageBox(_ message: String, description: String?=nil) -> Bool {
        let myPopup: NSAlert = NSAlert()
        myPopup.alertStyle = NSAlert.Style.critical
        myPopup.addButton(withTitle: "OK")
        myPopup.messageText = message
        if let informativeText = description {
            myPopup.informativeText = informativeText
        }
        return (myPopup.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn)
    }

    @objc func Preferences(_ sender: AnyObject){
        self.window.makeKeyAndOrderFront(self)
    }
    
    @objc func startService(_ sender: AnyObject) {
        if !autoRaiseService.isRunning {
            autoRaiseService = Process()
            let autoRaiseCmd = Bundle.main.url(forResource: "AutoRaise", withExtension: "")
            if FileManager().fileExists(atPath: autoRaiseCmd!.path) {
                autoRaiseService.launchPath = autoRaiseCmd?.path
                autoRaiseService.arguments = ["-delay", String(autoRaiseDelay / pollMillis)]
                autoRaiseService.arguments! += ["-focusDelay", String(autoFocusDelay / pollMillis)]
                autoRaiseService.arguments! += ["-mouseDelta", String(mouseDelta)]
                autoRaiseService.arguments! += ["-pollMillis", String(pollMillis)]
                if ( enableWarp == NSControl.StateValue.on ) {
                    autoRaiseService.arguments! += ["-warpX", "0.5", "-warpY", "0.5"]
                    if ( enableCursorScaling == NSControl.StateValue.on ) {
                        autoRaiseService.arguments! += ["-scale", "2.0"]
                    } else {
                        autoRaiseService.arguments! += ["-scale", "1.0"]
                    }
                }
                if ( enableAltTaskSwitcher == NSControl.StateValue.on ) {
                    autoRaiseService.arguments! += ["-altTaskSwitcher", "true"]
                }
                if ( !ignoreApps.isEmpty ) {
                    autoRaiseService.arguments! += ["-ignoreApps", ignoreApps]
                }
                if ( !stayFocusedBundleIds.isEmpty ) {
                    autoRaiseService.arguments! += ["-stayFocusedBundleIds", stayFocusedBundleIds]
                }
                if ( !disableKey.isEmpty ) {
                    autoRaiseService.arguments! += ["-disableKey", disableKey]
                }
                if ( ignoreSpaceChanged == NSControl.StateValue.on ) {
                    autoRaiseService.arguments! += ["-ignoreSpaceChanged", "true"]
                }
            }
            autoRaiseService.launch()
        }
        menuBarItem.button?.image = iconRunning
    }

    @objc func stopService(_ sender: AnyObject) {
        if autoRaiseService.isRunning {
            autoRaiseService.terminate()
            autoRaiseService.waitUntilExit()
        }
        menuBarItem.button?.image = icon
    }

    @objc func quitApplication(_ sender: AnyObject) {
        NSApplication.shared.terminate(sender)
    }
}
