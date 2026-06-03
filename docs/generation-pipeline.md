# Astromapper Generation Pipeline

This document walks through **how a sector is generated**, stage by stage: what is
rolled, what is calculated, the value ranges produced, and **which game system each
step comes from**.

Astromapper is a deliberate **hybrid**:

| Concern | Source system |
|---|---|
| Stellar **type / size** selection | **Traveller** (2d6 tables; companions derived from the primary) |
| Stellar / orbital **physics** (separation, snow line, limits, spacing) | **GURPS Space 4e** (pp. 104–107) |
| **World** generation (UWP, trade, factions, tech) | **Mongoose Traveller** (MgT pp. 170–180) |

The seam is intentional: GURPS gives believable orbital geometry; Traveller gives the
familiar UWP world. The notes at the end flag where the two don't quite line up.

---

## 0. Dice notation

> 🎲 **Likely rule set:** **Traveller** convention · *High* — everything is **2d6**; GURPS Space rolls **3d6**, so the 2d6 base is the Traveller tell.

All randomness routes through a few monkey-patched helpers (`extensions/integer.rb`):

| Expression | Meaning | Range |
|---|---|---|
| `n.d6` | sum of *n* six-sided dice | `n`…`6n` |
| `1.d3`, `1.d100` | one d3 / d100 | `1`–`3`, `1`–`100` |
| `toss(a, b)` | `max(0, a·d6 − b)` — *b* is a die modifier, floored at 0 | see below |
| `x.max(n)` | **cap** at n (returns n if x > n) | — |
| `x.min(n)` | **floor** at n (returns n if x < n) | — |
| `x.whole` | `max(0, x)` | ≥ 0 |
| `x.hexd` | hex digit, capped at `F` | `0`–`F` |
| `x.roman` | luminosity numeral (`V`, `III`, …; `500 → D`) | — |

Common tosses used throughout:

| Call | Formula | Range |
|---|---|---|
| `toss()` | 2d6 − 2 | 0–10 |
| `toss(2,0)` | 2d6 | 2–12 |
| `toss(2,1)` | 2d6 − 1 | 1–11 |
| `toss(2,4)` | max(0, 2d6 − 4) | 0–8 |
| `toss(2,7)` | max(0, 2d6 − 7) | 0–5 |
| `toss(1,0)` | 1d6 | 1–6 |
| `toss(3)` | 3d6 − 2 | 1–16 |

> **Reproducibility:** a seed calls `srand(int)` once before generation, so the entire
> stream below is deterministic. See `lib/astromapper/seed.rb`.

---

## Key variables

Both Traveller and GURPS describe generation as *“roll dice, then add/subtract modifiers
before reading a table.”* A **DM** (**die modifier**) is one of those add-ons. In this code
a `*_dm` name is **the rolled-and-modified number used to index a table**, and most of the
single-purpose ivars (`@size`, `@atmo`, …) are the **eight UWP digits** of a world.

### Die modifiers — the table indexes

| Variable | Computed as | Indexes / feeds | Meaning of a *higher* value |
|---|---|---|---|
| `star_dm` | `STAR_BIAS[genre]` → 0 / +2 / +4 | added into `type_dm` | genre pressure toward habitable stars |
| `type_dm` | `(2d6 + star_dm).max(12)` | the **spectral-type** table `[B B A M M M M M K G F F F]` | hotter, more Sun-like (toward F/G/K) |
| `size_dm` | `(2d6).max(12)` | the **luminosity-class** table `[0 1 2 3 4 5 … 500]` | larger/more evolved class (`500` = collapse → white dwarf) |
| orbit-count `dm` | `+4` giant · `+8` supergiant · `−4` M · `−2` K | added to `2d6` for **number of orbits** | bigger/hotter star → more orbits |
| `tek_dm` | Σ of starport/size/atmo/hydro/pop/gov modifiers | added to `1d6` for **tech level** | more developed world |

> **Note — DMs carry forward.** `type_dm` and `size_dm` are *stored on the primary* and
> reused for companions: a companion's type is `(2d6 + primary.type_dm).max(12)`. So a hot
> primary tends to have hot companions; the family resembles itself.
>
> `.max(12)` **caps** the index at the table's last slot (it does **not** mean "minimum 12").

