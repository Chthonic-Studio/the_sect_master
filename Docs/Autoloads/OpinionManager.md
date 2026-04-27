# OpinionManager

**File:** `Scripts/Globals/Managers/opinion_manager.gd`  
**Autoload name:** `OpinionManager`  
**Load order:** 12

---

## Purpose

`OpinionManager` **calculates the dynamic relationship score** between two characters. It is stateless — it reads from character data and sect relationships, computes a score, and returns it. No data is stored here.

---

## Getting an Opinion

```gdscript
var score: int = OpinionManager.get_opinion(char_a, char_b)
# Returns -100 to 100
```

`char_a` is the observer (the one forming the opinion). `char_b` is the subject (the one being judged).

Returns `0` if either argument is null or if both are the same character.

---

## Opinion Calculation Components

The score is built from four layers:

### 1. Sect Affiliation
- Same sect: **+10**
- Different sects (both in a sect): `sect_relationship * 0.25`
  - At max hostility (-100): **-25**
  - At max alliance (+100): **+25**

### 2. Trait Compatibility
Iterates `char_a`'s traits and checks:
- `char_b` has the **same trait**: adds `same_trait_opinion` from the trait's JSON.
- `char_b` has a **conflicting trait** (defined in `conflicts` array): adds `opposite_trait_opinion` (usually negative).
- `char_b` has a **specifically flagged trait**: adds the value from `specific_trait_opinions` dictionary in the trait's JSON.

### 3. Directed Opinions (Temporal)
Reads `char_a.directed_opinions[char_b.char_id]` — an array of active opinion modifiers such as "insulted" or "swayed". These expire over time.

### 4. Charisma Impact
`char_b`'s CHARISMA stat above 50 adds a small passive bonus: `(charisma - 50) * 0.2`.

---

## Trait Data Format for Compatibility

In trait JSON:

```json
{
  "id": "honorable",
  "same_trait_opinion": 10,
  "conflicts": ["deceptive", "cowardly"],
  "opposite_trait_opinion": -15,
  "specific_trait_opinions": {
    "ambitious": 5,
    "ruthless": -10
  }
}
```

---

## Usage in Other Systems

`SectProposal` uses `get_opinion(elder, sect_master)` to modify an elder's vote likelihood. An elder who respects the Sect Master gives +25 support; one who despises them gives -25.

---

## Pitfalls

- The opinion is **not symmetric**. `get_opinion(A, B)` and `get_opinion(B, A)` can return different values because `char_a`'s traits and opinions are used as the observer lens.
- Directed opinions expire by day (`expiration_day`), but `OpinionManager` does not clean them up — that is done in `CharacterData.process_daily_tick()`. If a character hasn't ticked recently (FROZEN tier), their expired opinions might still count until the next tick.
- There is no persistence in `OpinionManager` itself. If you need to snapshot an opinion value, store it yourself.

---

## Best Practices

- Always call `get_opinion()` at the moment you need the value rather than caching it. Opinion is dynamic and stale cached values can cause subtle bugs.
- To apply a timed opinion modifier (e.g., after a gift), use `CharacterData.add_directed_opinion()` on the character who is forming the opinion:

```gdscript
char_a.add_directed_opinion(
    char_b.char_id,   # who the opinion is directed at
    "gift_received",  # opinion modifier ID
    15,               # value
    90                # duration in days
)
```
