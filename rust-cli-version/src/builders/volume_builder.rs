use crate::models::{Volume, OrbitContent};
use crate::error::Result;
use crate::builders::StarBuilder;
use crate::data::get_planet_names;
use crate::rng;

pub struct VolumeBuilder {
    row: usize,
    col: usize,
}

impl VolumeBuilder {
    pub fn new(row: usize, col: usize) -> Self {
        VolumeBuilder { row, col }
    }
    
    pub fn build(self) -> Result<Volume> {
        let mut volume = Volume::new(self.row, self.col);
        
        // Check if system exists (based on density/chance)
        if rng::roll_1d6() <= 4 {  // ~66% chance for now
            // Generate star system
            let star = StarBuilder::build_primary()?;
            volume.star = Some(star);
            
            // Extract world from star's orbits if present
            if let Some(ref star) = volume.star {
                for orbit in &star.orbits {
                    if let OrbitContent::World(world_orbit) = orbit {
                        volume.world = Some(world_orbit.world.clone());
                        break;
                    }
                }
            }
            
            // If no world was generated in orbits but we have a star,
            // ensure we have at least a name
            if volume.world.is_none() && volume.star.is_some() {
                // Volume has a star system but no habitable world
                // Set a name for the system
                let names = get_planet_names();
                if !names.is_empty() {
                    let name_idx = (rng::roll_1d6() as usize * 100 + rng::roll_d100() as usize) % names.len();
                    volume.name = names[name_idx].clone();
                }
            }
        }
        
        Ok(volume)
    }
}