# Notes for App Review

Paste this into "App Review Information, Notes" when you submit.

---

Casseti is a music player that presents Apple Music albums and playlists as cassette tapes.

**To test it you need an Apple Music subscription** on the test device, signed in. On first launch, go through the introduction and tap "Connect Apple Music". A short hands-on tour then starts on the player: it asks you to press each key in turn, and "End tour" on its card leaves it at any time. To play something, press the key with the music note to open the library, pick any album, and it will play.

**Payment and Apple Music (guideline 4.5.2).** The purchase price is for the app itself: its player interface, themes and effects. It does not sell, unlock or meter access to Apple Music. Music playback uses MusicKit and requires the user's own Apple Music subscription. There are no in-app purchases, no advertising and no data collection.

**Background audio (guideline 2.5.4).** The app declares the audio background mode for two user-facing reasons. Music continues to play when the app is in the background. And the app plays an audible tape-hiss effect under the music, mixed with it, which continues in the background along with the music. The effect can be heard by turning the volume up while a tape plays, and can be switched off in the app's settings under Sound. The app never plays silent audio: when nothing audible is playing in the background, its audio engine is paused.

**iCloud.** The app uses iCloud key-value storage to sync the user's settings between their own devices.

**Motion.** Device motion is used only to move reflections on the on-screen player.

**Folding iPhone.** The app adapts to the closed and open displays of iPhone Duo and also runs on every other iPhone. It is an iPhone-only app.

**Contact.** Roger Sengthavychith, support@casseti.com.
