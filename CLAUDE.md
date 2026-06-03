# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Key Learnings from Development

### Porting Code Between Languages
- When porting from one language to another (Ruby to Go), don't just translate syntax - understand the domain logic first
- Array/slice bounds are a common source of bugs when porting - always verify index calculations against array sizes
- Different languages have different conventions (Ruby's 40x32 vs standard Traveller's 32x40) - verify against domain standards

### User Experience Design
- Start with the simplest interface that solves the problem (CLI vs TUI)
- Seed systems should balance reproducibility with ease of use (readable formats like XXXXX-XXXXX)
- When accepting user input, handle multiple formats gracefully (raw strings vs formatted codes)

### Random Generation Systems
- Use cryptographically secure random for seed generation
- Convert arbitrary strings to fixed-format codes for consistency
- Character sets matter - avoid ambiguous characters (I/1, O/0) in user-facing codes

### File Organization
- Separate concerns clearly: models, builders, formatters (SVG/ASCII), utilities (RNG)
- Embed static data (planet names) rather than requiring external files for portability
- Generate both human-readable (ASCII) and visual (SVG) outputs

### Testing Approach
- Test edge cases early (empty hexes, array bounds, format conversions)
- Verify output matches domain expectations (hex coordinates, subsector layouts)
- Use consistent test seeds to verify reproducibility

### Cross-Implementation Consistency
- When maintaining multiple implementations (Go, Rust, Ruby), ensure feature parity across all versions
- Use one implementation as reference when fixing bugs or adding features to others
- Test with identical seeds to verify consistent output across implementations
- Document shared algorithms and formulas to ensure consistent behavior

### Output Formatting and Alignment
- Text alignment issues compound - fix systematically by defining exact column widths upfront
- Always verify output visually, not just programmatically - alignment issues are immediately obvious to users
- When porting formatting code, preserve exact spacing and padding specifications
- Create test outputs with maximum-width values to catch overflow issues early

### Feature Discovery Through Comparison
- Comparing implementations reveals missing features (orbits, factions, etc.)
- Use working implementation as specification for missing features
- Check both data generation AND display/serialization when comparing outputs
- Features may exist in models but not be displayed - check entire pipeline

### Incremental Development Strategy
- Implement core functionality first (basic generation), then enhance (add orbits, factions)
- Keep implementations in sync - when adding a feature to one, add to all
- Test each incremental addition before moving to the next feature
- Use consistent random seeds to verify changes don't break existing functionality

## Project Overview
Astromapper is a Ruby gem that generates random Traveller RPG star maps. It creates ASCII and SVG outputs of star systems with detailed orbital mechanics and world characteristics based on Traveller RPG rules.

## Common Development Commands

### Build and Install
```bash
# Build the gem
rake build

# Install the gem locally
rake install

# Release to RubyGems (requires credentials)
rake release
```

### Running Astromapper
```bash
# Create a new project
astromapper new <project_name>

# Generate ASCII sector map (run in project directory)
astromapper generate

# Convert ASCII to SVG
astromapper svg

# Get volume details
astromapper about <volume_id>
```

### Dependencies
```bash
# Install dependencies
bundle install

# Note: Optional ImageMagick with RSVG for format conversion
```

## Architecture and Code Structure

### Module Organization
- **Astromapper::Builder**: ALL domain models AND generation logic (Sector, Volume, Star, Orbit and its subclasses World/GasGiant/Belt/Rockball/Hostile/Moon). This is the heart of the system. (Note: a former empty `Astromapper::Astro` stub namespace was deleted — models live only under Builder.)
- **Astromapper::Seed**: Crawford-code (XXXXX-XXXXX) seed handling with FNV-1a derivation.
- **Astromapper::Extensions**: Ruby core class extensions for dice rolling and utility methods
- **Astromapper::CLI**: Thor-based command-line interface handling user commands

### Key Files
- `lib/astromapper/astromapper.rb`: Main module with autoloads for lazy loading
- `lib/astromapper/cli.rb`: Command-line interface definition
- `templates/config.erb`: Project configuration template
- `templates/names.yml`: Database of 2000+ sci-fi planet names

### Configuration System
Projects use `_astromapper.yml` files generated from ERB templates. Configuration includes sector dimensions, output formats, and generation parameters.

### Design Patterns
- Extensive use of autoloading for performance
- Builder pattern for complex object construction
- Template-based project scaffolding with ERB
- Monkey patching of Integer/String classes for dice notation and utilities

