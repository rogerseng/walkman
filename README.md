# Casseti

A cassette player for Apple Music. Your playlists and albums are tapes on a shelf. Pick one and it drops into the deck, the reels turn, and the keys clunk.

## What it does

* Plays your Apple Music library and anything from the Apple Music catalogue (MusicKit).
* Closed phone (or any ordinary phone screen): the whole screen is the body of a tape player with the cassette inside it. The cassette is as large as the screen allows and runs underneath the body and the keys. The smoked casing covers most of it, dimly showing what is underneath, and a clear window over the label and reels shows the tape itself. The look is eighties throughout: the Neon theme (deep purple, hot pink keys, a five colour stripe) is the default, and the Smoke and Yellow themes are there for a plainer deck. Glare on the body moves only when the phone moves: reflections slide as it tilts left and right, and a hot spot follows both tilts.
* Built for the iPhone Duo's outer display, 466 x 678 points. iOS reserves an 84 point column down one side for the camera, clock and status icons; six large keys (play, stop, fast forward, rewind, tape library, settings) sit in that column underneath them, on a solid plastic panel that is not see-through. Play and stop are a latching pair: pressing one in lets the other out. Stop holds the tape where it is. Play is orange, settings is black, and the library key carries the two-note music mark. On other phones the keys get their own strip. The panel, keys and fader are drawn as moulded parts: grained plastic, keys that stand proud of wells cut into the panel and sink when pressed, engraved symbols, and a metal fader cap in a recessed slot. The solid panel's inner edge is a shallow curve that comes closest to the tape window at mid height. A vertical volume fader stands on the panel beside the keys, exactly as tall as the window. Inside its slot a ladder of amber level lights is lit from the bottom up to the knob, never past it, and pulses while a tape plays. The pulse is for show: Apple Music does not let an app read the audio. The name Casseti is moulded faintly into the top left corner of the case. It sets the phone's volume and follows the side buttons.
* Haptics: a firm tap when a key goes down, a lighter one when it springs back, a heavy thud for the cassette door, and a soft pulse four times a second while the tape winds.
* The cassette is a clear one, built in layers. At the back is the inside of the shell: the slip sheet, the wells the reels turn in, the steel shield and the pressure pad's spring. On that sit the reels of wound tape, drawn turn upon turn, with clear hubs and the tape running down to the rollers. Over them is the see-through front: bright moulded edges and ridges, stickers, a label strip, guide rollers, black screws, hairline scratches and reflections. The artwork source is `tools/cassette-art.html`; `node tools/render-art.js` re-renders it.
* Open phone (a large, wide screen): the tape shelf on the left and the chosen tape on the right. The shelf shows each playlist and album as a cassette spine: an off-white card with the name handwritten on it and a band in one of the five stripe colours, on a deep purple shelf. Pick a tape, then close the phone to start it playing. The same keys as on the closed phone are there in a row (play, stop, fast forward, rewind, eject, settings), for screens that cannot fold.
* It behaves like tape. The reels show where you are on the whole side, not in the current song: the left pack shrinks and the right one grows across the side, and each reel turns at the rate its pack size calls for.
* Two sides. Every album and playlist is split into side A and side B of about equal length. When a side runs out the play key pops up and the music stops. Double-tap the tape to turn it over. Turn it over part way through and, as with a real cassette, you land as far from the end of the other side as you were from the start of this one.
* Labels come from the music. An album tape has a printed label with the album's title and artist, in the colours of its cover art, and the clear shell is tinted the same colour. The song that is playing is shown on the casing under the window. Playlists and mixtapes have a paper label with the name and current track written by hand.
* Winding. Tap fast forward or rewind to skip a song. Hold either and the deck winds the tape as an old one would: the music stops, the reels spin up to speed, and the tape runs on through song after song until you let go or it runs out. Music picks up from wherever the tape stopped.
* Tape deck sounds: key clunks, door and eject, tape hiss while playing, motor whir while winding. They are generated in code and mix over the music. The speaker button on the deck turns them off. They are not muted by the silent switch, because the app has to hold a playback audio session to stay awake behind the lock screen.

## First run

The first time it opens, Casseti shows a four page introduction: what it is, how the deck works, connecting Apple Music, and a few starting choices (iCloud sync, the lock screen tape, and the skin). It can be skipped, and shown again from Settings.

## Themes

A theme is what the closed phone looks like: which player it is and what colour its case is. Pick one in Settings, under Theme, or on the last page of the introduction. Every theme plays the same tapes, with the same two sides, flipping and mixtapes.

| Theme | What it is |
| --- | --- |
| Tape deck, Black | The cassette and its reels behind a window in dark smoked plastic, with the volume fader and keys beside it. |
| Tape deck, Yellow | The same in bright yellow with dark engraved lettering. |
| Tape deck, Blue | Blue painted metal with a silver side for the keys and a red play key. |
| Tape deck, Retro 80s | Eighties neon: deep purple, a glowing pink and cyan window, a hot pink play key and a band of stripes. |
| MP3 player, Black | A display of menus and a white jog dial, in dark plastic. |
| MP3 player, Retro 80s | The same in purple, with cyan lettering on the display and a pink highlight. |
| Click wheel, Black | A screen above a click wheel. Xcode builds only. |
| Click wheel, Silver | The same in silver with a white wheel. Xcode builds only. |

