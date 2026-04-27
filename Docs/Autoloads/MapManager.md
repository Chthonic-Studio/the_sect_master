# MapManager

**File:** `Scripts/Map/map_manager.gd`  
**Autoload name:** `MapManager`  
**Load order:** 16 (last)

---

## Purpose

`MapManager` governs the **world map state**: which layer is active, which province/region the cursor is hovering, and which sects are assigned to which provinces. It uses pixel color lookups on mask images to identify geography.

---

## Signals

| Signal | When emitted |
|---|---|
| `hovered_province_changed(province_id)` | Mouse moves to a new province |
| `hovered_region_changed(region_id)` | Hovered region changes |
| `map_layer_changed(layer)` | Active interaction layer changes |
| `province_clicked(province_id)` | Player clicks a province |
| `region_clicked(region_id)` | Player clicks a region |

---

## Map Layer System

```gdscript
enum MapLayer {
	VISUAL,     # Background art only — no interaction
	REGIONS,    # Region-level borders and highlighting
	PROVINCES   # Province-level borders and highlighting
}
```

```gdscript
MapManager.set_map_layer(MapManager.MapLayer.PROVINCES)
MapManager.cycle_map_layer()   # Cycles VISUAL → REGIONS → PROVINCES → VISUAL
```

---

## How Color Lookup Works

The map is composed of three PNG images:
1. `Assets/Map/base_map.png` — Visible art (decorative only)
2. `Assets/Map/region_map.png` — One unique color per region
3. `Assets/Map/province_map.png` — One unique color per province

When the player moves the mouse, `MapRenderer` reads the pixel color under the cursor from the appropriate mask image. It converts the color to a lowercase `"#rrggbb"` hex string and calls:

```gdscript
var province_id = MapManager.get_province_by_color(hex_color)
var region_id   = MapManager.get_region_by_color(hex_color)
```

These look up the hex in `_province_color_map` and `_region_color_map`, which are built at startup from `DataManager.provinces_registry` and `DataManager.regions_registry`.

---

## Map Dimensions

```gdscript
# Set by main_game.gd once the map Sprite2D is laid out
MapManager.map_width   # float, default 3840.0
MapManager.map_height  # float, default 2160.0
```

`MapRenderer` and `MapCameraController` read these to calculate zoom limits and coordinate transformations.

---

## Province Ownership

```gdscript
# Assign a sect to a province
MapManager.assign_sect_to_province("sect_7", "hangzhou")

# Get all sects in a province
var sect_ids: Array = MapManager.get_sects_in_province("hangzhou")

# Get all sects in a region
var sect_ids: Array = MapManager.get_sects_in_region("jiangnan")
```

A province can hold any number of sects. Ownership is stored in `province_sects` dictionary.

---

## Querying Geography

```gdscript
# Region for a province
var region_id: String = MapManager.get_region_for_province("hangzhou")   # "jiangnan"

# All provinces in a region
var provinces: Array[String] = MapManager.get_provinces_in_region("jiangnan")

# Random province, optionally filtered by region
var prov: String = MapManager.get_random_province("jiangnan")
var any_prov: String = MapManager.get_random_province()

# Neighbours of a province
var neighbours: Array[String] = MapManager.get_neighbouring_provinces("hangzhou")

# Check adjacency
var adjacent: bool = MapManager.are_provinces_neighbouring("hangzhou", "suzhou")
```

---

## Province IDs (Full List)

`luoyang, kaifeng, zhongdu, chengdu, emei_mountains, yanmen_pass, yanzhou, north_steppe, dunhuang, western_mountains, guangzhou, pearl_river_delta, hangzhou, suzhou, goryeo_capital, goryeo_south`

---

## Region IDs and Culture Mapping

| region_id | culture |
|---|---|
| `central_plains` | CENTRAL_PLAINS |
| `jiangnan` | JIANGNAN |
| `sichuan` | SICHUAN |
| `lingnan` | LINGNAN |
| `northern_border` | NORTHERN_BORDER |
| `western_regions` | WESTERN_REGIONS |
| `goryeo` | GORYEO |

---

## Rebuilding Color Maps

Color maps are built once in `_ready()`. If you modify `DataManager.provinces_registry` or `DataManager.regions_registry` at runtime (which you should not), call:

```gdscript
MapManager.build_color_maps()
```

---

## Pitfalls

- `MapManager` depends on `DataManager` being loaded (load order 3) and its registries being populated. If `MapManager._ready()` runs before `DataManager` has loaded map data, the color maps will be empty. The autoload order guarantees this is safe in normal game flow.
- `map_width` and `map_height` default to `3840 × 2160` but are **overwritten by `main_game.gd`** when the game scene loads. Code that reads these values before `main_game.gd` runs (e.g., in another autoload's `_ready()`) will see the default values.
- Adding a new province requires: updating `provinces.json`, painting the new color on `province_map.png`, and ensuring the color is unique. Duplicate colors will produce incorrect lookup results.

---

## Best Practices

- Always use `get_sects_in_province()` and `get_sects_in_region()` rather than iterating `province_sects` directly.
- When generating sects in a specific region, use `get_random_province(region_id)` rather than hardcoding province names.
- For UI hover feedback, connect to `hovered_province_changed` and `hovered_region_changed` rather than polling `hovered_province_id` per frame.
