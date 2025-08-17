# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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