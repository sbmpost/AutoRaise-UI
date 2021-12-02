/*
 *
 * AutoRaise Launcher
 *
 * Copyright (c) 2021 Lothar Haeger
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
import MASShortcut

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
    @IBOutlet weak var delaySlider: NSSlider!
    @IBOutlet weak var enableWarpButton: NSButton!
    @IBOutlet weak var enableCurserScalingButton: NSButton!
    @IBOutlet weak var enableOnLaunchButton: NSButton!
    @IBOutlet weak var openAtLoginButton: NSButton!
    @IBOutlet weak var shortcutView: MASShortcutView!

    // About
    @IBOutlet weak var aboutText: NSTextField!
    @IBOutlet weak var homePage: URLButton!

    let appVersionString: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    let buildNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String

    let appAbout =  "AutoRaise & Launcher\n" +
        "Version 2.1.0, 2021-05-07\n\n" +
        "©2021 Stefan Post, Lothar Haeger\n" +
        "Icons made by https://www.flaticon.com/authors/fr"
    
    let homePageUrl = "https://github.com/lhaeger/AutoRaise"

    let prefs = UserDefaults.standard

    var statusBar = NSStatusBar.system
    var menuBarItem : NSStatusItem = NSStatusItem()
    var menu: NSMenu = NSMenu()
    var menuItemPrefs : NSMenuItem = NSMenuItem()
    var menuItemQuit : NSMenuItem = NSMenuItem()
    var autoRaiseUrl : URL!
    var autoRaiseService: Process = Process()

    var autoRaiseDelay : NSInteger = 40
    var enableWarp = NSControl.StateValue.off
    var enableCursorScaling = NSControl.StateValue.off
    var enableOnLaunch = NSControl.StateValue.off
    var openAtLogin = NSControl.StateValue.off

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

        shortcutView.associatedUserDefaultsKey = "HotKey"
       // let shortcut = shortcutView.shortcutValue

      //  MASShortcutMonitor.shared().register(shortcut, withAction: {
      //      self.menuBarItemClicked(self.menuBarItem.button!);
       // })

        // example code to act on hotkey change
//        shortcutView.shortcutValueChange = { (sender) in
//
//            let callback: (() -> Void)!
//
//            if self.shortcutView.shortcutValue?.keyCodeStringForKeyEquivalent == "k" {
//                callback = {
//                    print("K shortcut handler")
//                }
//            } else {
//                callback = {
//                    print("Default handler")
//                }
//            }
//        }

        MASShortcutMonitor.shared().register(self.shortcutView.shortcutValue, withAction:{  self.menuBarItemClicked(self.menuBarItem.button!);
        })
    }

    @objc func menuBarItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        if event.type == NSEvent.EventType.rightMouseUp {
            menuBarItem.menu = menu
        } else {
            if autoRaiseService.isRunning {
                self.stopService(self)
            } else {
                self.startService(self)
            }
        }
    }

    @IBAction func enableOnLaunch(_ sender: NSButton) {
        enableOnLaunch = enableOnLaunchButton.state
        self.prefs.set(enableOnLaunch == NSControl.StateValue.on ? "1" : "0", forKey: "enableOnLaunch")
    }

    @IBAction func openAtLogin(_ sender: NSButton) {
        openAtLogin = openAtLoginButton.state
        self.prefs.set(openAtLogin == NSControl.StateValue.on ? "1" : "0", forKey: "openAtLogin")
    }

    @IBAction func autoRaiseDelay(_ sender: Any) {
        autoRaiseDelay = delaySlider.integerValue
        delaySliderLabel.stringValue = "Delay window activation for " + String(autoRaiseDelay) + " ms"
        self.prefs.set(autoRaiseDelay, forKey: "autoRaiseDelay")
        if autoRaiseService.isRunning {
            self.stopService(self)
            self.startService(self)
        }
    }

    @IBAction func enableWarp(_ sender: NSButton) {
        enableWarp = enableWarpButton.state
        enableCurserScalingButton.isEnabled = (enableWarp == NSControl.StateValue.on)
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

    func readPreferences() {
        if let rawValue = prefs.string(forKey: "enableWarp") {
            enableWarp = NSControl.StateValue(rawValue: Int(rawValue) ?? 0)
            autoRaiseDelay = prefs.integer(forKey: "autoRaiseDelay")
        }
        if let rawValue = prefs.string(forKey: "enableCursorScaling") {
            enableCursorScaling = NSControl.StateValue(rawValue: Int(rawValue) ?? 0)
        }
        if let rawValue = prefs.string(forKey: "enableOnLaunch") {
            enableOnLaunch = NSControl.StateValue(rawValue: Int(rawValue) ?? 0)
        }
        if let rawValue = prefs.string(forKey: "openAtLogin") {
            openAtLogin = NSControl.StateValue(rawValue: Int(rawValue) ?? 0)
        }
        delaySliderLabel.stringValue = "Delay window activation for " + String(autoRaiseDelay) + " ms"
        enableOnLaunchButton.state = enableOnLaunch
        openAtLoginButton.state = openAtLogin
        enableWarpButton.state = enableWarp
        enableCurserScalingButton.state = enableCursorScaling
        if enableWarp == NSControl.StateValue.on {
            enableCurserScalingButton.isEnabled = true
        } else {
            enableCurserScalingButton.isEnabled = false
        }
        delaySlider.integerValue = autoRaiseDelay
    }

    @IBAction func homePagePressed(_ sender: NSButton) {
        let url = URL(string: homePageUrl)!
        NSWorkspace.shared.open(url)
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(CGWindowLevelKey.floatingWindow)))

        menuBarItem.button?.image = icon

        readPreferences()

        if enableOnLaunch == NSControl.StateValue.on {
            self.startService(self)
        }

       // update about tab contents
        aboutText.stringValue = appAbout
        // homepage link
        let pstyle = NSMutableParagraphStyle()
        pstyle.alignment = NSTextAlignment.center
        homePage.attributedTitle = NSAttributedString(
            string: homePageUrl,
            attributes: [ NSAttributedString.Key.font: NSFont.systemFont(ofSize: 13.0),
                          NSAttributedString.Key.foregroundColor: NSColor.blue,
                          NSAttributedString.Key.underlineStyle: 1,
                          NSAttributedString.Key.paragraphStyle: pstyle])
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        stopService(self)
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
                autoRaiseService.arguments = ["-delay", String(autoRaiseDelay / 20)]
                if ( enableWarp == NSControl.StateValue.on ) {
                    autoRaiseService.arguments! += ["-warpX", "0.5", "-warpY", "0.5"]
                    if ( enableCursorScaling == NSControl.StateValue.on ) {
                        autoRaiseService.arguments! += ["-scale", "2.0"]
                    } else {
                        autoRaiseService.arguments! += ["-scale", "1.0"]
                    }
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
