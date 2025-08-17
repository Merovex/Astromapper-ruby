# Rust Implementation Plan for Astromapper

## 1. RNG Strategy - Making Seeded RNG Available Everywhere

### Option A: Thread-Local Storage (Recommended)
```rust
thread_local! {
    static RNG: RefCell<Option<StdRng>> = RefCell::new(None);
}

// Initialize at start of generation
pub fn init_rng(seed: &str) {
    let seed_value = string_to_seed(seed);
    RNG.with(|r| {
        *r.borrow_mut() = Some(StdRng::seed_from_u64(seed_value));
    });
}

// Use throughout codebase
pub fn roll_2d6() -> u8 {
    RNG.with(|r| {
        let mut rng = r.borrow_mut();
        let rng = rng.as_mut().expect("RNG not initialized");
        rng.gen_range(2..=12)
    })
}
```

### Option B: Pass RNG Reference
```rust
pub struct WorldBuilder<'a> {
    rng: &'a mut StdRng,
}

impl<'a> WorldBuilder<'a> {
    pub fn build(&mut self) -> World {
        let pop = self.rng.gen_range(0..=12);
        // ...
    }
}
```

### Option C: Arc<Mutex<StdRng>> (For Multi-threading)
```rust
pub struct Generator {
    rng: Arc<Mutex<StdRng>>,
}
```

## 2. Module Structure

```
astromapper/
├── Cargo.toml
├── src/
│   ├── main.rs              # CLI entry point using clap
│   ├── lib.rs               # Library root
│   ├── rng.rs               # RNG module with thread-local storage
│   ├── models/
│   │   ├── mod.rs
│   │   ├── star.rs         # Star struct & methods
│   │   ├── orbit.rs        # Orbit trait & implementations
│   │   ├── world.rs        # World/UWP implementation
│   │   ├── sector.rs       # Sector & Volume structs
│   │   └── trade_codes.rs  # Trade code calculations
│   ├── builders/
│   │   ├── mod.rs
│   │   ├── star_builder.rs
│   │   ├── world_builder.rs
│   │   ├── sector_builder.rs
│   │   └── tables.rs       # All generation tables
│   ├── output/
│   │   ├── mod.rs
│   │   ├── ascii.rs        # ASCII format generation
│   │   └── svg.rs          # SVG generation
│   └── data/
│       └── names.rs        # Embedded planet names
```

## 3. Key Dependencies

```toml
[dependencies]
clap = { version = "4", features = ["derive"] }
rand = "0.8"
rand_chacha = "0.3"  # For reproducible RNG
fasthash = "0.4"     # For FNV hashing
once_cell = "1.19"   # For lazy statics
anyhow = "1"         # Error handling
thiserror = "1"      # Custom errors
chrono = "0.4"       # Timestamps

[build-dependencies]
include_dir = "0.7"  # Embed name files
```

## 4. Core Design Patterns

### Trait-Based Orbit System
```rust
pub trait Orbit {
    fn orbit_number(&self) -> u8;
    fn au(&self) -> f64;
    fn to_ascii(&self) -> String;
    fn orbit_type(&self) -> OrbitType;
}

pub enum OrbitContent {
    Empty(EmptyOrbit),
    World(World),
    GasGiant(GasGiant),
    Belt(Belt),
    Hostile(Hostile),
    Rockball(Rockball),
}

impl Orbit for OrbitContent {
    // Delegate to inner type
}
```

### Builder Pattern with RNG
```rust
pub struct SectorBuilder {
    name: String,
    width: usize,
    height: usize,
    density: f64,
}

impl SectorBuilder {
    pub fn build(self) -> Sector {
        let mut volumes = Vec::new();
        for row in 0..self.height {
            for col in 0..self.width {
                if rng::roll_float() < self.density {
                    volumes.push(VolumeBuilder::new(row, col).build());
                }
            }
        }
        Sector { name: self.name, volumes }
    }
}
```

## 5. Implementation Phases

### Phase 1: Core Infrastructure (Days 1-2)
- Set up Cargo project with dependencies
- Implement RNG module with thread-local storage
- Create basic models (Star, World, Orbit trait)
- Set up CLI with clap

### Phase 2: Generation Logic (Days 3-4)
- Port all generation tables from Go
- Implement star generation
- Implement world/UWP generation
- Implement orbit population logic

### Phase 3: Sector Generation (Day 5)
- Implement sector/subsector structure
- Port density calculations
- Implement volume placement

### Phase 4: Output Formats (Day 6)
- Implement ASCII formatter
- Implement SVG generation
- Add file writing with timestamps

### Phase 5: Polish & Testing (Day 7)
- Add comprehensive tests
- Implement CRAWFORD seed format
- Add --help and documentation
- Performance optimization

## 6. Rust-Specific Improvements

### Zero-Copy String Building
```rust
use std::fmt::Write;
let mut output = String::with_capacity(4096);
write!(&mut output, "{:04} {}", hex.coords, uwp)?;
```

### Const Tables
```rust
const STAR_TYPES: &[StarType] = &[
    StarType::B, StarType::B, StarType::A, // ...
];
```

### Error Handling
```rust
#[derive(thiserror::Error, Debug)]
pub enum AstromapperError {
    #[error("Invalid density: {0}")]
    InvalidDensity(String),
    #[error("RNG not initialized")]
    RngNotInitialized,
}
```

