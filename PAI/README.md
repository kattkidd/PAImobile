# PAI — your personal AI for iPhone

A pocket pAI inspired by the personal AI units from Space Station 14. It's a native iPhone app (SwiftUI) with home-screen and lock-screen widgets.

**What it does**
- **Chat with your pAI** (OpenAI) with **live web search** and source links. It can create reminders and start timers just from you asking ("remind me Friday at 6 to call Sam", "15 minute pasta timer").
- **ID card**: name, what to call you, pronouns, birthday, job, department, home city, interests, notes and a photo. It saves automatically, and the pAI uses it to talk to you.
- **Calendar** with reminders (one-off, daily, weekly, monthly). Reminders arrive as real iPhone notifications, even when the app is closed.
- **Timers**: presets, custom timers, pause/resume, and a stopwatch with laps. You get a notification when a timer is done.
- **Clock and date**, an animated pixel face that reacts (happy, thinking, alert, sleepy), six screen colours and read-aloud voice.
- **Widgets**: small, medium and large Home Screen widgets, plus Lock Screen widgets. They show the face, your next reminders and live timer countdowns.
- **Offline mode** without an API key: time, timers and calendar all still work.

**Straight from Space Station 14** (see CREDITS.md)
- **Two unit types**, switchable any time:
  - **Personal AI**: the pAI device in four chassis (standard, golden, syndicate, potato), with an animated screen and expressive faces.
  - **Station AI**: the AI core with all seven SS14 core displays and holopad holograms. You pick a lawset (Crewsimov, NT Default, Corporate and others); the laws flavour how it talks but never block real help. It gets a random SS14 AI name and speaks with the borg voice.
- **SS14 interface**:
  - SS14 window headers and chamfered buttons, with the green "pressed" state used for tabs.
  - Gold NanoHeading underlines and stripeback banners.
  - SS14's LineEdit fields and checkboxes, plus the Nanotrasen colours and radio-channel colours.
  - The **Noto Sans, Noto Sans Display and Roboto Mono** fonts SS14 uses.
- **The chat reads like SS14 chat**: "Alex says," and "PAI states,". New replies type out like a console.
- **Boot sequence** on launch: a Nanotrasen BIOS log, then the unit's screen powers on. You can turn it off in Settings.
- **First-run onboarding**: choose your unit, "searching for a pAI…", register your ID, upload laws (Station AI), allow alerts and install a mind (API key).
- **Transitions**:
  - Tabs slide in the direction you move, with a CRT scan sweep.
  - Boot and onboarding hand over with a CRT power-on effect.
  - Months slide in the calendar, the ID card flips when you change jobs, and timer digits roll.
  - Switching between pAI and Station AI plays an "intellicard transfer".
- **Sounds (all from SS14)**: see Settings → Sound board for the full list, with a preview button for each.
  - **Talk sounds**: the pAI uses the pAI voice and the Station AI uses the borg voice, each with say/ask/exclaim variants like in-game. Your own messages play the species voice you pick on the ID tab.
  - **Typing**: computer keyboard clacks while you type and during the boot log.
  - **Emotes**: the AI can beep, boop, chime, ping or buzz with the silicon emote sounds. Type `*waves` to emote yourself.
  - **Machines**:
    - microwave beeps for timers
    - ID insert and swipe for your ID card
    - law-board disc insert
    - scan-finish when search results arrive
    - print-and-rip for a new chat
    - stamp for your ID photo
    - airlock deny for a rejected key
  - **Station announcements**: the announcement chime for reminder notifications, the attention sound for laws, and the welcome sound when you finish setup.

**Everything from every fork, at once** (Settings → Customise). Space Station 14, Goob Station, Starlight and Nuclear 14 are merged into one set of options you can mix freely:
- **Quick presets**: one tap applies a server's whole vibe with the SS14 launcher "Connecting…" screen. You can still change anything afterwards.
- **Interface theme**: Nanotrasen, Launcher (SS14 StyleSpace), Starlight or Wasteland terminal. CRT effects and animations can be turned off.
- **Unit**: Personal AI, Station AI or Nuclear 14 Terminal, each with its own chassis, core or terminal model.
- **Personality**: Station standard, Goob chaos, Starlight roleplay or Wasteland survivor.
- **All lawsets** (SS14, Starlight, Delta-V/N14) plus Goob's custom lawboard. **All jobs**, including the wasteland ones. **All 12 accents.**
- **Boot screen** style, **sound pack**, **unit voice** (pAI, borg, AI radio blip, 39 barks or silent), Starlight job radio blips and the Goob highlight ping.

