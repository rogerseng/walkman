# TapeDeck

A cassette player for Apple Music. Your playlists and albums are tapes on a shelf. Pick one and it drops into the deck, the reels turn, and the keys clunk.

## What it does

* Plays your Apple Music library and anything from the Apple Music catalogue (MusicKit).
* Closed phone (or any ordinary phone screen): the whole screen is the body of a tape player with the cassette inside it. The cassette is as large as the screen allows and runs underneath the body and the keys. The smoked casing covers most of it, dimly showing what is underneath, and a clear window over the label and reels shows the tape itself. Colours are neutral throughout: greys, black and off-white. Glare on the body moves only when the phone moves: reflections slide as it tilts left and right, and a hot spot follows both tilts.
* Built for the iPhone Duo's outer display, 466 x 678 points. iOS reserves an 84 point column down one side for the camera, clock and status icons; five large keys (play/pause, fast forward, rewind, tape library, settings) sit in that column underneath them, on a solid plastic panel that is not see-through. There is no stop key: pause stops the music and keeps your place. On other phones the keys get their own strip. The solid panel's inner edge is a shallow curve that comes closest to the tape window at mid height. A vertical volume fader stands on the panel beside the keys, exactly as tall as the window. Settings has switches for the tape deck sounds and the haptics. It sets the phone's volume and follows the side buttons.
* Haptics: a firm tap when a key goes down, a lighter one when it springs back, a heavy thud for the cassette door, and a soft pulse four times a second while the tape winds.
* The cassette is a clear one. The shell front is see-through artwork (bright moulded edges and ridges, stickers, a stick-on paper label, guide rollers, black screws, reflections). Under it the whole reels, their clear hubs, the tape running down to the rollers and the handwriting on the label are drawn live. The artwork source is `tools/cassette-art.html`; `node tools/render-art.js` re-renders it.
* Open phone (a large, wide screen): the tape shelf on the left and the chosen tape on the right. The shelf shows each playlist and album as a cassette spine: an off-white card with the name handwritten on it and a grey band. Pick a tape, then close the phone to start it playing. The same keys as on the closed phone are there in a row (play/pause, fast forward, rewind, eject, settings), for screens that cannot fold.
* It behaves like tape. The reels show where you are on the whole side, not in the current song: the left pack shrinks and the right one grows across the side, and each reel turns at the rate its pack size calls for.
* Two sides. Every album and playlist is split into side A and side B of about equal length. When a side runs out the play key pops up and the music stops. Double-tap the tape to turn it over. Turn it over part way through and, as with a real cassette, you land as far from the end of the other side as you were from the start of this one.
* Mixtapes. Pick a blank C-60 or C-90, name it, and add songs from Apple Music to each side until the tape is full. A song that is too long for the tape left on a side cannot be added. Mixtapes are kept on the phone.
* Labels come from the music. An album tape has a printed label with the album's title and artist, in the colours of its cover art, and the clear shell is tinted the same colour. The song that is playing is shown on the casing under the window. Playlists and mixtapes have a paper label with the name and current track written by hand.
* Keys: REW and FF skip a track on a tap and wind the tape on a hold. PLAY and PAUSE latch down. STOP stops, and a second press ejects.
* Lock screen tape: while a tape is in the deck, a Live Activity shows the same clear cassette on the lock screen (and its reels in the Dynamic Island) with previous, play / pause and next keys. The hubs step round once a second, because iOS does not allow free running animation there. A tape left paused for ten minutes is taken off the lock screen.
* Tape deck sounds: key clunks, door and eject, tape hiss while playing, motor whir while winding. They are generated in code and mix over the music. The speaker button on the deck turns them off. They are not muted by the silent switch, because the app has to hold a playback audio session to stay awake behind the lock screen.

## Running it on your iPhone

You need a Mac with Xcode 16 or later, an Apple Music subscription on the phone, and an Apple Developer Program membership (MusicKit needs it).

1. Open `TapeDeck.xcodeproj` in Xcode.
2. Select the TapeDeck target, open Signing & Capabilities, and choose your team. Do the same for the TapeDeckWidgets target. If Xcode says a bundle identifier is taken, change both, keeping the widget one as the app one plus `.widgets`.
3. Go to developer.apple.com, Certificates, Identifiers & Profiles, Identifiers. Open the identifier for your bundle ID, choose the App Services tab, tick MusicKit, and save.
4. Plug in your iPhone, choose it as the run destination, and press Run.
5. On first launch, open the shelf and tap Connect Apple Music.

Music does not play in the Simulator. Use a real device.

## iPhone Duo measurements used

These came from developer write-ups, not from a device, so check them in Xcode's Duo simulator.

* Outer display: 466 x 678 points at 3x (Apple lists 1398 x 2034 pixels, 5.4 inches).
* Outer safe area: 84 points on the side with the camera, 34 at the bottom, none at the top. The app reads these from the system, so it follows whatever the device reports.
* Key column: keys 66 points wide and up to 84 tall, centred 48 points in from the screen edge. `railStatusHeight` in `DeckView.swift` (180 points) is how far down the keys start, to clear the camera and clock. It was measured from a screenshot of another app on a Duo, where the status pill ends about 154 points down.
* Inner display: reported as 669 x 951 or 626 x 890 points, regular in both size classes. The app treats either as open.

## Layout of the code

| File | What is in it |
| --- | --- |
| `TapeDeckApp.swift` | App entry and the closed / open layout switch |
| `PlayerModel.swift` | Apple Music access, library, search, playback, sides, flipping and key handling |
| `TapeModels.swift` | Tapes, their two sides, mixtapes and where mixtapes are stored |
| `MixtapeEditor.swift` | Recording and editing a mixtape |
| `TapeSounds.swift` | Synthesised sound effects |
| `CassetteView.swift` | The cassette and its reels |
| `DeckView.swift` | The closed phone: player body, cassette door and key strip |
| `OpenTrayView.swift` | The open phone's right half, where the chosen tape waits |
| `GlassShimmer.swift` | The glare on the case, driven by the motion sensor |
| `Haptics.swift` | The taps for keys, door, fader and winding |
| `SettingsView.swift` | Switches for sounds and haptics, and how the deck works |
| `VolumeFader.swift` | The vertical volume fader and its link to the system volume |
| `ShelfView.swift` | The tape shelf and search |
| `LockScreenTape.swift` | Starts and updates the lock screen Live Activity |
| `Shared/TapeActivity.swift` | Data and key actions shared by the app and the widget extension |
| `TapeDeckWidgets/` | The lock screen and Dynamic Island views, and the reel font |
| `tools/make_reel_font.py` | Regenerates the reel font |
| `Config/` | Info.plist additions for the two targets |