On the MP3 player, turn the dial to scroll and press it to choose. While a song is showing, the dial changes the volume and a press plays or pauses. The four keys beside it are back, play/pause, previous and next; hold previous or next to wind the tape. Its menus are Music (Mixtapes, Playlists, Albums), Now Playing, Flip Tape, and Settings and Themes. It is Casseti's own design: a knurled dial with no buttons on it, keys set apart, and an amber display.

The two click wheel themes resemble the iPod closely enough to risk rejection from the App Store, so they are for your own phone only. They appear when the app is run from Xcode onto a device (a Debug build) and are left out of the build archived for the App Store (a Release build). The switch is `includesClickWheel` in `Skin.swift`.

On a pale case a dark plate sits behind the Duo's clock so it stays readable. Themes apply to the closed screen.

### Getting to Settings and themes from anywhere

| Where you are | How to get to Settings |
| --- | --- |
| Tape deck | The black key with the gear, at the foot of the keys. |
| MP3 player or click wheel | "Settings and Themes" in the main menu. Press back (or MENU) until you reach it. |
| Open phone | The black key with the gear in the row of keys, or the gear at the top of the tape shelf. |
| Tape shelf | The gear at the top right. |

## Settings

Opened from the black key at the foot of the column.

| Setting | What it does | Starts |
| --- | --- | --- |
| Deck sounds | Key clunks, door, motor while winding | On |
| Tape hiss | The soft noise under the music | On |
| Haptics | Taps for keys, door, fader and winding | On |
| Glare follows the phone | Reflections move as the phone tilts | On |
| Level lights in the volume slot | The amber lights under the knob | On |
| Play when the phone is closed | A tape chosen with the phone open starts when it shuts | On |
| Flip at the end of a side | Turns the tape over by itself when a side runs out | Off |
| Sync with iCloud | Keeps settings the same across your devices | On |

Settings also shows whether Apple Music is connected, with a button to connect or to open the system settings, and a short guide to the deck.

## iCloud sync and backup

* Sync. Settings are kept in iCloud's key-value store and merged on every device signed in to the same account. If two devices have changed the same mixtape, the more recent change wins. A deleted mixtape stays deleted everywhere. The sync switch itself is per device.
* Backup file. Settings has "Save a backup file", which writes one JSON file holding the settings to wherever you choose: Files, iCloud Drive, AirDrop and so on. "Restore from a backup file" reads one back. Restoring sets the settings to the backup's and brings back its mixtapes, keeping any made since.
* Not covered: your Apple Music library and playlists, which Apple Music keeps itself, and which tape was in the deck.

Sync needs the iCloud capability on the app's identifier. The project carries the entitlement in `Config/TapeDeck.entitlements`; with automatic signing Xcode registers it when you pick your team.

## Selling it

The `store/` folder has what is needed to put Casseti on the App Store at $4.99: the listing text, a privacy policy, notes for App Review, and a checklist of what is done and what is left, including the risks to know about before submitting. Start with `store/checklist.md`.

## Website

The `website` folder is the site for casseti.com: a home page, the support page and the privacy policy, in flat bands of colour to match the app icon. It is plain files with nothing to build. `website/README.md` says how to put it online.

## Running it on your iPhone

You need a Mac with Xcode 16 or later, an Apple Music subscription on the phone, and an Apple Developer Program membership (MusicKit needs it).

1. Open `TapeDeck.xcodeproj` in Xcode. (The project and its folders keep the working name TapeDeck; the app installs as Casseti.)
2. Select the TapeDeck target, open Signing & Capabilities, and choose your team. If Xcode says a bundle identifier is taken, change both, keeping the widget one as the app one plus `.widgets`.
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
| `TapeSounds.swift` | Synthesised sound effects |
| `CassetteView.swift` | The cassette and its reels |
| `DeckView.swift` | The closed phone: player body, cassette door and key strip |
| `OpenTrayView.swift` | The open phone's right half, where the chosen tape waits |
| `GlassShimmer.swift` | The glare on the case, driven by the motion sensor |
| `Haptics.swift` | The taps for keys, door, fader and winding |
| `SettingsView.swift` | The settings screen |
| `Prefs.swift` | The stored settings and their defaults |
| `Skin.swift` | The case colours |
| `Theme.swift` | The themes people choose from, the theme list, and the web links shown in Settings |
| `MenuPlayerView.swift` | The MP3 player: its display, menus and jog dial (and the click-wheel form kept for personal builds) |
| `OnboardingView.swift` | The first-run introduction |
| `CloudSync.swift` | iCloud sync of mixtapes and settings, and the backup file format |
| `VolumeFader.swift` | The vertical volume fader and its link to the system volume |
| `ShelfView.swift` | The tape shelf and search |
| `tools/make_reel_font.py` | Regenerates the reel font |
| `Config/` | Info.plist additions for the two targets |
