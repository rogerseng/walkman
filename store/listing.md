# App Store listing for Casseti

Paste these into App Store Connect. Character limits are Apple's.

## Basics

| Field | Value |
| --- | --- |
| Name (30) | Casseti |
| Subtitle (30) | A tape deck for your music |
| Primary category | Music |
| Secondary category | Entertainment |
| Price | $4.99 (USD), one-time purchase |
| Copyright | 2026 ROGER SENG STUDIOS LLC |

The subtitle avoids the words "Apple Music" on purpose. Apple asks developers not to put its trademarks in an app's name or subtitle. The description may say the app works with Apple Music.

## Promotional text (170)

Your albums and playlists, on tape. Two sides, real reels, keys that clunk. Flip the tape when side A runs out.

## Description (4000)

Casseti turns your music into cassettes.

Browse your library by playlist, artist, album or song, or search all of Apple Music. Whatever you pick becomes a tape with two sides. Drop it in, press play, and watch the reels turn. When side A runs out the play key pops up and the music stops. Flip the tape to carry on.

A REAL DECK
• Play and stop are a pair of keys. Press one in and the other pops out.
• Tap fast forward or rewind to skip a song. Hold to wind the tape, reels spinning, until you let go.
• The reels show how much of the side is left, not just the current song.
• A volume fader with level lights, right on the player.
• The tape runs up to speed when you press play and slows to a stop when you press stop.
• Key clunks, the door, tape hiss and the whir of the motor. Turn them off if you prefer quiet.
• Haptics for every key, the door and the fader.

YOUR TAPES
• Every tape is labelled in marker pen. Albums wear a label in the colours of their cover art.
• Open an album or playlist to see its songs, and start the tape at any one of them.

DESIGNED FOR IPHONE DUO AND IPHONE
• On iPhone Duo, closed, the whole cover screen is the player.
• Open, your tape shelf is on one side and the tape on the other. Choose one and close the phone to start it playing.
• Works fully on every iPhone.

MORE
• Retro 80s, black, yellow or blue. The colours carry through the whole app.
• A hands-on tour teaches the keys by having you press them.
• Open an iPhone Duo and the player becomes a tape recorder, with a speaker grille, the tape behind a tinted door, and a row of chunky keys.
• Your settings sync with iCloud.

Casseti plays music from Apple Music. An Apple Music subscription is required.

## Keywords (100)

cassette,retro,player,vintage,80s,album,reels,analog,hifi,boombox,nostalgia,lofi,stereo,playlist

No other company's names are in the keywords. Words already in the name and subtitle (tape, deck, music) are left out because Apple indexes those anyway.

## URLs you must supply

| Field | What it needs |
| --- | --- |
| Support URL | `https://casseti.com/support.html` |
| Privacy Policy URL | `https://casseti.com/privacy.html` |
| Marketing URL | `https://casseti.com` |

These pages are in the `website` folder and need putting online first. See `website/README.md`.

## Age rating

Casseti has no content of its own, but it plays whatever is in the buyer's Apple Music, which can include explicit songs. Suggested answers:

| Question | Answer |
| --- | --- |
| Violence, sexual content, nudity, horror, gambling, contests, drugs, medical | None for every one |
| Profanity or crude humour | Infrequent or mild (songs can contain it) |
| Mature or suggestive themes | Infrequent or mild (songs can contain it) |
| Unrestricted web access | No |
| User-generated content, messaging, chat | No |
| Advertising | No |

The phone's own content restrictions for explicit music still apply inside Casseti.

## Content rights

App Store Connect asks whether the app contains or accesses third-party content. Answer yes, and that you have the rights: the music is played through Apple's MusicKit with the listener's own Apple Music subscription.

## Device support

iPhone only. The project is set to iPhone, so App Store Connect asks only for iPhone screenshots.

## Screenshots

Apple needs real screenshots taken from the running app, at the sizes it lists for iPhone. Ready-made pictures with headlines are in `store/screenshots`, made from the running app by `tools/store-shots.sh`. They show:

1. The closed tape deck in Retro 80s with an album tape playing.
2. The tape deck in Black, Yellow and Blue.
3. The deck eating a tape.
4. The open screen with the tape shelf.
5. The library: playlists, artists, albums and songs.
6. The open folding phone: the album's songs beside the player.

## App privacy answers ("nutrition label")

Data collected: none. Casseti has no accounts, no analytics and no advertising, and sends nothing to its developer. Settings stay on the device and in the buyer's own iCloud.
