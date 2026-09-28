# Kaiditya sizzle reel — edit decision list

Timeline is locked to the music: 128 BPM, beat = 0.46875 s, bar = 1.875 s, 24 bars = 45.0 s + tail to 47.5 s.
Bar N starts at (N-1) × 1.875 s. Source times are seconds into `clips/<name>.mp4` (1320×2868, 60 fps, silent, HUD hidden).
Music: `audio/sizzle_music.wav`, SFX: `audio/*.wav`, cue sheet: `audio/cues.json` (produced separately — may arrive later).

Punch-in = scale-up crop centred on the hero (the hero sits at roughly x=50%, y=50% of frame in gameplay clips; the camera follows him).
Most gameplay clips should be punched in 1.35–1.8× with a slow push (Ken Burns) so the pint-sized hero reads on a phone.

| Bars | Time (s) | Section | Shots (source clip @ start–end) | Graphics / notes |
|---|---|---|---|---|
| 1–2 | 0.000–3.750 | COLD OPEN | Four flash cuts on the stabs at 0.000, 0.9375, 1.875, 2.8125 — each shows ~0.45 s then snaps to near-black with a chromatic/glitch flicker: `chase@9.0`, `tower@9.0`, `harbor@12.0`, `boss@18.0` (hits). | Dark background, subtle film grain, light leak. Last half-beat: suck-in to black. |
| 3 | 3.750–5.625 | LOGO SLAM | none (motion graphics) | Impact at 3.75: "KAIDITYA" logo slams in (Lilita One, yellow #FFD13F with dark ink outline + drop shadow, like the in-game title), squash-and-stretch spring, radial sunburst rays rotating behind (deep navy #1E2440 → indigo), hero sprite pops up beside/under the logo with a bounce, sparkle burst, camera shake 3 frames. |
| 4–5 | 5.625–9.375 | TAGLINE | `park@0.0–3.75` (Town Square, hero with NPCs) — slightly blurred/darkened behind text, slow push. | Kinetic type: "PINT-SIZED HERO." (bar 4) then "BIG-TIME SAVE." (bar 5), word-by-word pop on beats, playful rotation. |
| 6 | 9.375–11.250 | SNEAK | `docks@3.0–4.875` (minion cone sweeping near hero), punch-in 1.6× | Caption: big word "SNEAK" + small "past the minions". Cone highlight glow optional. |
| 7 | 11.250–13.125 | SNEAK | `lab@7.5–9.375` (lasers, minion) punch-in 1.5× | Caption continues / swaps to "…and their lasers". |
| 8 | 13.125–15.000 | RESCUE | `docks@13.8–15.675` (hero at cage, unlock ring) punch-in 1.7× | Caption "RESCUE" + "the citizens". |
| 9 | 15.000–16.875 | RESCUE | `tower@2.4–4.275` (cage + lock ring) punch-in 1.7× | |
| 10 | 16.875–18.750 | CHASE | `chase@3.0–4.875` (truck + traffic), punch-in 1.2× | Caption "CHASE" + "the getaway". Speed lines / motion blur feel. |
| 11 | 18.750–20.625 | CHASE | `harbor@5.0–6.875` (speedboat + barges) punch-in 1.2× | |
| 12 | 20.625–22.500 | TRAPS | `gauntlet@9.0–10.875` (lasers, water, searchlight) punch-in 1.5× | Caption "DODGE" + "the traps". |
| 13 | 22.500–24.375 | TRAPS | `rooftops@3.0–4.875` (searchlight sweep) punch-in 1.6×; snare fill at end → quick whip-pan transition. | |
| 14–15 | 24.375–28.125 | BUILD | `boss@13.5–17.25` (approaching the fortress, Lord Chow-Chow appears) — desaturate slightly, red/purple vignette pulsing, slow push-in, subtle shake increasing | Text builds word by word on beats: "FACE" … "LORD" … "CHOW-CHOW" (last word huge, red-magenta). Beat 4 of bar 15 (27.656–28.125) = SILENCE: cut to black/white flash frame. |
| 16–19 | 28.125–35.625 | BOSS DROP | Impact at 28.125. Cut every 2 beats (0.9375 s), last bar every beat: `boss@18.0`, `chase@12.0`, `boss@20.0`, `harbor@18.0`, `boss@22.0`, `lab@9.0`, `boss@24.0`, `sewers@21.0` (checkpoint sparkle), then bar 19 one-beat cuts: `power@12.0`, `rooftops@9.0`, `park@9.0`, `boss@25.5`. | Flash frames / zoom punches on every cut, RGB-split transitions, camera shake on downbeats, a quick "POW!" comic burst on boss hits. |
| 20 | 35.625–37.500 | HERO CITY | `hub@2.0–3.875` (Hero City plaza, fountain, dog) gentle push | Caption "EXPLORE" + "Hero City". Bouncy, bright. |
| 21 | 37.500–39.375 | UNLOCKS | Two floating phone screens / split: `shop@0.5–2.375` + `map@0.5–2.375` (and optionally `complete@0.8` card), slight 3D tilt, sliding in | Caption "UNLOCK" + "gadgets & costumes" / "EARN ★★★". |
| 22–24 | 39.375–45.000 (+tail to 47.5) | END CARD | Background: `boss@27.5+` ("YOU SAVED THE WORLD!" card) very briefly (0.5 s) then motion-graphics end card | Impact at 39.375: logo returns big with hero sprite, tagline "Pint-Sized Hero, Big-Time Save" types on, then three pill badges pop in on beats: "No ads" · "No in-app purchases" · "Plays offline". Button hit at 43.125: final punch/flash + "Coming soon on iPhone". Hold to 47.5 with gentle ray rotation, fade to black over last 0.5 s. |

## Art assets available
- Font: `~/code/kaiditya/Resources/Fonts/LilitaOne-Regular.ttf` (OFL).
- Hero sprite frames: `~/code/kaiditya/Resources/Sprites/hero.atlas/hero_idle_s*.png`, `hero_walk_s_*.png` (+ other directions).
- Boss: `chowchow.atlas`; minion: `minion.atlas`; props (`props.atlas`: coin_0..5, crystal_0..7, chest, cage), buildings (`buildings.atlas`), vehicles (`vehicles.atlas`).
- Palette (from `Sources/Game/Theme.swift`): heroBlue #3373F2, heroRed #F0474D, energy/yellow #FFD140, crystal/teal #4DEBD9, villain purple #52387A, panel indigo #262B4A, ink #1A1F2E.
