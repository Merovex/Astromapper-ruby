use serde::{Deserialize, Serialize};
use crate::models::{World, Star};
use crate::models::orbit::Orbit;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Volume {
    pub row: usize,
    pub col: usize,
    pub world: Option<World>,
    pub star: Option<Star>,
    pub name: String,
}

impl Volume {
    pub fn new(row: usize, col: usize) -> Self {
        Volume {
            row,
            col,
            world: None,
            star: None,
            name: String::new(),
        }
    }
    
    pub fn is_empty(&self) -> bool {
        self.world.is_none()
    }
    
    pub fn coords(&self) -> String {
        format!("{:02}{:02}", self.col + 1, self.row + 1)
    }
    
    pub fn to_ascii(&self) -> String {
        if let Some(world) = &self.world {
            let stars_str = if let Some(star) = &self.star {
                star.to_string()
            } else {
                String::new()
            };
            
            let orbits_str = if let Some(star) = &self.star {
                star.orbits.iter()
                    .enumerate()
                    .map(|(i, o)| {
                        let bio = if let Some(s) = &self.star {
                            let (bio_inner, bio_outer) = s.biozone();
                            let au = s.orbit_to_au(i as u8);
                            if au >= bio_inner && au <= bio_outer {
                                "*"
                            } else if au > s.outer_limit() {
                                "-"
                            } else {
                                " "
                            }
                        } else {
                            " "
                        };
                        format!("\n  -- {:2}. {} {} // {:9} // {:4.1} au",
                            i + 1,
                            bio,
                            o.to_ascii(),
                            Self::orbit_uwp(o),
                            o.au()
                        )
                    })
                    .collect::<Vec<_>>()
                    .join("")
            } else {
                String::new()
            };
            
            // Generate orbits crib string (showing orbit types)
            let orbits_crib = if let Some(star) = &self.star {
                star.orbits.iter()
                    .map(|o| match o {
                        crate::models::OrbitContent::Empty(_) => ".",
                        crate::models::OrbitContent::World(_) => "W",
                        crate::models::OrbitContent::GasGiant(_) => "G",
                        crate::models::OrbitContent::Belt(_) => "B",
                        crate::models::OrbitContent::Hostile(_) => "H",
                        crate::models::OrbitContent::Rockball(_) => "R",
                    })
                    .collect::<Vec<_>>()
                    .join("")
            } else {
                String::new()
            };
            
            // Generate factions string
            let factions = if world.factions.is_empty() {
                ".".to_string()
            } else {
                world.factions.join(" ")
            };
            
            // Format with proper spacing/alignment
            let coords_padded = format!("{:<8}", self.coords());
            let uwp_padded = format!("{:<9}", world.uwp);  
            let temp_padded = format!("{:<4}", world.temperature.to_code());
            let bases_padded = format!("{:<5}", world.bases_string());
            let trade_codes_padded = format!("{:<11}", world.trade_codes_string());
            let factions_padded = format!("{:<12}", factions);
            let stars_padded = format!("{:<13}", stars_str);
            let orbits_crib_padded = format!("{:<13}", orbits_crib);
            
            format!(
                "{} {} {} {} {} {} {} {} {}{}",
                coords_padded,      // Left-align in 8-character field
                uwp_padded,         // Left-align UWP in 13-character field (11 + 2 padding)
                temp_padded,        // Left-align in 4-character field
                bases_padded,       // Left-align in 5-character field
                trade_codes_padded, // Left-align in 11-character field
                factions_padded,    // Left-align in 12-character field
                stars_padded,       // Left-align in 13-character field
                orbits_crib_padded, // Left-align in 13-character field
                world.name,
                orbits_str
            )
        } else if let Some(_star) = &self.star {
            // System exists but no habitable world
            format!("{} Empty system: {}", self.coords(), self.name)
        } else {
            format!("{} Empty", self.coords())
        }
    }
    
    fn orbit_uwp(orbit: &crate::models::OrbitContent) -> String {
        use crate::models::OrbitContent;
        match orbit {
            OrbitContent::Empty(_) => ".........".to_string(),
            OrbitContent::World(w) => w.world.uwp.clone(),
            OrbitContent::GasGiant(g) => {
                match g.size {
                    crate::models::orbit::GiantSize::Small => "Small GG ".to_string(),
                    crate::models::orbit::GiantSize::Large => "Large GG ".to_string(),
                }
            },
            OrbitContent::Belt(_) => "Belt     ".to_string(),
            OrbitContent::Hostile(h) => {
                format!("X..{:X}{:X}...-.",
                    h.atmosphere.min(15),
                    h.hydrographics.min(15)
                )
            },
            OrbitContent::Rockball(_) => "Y......-.".to_string(),
        }
    }
}