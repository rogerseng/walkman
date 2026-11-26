# TapeDeck

A cassette player for Apple Music. Your playlists and albums are tapes on a shelf. Pick one and it drops into the deck, the reels turn, and the keys clunk.

## What it does

* Plays your Apple Music library and anything from the Apple Music catalogue (MusicKit).
* Closed phone (or any ordinary phone screen): a tape player with a clear case. The cassette stands on end and fills the whole screen with its reels spinning. Over it sits the see-through shell, with a reflection that slides as you tilt the phone and a glint that sweeps across every few seconds. The two round buttons and the strip of five keys down the right edge are frosted clear plastic, so the tape shows through underneath them. Volume is on the phone's own buttons.
* The cassette is a clear one. The shell front is see-through artwork (bright moulded edges and ridges, stickers, a stick-on paper label, guide rollers, black screws, reflections). Under it the whole reels, their clear hubs, the tape running down to the rollers and the handwriting on the label are drawn live. The artwork source is `tools/cassette-art.html`; `node tools/render-art.js` re-renders it.
* Open phone (a large, wide screen): the tape shelf on the left and the chosen tape on the right. Pick a tape, then close the phone to start it playing. The keys are there too, for screens that cannot fold.
* The reels behave like a real tape. The left pack shrinks and the right one grows as the track plays, and each reel turns at the rate its pack size calls for.
* Keys: REW and FF skip a track on a tap and wind the tape on a hold. PLAY and PAUSE latch down. STOP stops, and a second press ejects.
* Lock screen tape: while a tape is in the deck, a Live Activity shows the cassette on the lock screen (and in the Dynamic Island) with previous, play / pause and next keys. The reels step round once a second, because iOS does not allow free running animation there. A tape left paused for ten minutes is taken off the lock screen.
* Tape deck sounds: key clunks, door and eject, tape hiss while playing, motor whir while winding. They are generated in code and mix over the music. The speaker button on the deck turns them off. They are not muted by the silent switch, because the app has to hold a playback audio session to stay awake behind the lock screen.

## Running it on your iPhone

You need a Mac with Xcode 16 or later, an Apple Music subscription on the phone, and an Apple Developer Program membership (MusicKit needs it).

1. Open `TapeDeck.xcodeproj` in Xcode.
2. Select the TapeDeck target, open Signing & Capabilities, and choose your team. Do the same for the TapeDeckWidgets target. If Xcode says a bundle identifier is taken, change both, keeping the widget one as the app one plus `.widgets`.
3. Go to developer.apple.com, Certificates, Identifiers & Profiles, Identifiers. Open the identifier for your bundle ID, choose the App Services tab, tick MusicKit, and save.
4. Plug in your iPhone, choose it as the run destination, and press Run.
5. On first launch, open the shelf and tap Connect Apple Music.

Music does not play in the Simulator. Use a real device.

## Layout of the code

| File | What is in it |
| --- | --- |
| `TapeDeckApp.swift` | App entry and the closed / open layout switch |
| `PlayerModel.swift` | Apple Music access, library, search, playback and key handling |
| `TapeSounds.swift` | Synthesised sound effects |
| `CassetteView.swift` | The cassette and its reels |
| `DeckView.swift` | The closed phone: player body, cassette door and key strip |
| `OpenTrayView.swift` | The open phone's right half, where the chosen tape waits |
| `GlassShimmer.swift` | The moving reflection on the door glass, brushed metal and screws |
| `ShelfView.swift` | The tape shelf and search |
| `LockScreenTape.swift` | Starts and updates the lock screen Live Activity |
| `Shared/TapeActivity.swift` | Data and key actions shared by the app and the widget extension |
| `TapeDeckWidgets/` | The lock screen and Dynamic Island views, and the reel font |
| `tools/make_reel_font.py` | Regenerates the reel font |
| `Config/` | Info.plist additions for the two targets |
