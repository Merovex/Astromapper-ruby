# Astromapper CLI - Go Version

A command-line application for generating Traveller RPG star maps, reimplemented in Go from the original Ruby gem.

## Features

- **Seed-based Generation**: Enter any string as a seed to generate consistent, reproducible star maps
- **Two Generation Modes**:
  - **Sector Generation**: Creates a 32×40 hex grid (4×4 subsectors, each 8×10 hexes) with multiple star systems (ASCII + SVG)
  - **Volume Generation**: Creates a single hex system with detailed orbital information (ASCII only)
- **Density Selection for Sectors**: Choose from 8 density levels:
  - Extra Galactic (1% - deep space between galaxies)
  - Rift (3% - galactic voids)
  - Sparse (17% - frontier regions)
  - Scattered (33% - outer rim)
  - Standard (50% - typical space)
  - Dense (66% - inner systems)
  - Cluster (83% - stellar clusters)
  - Core (91% - galactic core)
- **Automatic File Output**: 
  - ASCII text files for all generations
  - SVG vector graphics for sector maps
  - Files saved to `output/` directory with timestamp
- **Traveller RPG Rules**: Implements world generation according to Mongoose Traveller rules
- **Random Seed Generation**: Automatically generates 16-character alphanumeric seeds if not provided
- **2000+ Planet Names**: Includes a database of sci-fi planet names from the original Ruby version

## Installation

```bash
# Ensure you have Go 1.21+ installed
go build -o astromapper
```

## Usage

### Basic Usage
```bash
# Generate a standard density sector with random seed
./astromapper

# Generate with specific seed
./astromapper --seed MYSEED123

# Generate sparse sector
./astromapper --density sparse

# Generate single star system
./astromapper --type volume
```

### Command-line Options

- `--type <type>` - Generation type: 'sector' or 'volume' (default: sector)
- `--density <density>` - Density for sector generation (default: standard)
  - Options: extra-galactic, rift, sparse, scattered, standard, dense, cluster, core
- `--seed <string>` - Seed string for generation
  - If not provided, generates a random 16-character alphanumeric seed
- `--list-densities` - List available density options with descriptions
- `--help` - Show help message

### Examples

```bash
# Generate sparse frontier sector
./astromapper --density sparse --seed FRONTIER

# Generate dense core sector with random seed
./astromapper --density core

# Generate single star system
./astromapper --type volume --seed ALPHA7

# List all density options
./astromapper --list-densities
```

## Output Format

The generated output follows the standard Traveller RPG format:

```
Location UWP         Temp Bases TC          Factions     Stars         Orbits        Name
-------- ----------- ---- ----- ----------- ------------ ------------- ------------- ----
0101     B654456-7   T    .     Ni          O,O,F        G2V           WGB           Andoria
```

### UWP (Universal World Profile)
- **Starport** (A-E, X): Quality of starport facilities
- **Size** (0-F): Planet size
- **Atmosphere** (0-F): Atmosphere type
- **Hydrographics** (0-A): Water percentage
- **Population** (0-C): Population exponent
- **Government** (0-F): Government type
- **Law Level** (0-F): Legal restrictions
- **Tech Level** (0-F): Technology level

### Additional Codes
- **Temperature**: F (Frozen), C (Cold), T (Temperate), H (Hot), R (Roasting)
- **Bases**: N (Naval), S (Scout), R (Research)
- **Trade Codes**: Ag (Agricultural), In (Industrial), Hi (High Pop), etc.
- **Factions**: O (Other), F (Faction), M (Military), N (Noble), S (Scout), P (Psion)

## Seed System

The seed system converts any input string into a deterministic random number generator seed using FNV-1a hashing. This ensures:
- Same seed always produces the same map
- Any length string can be used as seed
- If no seed is provided, a random 16-character alphanumeric seed is generated (e.g., "E7POGGAO3Z23GPFL")

## Project Structure

```
.
├── main.go                 # TUI application entry point
├── pkg/
│   ├── rng/               # Random number generator with seed support
│   ├── models/            # Domain models (Star, World, Orbit, etc.)
│   ├── builder/           # Generation logic
│   └── data/              # Embedded planet names
└── ruby-version/          # Original Ruby gem for reference
```

## File Output

Generated files are automatically saved to the `output/` directory with the following naming convention:
- ASCII: `{type}_{seed}_{timestamp}.txt`
- SVG: `{type}_{seed}_{timestamp}.svg`

Example:
- `sector_myseed_20240115-143022.txt`
- `sector_myseed_20240115-143022.svg`

The SVG files include responsive CSS that adapts to light/dark mode preferences.

## Differences from Ruby Version

- **CLI Interface**: Simple command-line interface with flags instead of Thor-based commands
- **Automatic Seed Generation**: Generates random 16-character seeds when not provided
- **Automatic File Writing**: Files are written automatically on generation (Ruby required separate commands)
- **Simplified Configuration**: No YAML configuration files; parameters are set via command-line flags
- **Embedded Data**: Planet names are embedded in the binary rather than loaded from external files
- **Single Binary**: Compiles to a single executable with no runtime dependencies

## Credits

Based on the original Astromapper Ruby gem, implementing Traveller RPG rules from:
- Mongoose Traveller
- Classic Traveller
- GURPS Space (for stellar characteristics)