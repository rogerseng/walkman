import MusicKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Everything that can be switched, how the deck works, and what the app is.
struct SettingsView: View {
    @EnvironmentObject private var model: PlayerModel
    @EnvironmentObject private var tour: Tour
    @Environment(\.dismiss) private var dismiss

    @AppStorage(Prefs.hiss) private var hissOn = true
    @AppStorage(Prefs.haptics) private var hapticsOn = true
    @AppStorage(Prefs.glare) private var glareOn = true
    @AppStorage(Prefs.levelLights) private var levelLightsOn = true
    @AppStorage(Prefs.playOnClose) private var playOnCloseOn = true
    @AppStorage(Prefs.autoFlip) private var autoFlipOn = false
    @AppStorage(Prefs.tapeRamp) private var tapeRampOn = true
    @AppStorage(Prefs.iCloudSync) private var iCloudOn = true
    @AppStorage(Prefs.introSeen) private var introSeen = true

    @State private var backup = BackupDocument(data: Data())
    @State private var savingBackup = false
    @State private var choosingBackup = false
    @State private var backupNote: String?
    @State private var disconnecting = false

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
                        Text(kind.title)
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
                    Toggle("Play when a folding phone is closed", isOn: $playOnCloseOn)
                    Toggle("Flip at the end of a side", isOn: $autoFlipOn)
                    Toggle("Tape runs up to speed and down to a stop", isOn: $tapeRampOn)
                } header: {
                    Text("Tape")
                } footer: {
                    Text("With flipping off, the music stops when a side runs out and you turn the tape over yourself.")
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
                    Text("Sync keeps these settings the same on every device signed in to your iCloud account. A backup file holds the same settings and can be saved anywhere. Your music library is kept by your music service.")
                }

                // One music service at a time. Apple Music is the one built
                // in; its access is granted and withdrawn in iOS Settings.
                Section {
                    switch model.authStatus {
                    case .authorized:
                        LabeledContent("Apple Music") {
                            Label("Connected", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                        Button("Disconnect Apple Music") {
                            disconnecting = true
                        }
                    case .notDetermined:
                        LabeledContent("Apple Music", value: "Not connected")
                        Button("Connect Apple Music") {
                            Task { await model.requestAccess() }
                        }
                    default:
                        LabeledContent("Apple Music", value: "Access is off")
                        Button("Turn on access in Settings") { openSystemSettings() }
                    }
                } header: {
                    Text("Music service")
                } footer: {
                    Text("Cassety plays from one music service at a time. Apple Music needs a subscription. To disconnect, iOS asks you to switch off Media & Apple Music for Cassety in the Settings app.")
                }

                Section("How the deck works") {
                    Label("Play and stop are a pair. Press one in and the other pops out.", systemImage: "play.fill")
                    Label("Tap fast forward or rewind to skip a song. Hold to wind the tape.", systemImage: "forward.fill")
                    Label("Double-tap the tape to turn it over.", systemImage: "arrow.triangle.2.circlepath")
                    Label("The music key opens your shelf. On a folding phone, open it to choose a tape and close it to start playing.", systemImage: "music.note")
                    Label("On the MP3 player, turn the dial to scroll and press it to choose. The top key goes back, or opens Settings from the first menu.", systemImage: "dial.medium")
                    // The tour is done on the tape deck, so it is offered
                    // only while the deck is the player showing.
                    if tour.deckShowing {
                        Button("Take the hands-on tour") {
                            dismiss()
                            tour.start(hasTape: model.hasTape)
                        }
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
                    Text("Music is played by your music service and needs its subscription.")
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
            .scrollContentBackground(.hidden)
            .background(ShelfBackground())
            .confirmationDialog("Disconnect Apple Music?", isPresented: $disconnecting, titleVisibility: .visible) {
                Button("Open Settings") { openSystemSettings() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Only iOS can withdraw access. In Settings, switch off Media & Apple Music for Cassety. The tape in the deck will stop.")
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
            _ = count
            backupNote = "Restored your settings."
        } catch {
            backupNote = "That file could not be restored. \(error.localizedDescription)"
        }
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let number = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(number) (\(build))"
    }
}
