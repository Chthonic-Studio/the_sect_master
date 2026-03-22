# Modding The Sect Master

Welcome to the Modding Documentation for **The Sect Master**. TSM  is built from the beginning to be heavily data-driven, allowing you to easily add new traits, cultures, items, and even entirely new autonomous AI behaviors.

There are two types of mods in The Sect Master: **Data Mods** (JSON) and **Logic Mods** (Scripts).

---

## 1. Data Mods (Adding Traits, Names, Modifiers)
Data mods are simple JSON files. The game&#39;s `DataManager` automatically scans the `user://Mods/` directory and merges your JSONs with the vanilla game data.

### Mod Structure
Create a folder structure identical to the base game&#39;s `Data/` folder.
```text
user://Mods/
├── Traits/
│   ├── my_custom_traits.json
├── Names/
│   ├── new_demonic_names.json
└── Modifiers/
    ├── custom_pills.json
```

### Overwriting vs. Adding
* **Adding:** If you use a new `"id"` (e.g., `"id": "blood_demon_physique"`), the game will add it to the pool.
* **Overwriting:** If you use an existing vanilla `"id"` (e.g., `"id": "righteous"`), your JSON will **overwrite** the vanilla trait. This allows you to rebalance the base game.

---

## 2. Logic Mods (Adding AI Desires, Actions, UI logic)
If you want to add new behaviors (like a new `Desire` for characters to steal artifacts) or new UI scripts, **you cannot simply upload raw `.gd` files.** Godot exported builds cannot natively compile `.gd` files from the user directory.

To create a Logic Mod, you must pack your files using the Godot Editor.

### Workflow for Logic Mods:
1. **Download the Modding Kit / Base Project:** Open the game&#39;s project in Godot 4.4+.
2. **Create your Scripts:** Write your new `Desire` or `ActionPlan` extending our base classes. Place them in the appropriate `res://Scripts/` folders.
3. **Export as a Mod Pack (ZIP/PCK):**
   * Go to `Project -> Export`.
   * Select the files/folders specific to your mod.
   * Click **Export PCK/ZIP**.
   * Save it as `MyAwesomeMod.zip`.

### Installation
Players simply drop `MyAwesomeMod.zip` into their `user://Mods/` folder. The game will natively mount the `.zip` file into the virtual `res://` directory upon startup. The game&#39;s automated resource scanners will instantly pick up your new AI scripts and inject them into the simulation.

---

## 3. Best Practices
* **Avoid Monolithic Scripts:** If creating a complex Action, use Godot&#39;s node composition or helper RefCounted classes.
* **Respect the Simulation:** AI runs on hundreds of characters simultaneously. Do not use `get_node()` or traverse the SceneTree inside `evaluate()` functions. Read exclusively from the `CharacterData` object passed into the function.
* **Unique Naming:** Prefix your data IDs with your mod name to avoid conflicts with other mods (e.g., `"id": "taka_demonic_blood_pill"`).