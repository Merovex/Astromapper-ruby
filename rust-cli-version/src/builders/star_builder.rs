use crate::models::{Star, StarType, StarSize};
use crate::error::Result;

pub struct StarBuilder;

impl StarBuilder {
    pub fn build_primary() -> Result<Star> {
        // Simplified for now
        Ok(Star::new(StarType::G, StarSize::V, true))
    }
}