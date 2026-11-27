import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Keeps mixtapes and settings the same on every device signed in to the same
/// iCloud account, using iCloud's key-value store. It holds about a megabyte,
/// which is room for thousands of songs' worth of mixtapes.
@MainActor
final class CloudSync {
    /// Called when another device has changed something.
    var onRemoteChange: (() -> Void)?
    private(set) var lastSync: Date?

    private let store = NSUbiquitousKeyValueStore.default
    private let libraryKey = "mixtapeLibrary"
    private var observers: [NSObjectProtocol] = []

    /// The settings that travel between devices.
    static let syncedPrefs = [Prefs.sounds, Prefs.hiss, Prefs.haptics, Prefs.glare, Prefs.levelLights,
                              Prefs.playOnClose, Prefs.autoFlip, Prefs.lockScreenTape]

    /// Settings that are words rather than switches.
    static let syncedChoices = [Prefs.skin, Prefs.player]

    var isSignedIn: Bool { FileManager.default.ubiquityIdentityToken != nil }
    var isOn: Bool { Prefs.isOn(Prefs.iCloudSync) }

    var status: String {
        if !isOn { return "Off" }
        if !isSignedIn { return "Not signed in to iCloud" }
        guard let lastSync else { return "On" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Synced \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
    }

    func start() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                            object: store, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isOn else { return }
                self.pullSettings()
                self.lastSync = Date()
                self.onRemoteChange?()
            }
        })
        // A setting changed on this device: send it on.
        observers.append(center.addObserver(forName: UserDefaults.didChangeNotification,
                                            object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.pushSettings() }
        })
        store.synchronize()
    }

    // MARK: Mixtapes

    func remoteLibrary() -> MixtapeLibrary? {
        guard isOn, let data = store.data(forKey: libraryKey) else { return nil }
        return try? JSONDecoder().decode(MixtapeLibrary.self, from: data)
    }

    func push(_ library: MixtapeLibrary) {
        guard isOn, let data = try? JSONEncoder().encode(library) else { return }
        if store.data(forKey: libraryKey) != data {
            store.set(data, forKey: libraryKey)
            store.synchronize()
        }
        lastSync = Date()
    }

    // MARK: Settings

    /// Takes on the settings iCloud has, where they differ from this device's.
    func pullSettings() {
        guard isOn else { return }
        for key in Self.syncedPrefs {
            guard let remote = store.object(forKey: key) as? Bool else { continue }
            if Prefs.isOn(key) != remote {
                UserDefaults.standard.set(remote, forKey: key)
            }
        }
        for key in Self.syncedChoices {
            guard let remote = store.string(forKey: key) else { continue }
            if UserDefaults.standard.string(forKey: key) != remote {
                UserDefaults.standard.set(remote, forKey: key)
            }
        }
    }

    /// Sends this device's settings to iCloud, where they differ.
    func pushSettings() {
        guard isOn else { return }
        var changed = false
        for key in Self.syncedPrefs {
            let local = Prefs.isOn(key)
            if store.object(forKey: key) as? Bool != local {
                store.set(local, forKey: key)
                changed = true
            }
        }
        for key in Self.syncedChoices {
            guard let local = UserDefaults.standard.string(forKey: key) else { continue }
            if store.string(forKey: key) != local {
                store.set(local, forKey: key)
                changed = true
            }
        }
        if changed { store.synchronize() }
    }
}

// MARK: Backup files

/// Everything worth keeping, as one file: mixtapes and settings.
struct Backup: Codable {
    var app = "Cassety"
    var format = 1
    var created = Date()
    var library: MixtapeLibrary
    var settings: [String: Bool]
    /// Settings that are words, such as the skin. Absent from older backups.
    var choices: [String: String]?
}

/// A backup as a document the system can save to, or open from, Files,
/// iCloud Drive or anywhere else it offers.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
