# TapeDeck

A cassette player for Apple Music. Your playlists and albums are tapes on a shelf. Pick one and it drops into the deck, the reels turn, and the keys clunk.

## What it does

* Plays your Apple Music library and anything from the Apple Music catalogue (MusicKit).
* Folded phone or any narrow screen: the whole screen is the player, with the cassette, spinning reels and the transport keys.
* Unfolded or any wide screen: the player on the left and the tape shelf on the right.
* The reels behave like a real tape. The left pack shrinks and the right one grows as the track plays, and each reel turns at the rate its pack size calls for.
* Keys: REW and FF skip a track on a tap and wind the tape on a hold. PLAY and PAUSE latch down. STOP stops, and a second press ejects.
* Tape deck sounds: key clunks, door and eject, tape hiss while playing, motor whir while winding. They are generated in code, mix over the music, and follow the silent switch. The speaker button on the deck turns them off.

## Running it on your iPhone

You need a Mac with Xcode 16 or later, an Apple Music subscription on the phone, and an Apple Developer Program membership (MusicKit needs it).

1. Open `TapeDeck.xcodeproj` in Xcode.
2. Select the TapeDeck target, open Signing & Capabilities, and choose your team. Change the bundle identifier if Xcode says it is taken.
3. Go to developer.apple.com, Certificates, Identifiers & Profiles, Identifiers. Open the identifier for your bundle ID, choose the App Services tab, tick MusicKit, and save.
4. Plug in your iPhone, choose it as the run destination, and press Run.
5. On first launch, open the shelf and tap Connect Apple Music.

Music does not play in the Simulator. Use a real device.

## Layout of the code

| File | What is in it |
| --- | --- |
| `TapeDeckApp.swift` | App entry and the folded / unfolded layout switch |
| `PlayerModel.swift` | Apple Music access, library, search, playback and key handling |
| `TapeSounds.swift` | Synthesised sound effects |
| `CassetteView.swift` | The cassette and its reels |
| `DeckView.swift` | The player body, keys, counter and volume |
| `ShelfView.swift` | The tape shelf and search |