### Parallel Generation (Optional)
```rust
use rayon::prelude::*;
let volumes: Vec<_> = (0..height)
    .into_par_iter()
    .flat_map(|row| {
        (0..width).filter_map(move |col| {
            // Each thread needs its own RNG
            let mut local_rng = StdRng::seed_from_u64(seed + row * width + col);
            if local_rng.gen::<f64>() < density {
                Some(build_volume(row, col, &mut local_rng))
            } else {
                None
            }
        })
    })
    .collect();
```

## 7. Key Advantages of Rust Implementation

1. **Memory Safety**: No null pointer issues like the Go array bounds problem
2. **Performance**: Zero-cost abstractions, no GC pauses
3. **Type Safety**: Stronger type system catches more errors at compile time
4. **Pattern Matching**: Cleaner handling of orbit types and trade codes
5. **Ownership**: Clear data ownership prevents mutation bugs
6. **Cargo**: Better dependency management than Go modules
7. **Traits**: More flexible than Go interfaces for the Orbit hierarchy

## 8. RNG Availability Strategy (Recommended)

Use **thread-local storage** for single-threaded generation:
- Simple to use throughout codebase
- No need to pass RNG references everywhere
- Safe and fast for CLI tool
- Easy to reset for each generation run

If parallel generation needed later, switch to seeded-per-coordinate approach where each hex gets deterministic seed based on position.

## 9. Implementation Notes

### Seed Conversion
```rust
use fasthash::fnv::fnv64;

fn string_to_seed(s: &str) -> u64 {
    fnv64(s.as_bytes())
}

fn generate_crawford_seed() -> String {
    const CHARSET: &[u8] = b"ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    let mut rng = thread_rng();
    let seed: String = (0..10)
        .map(|_| {
            let idx = rng.gen_range(0..CHARSET.len());
            CHARSET[idx] as char
        })
        .collect();
    format!("{}-{}", &seed[..5], &seed[5..])
}

fn string_to_crawford(input: &str) -> String {
    // Check if already CRAWFORD format
    if input.len() == 11 && input.chars().nth(5) == Some('-') {
        return input.to_string();
    }
    
    const CHARSET: &[u8] = b"ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    let hash = fnv64(input.as_bytes());
    let mut result = String::with_capacity(11);
    
    for i in 0..10 {
        let index = ((hash >> (i * 6)) as usize) % CHARSET.len();
        result.push(CHARSET[index] as char);
        if i == 4 {
            result.push('-');
        }
    }
    result
}
```

### Trade Codes Implementation
```rust
#[derive(Debug, Clone, PartialEq)]
pub enum TradeCode {
    Agricultural,
    Asteroid,
    Barren,
    Desert,
    FluidOceans,
    Garden,
    HighPop,
    HighTech,
    IceCapped,
    Industrial,
    LowPop,
    LowTech,
    NonAgricultural,
    NonIndustrial,
    Poor,
    Rich,
    Vacuum,
    WaterWorld,
}

impl TradeCode {
    pub fn calculate(world: &World) -> Vec<TradeCode> {
        let mut codes = Vec::new();
        
        // Agricultural: Atm 4-9, Hydro 4-8, Pop 5-7
        if (4..=9).contains(&world.atmosphere) 
            && (4..=8).contains(&world.hydrographics) 
            && (5..=7).contains(&world.population) {
            codes.push(TradeCode::Agricultural);
        }
        
        // ... other trade codes
        
        codes
    }
    
    pub fn to_code(&self) -> &'static str {
        match self {
            TradeCode::Agricultural => "Ag",
            TradeCode::Asteroid => "As",
            TradeCode::Barren => "Ba",
            // ... etc
        }
    }
}
```

### SVG Generation with Embedded CSS
```rust
pub struct SvgGenerator {
    width: f64,
    height: f64,
    hex_size: f64,
}

impl SvgGenerator {
    pub fn generate_sector(&self, sector: &Sector) -> String {
        let mut svg = String::new();
        svg.push_str(&self.header());
        svg.push_str(&self.styles());
        
        // Draw subsector grid
        for subsector in 0..16 {
            svg.push_str(&self.draw_subsector_border(subsector));
        }
        
        // Draw hexes
        for (row, col, volume) in sector.iter_volumes() {
            svg.push_str(&self.draw_hex(row, col, volume));
        }
        
        svg.push_str("</svg>");
        svg
    }
    
    fn styles(&self) -> &'static str {
        r#"<style>
            @media (prefers-color-scheme: dark) {
                .hex { stroke: #666; }
                .world { fill: #fff; }
                text { fill: #ccc; }
            }
            @media (prefers-color-scheme: light) {
                .hex { stroke: #000; }
                .world { fill: #000; }
                text { fill: #000; }
            }
        </style>"#
    }
}
```

## 10. Testing Strategy

```rust
#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_deterministic_generation() {
        init_rng("TEST-SEED");
        let sector1 = SectorBuilder::new("Test", 32, 40, 0.5).build();
        
        init_rng("TEST-SEED");
        let sector2 = SectorBuilder::new("Test", 32, 40, 0.5).build();
        
        assert_eq!(sector1, sector2);
    }
    
    #[test]
    fn test_crawford_format() {
        let crawford = string_to_crawford("test");
        assert_eq!(crawford.len(), 11);
        assert_eq!(crawford.chars().nth(5), Some('-'));
        
        // Already crawford format
        let input = "ABCDE-FGHJ";
        assert_eq!(string_to_crawford(input), input);
    }
}
```