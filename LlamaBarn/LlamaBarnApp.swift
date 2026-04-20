import AppKit
import SwiftUI
import os.log

#if canImport(Sparkle)
import Sparkle
#endif

@main
struct LlamaBarnApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    // Empty scene, as we are a menu bar app
    Settings {
      EmptyView()
    }
    .commands {
      CommandGroup(replacing: .appSettings) {
        Button("Settings...") {
          NotificationCenter.default.post(name: .LBShowSettings, object: nil)
        }
        .keyboardShortcut(",")
      }
    }
  }
}

class AppDelegate: NSObject, NSApplicationDelegate {
  #if canImport(Sparkle)
  private var updaterController: SPUStandardUpdaterController?
  #endif
  private let logger = Logger(subsystem: Logging.subsystem, category: "AppDelegate")
  private var menuController: MenuController?
  private var settingsWindowController: SettingsWindowController?
  private var updatesObserver: NSObjectProtocol?

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Enable visual debugging if LB_DEBUG_UI is set
    NSView.swizzleDebugBehavior()

    ErrorReporting.startIfAvailable(
      releaseName: AppInfo.shortVersion,
      environment: AppInfo.shortVersion == "0.0.0" ? "internal" : "production"
    )

    logger.info("Llamigo starting up")

    // Configure app as menu bar only (removes from Dock)
    NSApp.setActivationPolicy(.accessory)

    #if canImport(Sparkle)
      // Set up automatic updates using Sparkle framework
      // Skip starting the updater for debug builds to avoid false update prompts
      #if DEBUG
        let startUpdater = false
      #else
        let startUpdater = true
      #endif
      updaterController = SPUStandardUpdaterController(
        startingUpdater: startUpdater,
        updaterDelegate: self,
        userDriverDelegate: self
      )
    #endif

    // Initialize the shared model library manager to scan for existing models
    _ = ModelManager.shared

    // Create the AppKit-based status bar menu (installed models only for now)
    menuController = MenuController()

    // Initialize settings window controller (listens for LBShowSettings notifications)
    settingsWindowController = SettingsWindowController.shared

    // Start the server in Router Mode
    LlamaServer.shared.start()

    // Listen for explicit update requests from the menu controller
    updatesObserver = NotificationCenter.default.addObserver(
      forName: .LBCheckForUpdates, object: nil, queue: .main
    ) { [weak self] _ in
      #if canImport(Sparkle)
      self?.updaterController?.checkForUpdates(nil)
      #else
      _ = self
      #endif
    }

    #if DEBUG
      // Auto-open menu in debug builds to save a click
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        self?.menuController?.openMenu()
      }
    #endif

    logger.info("Llamigo startup complete")
  }

  func applicationWillTerminate(_ notification: Notification) {
    logger.info("Llamigo shutting down")

    // Gracefully stop the llama-server process when app quits
    LlamaServer.shared.stop()

    // Clean up observers
    if let updatesObserver { NotificationCenter.default.removeObserver(updatesObserver) }
  }
}

#if canImport(Sparkle)
  // MARK: - SPUStandardUserDriverDelegate

  extension AppDelegate: SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool {
      true
    }

    func standardUserDriverWillHandleShowingUpdate(
      _ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState
    ) {
      NSApp.setActivationPolicy(.regular)
    }

    func standardUserDriverWillFinishUpdateSession() {
      NSApp.setActivationPolicy(.accessory)
    }
  }

  // MARK: - SPUUpdaterDelegate

  extension AppDelegate: SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didFailToCheckForUpdatesWithError error: Error) {
      logger.error(
        "Sparkle: failed to check for updates: \(error.localizedDescription, privacy: .public)")
    }
  }
#endif