## Important Conventions
- **Worlds use Traveller 5 WorldGen** (see below); star systems use Classic Traveller + GURPS Space 4e orbital mechanics. GURPS-defined orbital math is intentionally NOT changed.
- Sector maps are 40x32 hex grids
- UWP (Universal World Profile) codes encode world characteristics, rendered in **extended hex (eHex)**: `0-9 A-H J-N P-Z` (skips I/O)
- ASCII output uses specific formatting for readability; the sector file opens with a `#`-commented legend (parsers skip lines not matching `/^\d{4}/`)

## Traveller 5 WorldGen
- The UWP is rolled per T5 (`builder/orbit.rb`): Size `2D-2` (reroll 10→1D+9), Atmo `Flux+Size`, Hydro `Flux+Atm`, Pop `2D-2` (reroll 10→9+1D), Gov `Flux+Pop` (max F), Law `Flux+Gov` (max **J**), Tech `1D+T5 mods`. **Flux = `1D-1D`** (symmetric −5..+5; the `flux` helper on `Builder::Base`, NOT the old clamped `toss(2,7)`).
- **Extensions** Ix/Ex/Cx + Resource Units (`World#build_extensions`, T5 page 435), shown as `{ +n } (RLI±E) [HASS] RU:n`. **Climate** is HZ-Variance-based (`World#climate`). **Trade codes** = full T5 TCS table (page 434); Political/Special are referee-deferred. **Starport** uses T5 orientation (low roll = best). **Native life** (`World#native_status`, page 436) gated by the `sophonts` flag.
- Pages photographed from the T5 book drove these; provenance is documented per-section in `docs/generation-pipeline.md`.

## Genre = the realism⟷romance stellar slider
- `genre` selects the **stellar model** (`Star#initialize`), tuned so the three options span the real galaxy to space opera:
  - **firm** — realistic main-sequence census (M-heavy array `M M F M M M M M K K G M`, hot only on nat 12). Matches the real solar neighbourhood: ~76% M, ~23% F/G/K.
  - **normal** — 50/50 blend of the T5 table and the realistic base (~48% F/G/K).
  - **opera** — the T5 spectral table (`Flux→type`, then ½ M→K). Sun-like, G-dominant (~82% F/G/K).
- `STAR_BIAS` (in `Volume`) is now all-zero — the genre split is model-based, not a die modifier. Genre ALSO drives world/pop realism passes (opera/firm) and the `firm` pop-strip.
- Worlds around **F-and-hotter stars are capped to colony size** (pop ≤ 6): short-lived/UV-harsh stars host colonies, not native homeworlds.

## Reproducibility & Seeding
- Ruby uses the global PRNG (`Kernel#rand`, `Array#sample`, `Random.rand` all share it). The CLI calls `srand(int)` once before generation, so a seed makes the WHOLE pipeline deterministic (dice, names, spectral types, SVG belt jitter).
- Seeds are human-readable Crawford codes `XXXXX-XXXXX` (charset omits I/O/0/1). Any string folds into a code via FNV-1a; the code folds into the srand integer via FNV-1a. `Astromapper::Seed` implements this.
- Provide a seed via `build --seed CODE` (alias `-S`) or the `seed:` field in `_astromapper.yml`. Blank = random, but the chosen code is printed so it can be replayed.
- **Decision: per-language reproducibility only, NOT cross-language byte parity.** Each of Ruby/Go/Rust is internally reproducible, and all three now derive the same Crawford code + seed integer from a given input (FNV-1a everywhere). But they use different RNG algorithms (Ruby MT19937, Go math/rand, Rust ChaCha8), so the same seed yields DIFFERENT maps across languages. True cross-language identical maps would require one shared RNG + identical draw order — deliberately not pursued.

## Testing
- `rake test` (or `ruby -Itest test/golden_master_test.rb`). Minitest; no external deps. (The `test/` dir was previously hidden by an over-broad `.gitignore` `test` pattern — now fixed.)
- Golden-master test: a fixed seed regenerates a sector and byte-compares it to `test/fixtures/sector_normal_<seed>.txt`. After an INTENTIONAL generation change, regenerate with `UPDATE_GOLDEN=1 rake test`.
- Also asserts: same-seed determinism, different-seed divergence, and the genre stellar model (opera > normal, opera > firm, firm M-heavy).

## Known dependency-rot fixes (modern Ruby)
- `YAML.unsafe_load` (not `load`) is required for the config's `!ruby/range` under Psych 4+.
- `String#to_permalink` uses `unicode_normalize(:nfkd)` (ActiveSupport's `Multibyte::Chars#normalize` was removed in AS 8.1).
- `bin/astromapper` prepends `lib/` to `$LOAD_PATH` so it runs from a source checkout without `gem install`.