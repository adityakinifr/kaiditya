# Kaiditya sprite pipeline (Blender 3D toon, headless)

Chibi 3D characters and vehicles, built entirely from Python in Blender (no .blend files).
They are rendered with flat toon shading and an ink outline to transparent PNG sprites for
SpriteKit.

```
art/
  build_all.sh          # renders everything -> Resources/Sprites/*.atlas + art/previews/*_sheet.png
  blender/
    common.py           # palette, toon material, part helpers, Cape cloth, camera/light rig, outline, render loops
    hero.py             # Kaiditya
    minion.py           # patrolling Static minion
    drone.py            # ghost drone minion (dronesStyle levels)
    chowchow.py         # Lord Chow-Chow (boss, 384px)
    npc.py              # Mayor Mia / Granny Gold / Tommy (--npc mayor|gran|tommy)
    vehicles.py         # hero car, traffic cars, villain truck, hero boat, villain speedboat, barge
    props.py            # world props (crates, bushes, tree, cage, generator, pickups ...) + shadow passes
    tiles.py            # seamless biome floor tiles, path tiles, scatter decals
    buildings.py        # 3/4 buildings (houses, shop, arcade, HQ, warehouse, lab, ...) + shadow passes
    envkit.py           # AO band, Cycles shadow-catcher pass (shared by props/tiles)
    hero_poc.py         # original proof of concept (kept for reference, not built)
  tools/finish.py       # 2x -> 1x Lanczos downsample + contact sheets (needs Pillow)
  tools/props_post.py   # crop props, compute anchorPoints, write props_manifest.json + previews/props.png
  tools/buildings_post.py # downsample + crop buildings, anchors, sign/door offsets -> buildings_manifest.json + previews/buildings.png
  tools/tiles_post.py   # seamless wrap-downsample of tiles -> tiles_<biome>.atlas + previews/tiles*.png
  props_manifest.json   # generated: prop textures, sizes, anchors, footprints; tile names per biome
  previews/             # <asset>_sheet.png contact sheets for review
  .cache/raw/           # raw 2x renders + Blender logs (git-ignored)
```

## Running

```sh
art/build_all.sh                       # everything (~3 min on an M-series Mac)
art/build_all.sh hero chowchow         # only some assets
QUICK=1 art/build_all.sh minion        # look-dev: idle frames for s/e/n/se only
BLENDER=/path/to/Blender art/build_all.sh
```

You need Blender 5.1 (default path `/Applications/Blender.app/Contents/MacOS/Blender`) and a
`python3` with Pillow. The script uses the first one it finds among `python3`, `/usr/bin/python3`
and `/opt/homebrew/bin/python3`. Without Pillow it still resizes, using `sips`, but it skips the
contact sheets.

To run a single script by hand:
`Blender -b -P art/blender/hero.py -- --out /tmp/raw [--quick] [--dirs s,e]`

## Look

* **Toon shading.** A Diffuse BSDF goes into *Shader to RGB* and then a constant 4-stop ramp:
  shadow (cool purple tint), mid, lit, and a small highlight. It is output as Emission, so the
  bands stay flat. A procedural cool rim, computed in world space, lights the screen-right and
  top edges.
* **Lighting.** One warm key sun from the screen's top-left gives the same bands on every asset
  and in every direction. No world light, and no ground shadow is baked in, because the game
  draws its own shadows.
* **Outline.** Freestyle ink (Palette.ink): a 2.2px outer contour and 1.3px inner silhouettes,
  measured in final pixels.
* **Supersampling.** Everything renders at 2x and is downsampled with Lanczos (premultiplied
  alpha, so edges have no dark fringe).
* **Camera.** Orthographic, tilted 55° from straight down (top-down 3/4). Vehicles use a
  straight-down camera because they rotate in-engine.
* **Shared scale.** Every asset has the same pixel density, about 116 final px per world unit.
  One `setScale` works for everything, and the boss really is 1.4x the hero.

## Output and naming

Each asset becomes a SpriteKit **texture atlas folder**, `Resources/Sprites/<asset>.atlas/`.
Xcode compiles `*.atlas` folders into atlases automatically.

