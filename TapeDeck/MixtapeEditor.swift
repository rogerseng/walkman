import SwiftUI

/// Recording a mixtape: name it, pick a blank, and add songs to each side
/// until the tape is full. A song that is longer than the tape left on the
/// side cannot be added.
struct MixtapeEditor: View {
    @EnvironmentObject private var model: PlayerModel
    @Environment(\.dismiss) private var dismiss

    @State var mixtape: Mixtape
    @State private var side = 0
    @State private var term = ""
    @State private var results: [MixSong] = []

    var body: some View {
        NavigationStack {
            List {
                Section("Tape") {
                    TextField("Name", text: $mixtape.name)
                    Picker("Blank", selection: $mixtape.minutesPerSide) {
                        Text("C-60, 30 minutes a side").tag(30)
                        Text("C-90, 45 minutes a side").tag(45)
                    }
                }

                Section("Recorded") {
                    Picker("Side", selection: $side) {
                        Text("Side A").tag(0)
                        Text("Side B").tag(1)
                    }
                    .pickerStyle(.segmented)

                    TapeGauge(used: mixtape.used(onSide: side), length: mixtape.sideLength)

                    if mixtape.songs(onSide: side).isEmpty {
                        Text("Nothing recorded on this side yet.")
                            .foregroundColor(.secondary)
                    }
                    ForEach(mixtape.songs(onSide: side)) { song in
                        SongRow(song: song, trailing: nil)
                    }
                    .onDelete { offsets in
                        change { $0.remove(atOffsets: offsets) }
                    }
                    .onMove { from, to in
                        change { $0.move(fromOffsets: from, toOffset: to) }
                    }
                }

                Section("Add songs to side \(side == 0 ? "A" : "B")") {
                    TextField("Search Apple Music", text: $term)
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                    ForEach(results) { song in
                        let fits = mixtape.fits(song, onSide: side)
                        Button {
                            Haptics.keyDown()
                            change { $0.append(song) }
                        } label: {
                            SongRow(song: song, trailing: fits ? "plus.circle.fill" : "xmark.circle")
                        }
                        .disabled(!fits)
                        .accessibilityHint(fits ? "Adds this song to the tape" : "Too long for the tape left on this side")
                    }
                }
            }
            .navigationTitle(mixtape.name.isEmpty ? "New Mixtape" : mixtape.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        model.save(mixtape)
                        dismiss()
                    }
                    .disabled(mixtape.sideA.isEmpty && mixtape.sideB.isEmpty)
                }
            }
            .task(id: term) {
                // Wait for a pause in typing before searching.
                do { try await Task.sleep(nanoseconds: 400_000_000) } catch { return }
                let found = await model.searchSongs(term)
                if !Task.isCancelled { results = found }
            }
            .onChange(of: mixtape.minutesPerSide) { _, _ in
                // A shorter blank holds less: drop what no longer fits, from the end.
                for index in 0...1 {
                    while mixtape.used(onSide: index) > mixtape.sideLength, !mixtape.songs(onSide: index).isEmpty {
                        if index == 0 { mixtape.sideA.removeLast() } else { mixtape.sideB.removeLast() }
                    }
                }
            }
        }
    }

    /// Applies a change to whichever side is showing.
    private func change(_ edit: (inout [MixSong]) -> Void) {
        if side == 0 {
            edit(&mixtape.sideA)
        } else {
            edit(&mixtape.sideB)
        }
    }
}

private struct SongRow: View {
    let song: MixSong
    /// A symbol at the end of the row, if any.
    let trailing: String?

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(song.title)
                Text(song.artist).font(.footnote).foregroundColor(.secondary)
            }
            .lineLimit(1)
            Spacer(minLength: 0)
            Text(clock(song.duration))
                .font(.footnote.monospacedDigit())
                .foregroundColor(.secondary)
            if let trailing {
                Image(systemName: trailing)
            }
        }
    }
}

/// How much of one side is recorded, as a bar of tape.
private struct TapeGauge: View {
    let used: TimeInterval
    let length: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(white: 0.22))
                    Capsule()
                        .fill(Color(white: 0.85))
                        .frame(width: geo.size.width * CGFloat(min(1, max(0, used / max(1, length)))))
                }
            }
            .frame(height: 8)
            Text("\(clock(used)) recorded, \(clock(max(0, length - used))) of tape left")
                .font(.footnote.monospacedDigit())
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

private func clock(_ time: TimeInterval) -> String {
    let total = Int(max(time, 0).rounded())
    return String(format: "%d:%02d", total / 60, total % 60)
}
