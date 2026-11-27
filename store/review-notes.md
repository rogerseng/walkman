# Notes for App Review

Paste this into "App Review Information, Notes" when you submit.

---

Cassety is a music player that presents Apple Music albums and playlists as cassette tapes.

**To test it you need an Apple Music subscription** on the test device, signed in. On first launch, go through the introduction and tap "Connect Apple Music". Then open the tape library (the key with the music note), pick any album, and it will play.

**Payment and Apple Music (guideline 4.5.2).** The purchase price is for the app itself: its player interface, mixtape recording and effects. It does not sell, unlock or meter access to Apple Music. Music playback uses MusicKit and requires the user's own Apple Music subscription. There are no in-app purchases, no advertising and no data collection.

**Background audio (guideline 2.5.4).** The app declares the audio background mode for two user-facing reasons. Music continues to play when the app is in the background. And the app plays an audible tape-hiss effect under the music, mixed with it, which continues in the background along with the music. The effect can be heard by turning the volume up while a tape plays, and can be switched off in the app's settings under Sound. The app never plays silent audio.

**Live Activity.** While a tape is playing, a Live Activity shows the cassette on the Lock Screen with previous, play/pause and next controls.

**iCloud.** The app uses iCloud key-value storage to sync the user's mixtapes and settings between their own devices.

**Motion.** Device motion is used only to move reflections on the on-screen player.

**Folding iPhone.** The app adapts to the closed and open displays of iPhone Duo and also runs on every other iPhone.