| asset | frame size | files |
|---|---|---|
| hero, minion, drone, npc_mayor, npc_gran, npc_tommy | 256×256 | `<asset>_idle_<dir>.png`, `<asset>_walk_<dir>_<0-3>.png` |
| chowchow (boss) | 384×384 | same scheme |
| vehicles | fit to footprint (multiples of 8) | `car_hero`, `car_traffic_{red,blue,yellow,white}`, `truck_villain`, `boat_hero`, `boat_villain`, `barge` |

* **Directions** (`<dir>`): `n ne e se s sw w nw`. `s` faces the camera (screen-down) and `e`
  faces screen-right. Sheets list the rows in that order.
* **Walk cycle**: 4 frames. Frame 0 is left foot forward (low), 1 is passing (high), 2 is right
  foot forward (low), 3 is passing (high). About 8 fps looks right at hero walking speed.
* **Idle**: 1 frame per direction.
* **Anchor**: characters stand on the ground point at **(0.5, 0.18)** of the frame, the same for
  the 256 and 384 frames. Vehicles are centred (anchor 0.5, 0.5) and point up (+y). Rotate them
  with `zRotation` as the current shape nodes do.
* **Scale**: `setScale(0.3)` puts the hero at about 55pt tall, the same size as the current
  vector hero. Use the same factor for all assets.
* The drone's model floats about 0.28 units above its anchor. Keep drawing its shadow at the
  anchor.

## Integrating in the game (not done yet: gameplay code is owned elsewhere)

1. **project.yml**: add the sprite folder to the target's `sources` (next to Assets.xcassets),
   then run `xcodegen`:

   ```yaml
   targets:
     Kaiditya:
       sources:
         - path: Sources
         - path: Resources/Assets.xcassets
         - path: Resources/Sprites        # *.atlas folders -> compiled SpriteKit atlases
           buildPhase: resources
   ```

2. **Load and animate** (for example in a new `Sources/Game/SpriteSet.swift`):

   ```swift
   import SpriteKit

   enum SpriteDir: String, CaseIterable {
       case n, ne, e, se, s, sw, w, nw
       /// Nearest of 8 directions for a movement vector (SpriteKit: +y is up).
       static func from(_ v: CGVector) -> SpriteDir {
           let octant = Int((atan2(v.dy, v.dx) / (.pi / 4)).rounded()) & 7   // 0 = east, CCW
           return [.e, .ne, .n, .nw, .w, .sw, .s, .se][octant]
       }
   }

   final class SpriteSet {
       let name: String
       private let atlas: SKTextureAtlas
       private var walkCache: [SpriteDir: [SKTexture]] = [:]
       init(_ name: String) { self.name = name; atlas = SKTextureAtlas(named: name) }
       func idle(_ d: SpriteDir) -> SKTexture { atlas.textureNamed("\(name)_idle_\(d.rawValue)") }
       func walk(_ d: SpriteDir) -> [SKTexture] {
           if let w = walkCache[d] { return w }
           let w = (0..<4).map { atlas.textureNamed("\(name)_walk_\(d.rawValue)_\($0)") }
           walkCache[d] = w; return w
       }
       static let hero = SpriteSet("hero"), minion = SpriteSet("minion"), drone = SpriteSet("drone")
       static let boss = SpriteSet("chowchow")
   }

   // Usage (for example inside Player): replaces the SKShapeNode body.
   let sprite = SKSpriteNode(texture: SpriteSet.hero.idle(.s))
   sprite.anchorPoint = CGPoint(x: 0.5, y: 0.18)
   sprite.setScale(0.3)

   var currentDir: SpriteDir = .s
   var walking = false
   func updateSprite(velocity v: CGVector) {
       let moving = hypot(v.dx, v.dy) > 5
       let dir = moving ? SpriteDir.from(v) : currentDir
       guard dir != currentDir || moving != walking else { return }
       currentDir = dir; walking = moving
       sprite.removeAction(forKey: "walk")
       if moving {
           sprite.run(.repeatForever(.animate(with: SpriteSet.hero.walk(dir), timePerFrame: 0.12)),
                      withKey: "walk")
       } else {
           sprite.texture = SpriteSet.hero.idle(dir)
       }
   }

   // Vehicles: one atlas, rotate the node.
   let car = SKSpriteNode(texture: SKTextureAtlas(named: "vehicles").textureNamed("car_hero"))
   car.setScale(0.3)
   ```

   Call `SKTextureAtlas.preloadTextureAtlases([...])` during level load to avoid a hitch the
   first time.

