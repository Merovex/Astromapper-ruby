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
- **Astromapper::Astro**: Domain models (Star, World, Volume, Orbit) representing astronomical objects and their properties
- **Astromapper::Builder**: Generation logic for creating sectors and volumes with Traveller RPG rules
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