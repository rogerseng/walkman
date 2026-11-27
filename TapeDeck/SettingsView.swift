import SwiftUI

/// The few things worth switching, and a reminder of how the deck works.
struct SettingsView: View {
    @EnvironmentObject private var model: PlayerModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Haptics.settingKey) private var hapticsOn = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Tape deck sounds", isOn: $model.soundEffectsOn)
                    Toggle("Haptics", isOn: $hapticsOn)
                } footer: {
                    Text("Sounds are the key clunks, the door, tape hiss and the motor while winding. They play over the music and are not silenced by the mute switch.")
                }

                Section("How the deck works") {
                    Label("Double-tap the tape to turn it over.", systemImage: "arrow.triangle.2.circlepath")
                    Label("Tap fast forward or rewind to skip a song. Hold to wind the tape.", systemImage: "forward.fill")
                    Label("When a side runs out the music stops. Flip the tape to carry on.", systemImage: "stop.circle")
                    Label("Open the phone to choose a tape, then close it to start playing.", systemImage: "rectangle.portrait.on.rectangle.portrait")
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
}