**Your character (ID tab → Edit character)**: an SS14-style Character Setup.
- **35 species**: 11 from SS14, 12 from Goob Station, 10 from Starlight and 2 from Nuclear 14.
- **Appearance**: body type, skin (SS14's human skin-tone slider or a colour), eyes, hair and facial hair with colour, and height/width sliders.
- **Markings** for every category the species allows (tails, horns, frills, wings, ears, snouts, tattoos and more), with per-layer colours.
- **Loadout**: SS14 job loadouts for any job, plus a **wardrobe** to put any item in any slot.
- Everything is layered exactly like the game and lines up per species using SS14's displacement maps. Rotate the character and randomise it.
- **Voice** (37 talk sounds) and **emotes**: type `*scream`, `*laugh`, `*hiss`, `*meow`, `*weh`… in chat (or use the Say button menu) for your species' real emote sounds. `*flip`, `*spin`, `*jump` and `*dance` animate your character.
- Your character appears on your ID card, as your chat avatar and next to your unit on the home screen (tap it to emote).

**Music**: 33 lobby and jukebox tracks from SS14 and the forks in four playlists, plus station ambience loops. Mute from the ♪ button on every screen; play, skip, volume, shuffle and playlists are in Settings → Sound & music.

**Animations**: emotes flip, jump, spin, shake and bounce your character and unit. SS14-style floating popup text appears when you set reminders and timers, save your character or apply a preset.

---

## You don't need a Mac

GitHub's free cloud Macs build the app for you. You then install it from Windows with Sideloadly.

### 1. Get an OpenAI API key (for chat and search)
1. Go to **platform.openai.com** and sign in with your ChatGPT account.
2. Under **Billing**, add a little credit. $5 lasts a long time on the default `gpt-5.4-mini` model.
   ChatGPT Go/Plus subscriptions **do not** include API access. The API is billed separately.
3. Under **API keys**, click **Create new secret key** and copy it. You'll paste it into the app later.

### 2. Build the app on GitHub
1. Make a free account at **github.com**.
2. Install **GitHub Desktop** (desktop.github.com). It's the easiest way to upload this folder, including the hidden `.github` folder.
3. In GitHub Desktop, choose **File → Add local repository**, pick this `PAI` folder, and say yes to "create a repository". Then click **Publish repository**.
   - You can make it **public**: your API key is never in the code. Public repos get unlimited free build minutes.
4. On github.com, open your repo and go to the **Actions** tab. The **Build PAI** job starts automatically (enable Actions if asked). It takes about 5–10 minutes.
5. When it shows a green tick, click the run and download **PAI-ipa** under *Artifacts*. Unzip it to get **PAI.ipa**.

> If the build shows a red ✗, download **build-log**, or copy the red error lines, and send them to Claude to fix.

### 3. Install on your iPhone from Windows (Sideloadly)
1. Install **iTunes** and **iCloud** from **apple.com**. Use the website versions, not the Microsoft Store versions; Sideloadly needs them.
2. Install **Sideloadly** from sideloadly.io.
3. Plug your iPhone into the PC with a cable, then tap **Trust** on the phone.
4. Drag **PAI.ipa** into Sideloadly, enter your Apple ID, and press **Start**.
5. On the iPhone:
   - Go to **Settings → Privacy & Security → Developer Mode**, turn it on and restart.
   - Go to **Settings → General → VPN & Device Management**, tap your Apple ID and choose **Trust**.
6. Open **PAI**, allow notifications, then go to **Settings** in the app and paste your API key.

**Free Apple ID limit:** apps you sideload with a free Apple ID stop opening after **7 days**. Reinstall with Sideloadly to refresh; your data stays. Sideloadly's auto-refresh option can do this over Wi-Fi. A paid Apple Developer account ($99/yr) gives you 1-year installs and TestFlight.

### 4. Add the widgets
- **Home Screen:** long-press an empty spot → **Edit** → **Add Widget** → search **PAI** → pick a size.
- **Lock Screen:** long-press the Lock Screen → **Customize** → **Lock Screen** → tap the widget row → **PAI**.

If the widget shows the face but never your reminders, your sideload setup didn't keep the "App Group" that lets the app and widget share data. Everything inside the app still works. Installing with a paid developer account fixes it.

---

## Using it
- **PAI tab:** clock, face and chat. Try "What's the weather?", "Remind me tomorrow at 9 to take the bins out" or "Set a timer for 20 minutes called laundry".
- **Calendar:** tap a day, then **+** to add a reminder. Tap a reminder to edit it, or long-press it to delete it.
- **Timers:** tap a preset or **Custom timer…**. Switch to **Stopwatch** at the top.
- **ID:** fill it in once, and the pAI will call you by your chosen name and use your city for weather.
- **Settings:** pAI name, screen colour, API key, model, web search, read-aloud, widget help and reset.

## Project layout
```
PAI/
├─ project.yml                 XcodeGen spec (app + widget targets)
├─ .github/workflows/build.yml Cloud build → PAI.ipa
├─ App/                        iPhone app
│  ├─ PAIApp.swift             App entry, boot → onboarding → tabs, transitions
│  ├─ Models/                  Data models + AppStore (saving, chat, tools)
│  ├─ Services/                OpenAI client, notifications, keychain, voice
│  ├─ Views/                   Boot, Onboarding, Home/chat, Calendar, Timers, ID, Settings, SS14 UI kit
│  ├─ Sounds/                  SS14 sounds (CAF)
├─ GameData/                   Generated from SS14 + forks: Character (species, markings, clothing sprites + character.json), Audio (voices, emotes, barks, music + audio.json)
├─ Tools/                      The Python scripts that generated GameData, with per-file licence lists
│  └─ Assets.xcassets          App icon
├─ Widget/PAIWidget.swift      Home/Lock Screen widgets
└─ Shared/                     Code used by both
   ├─ PAIFace.swift            pAI + Station AI unit views, SS14 fonts
   ├─ SS14.xcassets            SS14 sprites (pAI, AI core, holograms, ID cards, job icons, NT logo)
   ├─ SS14Style.swift          SS14 palette, window chrome, shapes
   └─ Fonts/                   Noto Sans, Noto Sans Display, Roboto Mono
```

## Customising
- **Bundle ID:** if Sideloadly or Apple complains the ID is taken, replace `com.yourname` everywhere in `project.yml` and `Shared/SharedModels.swift` (the `appGroup` line) with something unique, like `com.yourname123`.
- **Model:** change it in the app's Settings, e.g. to `gpt-5.4` for smarter but pricier replies.
- **Faces:** the screens are PNGs in `Shared/SS14.xcassets` (`screen_<chassis>_<mood>_<frame>`). Edit them in any pixel editor.
