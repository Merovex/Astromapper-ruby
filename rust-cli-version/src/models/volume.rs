use serde::{Deserialize, Serialize};
use crate::models::{World, Star};
use crate::models::orbit::Orbit;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Volume {
    pub row: usize,
    pub col: usize,
    pub world: Option<World>,
    pub stars: Vec<Star>,
}

impl Volume {
    pub fn new(row: usize, col: usize) -> Self {
        Volume {
            row,
            col,
            world: None,
            stars: Vec::new(),
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
            let stars_str = self.stars.iter()
                .map(|s| s.to_string())
                .collect::<Vec<_>>()
                .join(" ");
            
            let orbits_str = if let Some(primary) = self.stars.first() {
                primary.orbits.iter()
                    .map(|o| o.to_ascii())
                    .collect::<Vec<_>>()
                    .join("")
            } else {
                String::new()
            };
            
            format!(
                "{} {} {} {} {} {} {} {} {}",
                self.coords(),
                world.uwp,
                world.temperature.to_code(),
                world.bases_string(),
                world.trade_codes_string(),
                ".",  // Factions placeholder
                stars_str,
                orbits_str,
                world.name
            )
        } else {
            format!("{} Empty", self.coords())
        }
    }
}