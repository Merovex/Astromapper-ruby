use crate::models::{OrbitContent, Star};
use crate::models::orbit::{
    EmptyOrbit, WorldOrbit, GasGiant, Belt, Hostile, Rockball,
    GiantSize, Moon
};
use crate::rng;
use crate::error::Result;
use crate::builders::WorldBuilder;
use crate::data::get_planet_names;

pub struct OrbitBuilder;

impl OrbitBuilder {
    pub fn populate_orbits(star: &mut Star) -> Result<()> {
        // Calculate number of orbits
        let dm = Self::orbit_dm(star);
        let num_orbits = (rng::roll_2d6().unwrap_or(7) as i32 + dm).max(0) as u8;
        
        let names = get_planet_names();
        let mut world_found = false;
        
        for orbit_num in 0..num_orbits {
            let au = star.orbit_to_au(orbit_num);
            
            // Skip if beyond outer limit
            if au > star.outer_limit() {
                break;
            }
            
            let orbit = Self::populate_orbit(star, orbit_num, au, &names, &mut world_found)?;
            star.orbits.push(orbit);
        }
        
        Ok(())
    }
    
    fn orbit_dm(star: &Star) -> i32 {
        let mut dm = 0;
        
        // Size modifiers
        match star.star_size {
            crate::models::StarSize::Ia | crate::models::StarSize::Ib => dm -= 4,
            crate::models::StarSize::II => dm -= 2,
            crate::models::StarSize::III => dm += 4,
            crate::models::StarSize::IV | crate::models::StarSize::V => dm += 0,
            crate::models::StarSize::VI | crate::models::StarSize::D => dm += 8,
        }
        
        // Type modifiers
        match star.star_type {
            crate::models::StarType::M => dm -= 4,
            crate::models::StarType::K => dm -= 2,
            _ => {}
        }
        
        dm
    }
    
    fn populate_orbit(
        star: &Star,
        orbit_num: u8,
        au: f64,
        names: &[String],
        world_found: &mut bool,
    ) -> Result<OrbitContent> {
        // Check if in inner limit
        if au < star.inner_limit() {
            return Ok(OrbitContent::Empty(EmptyOrbit { orbit_number: orbit_num, au }));
        }
        
        let (bio_inner, bio_outer) = star.biozone();
        
        // Determine zone
        let zone = if au < bio_inner {
            -1 // Inner zone
        } else if au > bio_outer {
            1  // Outer zone
        } else {
            0  // Biozone
        };
        
        // Generate content based on zone
        let content = match zone {
            0 => {
                // Biozone - try to place world if not found yet
                if !*world_found && rng::roll_2d6().unwrap_or(7) >= 4 {
                    *world_found = true;
                    let world = WorldBuilder::new(0, 0)
                        .with_names(names.to_vec())
                        .build()?;
                    OrbitContent::World(WorldOrbit { 
                        orbit_number: orbit_num, 
                        au, 
                        world 
                    })
                } else {
                    Self::generate_non_world_orbit(orbit_num, au, zone)
                }
            }
            -1 => {
                // Inner zone
                Self::generate_inner_orbit(orbit_num, au)
            }
            1 => {
                // Outer zone
                Self::generate_outer_orbit(orbit_num, au)
            }
            _ => OrbitContent::Empty(EmptyOrbit { orbit_number: orbit_num, au }),
        };
        
        Ok(content)
    }
    
    fn generate_inner_orbit(orbit_num: u8, au: f64) -> OrbitContent {
        let roll = rng::roll_2d6().unwrap_or(7);
        
        match roll {
            2..=4 => OrbitContent::Empty(EmptyOrbit { orbit_number: orbit_num, au }),
            5..=6 => OrbitContent::Rockball(Rockball { orbit_number: orbit_num, au }),
            7..=9 => {
                // Hostile world
                let atmosphere = rng::roll_1d6() + 9; // Corrosive/insidious
                let hydrographics = rng::roll_1d6() - 1;
                OrbitContent::Hostile(Hostile { 
                    orbit_number: orbit_num, 
                    au,
                    atmosphere: atmosphere.min(15) as u8,
                    hydrographics: hydrographics.max(0) as u8,
                })
            }
            10..=11 => OrbitContent::Belt(Belt { orbit_number: orbit_num, au }),
            _ => {
                // Small gas giant
                let moons = Self::generate_moons();
                OrbitContent::GasGiant(GasGiant {
                    orbit_number: orbit_num,
                    au,
                    size: GiantSize::Small,
                    moons,
                })
            }
        }
    }
    
