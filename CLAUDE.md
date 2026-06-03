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
- The gem follows Traveller RPG rules (Mongoose, Classic, and GURPS Space variants)
- Sector maps are 40x32 hex grids
- UWP (Universal World Profile) codes encode world characteristics
- ASCII output uses specific formatting for readability

## Reproducibility & Seeding
- Ruby uses the global PRNG (`Kernel#rand`, `Array#sample`, `Random.rand` all share it). The CLI calls `srand(int)` once before generation, so a seed makes the WHOLE pipeline deterministic (dice, names, spectral types, SVG belt jitter).
- Seeds are human-readable Crawford codes `XXXXX-XXXXX` (charset omits I/O/0/1). Any string folds into a code via FNV-1a; the code folds into the srand integer via FNV-1a. `Astromapper::Seed` implements this.
- Provide a seed via `build --seed CODE` (alias `-S`) or the `seed:` field in `_astromapper.yml`. Blank = random, but the chosen code is printed so it can be replayed.
- **Decision: per-language reproducibility only, NOT cross-language byte parity.** Each of Ruby/Go/Rust is internally reproducible, and all three now derive the same Crawford code + seed integer from a given input (FNV-1a everywhere). But they use different RNG algorithms (Ruby MT19937, Go math/rand, Rust ChaCha8), so the same seed yields DIFFERENT maps across languages. True cross-language identical maps would require one shared RNG + identical draw order — deliberately not pursued.

## Genre semantics (realism dial), not system size
- `genre` (normal | opera | firm) controls world REALISM, not the number/size of systems (that's `density` and per-star dice).
- `normal`: gonzo worlds, no star bias. `opera`: atmosphere/hydro realism pass + moderate F/G/K star bias. `firm`: also strips population from marginal worlds + strong F/G/K bias.
- The F/G/K star bias is the realized "B-practical" fix for the old dead `Volume#star_dm`: a genre-driven `+DM` (normal 0 / opera +2 / firm +4) on the primary star-TYPE roll (`Volume::STAR_BIAS`), so settled space trends toward warm, long-lived (habitable) stars. Verified gradient: ~32% / ~58% / ~86% F/G/K.

## Testing
- `rake test` (or `ruby -Itest test/golden_master_test.rb`). Minitest; no external deps.
- Golden-master test: a fixed seed regenerates a sector and byte-compares it to `test/fixtures/sector_normal_<seed>.txt`. After an INTENTIONAL generation change, regenerate with `UPDATE_GOLDEN=1 rake test`.
- Also asserts: same-seed determinism, different-seed divergence, and the genre F/G/K gradient.

## Known dependency-rot fixes (modern Ruby)
- `YAML.unsafe_load` (not `load`) is required for the config's `!ruby/range` under Psych 4+.
- `String#to_permalink` uses `unicode_normalize(:nfkd)` (ActiveSupport's `Multibyte::Chars#normalize` was removed in AS 8.1).
- `bin/astromapper` prepends `lib/` to `$LOAD_PATH` so it runs from a source checkout without `gem install`.