use crate::models::{Star, StarType, StarSize};
use crate::error::Result;
use crate::rng;
use crate::builders::OrbitBuilder;

pub struct StarBuilder;

impl StarBuilder {
    pub fn build_primary() -> Result<Star> {
        let mut star = Self::generate_star(true)?;
        
        // Set bode constant
        star.bode_constant = (rng::roll_2d6().unwrap_or(7) as f64) * 0.05 + 0.25;
        
        // Populate orbits
        OrbitBuilder::populate_orbits(&mut star)?;
        
        Ok(star)
    }
    
    fn generate_star(is_primary: bool) -> Result<Star> {
        let star_type = Self::determine_star_type();
        let star_size = Self::determine_star_size(&star_type);
        let spectral_subtype = rng::roll_1d10() - 1;
        
        let mut star = Star::new(star_type, star_size, is_primary);
        star.spectral = format!("{}{}", star_type, spectral_subtype);
        
        // Set stellar characteristics based on type and size
        Self::set_stellar_characteristics(&mut star);
        
        Ok(star)
    }
    
    fn determine_star_type() -> StarType {
        let roll = rng::roll_2d6().unwrap_or(7);
        
        match roll {
            2 => StarType::A,
            3..=4 => StarType::M,
            5..=6 => StarType::K,
            7..=8 => StarType::G,
            9 => StarType::F,
            10..=11 => StarType::M,
            _ => StarType::M,
        }
    }
    
    fn determine_star_size(_star_type: &StarType) -> StarSize {
        let roll = rng::roll_2d6().unwrap_or(7);
        
        // Simplified size determination
        match roll {
            2 => StarSize::II,
            3 => StarSize::III,
            4 => StarSize::IV,
            5..=10 => StarSize::V,
            11 => StarSize::VI,
            _ => StarSize::D,
        }
    }
    
    fn set_stellar_characteristics(star: &mut Star) {
        // Set basic stellar characteristics based on type
        match star.star_type {
            StarType::O => {
                star.mass = 60.0;
                star.luminosity = 500000.0;
                star.temperature = 40000;
            }
            StarType::B => {
                star.mass = 10.0;
                star.luminosity = 10000.0;
                star.temperature = 20000;
            }
            StarType::A => {
                star.mass = 2.0;
                star.luminosity = 20.0;
                star.temperature = 8500;
            }
            StarType::F => {
                star.mass = 1.3;
                star.luminosity = 2.5;
                star.temperature = 6500;
            }
            StarType::G => {
                star.mass = 1.0;
                star.luminosity = 1.0;
                star.temperature = 5800;
            }
            StarType::K => {
                star.mass = 0.7;
                star.luminosity = 0.4;
                star.temperature = 4500;
            }
            StarType::M => {
                star.mass = 0.3;
                star.luminosity = 0.04;
                star.temperature = 3000;
            }
            StarType::D => {
                star.mass = 0.8;
                star.luminosity = 0.001;
                star.temperature = 10000;
            }
        }
        
        // Adjust for size
        match star.star_size {
            StarSize::Ia | StarSize::Ib => {
                star.luminosity *= 10000.0;
                star.mass *= 10.0;
            }
            StarSize::II => {
                star.luminosity *= 1000.0;
                star.mass *= 5.0;
            }
            StarSize::III => {
                star.luminosity *= 100.0;
                star.mass *= 2.0;
            }
            StarSize::IV => {
                star.luminosity *= 10.0;
                star.mass *= 1.5;
            }
            StarSize::V => {
                // Main sequence - no adjustment
            }
            StarSize::VI => {
                star.luminosity *= 0.1;
                star.mass *= 0.8;
            }
            StarSize::D => {
                star.luminosity *= 0.001;
                star.mass = 0.8;
            }
        }
    }
}