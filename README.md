# Isometric World Generator

A procedural isometric map generator built in **Godot 4** using the **Wave Function Collapse (WFC)** algorithm. Press a button and get a brand-new 80×80 tile world: rolling grassland, flower meadows, dirt patches, rocky outcrops, fallen logs, and a winding river that cuts across the map.

---

## Features

- **Wave Function Collapse terrain** — tiles are collapsed by lowest entropy, with constraint propagation via a BFS queue so neighbouring tiles always obey the adjacency rules.
- **Weighted tile selection** — each terrain type has a weight (e.g. grass is far more common than flower grass or stone), so you can tune the look of the world without touching the rules.
- **Procedural river** — a river is seeded *before* WFC runs. It starts and ends on two different map edges and meanders using velocity inertia, a pull towards the exit point, and random perpendicular drift. WFC then fills the land around it, so the banks (shore stone and dirt) form naturally.
- **Fake height with layered tilemaps** — grass and cliffs are drawn on raised layers with a vertical offset over a dirt base, giving the blocky isometric "elevation" look.
- **Shadow pass** — raised tiles cast a one-tile shadow onto neighbouring dirt, shallow water and shore tiles.
- **Decorations** — random logs on grass, rocks on cliffs, and animated/instanced plant scenes scattered across the meadows.
- **Contradiction recovery** — if WFC ever reaches a cell with no valid tiles, generation restarts automatically with a fresh seed.
- **Fresh result every time** — uses a dedicated `RandomNumberGenerator` that is re-randomised on every run.
- **Pan and zoom camera** — drag with the middle or right mouse button, scroll to zoom towards the cursor.

---

## Controls

| Input | Action |
|---|---|
| **GENERATE** button | Generate a new world |
| Middle / Right mouse drag | Pan the camera |
| Mouse wheel | Zoom in / out (towards the cursor, clamped 0.5×–3.0×) |

---

## Getting Started

### Run the prebuilt version (Windows)

Run `IsometricWorld.exe`. (`IsometricWorld.pck` must stay in the same folder.)

### Run from source

1. Install **Godot 4.x** (the project is configured for 4.7, Forward Plus renderer).
2. Clone or download this repository.
3. Open Godot → **Import** → select `project.godot`.
4. Press **F5**. The main scene is `world_generator.tscn`.

---

## How It Works

### 1. Tile types and adjacency rules

There are eight terrain types:

`OCEAN_DEEP` · `OCEAN_MID` · `OCEAN_SHALLOW` · `STONE_SHORE` · `DIRT` · `GRASS` · `FLOWER_GRASS` · `STONE_CLIFF`

Each type lists which types may sit next to it in the four cardinal directions. For example, water can only transition to land through shore stone or dirt, and flower grass can only touch grass or more flower grass. This gives believable transitions (deep water → shallow → shore → dirt → grass) without hand-placing anything.

### 2. The WFC loop

1. Every cell begins as a "superposition" of all eight types.
2. If a river is enabled, it is carved first and propagated.
3. Repeatedly find the cell with the **fewest remaining options** (random tiebreak noise stops the algorithm from always scanning in the same order).
4. **Collapse** it to a single type, chosen by weighted random.
5. **Propagate** the consequences to neighbours, removing any options that are no longer legal.
6. Stop when every cell is resolved. If any cell hits zero options, restart.

### 3. Rendering

Once resolved, each logical tile is mapped to a random variant from its atlas list (so the map doesn't look repetitive) and drawn across four `TileMapLayer`s:

| Layer | Contents |
|---|---|
| `BaseLayer` | Water, shore, dirt (also underneath grass and cliffs) |
| `ShadowLayer` | Shadow tiles cast by raised terrain |
| `HeightLayer1` | Grass, flower grass, cliffs, logs, plants |
| `HeightLayer2` | Rock decorations on cliffs |

Layers use Y-sorting and per-layer vertical offsets to create the elevated look.

---

## Configuration

Select the root node of `world_generator.tscn` and tweak these in the Inspector:

| Property | Default | Description |
|---|---|---|
| `width` / `height` | 80 / 80 | Map size in tiles |
| `generate_river` | `true` | Toggle the river |
| `river_width` | 2 | River thickness in tiles (minimum 2) |
| `layer_height_offset` | -8.0 | Pixel offset per elevation layer |
| `shadow_direction` | (-1, 1) | Grid direction shadows are cast in |
| `plant_scene` | — | Scene instanced on grass for plants/flowers |

For deeper tuning, edit the constants at the top of `Scripts/world_generation.gd`:

- `TILE_WEIGHTS` — how common each terrain type is
- `adjacency_rules` (in `define_adjacency_rules()`) — which tiles may touch
- `TILE_ATLAS_MAP` — which spritesheet cells represent each terrain type
- Decoration chances in `render_grid()` (4% logs, 12% plants, 8% cliff rocks)

---

## Project Structure

```
├── world_generator.tscn      # Main scene (tilemap layers, camera, UI button)
├── Scripts/
│   ├── world_generation.gd   # WFC, river generation, rendering, shadows
│   ├── camera_control.gd     # Pan + zoom-to-cursor camera
│   └── shadow.gd             # Shadow helper (stub)
├── Scenes/
│   └── plant_scene.tscn      # Plant decoration scene
├── Tiles/
│   └── spritesheet.png       # 32×32 tile atlas
└── project.godot
```

Tiles are 32×16 isometric diamonds (`tile_shape = isometric`) cut from a 32×32 atlas.

---

## Known Limitations

- **No backtracking.** On a contradiction the whole map is regenerated rather than repairing the local area. This is fine at 80×80 with the current rules but could get slow on larger or stricter rule sets.
- **Rules are tile-type level, not edge-level.** Adjacency is defined between terrain categories rather than matching sprite edges, so transitions rely on the art being tileable.
- **Entropy is a simple candidate count**, not weighted Shannon entropy, and the lowest-entropy search scans the whole grid each step.
- **Terrain is blocky and noisy** — grass and dirt patches are fine-grained rather than forming large biomes. Larger-scale structure (e.g. a noise-driven biome pass feeding WFC) is a possible future improvement.

## Ideas for Future Work

- Biome layer (forest, meadow, rocky highlands) to bias tile weights regionally
- Seed input so maps can be reproduced and shared
- Weighted-entropy cell selection and local backtracking
- Lakes/coastlines using the unused deep and mid ocean tiles
- Export generated maps to PNG or a saved scene

---

## Credits

- Built with [Godot Engine](https://godotengine.org/)
- Tile art: *add the spritesheet's author and licence here*
- Wave Function Collapse by Maxim Gumin — [mxgmn/WaveFunctionCollapse](https://github.com/mxgmn/WaveFunctionCollapse)

## Author

**Lehi Smart** — [GitHub](https://github.com/) · [LinkedIn](https://www.linkedin.com/)