3. Keep the game-side extras: the cone, the `?`/`!` alert mark, the name plates and the ground
   shadows (`Effects.groundShadow`). The sprites leave those out on purpose. Minion stun spin
   and hero shield effects still work as node actions on the sprite.

## Adding or changing an asset

Copy `minion.py` (the simplest one). Build parts with `C.sphere / C.box / C.cone_dir / C.decal`
in world rest-pose coordinates, facing -Y and standing on z=0. Parent them to pivot empties
(hips, shoulders, head), and write a `pose(phase)` function that uses `C.walk_curves`. Then call
`C.render_character(name, root, pose, opts)` and add the name to `ALL` in `build_all.sh`.

## Props and floor tiles (`art/build_all.sh props tiles`)

* **props** -> `Resources/Sprites/props.atlas`. Every prop `<name>` has a `<name>_shadow`
  (black RGB, shadow in alpha, falling down-right). Spin sets `coin_0..5` / `crystal_0..7` share
  `coin_shadow` / `crystal_shadow`. Use the same anchorPoint for a prop and its shadow; tint the
  shadow violet (`colorBlendFactor = 1`) at ~0.4 alpha under the prop. `art/props_manifest.json`
  lists each texture's 1x size, anchorPoint (ground-footprint centre) and `footprint_pt`
  (width x height of the ground rect in world points at worldScale 0.3; height foreshortened by
  cos 55deg like the tiles), for hide/collision rects.
* **tiles** -> `Resources/Sprites/tiles_<biome>.atlas` for park, docks, tower, rooftops, lab,
  sewers, fortress: `<biome>_0..3` (base, seamless against each other in any mix),
  `<biome>_path_0..1` (walkway strip), `<biome>_decal_*` (transparent scatter). Tiles are
  233x133 px = 70x40 pt at worldScale 0.3 (`SKTileMapNode` tileSize). The 3x3/5x5 seam checks
  are in `art/previews/tiles_check_<biome>.png`.

## Buildings (`art/build_all.sh buildings`)

* **buildings** -> `Resources/Sprites/buildings.atlas`: `bld_house_{blue,red,green,orange,purple}`,
  `bld_shop`, `bld_arcade`, `bld_hq`, `bld_warehouse`, `bld_lab`, `bld_pumphouse`, `bld_rooftop`,
  `bld_lair`, `bld_bunker` (canonical footprint 200x150 pt) and `bld_fortress` (400x220 pt), each
  with a `<name>_shadow`. Rendered whole from the character camera (55deg, ~116 px/unit); only the
  front face and the roof show.
* Footprint: a W x H pt spec (H = on-screen depth) is modelled as W/(0.3*PPU) x H/(0.3*PPU*cos55)
  units, so the ground rect projects to exactly W x H pt at scale 0.3 (same convention as the props'
  `footprint_pt`). For other spec sizes scale the node uniformly by `0.3 * specW / footprint_pt[0]`.
* `art/buildings_manifest.json`: `anchor` (ground-footprint centre; same for the shadow),
  `sign_center_pt` / `sign_size_pt` (blank light plate for a SpriteKit label, dark text reads best),
  `door_pt` (threshold, bottom centre of the door) and `door_top_pt`, all in points from the node
  position at scale 0.3. Multiply offsets by `scale / 0.3` when a building is scaled.
* Renders use `dither_intensity = 0` (flat fills compress ~3x better), and shadows are lightly
  blurred and snapped to 32 alpha levels, so the atlas stays around 5 MB.
