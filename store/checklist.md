# Getting Casseti on sale: what is done and what is left

## Done in this repository

* **Privacy manifest.** `PrivacyInfo.xcprivacy` in the app, declaring no tracking, no data collection, and the app's use of stored settings.
* **Export compliance.** The app declares it uses no non-exempt encryption, so App Store Connect will not ask each time.
* **No silent background audio.** The app pauses its audio engine whenever nothing audible is playing in the background. There is no lock screen widget; the system's own media controls are used.
* **Click-wheel skins held back.** They are built but switched off for the store build (see Risks).
* **App icon.** In the project, with the dark and tinted versions newer iPhones can show. A copy is in this folder as `app-icon-1024.png`.
* **Settings reachable everywhere.** Every screen and theme has a way to Settings, where the theme is changed.
* **Listing text, privacy policy and review notes.** In this folder.

## Left for you, in order

1. **Join the Apple Developer Program** if you have not ($99 a year). Selling requires it.
2. **Sign the Paid Apps agreement** in App Store Connect, under Business, and enter your bank and tax details. Without it a paid app cannot go on sale.
3. **Get the app building.** Done: the app builds in Debug and Release with no warnings and runs on a real iPhone Duo.
4. **Test on a real phone** with an Apple Music subscription: playing, flipping, winding, the open-phone boombox, and settings sync between two devices.
5. **Turn on MusicKit** (under App Services) for the app ID `com.rogerseng.tapedeck` at developer.apple.com, and check iCloud is on for it.
6. **Take real screenshots** (see `listing.md`).
7. **Put the website online.** Buy casseti.com and publish the `website` folder to it, following `website/README.md`. It carries the privacy policy and support pages Apple requires. The app's Settings already links to them. Set up the `support@casseti.com` address, or change it in the pages.
8. **Create the app in App Store Connect**: paste in the listing, set the price to $4.99, answer the age rating and privacy questions, add the review notes.
9. **Archive and upload** from Xcode, then submit for review.

## Risks to know about before you submit

**A paid app that plays Apple Music.** Apple's rules say an app may not "require payment or indirectly monetize access to the Apple Music service". Paid Apple Music players are on the store today, so a purchase price for the app itself has been accepted. But the rule is worded broadly and a reviewer could read it against you. The review notes make the case. If it is rejected on this point, the fallback is a free app with a one-time purchase that unlocks extras which have nothing to do with playback, such as skins.

**Background audio.** The app keeps the audio background mode so the tape hiss carries on with the music. Reviewers sometimes question this mode. The review notes explain it. If it is refused, the fallback is to remove the mode, which means no hiss in the background.

**The MP3 player.** It was redesigned so it does not look like an iPod: a jog dial with no buttons on it, separate keys, an amber display, and Casseti's own case colours. That removes the obvious reason for a rejection but does not guarantee approval. Do not call it an iPod, or compare it to one, anywhere in the listing.

**Click-wheel skins.** Apple has removed apps whose players looked like the iPod. The two click-wheel skins are Casseti's own drawing and do not use the iPod name or Apple's graphics, but the resemblance is the point of them. They are left out of the build you archive for the App Store automatically, and included when you run the app from Xcode onto your own phone. Before uploading, check the theme list in the archived build shows only the four tape decks (Retro 80s, Black, Yellow, Blue) and the two MP3 players (Retro 80s, Black), with no Click wheel group.

**Other companies' names.** Do not use "Walkman", "iPod", "Maxell" or similar in the name, subtitle, screenshots or description. The listing text here avoids them.

**iPhone Duo measurements.** The layout for the Duo's closed screen is built from published figures and one screenshot, not from a device. Check it on a real Duo or in Xcode's Duo simulator before submitting.

**The level lights.** They pulse while music plays but do not follow the music, because apps cannot hear Apple Music's audio. The app's settings say so. Do not describe them in the listing as a real level meter.
