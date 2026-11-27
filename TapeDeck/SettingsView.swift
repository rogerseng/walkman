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
    @AppStorage(Prefs.beatHaptics) private var beatHapticsOn = false
    @AppStorage(Prefs.beatStrength) private var beatStrength = Prefs.defaultBeatStrength
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
                ForEach(PlayerKind.offered) { kind in
                    Section {
                        ThemePicker(kind: kind)
                    } header: {
                        Text(kind.title)
                    } footer: {
                        if kind == PlayerKind.offered.last {
                            Text(Theme.includesMP3
                                 ? "The tape deck shows the cassette and its reels. The MP3 player has a display of menus and a dial to scroll them. Both play the same tapes, and the colours carry over to the shelf and the open phone."
                                 : "Pick a colour and the whole app follows it: the player, the shelf and the open phone.")
                        }
                    }
                }

                // One music service at a time. Apple Music is the one built
                // in; its access is granted and withdrawn in iOS Settings.
                Section {
                    switch model.authStatus {
                    case .authorized:
                        LabeledContent("Apple Music") {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Connected")
                            }
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
                    Text("Casseti plays from one music service at a time. Apple Music needs a subscription. To disconnect, iOS asks you to switch off Media & Apple Music for Casseti in the Settings app.")
                }

                Section {
                    Toggle("Deck sounds", isOn: $model.soundEffectsOn)
                    Toggle("Tape hiss", isOn: $hissOn)
                        .disabled(!model.soundEffectsOn)
                } header: {
                    Text("Sound")
                } footer: {
                    Text("Deck sounds are the clunk of the keys, the cassette door, and the motor while a tape winds or stops. Tape hiss is the soft noise under the music while a tape plays. Both play on top of your music and are not silenced by the mute switch, so turn them off here if you want quiet.")
                }

                Section {
                    Toggle("Haptics", isOn: $hapticsOn)
                    Toggle("Tap along with the music", isOn: $beatHapticsOn)
                        .disabled(!hapticsOn)
                    if beatHapticsOn, hapticsOn {
                        // How hard each tap lands. Letting go gives one tap
                        // at the chosen strength, to feel it.
                        HStack(spacing: 12) {
                            Text("Strength")
                            Slider(value: $beatStrength, in: 0...1) { editing in
                                if !editing { Haptics.beat() }
                            }
                            .accessibilityLabel("Tap strength")
                        }
                    }
                } header: {
                    Text("Haptics")
                } footer: {
                    Text("Haptics are the clicks you feel from the keys, the door and the volume fader. Tap along adds a light tap on each beat while a tape plays, on the tape deck only. It keeps a steady beat and cannot hear the music, so it will not always match the song.")
                }

                Section {
                    Toggle("Glare follows the phone", isOn: $glareOn)
                    Toggle("Level lights in the volume slot", isOn: $levelLightsOn)
                } header: {
                    Text("Display")
                } footer: {
                    Text("Glare is the soft light on the case that shifts as you tilt the phone. The level lights are the row of lamps in the volume slot, which move in time while a tape plays. They are for show and do not measure the music.")
                }

                Section {
                    Toggle("Flip at the end of a side", isOn: $autoFlipOn)
                    Toggle("Tape runs up to speed and down to a stop", isOn: $tapeRampOn)
                    Toggle("Play when a folding phone is closed", isOn: $playOnCloseOn)
                } header: {
                    Text("Playback")
                } footer: {
                    Text("With flipping off, the music stops when a side runs out and you turn the tape over yourself. Running up and down makes the music slur for a moment as the tape starts and stops, as a real deck does. On a folding phone, a tape chosen while it is open starts when you close it.")
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

                Section {
                    Label("Play and stop are a pair. Press one in and the other pops out.", systemImage: "play.fill")
                    Label("Tap fast forward or rewind to skip a song. Hold to wind the tape.", systemImage: "forward.fill")
                    Label("Double-tap the tape to turn it over.", systemImage: "arrow.triangle.2.circlepath")
                    Label("The music key opens your shelf. On a folding phone, open it to choose a tape and close it to start playing.", systemImage: "music.note")
                    if Theme.includesMP3 || Skin.includesClickWheel {
                    Label("On the MP3 player, turn the dial to scroll and press it to choose. The top key goes back, or opens Settings from the first menu.", systemImage: "dial.medium")
                    }
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
                } header: {
                    Text("How the deck works")
                } footer: {
                    Text("The tour walks you through the keys on the tape deck itself. The introduction is the short welcome shown the first time Casseti opens.")
                }

                Section {
                    HStack {
                        Text("Casseti")
                        Spacer()
                        Text(version).foregroundColor(.secondary)
                    }
                    if let url = URL(string: AppLinks.privacyPolicy), !AppLinks.privacyPolicy.isEmpty {
                        Link("Privacy policy", destination: url)
                    }
                    if let url = URL(string: AppLinks.support), !AppLinks.support.isEmpty {
                        Link("Help and support", destination: url)
                    }
                    Button("Email the developer") { AppLinks.contactSupport() }
                } footer: {
                    Text("Something not working, or an idea to share? Write to \(AppLinks.supportEmail). Music is played by your music service and needs its subscription.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: iCloudOn) { _, _ in
                model.syncWithCloud()
            }
            .fileExporter(isPresented: $savingBackup, document: backup, contentType: .json,
                          defaultFilename: "Casseti backup") { result in
                if case .failure(let error) = result {
                    backupNote = "The backup could not be saved. \(error.localizedDescription)"
                }
            }
            .fileImporter(isPresented: $choosingBackup, allowedContentTypes: [.json]) { result in
                restore(result)
            }
            .scrollContentBackground(.hidden)
            .background(ShelfBackground())
            // Where there is no rail, Done is in the title bar, which does
            // not scroll away: plain to see and always in reach.
            .toolbar {
                if !hasRail {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") { dismiss() }
                            .fontWeight(.semibold)
                    }
                }
            }
            .confirmationDialog("Disconnect Apple Music?", isPresented: $disconnecting, titleVisibility: .visible) {
                Button("Open Settings") { openSystemSettings() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Only iOS can withdraw access. In Settings, switch off Media & Apple Music for Casseti. The tape in the deck will stop.")
            }
            .alert("Backup", isPresented: backupNoteShown) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(backupNote ?? "")
            }
        }
        // On the Duo, Done sits in the rail under the clock and stays put
        // however far the page is scrolled.
        .overlay {
            GeometryReader { geo in
                let rail = geo.safeAreaInsets.trailing
                Color.clear.onChange(of: rail >= 60, initial: true) { _, has in hasRail = has }
                if rail >= 60 {
                    doneKey
                        .frame(width: min(72, rail - 12))
                        .position(x: geo.size.width + rail / 2,
                                  // The clock takes less of the rail on the open phone
                                  y: (geo.size.width > geo.size.height ? 122 : 180) - geo.safeAreaInsets.top + 24)
                }
            }
        }
    }

    /// The Duo's rail is on screen, and Done sits in it.
    @State private var hasRail = false
    @Environment(\.horizontalSizeClass) private var horizontalSize
    /// A wide screen: the open folding phone.
    private var wide: Bool { horizontalSize == .regular }

    /// The key that closes Settings.
    private var doneKey: some View {
        Button {
            dismiss()
        } label: {
            Text("Done")
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        // A plain system button: it is not part of the player.
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
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
