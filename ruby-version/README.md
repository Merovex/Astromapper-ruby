Traveller Astromapper
==========================

The **Traveller Astromapper** creates random Traveller star maps intended for YOTU (Your Own Traveller Universe).

The maps are generated using an inspired amalgam of [Traveller5](http://www.farfuture.net/) and [Classic Traveller](http://www.farfuture.net/) rules, with some [Gurps Space](http://www.sjgames.com/gurps/books/space/) 4e and 3e.

Traveller5 WorldGen (the StSAHPGL-T tables) is used when generating the World characteristics (the UWP). Classic Traveller is used when fleshing out star system details such as stars, non-world orbits, presence of companion stars. Gurps is used to flesh out star characteristics and the impact of a companion star on the primary's orbits.

* Sector: 40x32 hex grid
* Tract:  8x10 hex grid (Traveller Subsector)
* Volume: 1-hex
* World: primary inhabited planet.
* Orbit: A slot around primary star, may include companion stars, planets, belts or nothing.

Installation
============

This software runs on modern Ruby (tested on **Ruby 3.x**). From a source checkout:

```
bundle install         # installs activesupport, thor, minitest
bin/astromapper version
```

To convert from SVG to JPG, PNG, GIF you will need to install Imagemagick with -rsvg flag (later feature).

How to Use Traveller Astromapper
======================

To create a new Traveller Astromapper project, execute the following on the command line:

```
astromapper new yotu_sector
```

The command creates the following directory structure:

```
yotu_sector
├── _astromapper.yml
├── output
└── templates
    └── names.yml
```

Configuration
-------------

Edit `_astromapper.yml` to control generation:

* **density** — systems per sector: `rift`, `sparse`, `dunbar` (~150, one Dunbar's Number), `scattered` (default), `dense`, `cluster`, `core`.
* **genre** — the realism⟷romance stellar slider:
  * `firm` — the galaxy *as it really is* (M-dwarf-dominated, ~23% F/G/K, sparse).
  * `normal` — classic-Traveller midpoint (~48% F/G/K).
  * `opera` — space opera, Sun-like and habitable (~82% F/G/K).
* **sophonts** — `human` (default; worlds are Settled/Colony) or `varied` (native alien sophonts).
* **seed** — a Crawford code (`XXXXX-XXXXX`) or any string for reproducible maps. Leave blank for random (the seed used is printed). Override with `astromapper build --seed CODE`.
* **always_inhabited** — `true` (default) guarantees a mainworld per system.
* **prune_isolated** — `true` (default) drops systems with no neighbour within jump-4 (lone stars no route can reach), so the map has no disconnected dots.
* **islands** — `true` (default) outlines clusters of nearby systems on the SVG along the hex grid. Tune with `island_jump` (cluster reach in jumps, default 2), `island_min` (minimum systems per island, default 2), and `island_opacity` (default 0.85).

Worlds follow **Traveller 5** WorldGen (UWP, the Ix/Ex/Cx extensions, climate, trade codes); star systems use Classic Traveller + GURPS Space orbital mechanics. See `docs/generation-pipeline.md` for the full algorithm.

Commands: `astromapper new <name>`, `build [--seed CODE]`, `svg`, `about <hex>`, `version`. Each `build` writes both the ASCII `.sector` and a T5 Second Survey `.tab` (below).

ASCII Output
------------

The block below shows Traveller Astromapper's ASCII output. The top row is the key system aspects: Volume ID, World UWP, Temperature, Presence of Bases & Gas Giants, Trade Codes, Stars, Primary Star's Orbits, Name. The rows that follow elaborate the primary star's orbits. Rows with two dashes are the Primary's orbits, orbit type, UWP, and orbit distance (usable for travel and year length). Other rows with the '/' are that orbit's satellites. When the UWP is dots, that orbit is empty.

```
1201 E949556-5 T ..G.. .. Lt,NI                     F0IV/DB           R..WGG..S         Secundus
  --  1.    R // X600000-0 //  0.4 au
                            /    7 rad. X420000
                            /    9 rad. X620000
  --  2.    . // .......-. //  0.7 au
  --  3.    . // .......-. //  1.4 au
  --  4. *  W // E949556-5 //  2.8 au
  --  5.    G // Large GG  //  5.6 au
  --  6.    G // Large GG  // 11.2 au
                            /    1 rad. XR00000
                            /    6 rad. X402000
                            /    7 rad. X405000
                            /    9 rad. X100000
                            /   10 rad. X302000
  --  7.    . // .......-. // 22.4 au
  --  8.    . // .......-. // 44.8 au
  --  9. -  S // DB        // 89.6 au
```

To generate a (mostly) random Traveller sector in the ASCII format, execute the following on the command line:

```
astromapper generate
```

SVG Output
----------

Traveller Astromapper converts the ASCII output as described above to create an SVG file describing the key aspects of a volume. This includes the Star type, Starport, Name and the presence of bases (Navy, Scout, etc.) and Gas Giants. Clusters of nearby systems are outlined as **islands** along the hex grid (see the `islands` config keys above).

To convert that ASCII into an SVG image, execute the following:

```
astromapper svg
```

T5 Second Survey (Tab) Output
-----------------------------

Every `astromapper build` also writes a **T5 Second Survey** tab-delimited file
(`output/<name>.tab`) — the TravellerMap interchange standard, robust to parse and
interoperable with TravellerMap and other Traveller tools. A `#`-commented legend
heads the file; the columns are:

```
Sector  SS  Hex  Name  UWP  Bases  Remarks  Zone  PBG  Allegiance  Stars  {Ix}  (Ex)  [Cx]  Nobility  W  RU
```

Tools
-----

`tools/` holds standalone scripts (run with plain `ruby` against the lib) for format
bridging and post-processing — handy when importing a foreign "Converted Sector" JSON
or overlaying canon data:

| Script | Purpose |
|--------|---------|
| `json2tab.rb in.json [out.tab]` | Converted-Sector JSON → T5 Second Survey tab |
| `json2sector.rb in.json [out.sector.txt]` | JSON → expanded columnar sector (every orbit + moons) |
| `json2svg.rb in.json [out.svg]` | JSON → SVG, via the production renderer |
| `sector2svg.rb in.tab [out.svg]` | T5SS tab (or columnar `.sector.txt`) → SVG |
| `enrich.rb in.json [out.json]` | layer the Ruby T5 features (Ix/Ex/Cx/RU, moons, trade codes) onto a lean JSON **without** re-rolling the base values |
| `canon.rb rename\|tab\|highlight <file>` | overlay canon system names (`.sector` / `.tab`) and tint canon hexes (`.svg`) |
| `island-borders.rb in.svg` | draw island borders onto an existing SVG (also woven into the generator) |
| `island-conflicts.rb in.tab` | diagnose island-border overlaps / touches |

The island-border geometry is shared (`lib/astromapper/islands.rb`), so the generator,
`island-borders.rb`, and `sector2svg.rb` all produce identical, conflict-free borders
(each hex belongs to exactly one island via nearest-cluster assignment).

License
=======

The Astromapper software is released under the **MIT License**. The game rules it
implements (Traveller, GURPS) are used under their respective fair-use policies. See
[LICENSE.md](../LICENSE.md) for the full text — MIT license, the Far Future Enterprises
Traveller Fair Use Policy, the Steve Jackson Games / GURPS notice, and credits.

Changelog
=========

Version 2.1 (2026)
------------------
* **T5 Second Survey tab export** — every build emits a TravellerMap-compatible `.tab` (`Sector SS Hex Name UWP Bases Remarks Zone PBG Allegiance Stars {Ix} (Ex) [Cx] Nobility W RU`).
* **Island borders** — clusters of nearby systems are outlined on the SVG along the hex grid; tunable, and conflict-free (each hex belongs to one island). Shared geometry in `lib/astromapper/islands.rb`.
* **prune_isolated** drops lone systems no route can reach.
* **`tools/`** — format-bridge and post-processing scripts (`json2tab`, `json2sector`, `json2svg`, `sector2svg`, `enrich`, `canon`, `island-borders`, `island-conflicts`).

Version 2.0 (2026)
------------------
* **Traveller 5 WorldGen**: full StSAHPGL-T UWP (with Flux, eHex, reroll-on-10), the Ix/Ex/Cx Extensions + Resource Units, HZ-based climate, the complete T5 trade-classification table, T5 bases, and native intelligent life.
* **Genre stellar slider** (`firm`/`normal`/`opera`) spanning the real galaxy → space opera, plus a `dunbar` density and a `sophonts` (human-only) flag.
* **Reproducible seeds** (`--seed`, Crawford codes) so a seed always yields the same map.
* Runs on modern Ruby (3.x); golden-master + property test suite; many correctness fixes.

Version 1.0 (7 April 2013)
--------------------------
* Re-implemented as Ruby Gem

Version 0.1 (1 March 2012)
--------------------------
* Initially written; generate sector map; convert to SVG