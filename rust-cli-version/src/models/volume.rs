use serde::{Deserialize, Serialize};
use crate::models::{World, Star, OrbitContent};
use crate::models::orbit::Orbit;
use crate::models::world::ehex;

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

    /// One T5 Second Survey row (tab-delimited). Mirrors Ruby/Go Volume#to_tab.
    pub fn to_tab(&self, sector_name: &str, allegiance: &str) -> String {
        let w = match &self.world {
            Some(w) => w,
            None => return String::new(),
        };
        let ss = (b'A' + ((self.row / 10) * 4 + (self.col / 8)) as u8) as char;

        let (mut belts, mut gg, mut worlds) = (0i32, 0i32, 0i32);
        if let Some(star) = &self.star {
            for o in &star.orbits {
                match o {
                    OrbitContent::Belt(_) => belts += 1,
                    OrbitContent::GasGiant(_) => gg += 1,
                    OrbitContent::World(_) => worlds += 1,
                    _ => {}
                }
            }
        }
        if worlds < 1 {
            worlds = 1;
        }
        let pbg = format!("{}{}{}", w.pop_multiplier, belts.min(9), gg.min(9));

        let zone = if (w.government == 0 && w.law_level == 0) || w.law_level >= 9 {
            "A"
        } else {
            ""
        };

        let stars = if let Some(s) = &self.star {
            let mut v = vec![s.to_string()];
            for c in &s.companions {
                v.push(c.to_string());
            }
            v.join(" ")
        } else {
            String::new()
        };

        let (ix, ex, cx) = if w.extended {
            (
                format!("{{ {} }}", w.ix),
                format!(
                    "({}{}{}{:+})",
                    ehex(w.ex[0] as u8), ehex(w.ex[1] as u8), ehex(w.ex[2] as u8), w.ex[3]
                ),
                format!(
                    "[{}{}{}{}]",
                    ehex(w.cx[0] as u8), ehex(w.cx[1] as u8), ehex(w.cx[2] as u8), ehex(w.cx[3] as u8)
                ),
            )
        } else {
            (String::new(), String::new(), String::new())
        };

        let t5bases = {
            let b = w.bases_string();
            if b == "." {
                String::new()
            } else {
                b
            }
        };

        let fields = vec![
            sector_name.to_string(),
            ss.to_string(),
            self.coords(),
            w.name.clone(),
            w.uwp.clone(),
            t5bases,
            w.trade_codes.join(" "),
            zone.to_string(),
            pbg,
            allegiance.to_string(),
            stars,
            ix,
            ex,
            cx,
            String::new(),
            worlds.to_string(),
            w.ru.to_string(),
        ];
        fields.join("\t")
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

            // Name, then the T5 extension block and native status when present.
            let mut name_ext = world.name.clone();
            let ext = world.extensions();
            if !ext.is_empty() {
                name_ext.push_str("  ");
                name_ext.push_str(&ext);
            }
            if !world.native.is_empty() {
                name_ext.push_str("  ");
                name_ext.push_str(&world.native);
            }

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
                name_ext,
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