### Geometry intermediates

| Variable | What it is | Range / values |
|---|---|---|
| `bode_constant` | Bode's-law base for orbit spacing: `orbit_to_au(o) = inner_limit + bode_constant·2^o` | `0.3 / 0.35 / 0.4`, or `0.2` for an M-V red dwarf |
| `ternary` | companion ordinal (0 = secondary, 1 = tertiary); shifts the separation-table index so later companions sit farther out | 0–1 |
| `separation` | companion distance from primary | AU (≈0.05 … 50) |
| `zone` | an orbit's position vs the star's biozone | `−1` inner · `0` biozone · `+1` outer |
| `distant` | far-outer flag (`au > 10 × biozone.outer`); gives a `+1` to outer-zone content rolls | boolean |
| `port_roll` | `2d6`, indexes the starport-quality table | 2–12 |
| `fax_r` | faction count: `1d3` ±1 by law | 0–4 |

### UWP attributes — the eight world digits

These ivars are the world's Universal World Profile (`Port Size Atmo Hydro Pop Gov Law-Tech`):

Digits use **Traveller extended hex** (eHex): `0-9, A-H, J-N, P-Z` — `I` and `O` are
skipped so they can't be mistaken for `1` and `0`. So `15→F, 16→G, 17→H, 18→J`.

| Variable | UWP digit | T5 ceiling | Currently generated |
|---|---|---|---|
| `port` | Starport | A (best) | A |
| `@size` | Size | F | 0–B \* |
| `@atmo` | Atmosphere | F | 0–A \* |
| `@h20` | Hydrographics (water) | A | 0–A |
| `@popx` | Population | F | 0–B \* |
| `@govm` | Government | F | 0–F |
| `@law` | Law level | **J** (18) | 0–J |
| `@tek` | Tech level | F | 0–F |

\* Size/Atmo/Pop are *capped* at the T5 ceiling but don't reach it: they're rolled as
flat 2d6 (`size = 2d6−1`, `atmo = 2d6−2`, `pop = 2d6−2`) rather than T5's
`Size + Flux` chains, so they top out around A–B. Reaching the full 0–F range would
require reworking those rolls (see note below).

> A stray `@hydro` (vs `@h20`) is a separate, mostly-unused variable — see Integration
> note #4.

---

## 1. Sector — which hexes hold a system

> 🎲 **Likely rule set:** **Traveller**-style, custom thresholds · *Medium* — `standard = 50%` matches Classic Traveller's per-hex world chance; the graded rift→core categories are a custom d100 extension, not from one book.

**File:** `builder/sector.rb`

A **40 × 32** hex grid. For each hex, roll **1d100** against a density threshold; if it
passes, build a `Volume` (system) there.

