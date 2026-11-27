import MusicKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Everything that can be switched, how the deck works, and what the app is.
struct SettingsView: View {
    @EnvironmentObject private var model: PlayerModel
    @EnvironmentObject private var tour: Tour
    @AppStorage(Prefs.player) private var player = "tape"
    @Environment(\.dismiss) private var dismiss

    @AppStorage(Prefs.hiss) private var hissOn = true
    @AppStorage(Prefs.haptics) private var hapticsOn = true
    @AppStorage(Prefs.glare) private var glareOn = true
    @AppStorage(Prefs.levelLights) private var levelLightsOn = true
    @AppStorage(Prefs.playOnClose) private var playOnCloseOn = true
    @AppStorage(Prefs.autoFlip) private var autoFlipOn = false
    @AppStorage(Prefs.tapeRamp) private var tapeRampOn = true
    @AppStorage(Prefs.lockScreenTape) private var lockScreenTapeOn = true
    @AppStorage(Prefs.iCloudSync) private var iCloudOn = true
    @AppStorage(Prefs.introSeen) private var introSeen = true

    @State private var backup = BackupDocument(data: Data())
    @State private var savingBackup = false
    @State private var choosingBackup = false
    @State private var backupNote: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Deck sounds", isOn: $model.soundEffectsOn)
                    Toggle("Tape hiss", isOn: $hissOn)
                        .disabled(!model.soundEffectsOn)
                } header: {
                    Text("Sound")
                } footer: {
                    Text("Deck sounds are the key clunks, the door and the motor while winding. Hiss is the soft noise under the music. They play over the music and are not silenced by the mute switch.")
                }

                ForEach(PlayerKind.offered) { kind in
                    Section {
                        ThemePicker(kind: kind)
                    } header: {
                        Text(kind.rawValue)
                    } footer: {
                        if kind == PlayerKind.offered.last {
                            Text("The tape deck shows the cassette and its reels. The MP3 player has a display of menus and a dial to scroll them. Both play the same tapes, and the colours carry over to the shelf, the open phone and the lock screen.")
                        }
                    }
                }

                Section {
                    Toggle("Haptics", isOn: $hapticsOn)
                    Toggle("Glare follows the phone", isOn: $glareOn)
                    Toggle("Level lights in the volume slot", isOn: $levelLightsOn)
                } header: {
                    Text("Look and feel")
                } footer: {
                    Text("The level lights move in time while a tape plays. They are for show: Apple Music does not let an app listen to the music itself.")
                }

                Section {
                    Toggle("Play when the phone is closed", isOn: $playOnCloseOn)
                    Toggle("Flip at the end of a side", isOn: $autoFlipOn)
                    Toggle("Tape runs up to speed and down to a stop", isOn: $tapeRampOn)
                } header: {
                    Text("Tape")
                } footer: {
                    Text("With flipping off, the music stops when a side runs out and you turn the tape over yourself.")
                }

                Section {
                    Toggle("Show the tape on the lock screen", isOn: $lockScreenTapeOn)
                } header: {
                    Text("Lock screen")
                } footer: {
                    Text("It keeps in step with the music while tape hiss is on. With hiss off, it shows the tape as it was when you left Cassety.")
                }

                Section {
                    Toggle("Sync with iCloud", isOn: $iCloudOn)
                    LabeledContent("Status", value: model.cloudStatus)
                    Button("Save a backup file") {
                        if let data = model.makeBackup() {
                            backup = BackupDocument(data: data)
                            savingBackup = true
                        }
                    }
                    Button("Restore from a backup file") {
                        choosingBackup = true
                    }
                } header: {
                    Text("iCloud and backup")
                } footer: {
                    Text("Sync keeps your mixtapes and these settings the same on every device signed in to your iCloud account. A backup file holds the same things and can be saved anywhere. Restoring brings back the tapes in the file and keeps any you have made since. Your Apple Music library is kept by Apple Music itself.")
                }

                Section("Apple Music") {
                    switch model.authStatus {
                    case .authorized:
                        Label("Connected", systemImage: "checkmark.circle.fill")
                    case .notDetermined:
                        Button("Connect Apple Music") {
                            Task { await model.requestAccess() }
                        }
                    default:
                        Button("Turn on access in Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                }

                Section("How the deck works") {
                    Label("Play and stop are a pair. Press one in and the other pops out.", systemImage: "play.fill")
                    Label("Tap fast forward or rewind to skip a song. Hold to wind the tape.", systemImage: "forward.fill")
                    Label("Double-tap the tape to turn it over.", systemImage: "arrow.triangle.2.circlepath")
                    Label("Open the phone to choose a tape, then close it to start playing.", systemImage: "rectangle.portrait.on.rectangle.portrait")
                    Button("Take the hands-on tour") {
                        // The tour is done on the tape deck itself.
                        player = "tape"
                        dismiss()
                        tour.start(hasTape: model.hasTape)
                    }
                    Button("Show the introduction again") {
                        dismiss()
                        introSeen = false
                    }
                }

                Section {
                    HStack {
                        Text("Cassety")
                        Spacer()
                        Text(version).foregroundColor(.secondary)
                    }
                    if let url = URL(string: AppLinks.privacyPolicy), !AppLinks.privacyPolicy.isEmpty {
                        Link("Privacy policy", destination: url)
                    }
                    if let url = URL(string: AppLinks.support), !AppLinks.support.isEmpty {
                        Link("Help and support", destination: url)
                    }
                } footer: {
                    Text("Music is played by Apple Music and needs a subscription.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: iCloudOn) { _, _ in
                model.syncWithCloud()
            }
            .fileExporter(isPresented: $savingBackup, document: backup, contentType: .json,
                          defaultFilename: "Cassety backup") { result in
                if case .failure(let error) = result {
                    backupNote = "The backup could not be saved. \(error.localizedDescription)"
                }
            }
            .fileImporter(isPresented: $choosingBackup, allowedContentTypes: [.json]) { result in
                restore(result)
            }
            .alert("Backup", isPresented: backupNoteShown) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(backupNote ?? "")
            }
            .toolbar {
                // On the Duo the trailing items sit in the rail, under the
                // clock and status icons.
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var backupNoteShown: Binding<Bool> {
        Binding(get: { backupNote != nil }, set: { if !$0 { backupNote = nil } })
    }

    private func restore(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            // Files outside the app need permission to be opened.
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let count = try model.restore(from: Data(contentsOf: url))
            backupNote = count == 1
                ? "Restored your settings and 1 mixtape."
                : "Restored your settings and \(count) mixtapes."
        } catch {
            backupNote = "That file could not be restored. \(error.localizedDescription)"
        }
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let number = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(number) (\(build))"
    }
}
