import SwiftUI
import VendorContainment
import VendorContainmentUI

/// The part a product team owns: which vendor SDKs the app ships, when each
/// may start, and the compiled-in policy that applies before the app's own
/// control plane has ever answered.
///
/// The library enforces its own floors whatever this says: no vendor can
/// start before the first frame (there is no such stage), a vendor named in
/// no policy is off, and a stale remote policy can only restrict this one.
enum DemoRoster {
    static let analytics: VendorID = "analytics"
    static let attribution: VendorID = "attribution"
    static let messaging: VendorID = "messaging"

    static let vendors: [(id: VendorID, stage: StartupStage)] = [
        (analytics, .afterFirstFrame),
        (attribution, .afterFirstFrame),
        (messaging, .idle),
    ]

    /// Version 0: the shipped default. Messaging is a privacy-sensitive
    /// vendor, so if it is ever disabled its queued events are dropped, not
    /// replayed.
    static let compiledPolicy = PolicyDocument(version: 0, rules: [
        analytics: VendorRule(),
        attribution: VendorRule(),
        messaging: VendorRule(whenDisabled: .drop),
    ])

    static var configuration: ContainmentConfiguration {
        var config = ContainmentConfiguration()
        config.stabilityWindow = 10
        config.idleStageDelay = 2
        config.sentinel = SentinelConfiguration(strikeThreshold: 2, baseCooldown: 3_600, maxCooldown: 7 * 86_400)
        config.bufferCapacityPerVendor = 200
        return config
    }
}

@main
struct DemoApp: App {
    // The default scenario is the 28 Sep 2026 incident: the attribution SDK's
    // remote config ships a null flag name, and payload validation is off
    // (as it would be for a config the SDK fetches internally). "Replay ×4"
    // shows two crashes, then containment.
    @State private var model = ContainmentConsoleModel(
        vendors: DemoRoster.vendors,
        compiledPolicy: DemoRoster.compiledPolicy,
        configuration: DemoRoster.configuration,
        initialFaults: [DemoRoster.attribution: .nullFlagCrashOnStart],
        validatesPayloads: false
    )

    var body: some Scene {
        WindowGroup {
            ContainmentConsoleView(model: model)
        }
    }
}