| `density` | Threshold (system if 1d100 ≤) | Typical systems* |
|---|---|---|
| extra_galactic | 1 | ~5 |
| rift | 3 | ~18 |
| sparse | 17 | ~110 |
| **dunbar** | 23 | **~150** (one [Dunbar's Number](https://en.wikipedia.org/wiki/Dunbar%27s_number) per sector) |
| scattered | 33 (default) | ~230 |
| dense | 66 | ~450 |
| cluster | 83 | ~570 |
| core | 91 | ~630 |
| *(standard/other)* | 50 | ~355 |

\* Empirically measured (normal genre, mean of several seeds on the 40×32 ≈ 1280-hex
grid). These run **well below `density% × 1280`** because a hex that passes the density
roll still produces a `Volume`, which is then **dropped if it has no mainworld** — only
~54% survive. Systems most likely to be dropped are M-dwarf stars, whose biozone is so
tight (and whose orbit count is low, `2d6 − 4`) that often no orbit lands a `World`.
Genre shifts this slightly: `opera`/`firm` raise the F/G/K share, and those stars have
wider biozones, so they survive a bit more often.

---

## 2. Volume — one system

> 🎲 **Likely rule set:** **Traveller** (2d6 companion table) + **custom** genre bias · *High / —* — the 2d6 companion-count table is Traveller lineage; the `STAR_BIAS` genre modifier is Astromapper's own invention, in no rulebook.

**File:** `builder/volume.rb`

For each occupied hex:

1. **Name** — sampled from the 2,000-name list (`named: true`) or the `CCRR` coordinate.
2. **Primary star** — `Star.new(self, star_dm: STAR_BIAS[genre])`.
3. **Companion count** — index `2d6` into `[0,0,0,0,0,0,0,0,1,1,1,1,2]`:

   | 2d6 | Companions |
   |---|---|
   | 2–7 | 0 |
   | 8–11 | 1 |
   | 12 | 2 |

**Genre star-type bias** (`Volume::STAR_BIAS`) — a die modifier added to the primary
**type** roll so that settled space trends toward warm, long-lived (habitable) stars:

| `genre` | `star_dm` | Effect | Observed F/G/K share |
|---|---|---|---|
| normal | 0 | gonzo, no skew | ~27% |
| opera | +2 | moderate skew | ~59% |
| firm | +4 | strong skew | ~83% |

The bias caps at F, so it only redistributes the **main-sequence** roll; a separate ~3–5%
of stars are **hot A/B/O** (the §3 Hot branch), genre-independent, plus the usual M dwarfs
and white dwarfs filling the remainder.

---

## 3. Primary star — type & size

> 🎲 **Likely rule set:** **classic Traveller stellar-generation lineage** (2d6 type + size,
> companions off the primary, with a *Hot* sub-table). The exact book is **unverified** — see
> "Provenance" below — but it is **not** GURPS. · *Medium*

**File:** `builder/star.rb`

```
natural = 2d6                                    # raw roll, BEFORE the genre bias
if natural >= 11:                                # ~8% — the Hot branch (rare, genre-independent)
    type_dm   = natural
    star_type = [A A A A A A A A A A B B O][2d6] # Hot sub-table: mostly A, rare B, very rare O
else:
    type_dm   = (natural + star_dm).max(10)      # genre bias toward F/G/K, capped at F (no spill into Hot)
    star_type = [B B A M M M M M K G F][type_dm]
size_dm   = (2d6).max(12)
star_size = [0 1 2 3 4 5 5 5 5 5 5 6 500][size_dm]   # luminosity class
```

- **Main-sequence table** is a 2d6 bell curve peaking on **M** at roll 7 (the Traveller
  signature). The genre `+DM` (§2) pushes results toward the F/G/K end, **capped at F** so it
  can never spill into the Hot band.
- **Hot branch** fires on a *natural* 11–12 (~8%), kept separate from the genre bias on
  purpose — hot stars are short-lived and **not** habitable, so habitability pressure must not
  inflate them. It yields mostly **A**, rarely **B**, very rarely **O** (≈0.1%).
- **Size** is the Yerkes luminosity class index (`0=Ia … 5=V main-sequence … 6=VI`).
  The sentinel **500** means the star collapses to a **white dwarf** (`type → 'D'`).
- **Spectral subtype** — `star_type + SPECTRAL[star_type].sample` → e.g. `G2`.

> Reachable types in practice: **O, B, A, F, G, K, M, D**. The full range is now live — the
> Hot branch reaches `A/B/O`, so the `O`/`B` reference rows (`STAR_CHART`, `INNER_LIMIT`,
> `BIOZONE`, `MASS`) are no longer dead data.

### Provenance — which Traveller?

The 2d6 mechanic (separate type + size rolls, companions derived from the primary, extremes
sent to *Hot*/*Special* sub-tables) is common to the **entire Traveller stellar-generation
lineage**:

- **Classic Traveller, Book 6: Scouts** (GDW, 1983) — the original.
- **MegaTraveller — World Builder's Handbook** (Digest Group Publications, 1989) — the famous
  detailed expansion; the most likely candidate for a from-memory implementation.
- **Mongoose — A Guide to Star Systems** (Dougherty, 2015) and the **2e World Builder's
  Handbook** (2022) — modern descendants, explicitly named after the DGP book.

This code was written **before 2016 and without the Mongoose 2e books**, so its direct
ancestor is almost certainly **Book 6: Scouts** or the **MegaTraveller World Builder's
Handbook** — likely reconstructed partly from memory (which explains why it doesn't match any
one printed table verbatim). The comparison below is against the modern Mongoose tables only
because those are the ones reproduced in open-source code; the older books share the same
shape.

| 2d6 | 2 | 3–7 | 8 | 9 | 10 | 11–12 |
|---|---|---|---|---|---|---|
| **This code** | A | M | K | G | F | **Hot → A/B/O** |
| Mongoose "Realistic" | Special | M (3–8) | K (9) | G (10) | F (11) | Hot (12+) |
| Mongoose "Traditional" | Special | M (3–5), K (6–7) | G (8–9) | F (10) | — | Hot (11–12) |

With the Hot branch restored, the code now matches the lineage's **two-stage shape** (main
sequence + a Hot sub-roll), differing mainly in collapsing the `2` → *Special* result
straight to `A`. *(Note: the **world** generation in §7 cites Mongoose **1e** page numbers,
so overall the codebase blends Traveller star-gen + MgT 1e world-gen + GURPS Space 4e orbital
physics — sources spanning 1983–2008.)*

---

## 4. Companion stars — derived from the primary

> 🎲 **Likely rule set:** **Mixed** — separation = **GURPS Space 4e** p.105; type = **Traveller** · *High (cited)* — the clearest seam: GURPS sets *where* the companion sits, Traveller sets *what* it is.

**File:** `builder/star.rb` lines 88–93

```
separation = (2d6 × COMPANION_SEPARATION[toss(3) + 4·ternary − 2]).round(2)  # GURPS Space 4e p.105
orbit      = au_to_orbit(separation) − 1
star_type  = [X B A F F G G K K M M M M][(2d6 + primary.type_dm).max(12)]
star_size  = [0 1 2 3 4 500 500 5 5 6 …][(2d6 + primary.size_dm).max(12)]
```

- `COMPANION_SEPARATION` buckets AU separation: `0.05` (very close) → `0.5` → `2.0` →
  `10.0` → `50.0` (distant), GURPS Space 4e.
- The companion's **type is rolled relative to the primary** (`2d6 + primary's roll`) —
  the Traveller "companion off the primary" mechanic.
- When a companion is placed, its **forbidden orbit band** (0.67×–3× its AU) is cleared
  of planets (GURPS Space 4e p.107, `companions=`).

---

## 5. Star-derived physics

> 🎲 **Likely rule set:** **GURPS Space 4e** (limits, cited pp.104–107) + **Bode** spacing · *High / Medium* — radius/snow-line/outer-limit are cited GURPS; but orbit spacing is pure `inner + k·2^o` (Bode), **not** GURPS's random 1.4–2.0× multipliers, so spacing is custom/Bode.

**File:** `builder/star.rb`

Once type+size are known, the star's geometry is computed:

| Quantity | Formula | Source |
|---|---|---|
| Luminosity, temperature, mass, radius | `STAR_CHART[spectral]` lookup | (real stellar data) |
| `radius` | `(155000 · √luminosity)²` | GURPS Space 4e p.104 |
| `snow_line` | `4.85 · √luminosity` | GURPS Space 4e p.106 |
| `outer_limit` | `40 · mass` (AU) | GURPS Space 4e p.107 |
| `inner_limit` | `INNER_LIMIT[type][size%10]` (AU) | table |
| `biozone` | `BIOZONE[type][size%10]` → `[inner_au, outer_au]` | table |
| **Orbit spacing** | `orbit_to_au(o) = inner_limit + (bode_constant · 2^o)` | Bode's law |

`bode_constant` is `0.3 / 0.35 / 0.4` (rolled), or `0.2` for an M-V red dwarf. Each
orbit out doubles the Bode term — orbits get geometrically wider.

**Number of orbits** = `(2d6 + dm).whole`, with:

| Condition | dm |
|---|---|
| giant (size III) | +4 |
| supergiant (size < III) | +8 |
| M-type | −4 |
| K-type | −2 |

Orbits beyond `outer_limit` are not generated; trailing empty orbits are pruned.

---

## 6. Orbit population — what sits in each slot

> 🎲 **Likely rule set:** **Custom** — GURPS-*structured* but **Traveller-zoned** · *Medium* — ⚠️ GURPS zones orbits by the **snow line**, but `snow_line` is computed and **never used**; zoning actually keys off the **biozone** (a Traveller habitable-zone idea), with 2d6/1d6 content tables. This is the rough seam (see Integration note #6).

**File:** `builder/orbit.rb`

Each orbit is first **zoned** by its AU versus the biozone:

| Zone | Condition |
|---|---|
| inner | `au < biozone.inner` |
| biozone | within `[inner, outer]` |
| outer | `au > biozone.outer` |
| *distant* | `au > biozone.outer × 10` (a roll bonus outward) |

Then populated by zone:

**Inner zone** (`populate_inner`, 2d6):

| 2d6 | Body |
|---|---|
| < 5 | empty |
| 5–6 | **Hostile** (exotic/corrosive world) |
| 7–9 | Rockball |
| 10–11 | Belt |
| 12 | Gas Giant |

**Outer zone** (`populate_outer`, 1d6 +1 if distant):

| roll | Body |
|---|---|
| 1 | Rockball |
| 2 | Belt |
| 3 | empty |
| 4–7 | Gas Giant |
| else | Rockball |

**Biozone** (`populate_biozone`):
- `always_inhabited` (default): always a **World**.
- otherwise: 2d6 — `2–11` World, `12` Gas Giant.

Gas Giants roll **Large/Small** (`1d6 < 4 ? L : S`) and a moon count; the mainworld's
"gas giant present" flag is set if any orbit is a `G`.

---

## 7. The World — Traveller UWP

> 🎲 **Likely rule set:** **Mongoose Traveller** (1e) · *High (cited)* — MgT pp.170–180; the temperature band (F/C/T/H/R) and factions (O/F/M/N/S/P) are distinctly Mongoose, not GURPS or T5.

**Files:** `Terrestrial` then `World` in `builder/orbit.rb`

### 7a. Terrestrial base (size, atmosphere, temperature, water)

| Attribute | Roll / rule | Range | Cite |
|---|---|---|---|
| **Size** | `2d6 − 1` | 1–11 | MgT 170 |
| **Atmosphere** | `2d6 − 2` | 0–10 | MgT 170 |
| **Temperature** | `2d6 + mod[atmo]` → `F/C/T/H/R` (Frozen…Roasting) | — | MgT 171 |
| **Hydrographics** | size<2 or outside biozone → 0; thin/exotic atmo → `(2d6−11+size)`; else `(2d6−7+size)`, capped 10; −2 if Hot, −6 if Roasting | 0–10 | MgT 172 |

If `genre` is **opera** or **firm**, a realism pass (MgT 180) strips atmosphere/water
from worlds too small to hold them (size < 3 → vacuum, etc.).

### 7b. World social profile

| Attribute | Roll / rule | Range | Cite |
|---|---|---|---|
| **Starport** | `port_roll = 2d6` → `X X X E E D D C C B B A…` | X–A | MgT |
| **Population** | `2d6 − 2` (+firm atmo/size adjustments) | 0–10(11) | MgT |
| **Government** | `(2d6 − 7 + pop).whole` | 0–15 | MgT 173 |
| **Law** | `(2d6 − 7 + gov).whole` | 0–15 | MgT 173 |
| **Factions** | `1d3` (min 3) ±1 by law; types `O/F/M/N/S/P` | 0–4 groups | MgT 173 |
| **Tech** | `1d6 + Σ tek_dm`, capped by env. limit, pop, and `tech_cap` | 0–F | MgT 170, 179 |

`tek_dm` sums modifiers from **starport, size, atmosphere, hydrographics, population,
government** (each an indexed table, MgT 170). The environmental atmosphere limit then
caps it (MgT 179). If population is 0, gov/law/tech are zeroed (a barren world).

### 7c. Derived labels

- **Trade codes** — `Ag, As, Ba, De, Fl, Ga, Hi, Ht, IC, In, Lo, Lt, Na, NI, Po, Ri, Va, Wa`
  computed from size/atmo/hydro/pop thresholds.
- **Bases** — Navy / Scout / Consulate / Pirate, each rolled against a starport-keyed
  target; rendered together with the gas-giant flag (e.g. `NSGC.`).
- **Temperature fix-ups** — Ice/Vacuum force Frozen; Agricultural/Garden/Rich/Water force
  Temperate.

The final **UWP** is `Port Size Atmo Hydro Pop Gov Law – Tech` (hex digits), e.g.
`B564879-9`.

---

## 8. Moons

> 🎲 **Likely rule set:** **GURPS Space 4e**-inspired, custom dice · *Low–Medium* — the three moon families (close `C`, far `F`=×5, extreme `E`=×25) mirror GURPS's gas-giant moon families (inner moonlets / major / outer), but rolled on 2d6 with no citation in code.

**File:** `Moon` in `builder/orbit.rb`

Planets and gas giants roll `1d3` moons (gas-giant size depends on Large/Small). Each
moon gets a size (relative to its parent), an orbital distance (close/far/extreme radii),
and reduced atmosphere/hydrographics by zone. Moons render under their planet as
`radii. UWP`.

---

## Provenance summary

| Stage | Mechanic | System |
|---|---|---|
| Sector density | 1d100 vs threshold | custom (Traveller-flavored) |
| Companion count | 2d6 table | Traveller |
| **Star type/size** | 2d6 tables, companion off primary | **Traveller** (2d6) |
| Companion separation | `2d6 × separation table` | **GURPS Space 4e** p.105 |
| Forbidden orbits | 0.67×–3× clear | **GURPS Space 4e** p.107 |
| Radius / snow line / outer limit | √luminosity, 40·mass | **GURPS Space 4e** pp.104–107 |
| Orbit spacing | Bode `inner + k·2^o` | Bode's law |
| Orbit contents | zone + d6/2d6 tables | custom |
| **World UWP** | size/atmo/hydro/pop/gov/law/tech | **Mongoose Traveller** pp.170–180 |

---

## Integration notes & known seams

Where the GURPS↔Traveller graft shows (useful if re-tuning the blend):

1. **Type table is 2d6, not GURPS 3d6.** GURPS Space generates *stellar mass* on 3d6 and
   derives type from it; this code instead picks type directly on a Traveller 2d6 table,
   then reads mass/luminosity back out of `STAR_CHART`. So the *physics* (GURPS) is driven
   by a *type chosen the Traveller way*.
2. **Hot stars (resolved).** Originally `B`/`O` were unreachable — the flat type array never
   indexed them, so their `STAR_CHART`/`INNER_LIMIT`/`BIOZONE`/`MASS` rows were dead. The §3
   **Hot branch** (natural 11–12 → A/B/O) now makes them live, decoupled from the genre bias
   so they stay rare (~3–5%) and don't get inflated toward "habitable." An `O9` row was added
   to `STAR_CHART` and `INNER_LIMIT['O']`/`BIOZONE['O']`/`MASS['O']` were extended/fixed so an
   `O` star can't crash the orbit math.
3. **`star_dm` is a precondition, not a postcondition.** Habitability correlation is
   produced by biasing the star *before* the world exists (warm star → Earth-like biozone
   → breathable world), not by inspecting a finished world (which would be circular).
4. **Two hydrographics fields existed.** World water lives in `@h20`; a stray `@hydro`
   (used by Hostile worlds and two trade codes) was a separate, unrendered variable — a
   bug that left some worlds dry. Mainworld water now uses `@h20` consistently.
5. **Government index overflow (fixed).** `firm` could push population to 11 → government to
   16, overrunning a 16-element tech-modifier table (`orbit.rb:253`) and crashing. Government
   is now capped at 15 (Traveller codes are 0–F) at the source.
6. **Orphaned snow line (the biggest GURPS↔Traveller seam).** `snow_line` (GURPS Space 4e
   p.106) is computed on every star but **never read**. GURPS zones a system's orbits by
   the snow line; this code instead zones by the **biozone** (Traveller habitable zone).
   So the GURPS orbit-content skeleton was re-pinned to a Traveller reference point. To
   finish the integration, either drive orbit zoning from `snow_line` (true GURPS), or keep
   the biozone approach and delete the dead `snow_line` (commit to Traveller).
