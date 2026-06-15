# Kaiditya — Pint-Sized Hero, Big-Time Save

A kid-friendly iPhone adventure game in the spirit of *Sneaky Sasquatch*, starring
**Kaiditya**, a 7–8 year old superhero out to save the city from **Lord Chow-Chow**.

Top-down open world, walk-and-explore, talk to townsfolk, **sneak past patrolling
minions** (vision cones!), hide in bushes/crates, use a **secret-identity disguise**
to blend in — then suit up to grab Energy Crystals — plus a **high-speed driving
chase**. Concepts build up level by level, Sneaky-Sasquatch style.

Built with **SpriteKit** (native iOS). All art is drawn procedurally in code, so
there are no external asset dependencies.

## Levels (11, progressive mechanics)

1. **Sunnyside Park** (day) — basics: move, talk, collect crystals, stealth + the
   secret-identity disguise, charge the Power Core.
2. **Highway Chase** (driving) — chase the getaway truck up a curving highway;
   overtake same-direction traffic, BOOST to keep up. He runs fast then tires.
3. **Static Docks** (dusk) — advanced stealth: crates for cover, faster minions.
4. **City Rooftops** (night) — drones + sweeping searchlights + coins + a keycard.
5. **Secret Lab** (bright) — a toggling laser grid, speed pads, crystal-magnet, water.
6. **Flooded Sewers** (murky) — wade through water, grab a Super-Star, stealth takedowns.
7. **Downtown Gauntlet** (big) — a sprawling night-city run combining lasers, drones,
   searchlights, water and a keycard hunt across a large map (7 crystals).
8. **Harbor Boat Chase** (water) — switch to a speedboat and chase across the bay.
9. **The Power Plant** (big) — a massive laser-grid reactor guarding 8 crystals,
   with a magnet and a Super-Star to help.
10. **Static Tower** (electric night) — searchlights + a Super-Star, climb to the top.
11. **Chow-Chow's Fortress** (finale) — power up, then a **multi-phase boss fight**
    with escalating attacks (volleys, spirals, ground strikes, mines, rings, charges)
    and summoned guards.

Reachable from a **level-select map** with persistent unlock progress.

Each level has a dramatic intro card, a distinct biome/palette, atmosphere overlays
and particles, and a level-complete celebration.

## Concepts / mechanics

Movement + floating joystick · camera follow · **stealth vision cones** · hide in
bushes/crates/pillars · **secret-identity disguise** · Energy Crystals · **Power
Core** charging · DASH + SHIELD powers + energy meter · **driving chase** · **boat
chase** · curved roads + same-direction traffic + crashes · **coins/economy** ·
**keycard + locked exit** · **rotating searchlights** · **toggling laser gates** ·
**speed pads** · **crystal-magnet power-up** · **Super-Star invincibility** · **water
slow zones** · **stealth takedowns** · **drone enemies** · **multi-phase boss** with
escalating **attack patterns** (bolt volleys, shockwave rings, charge lunges) and
summoned guards · a **level-select map** with persistent unlock progress ·
dramatic cinematic popups · pill-banner toasts · camera **screenshake** ·
**procedural sound effects + looping background music** (synthesized at runtime,
no audio assets — explore / stealth / chase / boss / menu themes) ·
hardware-keyboard support.

## Gameplay

| Sneaky Sasquatch | Kaiditya |
| --- | --- |
| Open world to roam | A city with a Town Square, Hero HQ, and the Static Zone |
| Sneak past park rangers | Sneak past Lord Static's minions (vision cones) |
| Hide from authorities | Hide in bushes (cover) |
| Disguises to mingle | Secret-identity disguise — minions ignore a "normal kid" |
| Collecting (mushrooms, bones) | Collect Energy Crystals |
| NPCs & tasks | Mayor Mia and friends give a "save the world" mission chain |

### The mission chain
1. Find **Mayor Mia** in the Town Square.
2. Recover **5 Energy Crystals** from the guarded Static Zone.
3. Charge the **Power Core** back at HQ.
4. Confront and defeat **Lord Static**.

### Stealth & disguise
- In **HERO** mode you can grab crystals, charge the core, and fight — but minions
  can spot you (a vision cone filling to `!` means caught → sent back to HQ).
- Tap **HIDE** to switch to your **secret identity** (a normal kid): minions ignore
  you, but you can't pick up crystals. Switch to **HERO** to act, then **HIDE** again.
- Standing in a **bush** also hides you, even in costume.

### Powers
- **DASH** — a quick burst of speed (also used to hit Lord Static).
- **SHIELD** — a temporary bubble; minions can't catch you while it's up.
- Powers use the **POWER** meter (top-right), which refills over time. Crystals top it up.

## Controls

**Touch (phone):**
- **Left side** — touch and drag to summon a floating joystick and walk (or steer in
  the driving level).
- **Bottom-right cluster** — a grouped control pad with vector icons: SHIELD, DASH,
  HIDE/HERO (disguise), and a context button (TALK / CHARGE / FIGHT). In the driving
  level it collapses to a single **BOOST** button.
- Tap the title screen to start; tap to advance dialogue and intro/complete cards.

**Hardware keyboard (optional, e.g. when testing on a Mac/simulator):**
- Move: `WASD` or arrow keys
- Interact / advance dialogue: `Space`, `Return`, or `J`
- Dash: `K`  ·  Shield: `L`  ·  Disguise toggle: `H`

## Build & run

Requires Xcode (project generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen)).

```bash
xcodegen generate                 # regenerate Kaiditya.xcodeproj from project.yml
./run.sh                          # build + install + launch on the iPhone 16 simulator + screenshot
```

Or open `Kaiditya.xcodeproj` in Xcode and run on a simulator or device.

### Autopilot validation
A scripted self-play mode drives a full playthrough for testing/recording:

```bash
./demo.sh                         # build + launch with KAIDITYA_DEMO=1, capture frames to /tmp/kaiditya_demo
```

The env var `KAIDITYA_DEMO=1` makes the game play itself from title to victory
(used to validate movement, camera, stealth, dialogue, missions, powers, the boss
fight, and the win screen on-device).

## Project layout

```
project.yml                 XcodeGen project definition (iOS 17+, portrait + landscape)
Sources/
  App.swift                 SwiftUI app + UIViewController host (responder chain for keyboard)
  Game/
    Theme.swift             Color palette, z-layers, shape helpers
    Levels.swift            Biome + LevelData model and the 4 level definitions
    Characters.swift        Procedural vector art (hero, NPCs, minions, villain, car, truck, cover, crystal)
    Effects.swift           Shadows, atmosphere overlays, vignette, particle systems, exit portal
    Player.swift            Hero node: movement feel, energy, dash, shield, disguise, car mode
    Joystick.swift          Floating virtual joystick
    Button.swift            Vector control icons + round HUD touch buttons
    NPC.swift               Talkable townsfolk + quest markers
    Enemy.swift             Patrolling minion with a vision cone
    HUD.swift               Responsive objective panel, crystal counter, power meter, pill toasts
    GameScene.swift         Level loading, world building, driving chase, camera, input,
                            stealth, interactions, dramatic popups, autopilot
```
