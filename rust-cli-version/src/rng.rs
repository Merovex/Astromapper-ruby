use rand::prelude::*;
use rand_chacha::ChaCha8Rng;
use std::cell::RefCell;

use crate::error::{AstromapperError, Result};

thread_local! {
    static RNG: RefCell<Option<ChaCha8Rng>> = RefCell::new(None);
}

/// Initialize the thread-local RNG with a seed string
pub fn init_rng(seed: &str) {
    let seed_value = string_to_seed(seed);
    RNG.with(|r| {
        *r.borrow_mut() = Some(ChaCha8Rng::seed_from_u64(seed_value));
    });
}

/// Convert a string to a deterministic u64 seed
fn string_to_seed(s: &str) -> u64 {
    use std::collections::hash_map::DefaultHasher;
    use std::hash::{Hash, Hasher};
    
    let mut hasher = DefaultHasher::new();
    s.hash(&mut hasher);
    hasher.finish()
}

/// Roll dice with the thread-local RNG
pub fn roll(dice: u32, sides: u32) -> Result<u32> {
    RNG.with(|r| {
        let mut rng = r.borrow_mut();
        let rng = rng.as_mut().ok_or(AstromapperError::RngNotInitialized)?;
        
        let mut total = 0;
        for _ in 0..dice {
            total += rng.gen_range(1..=sides);
        }
        Ok(total)
    })
}

/// Common dice rolls
pub fn d6() -> Result<u32> {
    roll(1, 6)
}

pub fn roll_2d6() -> Result<u32> {
    roll(2, 6)
}

pub fn roll_3d6() -> Result<u32> {
    roll(3, 6)
}

// Convenience functions that panic on error (for use in builders)
pub fn roll_1d6() -> u32 {
    d6().unwrap_or(3)
}

pub fn roll_1d10() -> u32 {
    roll(1, 10).unwrap_or(5)
}

pub fn roll_d100() -> u32 {
    roll(1, 100).unwrap_or(50)
}

/// Get a random float between 0.0 and 1.0
pub fn roll_float() -> Result<f64> {
    RNG.with(|r| {
        let mut rng = r.borrow_mut();
        let rng = rng.as_mut().ok_or(AstromapperError::RngNotInitialized)?;
        Ok(rng.gen())
    })
}

/// Get a random integer in range [0, max)
pub fn roll_range(max: usize) -> Result<usize> {
    RNG.with(|r| {
        let mut rng = r.borrow_mut();
        let rng = rng.as_mut().ok_or(AstromapperError::RngNotInitialized)?;
        Ok(rng.gen_range(0..max))
    })
}

/// Get a random element from a slice
pub fn choose<T: Clone>(items: &[T]) -> Result<T> {
    if items.is_empty() {
        return Err(AstromapperError::FormatError("Cannot choose from empty slice".into()));
    }
    let idx = roll_range(items.len())?;
    Ok(items[idx].clone())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_deterministic_rolls() {
        init_rng("TEST-SEED");
        let roll1 = roll_2d6().unwrap();
        let roll2 = roll_2d6().unwrap();
        
        init_rng("TEST-SEED");
        let roll3 = roll_2d6().unwrap();
        let roll4 = roll_2d6().unwrap();
        
        assert_eq!(roll1, roll3);
        assert_eq!(roll2, roll4);
    }
    
    #[test]
    fn test_uninitialized_rng() {
        // Clear any previous RNG
        RNG.with(|r| *r.borrow_mut() = None);
        
        let result = roll_2d6();
        assert!(matches!(result, Err(AstromapperError::RngNotInitialized)));
    }
}