    fn generate_outer_orbit(orbit_num: u8, au: f64) -> OrbitContent {
        let roll = rng::roll_2d6().unwrap_or(7);
        
        match roll {
            2..=3 => OrbitContent::Empty(EmptyOrbit { orbit_number: orbit_num, au }),
            4..=5 => OrbitContent::Belt(Belt { orbit_number: orbit_num, au }),
            6..=7 => OrbitContent::Rockball(Rockball { orbit_number: orbit_num, au }),
            8..=9 => {
                // Hostile frozen world
                let atmosphere = rng::roll_1d6() - 1;
                let hydrographics = 0; // Frozen
                OrbitContent::Hostile(Hostile { 
                    orbit_number: orbit_num, 
                    au,
                    atmosphere: atmosphere.max(0) as u8,
                    hydrographics,
                })
            }
            10 => {
                // Small gas giant
                let moons = Self::generate_moons();
                OrbitContent::GasGiant(GasGiant {
                    orbit_number: orbit_num,
                    au,
                    size: GiantSize::Small,
                    moons,
                })
            }
            _ => {
                // Large gas giant
                let moons = Self::generate_moons();
                OrbitContent::GasGiant(GasGiant {
                    orbit_number: orbit_num,
                    au,
                    size: GiantSize::Large,
                    moons,
                })
            }
        }
    }
    
    fn generate_non_world_orbit(orbit_num: u8, au: f64, _zone: i32) -> OrbitContent {
        let roll = rng::roll_2d6().unwrap_or(7);
        
        match roll {
            2..=4 => OrbitContent::Empty(EmptyOrbit { orbit_number: orbit_num, au }),
            5..=6 => OrbitContent::Belt(Belt { orbit_number: orbit_num, au }),
            7..=8 => OrbitContent::Rockball(Rockball { orbit_number: orbit_num, au }),
            _ => {
                // Gas giant
                let size = if rng::roll_1d6() >= 4 {
                    GiantSize::Large
                } else {
                    GiantSize::Small
                };
                let moons = Self::generate_moons();
                OrbitContent::GasGiant(GasGiant {
                    orbit_number: orbit_num,
                    au,
                    size,
                    moons,
                })
            }
        }
    }
    
    fn generate_moons() -> Vec<Moon> {
        // Orbit tables from Ruby code
        let close_orbits = vec![1u8, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14];
        let ring_orbits = vec![1u8, 1, 1, 2, 2, 3];
        let far_orbits: Vec<u8> = close_orbits.iter().map(|&x| (x as u16 * 5).min(255) as u8).collect();
        let extreme_orbits: Vec<u8> = close_orbits.iter().map(|&x| (x as u16 * 25).min(255) as u8).collect();
        
        let num_moons = rng::roll_1d6();
        let mut moons = Vec::new();
        
        for orbit in 0..num_moons {
            let size = (rng::roll_1d6() as i8 - 3).max(0) as u8;
            
            // Calculate orbital radius based on dice rolls (Ruby logic)
            let orbit_roll = rng::roll_2d6().unwrap_or(7) + orbit;
            let orbital_radius = if size < 1 {
                // Ring/small moon - use ring orbits table
                let idx = ((rng::roll_1d6() - 1) as usize).min(ring_orbits.len() - 1);
                ring_orbits[idx]
            } else if orbit_roll == 12 {
                // Extreme orbit (for gas giant moons)
                let idx = (rng::roll_2d6().unwrap_or(7) as usize).min(extreme_orbits.len() - 1);
                extreme_orbits[idx]
            } else if orbit_roll < 8 {
                // Close orbit
                let idx = (rng::roll_2d6().unwrap_or(7) as usize).min(close_orbits.len() - 1);
                close_orbits[idx]
            } else {
                // Far orbit
                let idx = (rng::roll_2d6().unwrap_or(7) as usize).min(far_orbits.len() - 1);
                far_orbits[idx]
            };
            
            moons.push(Moon {
                orbit: orbit as u8,
                orbital_radius,
                size,
                atmosphere: 0,
                hydrographics: 0,
            });
        }
        
        moons
    }
}