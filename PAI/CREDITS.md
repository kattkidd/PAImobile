# Credits

PAI uses content from **Space Station 14** (https://github.com/space-wizards/space-station-14).
This is a fan project for personal use. It isn't affiliated with or endorsed by Space Wizards Federation.

Because some of these assets are **CC BY-SA 3.0**, the sprites in `Shared/SS14.xcassets` (including the extra screen faces adapted for this app) are shared under **CC BY-SA 3.0**. If you share this project, keep this file with it.

## Sprites — CC BY-SA 3.0
| Asset (in app) | SS14 source | Attribution |
|---|---|---|
| `pai_base_*`, `screen_*` | `Resources/Textures/Objects/Fun/pai.rsi` | Taken from tgstation at commit 9ddb8cf084e292571d4e9c79745db25befbd82fe. pai-searching-overlay heavily modified. Syndicate variants by fedKotikeD, potato by Doru991. The golden pAI is made from ScrapPAIGold by AsnDen. |
| `screen_*_happy/sad/surprised/alert/sleepy/blink_*` | Adapted from `pai-on-overlay` | New faces drawn for this app in the original screen style and palette (same licence). |
| `idcard_*` | `Resources/Textures/Objects/Misc/id_cards.rsi` | Taken and modified from /tg/station 13 at commit d917f4c, edited by AJCM-git, CrudeWax and DinnerCalzone. |
| `job_*` | `Resources/Textures/Interface/Misc/job_icons.rsi` | Taken and modified from /tg/station 13, with edits by PuroSlavKing, K-Dynamic, DinnerCalzone, anno_midi, spanky-spanky, frobnic8, TsjipTsjip and others (see that folder's meta.json). |
| `ai_core_base`, `aiscreen_*` | `Resources/Textures/Mobs/Silicon/station_ai.rsi` | Taken from vgstation (commit e2923df), modified by chromiumboy, base modified by monotheonist. |
| `ai_holo_*` | `Resources/Textures/Mobs/Silicon/holograms.rsi` | Taken from vgstation (commit e2923df), modified by chromiumboy. |
| `nt_logo` | `Resources/Textures/Interface/Nano/ntlogo.svg.png` | Space Station 14 (repository default CC BY-SA 3.0). |
| App icon | pai.rsi | Upscaled pAI sprite (same licence). |

## Sounds
| File | SS14 source | Licence / author |
|---|---|---|
| `pai_say.caf`, `pai_ask.caf`, `pai_exclaim.caf` | `Resources/Audio/Voice/Talk/pai*.ogg` | CC BY 3.0, hubismal |
| `twobeep.caf`, `chime.caf`, `buzz_sigh.caf` | `Resources/Audio/Machines/` | CC BY-SA 3.0, /tg/station |
| `ping.caf` | `Resources/Audio/Effects/Cargo/ping.ogg` | CC BY-SA 3.0, /tg/station |
| `borg_say.caf`, `borg_ask.caf`, `borg_exclaim.caf` | `Resources/Audio/Voice/Talk/Silicon/borg*.ogg` | CC BY-SA 4.0, recorded and mixed by MilenVolf |
| `click.caf` | `Resources/Audio/UserInterface/click.ogg` | CC0, el_boss (edited by mirrorcult) |
| `boot_beep.caf` | `Resources/Audio/Machines/beep.ogg` | CC0, dotY21 |
| `quickbeep.caf` | `Resources/Audio/Machines/quickbeep.ogg` | CC0, BasedUser |
| `hover.caf` | `Resources/Audio/UserInterface/hover.ogg` | CC0, MATRIXXX_ (edited by metalgearsloth) |
| `voice_speak_1…4*.caf`, `voice_lizard*`, `voice_slime*`, `voice_vulp*` | `Resources/Audio/Voice/Talk/` | **CC BY-NC-SA 3.0**, Goonstation (modified by Whisper). Non-commercial use only. |
| `voice_vox*.caf` | `Resources/Audio/Voice/Talk/vox*.ogg` | CC BY-SA 3.0, derived from shriek1.ogg (Paradise Station) by Errant |
| `voice_arachnid*.caf` | `Resources/Audio/Voice/Talk/arachnid*.ogg` | CC BY 4.0, recorded by PixelTheKermit |
| `announce.caf`, `attention.caf`, `welcome.caf` | `Resources/Audio/Announcements/` | CC BY-SA 3.0, /tg/station |
| `deny.caf` | `Resources/Audio/Machines/airlock_deny.ogg` | CC BY-SA 3.0, /tg/station |
| `print_rip.caf` | `Resources/Audio/Machines/short_print_and_rip.ogg` | CC0, 13F_Panska_Tlolkova_Matilda (cleaned up for SS14) |
| `scan_finish.caf` | `Resources/Audio/Machines/scan_finish.ogg` | CC0, pan14 |
| `id_insert.caf` | `Resources/Audio/Machines/id_insert.ogg` | CC0, dakamakat |
| `stamp.caf` | `Resources/Audio/Items/Stamp/thick_stamp_sub.ogg` | CC BY 4.0, newagesoup (converted by Lomcastar, crazybrain2) |
| `pop.caf` | `Resources/Audio/Effects/pop.ogg` | CC0, mirrorcult |
| `id_swipe.caf`, `timer_start.caf`, `timer_done.caf`, `button.caf`, `disc_insert.caf`, `ding.caf`, `buzz_two.caf`, `keyboard1…4.caf`, `power_on.caf` | `Resources/Audio/Machines/` (`id_swipe`, `microwave_start_beep`, `microwave_done_beep`, `button`, `terminal_insert_disc`, `ding`, `buzz-two`, `Keyboard/`), `Announcements/power_on.ogg` | No per-file entry; covered by SS14's default asset licence, CC BY-SA 3.0 |

The sounds were converted from OGG to CAF (mono, 44.1 kHz) so the iPhone can play them.

## Fonts (as bundled in SS14's `Resources/Fonts`)
- **Noto Sans**: Apache 2.0 (licence included in `Shared/Fonts`)
- **Noto Sans Display**: SIL Open Font License 1.1 (licence included)
- **Roboto Mono**: Apache 2.0 (licence included)

## UI
The window chrome, chamfered buttons, NanoHeading underline, stripeback and colours are recreated in SwiftUI from SS14's Nanotrasen stylesheet (`Content.Client/Stylesheets`, MIT) and `Resources/Textures/Interface/Nano`.

## Data and wording
These come from SS14's MIT-licensed repository:
- the job list and department colours (`Resources/Prototypes/Roles/Jobs`)
- silicon lawsets (`silicon-laws.yml`, `station-laws/laws.ftl`) and Station AI names (`datasets/names/ai.ftl`)
- radio channel colours (`radio_channels.yml`)
- the pAI item descriptions (`pai.yml`)
- pAI system text (`pai-system.ftl`)
- robotic speech verbs (`chat-manager.ftl`)
- the say/ask/exclaim sound rule (`speech_sounds.yml`)

## Fork content (the "Server" switch)

### Goob Station — github.com/Goob-Station/Goob-Station
| What | Source | Licence |
|---|---|---|
| Speech accents: Ohio, British, Medieval, New York, Cheese, Bogan, Scottish (`App/Models/AccentData.swift`; strong profanity filtered out) | `Resources/Locale/en-US/_Goobstation/accent/*.ftl` | **AGPL-3.0-or-later** (Goob's code/locale licence) |
| Custom lawboard idea + wording | `Resources/Locale/en-US/_Goobstation/customlawboard/` | AGPL-3.0-or-later |
| `goob_ping.caf` chat highlight ping | `Resources/Audio/_Goobstation/Interface/HighlightChatPings/Beep.ogg` | CC0, AnthonyRox |

Because the Goob accent lists (and Goob prototypes used to generate character data) are AGPL-3.0, keep this project's source public (e.g. a public GitHub repo) if you share the app.

### Starlight — github.com/ss14Starlight/space-station-14 (MIT code)
| What | Source | Licence |
|---|---|---|
| Accents: Nerd, Polite, Southern, Chav, Archaic | `Resources/Locale/en-US/_Starlight/accent/*.ftl` | MIT |
| Lawsets: Borgi, Genie in a Core, Jermov, Panicmov | `Resources/Locale/en-US/_Starlight/station-laws/laws.ftl` | MIT |
| UI colours (StyleStarlight.cs) and `sl_border` tech frame | `Content.Client/_Starlight/StyleStarlight.cs`, `Resources/Textures/_Starlight/Interface/Nano/border.png` | MIT / CC BY-SA 3.0 (repo default) |
| `sl_radio_*.caf` job radio blips | `Resources/Audio/_Starlight/Effects/Radio/` | CC BY 4.0, JustAdler |
| `sl_announce2.caf`, `sl_attention.caf` | `Resources/Audio/_Starlight/Announcements/` | **CC BY-NC-SA 3.0**, darkrell & JustAdler |
| `sl_id_pickup.caf`, `sl_id_drop.caf` | `Resources/Audio/_Starlight/Items/Handling/id_card_*` | CC BY-SA 3.0, sadboysuss for /tg/station |
| `sl_blink.caf` | `Resources/Audio/_Starlight/Effects/Emotes/blink.ogg` | CC0, Rarenth |

### Nuclear 14 — github.com/Misfit-Sanctuary/nuclear-14
| What | Source | Licence |
|---|---|---|
| Terminal sprites `n14_terminal*` | `Resources/Textures/_Nuclear14/Structures/Machines/Terminals/` | **CC BY-NC-SA 3.0**, from Mojave Sun 13 (frames by Peptide90) |
| Bark talk system (timings) | `Content.Client/_NC/Barks/BarkSystem.cs` | repo licence (MIT/AGPL dual) |
| `n14_bark_keytyped.caf` | `Resources/Audio/_Misfits/Voice/Barks/Bang-Howdy/` | **CC BY-NC-SA 3.0**, Grey Havens LLC |
| `n14_bark_book.caf` | `Resources/Audio/_Misfits/Voice/Barks/Whirled/` | **CC BY-NC-SA 3.0**, Grey Havens LLC |
| `n14_bark_ring.caf` | `Resources/Audio/_Misfits/Voice/Barks/Middens-Gingiva/` | **CC BY-NC-SA 3.0**, myformerselves |
| Lawsets: Hippocratic, Research, Engineering, Crusader, Clown, Chaplain, Peacekeeper | `Resources/Locale/en-US/deltav/station-laws/laws.ftl` (from Delta-V) | MIT |
| Wasteland job names | `Resources/Locale/en-US/_Nuclear14/job-names.ftl` | MIT |


## Merged customisation (everything from every fork at once)

### Characters — `GameData/Character`
Generated by `Tools/build_character.py` from each repo's species, marking, loadout and clothing prototypes. Every sprite strip is cut from the original `.rsi` (frame 0 of each direction), named by content hash; `Tools/sprite_licenses.json` lists the source RSI, licence and copyright line of every single one.

| Source | Sprites | Licences |
|---|---|---|
| Space Station 14 (species, hair, markings, clothing, displacement maps) | ~2,100 | almost all CC BY-SA 3.0; a few CC BY 3.0 / CC BY-SA 4.0 / CC0 / CC BY-NC-SA 3.0 |
| Goob Station (Felinid, Oni, Tajaran, Shadowkin, Plasmaman, Chitinid, Rodentia, Harpy, Feroxi, Yowie, Hydrakin, BananaMen; incl. Nyanotrasen, Delta-V, Einstein Engines, Floofstation ports) | ~990 | CC BY-SA 3.0/4.0; 46 are **CC BY-NC-SA 3.0** |
| Starlight (Thaven, Shadekin, Lagomorph, Doll, Elf, Felionoid, Experiment, Cyclorite, Resomi, Avali) | ~1,100 | CC BY-SA 3.0/4.0 |
| Nuclear 14 (RatFolk, Kobold) | 25 | CC BY-SA 3.0; 10 **CC BY-NC-SA 3.0** |

Layer order follows SS14's `BaseSpeciesLayers` (Resources/Prototypes/Body/species_appearance.yml); clothing and markings line up with each species using SS14's displacement maps (Content.Client/DisplacementMap, `displacement.swsl`). Height/width sliders come from Goob/Starlight's Einstein Engines port. Wasteland (Nuclear 14) jobs are dressed in SS14 clothing; N14's own clothing art is Fallout-derived and isn't included. Fallout species (ghouls, super mutants, robots, deathclaws) are not included either.

### Voices, emotes and barks — `GameData/Audio`
Generated by `Tools/build_audio.py` from each species' `speechSounds`, `emoteSounds` and sound collections. Per-file licences/authors are in `Tools/audio_licenses.json` (taken from each folder's `attributions.yml`). Mostly CC0 / CC BY / CC BY-SA, with some **CC BY-NC(-SA)**. Files with "Custom" licences (except Sampling Plus), weapon sounds, and bark sounds ripped from other games (Undertale, Don't Starve) were left out.

### Music — lobby/jukebox tracks
| Track | Artist | Playlist | From | Licence |
|---|---|---|---|---|
| Endless Space | SolusLunes | Wizard's Den | Space Station 14 | CC-BY-3.0 |
| Absconditus | ZhayTee | Wizard's Den | Space Station 14 | CC-BY-NC-SA-3.0 |
| Atomic Amnesia MMX | Philip Dyer | Wizard's Den | Space Station 14 | CC-BY-NC-SA-3.0 |
| Singuloose | Janis Schiedková | Wizard's Den | Space Station 14 | CC-BY-NC-SA-3.0 |
| Comet Halley | Stellardrone | Wizard's Den | Space Station 14 | CC-BY-NC-SA-3.0 |
| Title3 | Cuboos | Wizard's Den | Space Station 14 | CC-BY-NC-SA-3.0 |
| Spac Stac | Hayabusa | Wizard's Den | Space Station 14 | CC-BY-NC-SA-3.0 |
| phoron will make us rich | Sunbeamstress | Wizard's Den | Space Station 14 | CC-BY-NC-SA-3.0 |
| lasers rip apart the bulkhead | Sunbeamstress | Wizard's Den | Space Station 14 | CC-BY-NC-SA-3.0 |
| every light is blinking at once | Sunbeamstress | Wizard's Den | Space Station 14 | CC-BY-NC-SA-3.0 |
| The Gray Tide | mrjajkes | Goob Station | Goob Station | CC-BY-3.0 |
| Glorious Morning | Waterflame | Goob Station | Goob Station | CC-BY-3.0 |
| Abductor | Crockitz | Goob Station | Goob Station | CC-BY-SA-3.0 |
| Black Swarm | Bobik-music | Goob Station | Goob Station | CC-BY-4.0 |
| Future Perception | Merct | Goob Station | Goob Station | CC-BY-SA-3.0 |
| Mind Crawler | Merct | Goob Station | Goob Station | CC-BY-SA-3.0 |
| Clown Always Wins | NИTRODE | Goob Station | Goob Station | CC-BY-NC-SA-3.0 |
| Honk! | SlendyMawn, remastered by Scruq | Goob Station | Goob Station | CC-BY-NC-SA-3.0 |
| skubstep | finket | Goob Station | Goob Station | CC-BY-NC-SA-3.0 |
| The Future Soon | Jonathan Coulton | Goob Station | Goob Station | CC-BY-NC-SA-3.0 |
| The Station | A-Guy173 | Starlight | Starlight | CC0-1.0 |
| Timefracture | Bad History | Starlight | Starlight | CC-BY-3.0 |
| Liberation | Bolgarich | Starlight | Starlight | CC-BY-3.0 |
| Bluespace | Beptol Corporation Acoustics | Starlight | Starlight | CC-BY-NC-SA-3.0 |
| Redefining Lines | Beptol Corporation Acoustics | Starlight | Starlight | CC-BY-NC-SA-3.0 |
| Null Scar Gaze | Beptol Corporation Acoustics | Starlight | Starlight | CC-BY-NC-SA-3.0 |
| Drunk Reflections | JAM | Starlight | Starlight | CC0-1.0 |
| Stench of Whiskey | hermitsabee | Wasteland | Starlight | CC-BY-4.0 |
| Cowboy Western | SOULFULJAMTRACKS | Wasteland | Goob Station | CC-BY-4.0 |
| A.D.R (Lagoona rmx) | Andreas Viklund | Wasteland | Nuclear 14 | CC-BY-4.0 |
| Minute | Patricia Taxxon | Wasteland | Nuclear 14 | CC-BY-SA-3.0 |
| Scratch Post | Ghirardelli7 | Wasteland | Nuclear 14 | CC-BY-SA-4.0 |
| Nymphs of the Forest | Psirius | Wasteland | Nuclear 14 | CC-BY-NC-SA-4.0 |

Not included: tracks with permission granted only to a specific server ("Custom"), CC BY-ND tracks, and everything Nuclear 14 lists as Fallout/Bethesda music.

### Ambience
| Loop | Licence |
|---|---|
| Station hum | CC-BY-SA-3.0 (repository default) |
| Corridors | CC-BY-SA-3.0 (repository default) |
| Atmospherics | CC-BY-SA-3.0 (repository default) |

### Themes
Launcher theme: SS14 `Content.Client/Stylesheets/StyleSpace.cs` (MIT).

Also not included on purpose: music and sound effects the forks list as ripped from commercial games, anything branded with a game franchise, and lawsets that would make the AI agree with everything or encourage gambling.

Non-commercial (NC) assets are fine for a personal app; remove them before any commercial use.
