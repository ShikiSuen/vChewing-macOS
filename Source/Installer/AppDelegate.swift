/*
 *  AppDelegate.swift
 *
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

import Cocoa

private let kTargetBin = "vChewing"
private let kTargetType = "app"
private let kTargetBundle = "vChewing.app"
private let kDestinationPartial = "~/Library/Input Methods/"
private let kTargetPartialPath = "~/Library/Input Methods/vChewing.app"
private let kTargetFullBinPartialPath = "~/Library/Input Methods/vChewing.app/Contents/MacOS/vChewing"

private let kTranslocationRemovalTickInterval: TimeInterval = 0.5
private let kTranslocationRemovalDeadline: TimeInterval = 60.0

@main
@objc (AppDelegate)
class AppDelegate: NSWindowController, NSApplicationDelegate {
    @IBOutlet weak private var installButton: NSButton!
    @IBOutlet weak private var cancelButton: NSButton!
    @IBOutlet weak private var progressSheet: NSWindow!
    @IBOutlet weak private var progressIndicator: NSProgressIndicator!
    @IBOutlet weak private var appVersionLabel: NSTextField!
    @IBOutlet weak private var appCopyrightLabel: NSTextField!
    @IBOutlet private var appEULAContent: NSTextView!
    
    private var archiveUtil: ArchiveUtil?
    private var installingVersion = ""
    private var upgrading = false
    private var translocationRemovalStartTime: Date?
    private var currentVersionNumber: Int = 0

    func runAlertPanel(title: String, message: String, buttonTitle: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: buttonTitle)
        alert.runModal()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let installingVersion = Bundle.main.infoDictionary?[kCFBundleVersionKey as String] as? String,
              let versionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return
        }
        self.installingVersion = installingVersion
        self.archiveUtil = ArchiveUtil(appName: kTargetBin, targetAppBundleName: kTargetBundle)
        _ = archiveUtil?.validateIfNotarizedArchiveExists()

        cancelButton.nextKeyView = installButton
        installButton.nextKeyView = cancelButton
        if let cell = installButton.cell as? NSButtonCell {
            window?.defaultButtonCell = cell
        }
        
        if let copyrightLabel = Bundle.main.localizedInfoDictionary?["NSHumanReadableCopyright"] as? String {
            appCopyrightLabel.stringValue = copyrightLabel
        }
        if let eulaContent = Bundle.main.localizedInfoDictionary?["CFEULAContent"] as? String {
            appEULAContent.string = eulaContent
        }
        appVersionLabel.stringValue = String(format: "%@ Build %@", versionString, installingVersion)

        window?.title = String(format: NSLocalizedString("%@ (for version %@, r%@)", comment: ""), window?.title ?? "", versionString, installingVersion)
        window?.standardWindowButton(.closeButton)?.isHidden = true
        window?.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window?.standardWindowButton(.zoomButton)?.isHidden = true

        if FileManager.default.fileExists(atPath: (kTargetPartialPath as NSString).expandingTildeInPath) {
            let currentBundle = Bundle(path: (kTargetPartialPath as NSString).expandingTildeInPath)
            let shortVersion = currentBundle?.infoDictionary?["CFBundleShortVersionString"] as? String
            let currentVersion = currentBundle?.infoDictionary?[kCFBundleVersionKey as String] as? String
            currentVersionNumber = (currentVersion as NSString?)?.integerValue ?? 0
            if shortVersion != nil, let currentVersion = currentVersion, currentVersion.compare(installingVersion, options: .numeric) == .orderedAscending {
                upgrading = true
            }
        }

        if upgrading {
            installButton.title = NSLocalizedString("Upgrade", comment: "")
        }

        window?.center()
        window?.orderFront(self)
        NSApp.activate(ignoringOtherApps: true)
    }

    @IBAction func agreeAndInstallAction(_ sender: AnyObject) {
        cancelButton.isEnabled = false
        installButton.isEnabled = false
        removeThenInstallInputMethod()
    }

    @objc func timerTick(_ timer: Timer) {
        let elapsed = Date().timeIntervalSince(translocationRemovalStartTime ?? Date())
        if elapsed >= kTranslocationRemovalDeadline {
            timer.invalidate()
            window?.endSheet(progressSheet, returnCode: .cancel)
        } else if appBundleChronoshiftedToARandomizedPath(kTargetPartialPath) == false {
            progressIndicator.doubleValue = 1.0
            timer.invalidate()
            window?.endSheet(progressSheet, returnCode: .continue)
        }
    }

    func removeThenInstallInputMethod() {
        if FileManager.default.fileExists(atPath: (kTargetPartialPath as NSString).expandingTildeInPath) == false {
            self.installInputMethod(previousExists: false, previousVersionNotFullyDeactivatedWarning: false)
            return
        }

        let shouldWaitForTranslocationRemoval = appBundleChronoshiftedToARandomizedPath(kTargetPartialPath) && (window?.responds(to: #selector(NSWindow.beginSheet(_:completionHandler:))) ?? false)

        // http://www.cocoadev.com/index.pl?MoveToTrash
        let sourceDir = (kDestinationPartial as NSString).expandingTildeInPath
        let trashDir = (NSHomeDirectory() as NSString).appendingPathComponent(".Trash")
        var tag = 0

        NSWorkspace.shared.performFileOperation(.recycleOperation, source: sourceDir, destination: trashDir, files: [kTargetBundle], tag: &tag)

        let killTask = Process()
        killTask.launchPath = "/usr/bin/killall"
        killTask.arguments = ["-9", kTargetBin]
        killTask.launch()
        killTask.waitUntilExit()

        if shouldWaitForTranslocationRemoval {
            progressIndicator.startAnimation(self)
            window?.beginSheet(progressSheet) { returnCode in
                DispatchQueue.main.async {
                    if returnCode == .continue {
                        self.installInputMethod(previousExists: true, previousVersionNotFullyDeactivatedWarning: false)
                    } else {
                        self.installInputMethod(previousExists: true, previousVersionNotFullyDeactivatedWarning: true)
                    }
                }
            }

            translocationRemovalStartTime = Date()
            Timer.scheduledTimer(timeInterval: kTranslocationRemovalTickInterval, target: self, selector: #selector(timerTick(_:)), userInfo: nil, repeats: true)
		} else {
			self.installInputMethod(previousExists: false, previousVersionNotFullyDeactivatedWarning: false)
        }
    }

    func installInputMethod(previousExists: Bool, previousVersionNotFullyDeactivatedWarning warning: Bool) {
        guard let targetBundle = archiveUtil?.unzipNotarizedArchive() ?? Bundle.main.path(forResource: kTargetBin, ofType: kTargetType) else {
            return
        }
        let cpTask = Process()
        cpTask.launchPath = "/bin/cp"
        cpTask.arguments = ["-R", targetBundle, (kDestinationPartial as NSString).expandingTildeInPath]
        cpTask.launch()
        cpTask.waitUntilExit()

        if cpTask.terminationStatus != 0 {
            runAlertPanel(title: NSLocalizedString("Install Failed", comment: ""),
                          message: NSLocalizedString("Cannot copy the file to the destination.", comment: ""),
                          buttonTitle: NSLocalizedString("Cancel", comment: ""))
            endAppWithDelay()
        }

        guard let imeBundle = Bundle(path: (kTargetPartialPath as NSString).expandingTildeInPath),
              let imeIdentifier = imeBundle.bundleIdentifier
                else {
            endAppWithDelay()
            return
        }

        let imeBundleURL = imeBundle.bundleURL
        var inputSource = InputSourceHelper.inputSource(for: imeIdentifier)

        if inputSource == nil {
            NSLog("Registering input source \(imeIdentifier) at \(imeBundleURL.absoluteString).");
            let status = InputSourceHelper.registerTnputSource(at: imeBundleURL)
            if !status {
                let message = String(format: NSLocalizedString("Cannot find input source %@ after registration.", comment: ""), imeIdentifier)
                runAlertPanel(title: NSLocalizedString("Fatal Error", comment: ""), message: message, buttonTitle: NSLocalizedString("Abort", comment: ""))
                endAppWithDelay()
                return
            }

            inputSource = InputSourceHelper.inputSource(for: imeIdentifier)
            if inputSource == nil {
                let message = String(format: NSLocalizedString("Cannot find input source %@ after registration.", comment: ""), imeIdentifier)
                runAlertPanel(title: NSLocalizedString("Fatal Error", comment: ""), message: message, buttonTitle: NSLocalizedString("Abort", comment: ""))
            }
        }

        var isMacOS12OrAbove = false
        if #available(macOS 12.0, *) {
            NSLog("macOS 12 or later detected.");
            isMacOS12OrAbove = true
        } else {
            NSLog("Installer runs with the pre-macOS 12 flow.");
        }

        // If the IME is not enabled, enable it. Also, unconditionally enable it on macOS 12.0+,
        // as the kTISPropertyInputSourceIsEnabled can still be true even if the IME is *not*
        // enabled in the user's current set of IMEs (which means the IME does not show up in
        // the user's input menu).

        var mainInputSourceEnabled = InputSourceHelper.inputSourceEnabled(for: inputSource!)
        if !mainInputSourceEnabled || isMacOS12OrAbove {
            mainInputSourceEnabled = InputSourceHelper.enable(inputSource: inputSource!)
            if (mainInputSourceEnabled) {
                NSLog("Input method enabled: \(imeIdentifier)");
            } else {
                NSLog("Failed to enable input method: \(imeIdentifier)");
            }
        }

        if warning {
            runAlertPanel(title: NSLocalizedString("Attention", comment: ""), message: NSLocalizedString("vChewing is upgraded, but please log out or reboot for the new version to be fully functional.", comment: ""), buttonTitle: NSLocalizedString("OK", comment: ""))
        } else {
            if !mainInputSourceEnabled && !isMacOS12OrAbove {
                runAlertPanel(title: NSLocalizedString("Warning", comment: ""), message: NSLocalizedString("Input method may not be fully enabled. Please enable it through System Preferences > Keyboard > Input Sources.", comment: ""), buttonTitle: NSLocalizedString("Continue", comment: ""))
            } else {
                runAlertPanel(title: NSLocalizedString("Installation Successful", comment: ""), message: NSLocalizedString("vChewing is ready to use.", comment: ""), buttonTitle: NSLocalizedString("OK", comment: ""))
            }
        }

        endAppWithDelay()
    }

    func endAppWithDelay() {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
            NSApp.terminate(self)
        }
    }

    @IBAction func cancelAction(_ sender: AnyObject) {
        NSApp.terminate(self)
    }

    func windowWillClose(_ Notification: Notification) {
        NSApp.terminate(self)
    }


}
