import MusicKit
import SwiftUI
import UIKit

/// Everything that can be switched, how the deck works, and what the app is.
struct SettingsView: View {
    @EnvironmentObject private var model: PlayerModel
    @Environment(\.dismiss) private var dismiss

    @AppStorage(Prefs.hiss) private var hissOn = true
    @AppStorage(Prefs.haptics) private var hapticsOn = true
    @AppStorage(Prefs.glare) private var glareOn = true
    @AppStorage(Prefs.levelLights) private var levelLightsOn = true
    @AppStorage(Prefs.playOnClose) private var playOnCloseOn = true
    @AppStorage(Prefs.autoFlip) private var autoFlipOn = false
    @AppStorage(Prefs.lockScreenTape) private var lockScreenTapeOn = true

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
                    Text("To show it, Cassety stays awake in the background while a tape is in.")
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
                }

                Section {
                    HStack {
                        Text("Cassety")
                        Spacer()
                        Text(version).foregroundColor(.secondary)
                    }
                } footer: {
                    Text("Music is played by Apple Music and needs a subscription.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let number = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(number) (\(build))"
    }
}
