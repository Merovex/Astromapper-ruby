pub mod rng;
pub mod models;
pub mod builders;
pub mod output;
pub mod data;
pub mod error;

pub use error::{AstromapperError, Result};

// Re-export main types for convenience
pub use models::{Sector, Volume, World, Star};
pub use builders::{SectorBuilder, VolumeBuilder};

// Main generation functions that can be called from CLI or Tauri
use crate::rng::init_rng;

pub fn generate_sector(
    name: String,
    seed: String,
    density: f64,
) -> Result<Sector> {
    init_rng(&seed);
    
    let sector = SectorBuilder::new(name, 32, 40, density).build()?;
    Ok(sector)
}

pub fn generate_volume(
    seed: String,
    row: usize,
    col: usize,
) -> Result<Volume> {
    init_rng(&seed);
    
    let volume = VolumeBuilder::new(row, col).build()?;
    Ok(volume)
}

// Seed generation/conversion utilities
pub fn generate_crawford_seed() -> String {
    const CHARSET: &[u8] = b"ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    use rand::Rng;
    let mut rng = rand::thread_rng();
    
    let seed: String = (0..10)
        .map(|_| {
            let idx = rng.gen_range(0..CHARSET.len());
            CHARSET[idx] as char
        })
        .collect();
    
    format!("{}-{}", &seed[..5], &seed[5..])
}

pub fn string_to_crawford(input: &str) -> String {
    // Check if already CRAWFORD format
    if input.len() == 11 && input.chars().nth(5) == Some('-') {
        let valid_chars = input.chars()
            .filter(|c| *c != '-')
            .all(|c| "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".contains(c));
        if valid_chars {
            return input.to_string();
        }
    }
    
    const CHARSET: &[u8] = b"ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    
    use std::collections::hash_map::DefaultHasher;
    use std::hash::{Hash, Hasher};
    let mut hasher = DefaultHasher::new();
    input.hash(&mut hasher);
    let hash = hasher.finish();
    
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
