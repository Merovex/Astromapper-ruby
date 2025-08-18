use crate::models::World;
use crate::models::world::{Temperature, Base};
use crate::models::trade_codes::TradeCode;
use crate::rng;
use crate::error::Result;
use super::tables::*;

pub struct WorldBuilder {
    row: usize,
    col: usize,
    names: Vec<String>,
}

impl WorldBuilder {
    pub fn new(row: usize, col: usize) -> Self {
        WorldBuilder { 
            row, 
            col,
            names: Vec::new(),
        }
    }
    
    pub fn with_names(mut self, names: Vec<String>) -> Self {
        self.names = names;
        self
    }
    
    pub fn build(self) -> Result<World> {
        let mut world = World::new(self.row, self.col);
        
        // Generate starport
        let starport_roll = rng::roll_2d6()? as usize;
        world.starport = STARPORT_TABLE[starport_roll.min(12)];
        
        // Generate size
        let size_roll = rng::roll_2d6()? as usize;
        world.size = SIZE_TABLE[size_roll.min(12)];
        
        // Generate atmosphere based on size
        let atm_table = atmosphere_table(world.size);
        let atm_roll = rng::roll_2d6()? as usize;
        world.atmosphere = atm_table[atm_roll.min(atm_table.len() - 1)];
        
        // Generate hydrographics based on atmosphere
        let hydro_table = hydrographics_table(world.atmosphere);
        let hydro_roll = rng::roll_2d6()? as usize;
        world.hydrographics = hydro_table[hydro_roll.min(hydro_table.len() - 1)];
        
        // Generate population
        world.population = (rng::roll_2d6()? as u8).saturating_sub(2).min(12);
        
        // Generate government based on population
        if world.population == 0 {
            world.government = 0;
        } else {
            world.government = (rng::roll_2d6()? as u8)
                .saturating_sub(7)
                .saturating_add(world.population)
                .min(15);
        }
        
        // Generate law level based on government
        if world.population == 0 {
            world.law_level = 0;
        } else {
            world.law_level = (rng::roll_2d6()? as u8)
                .saturating_sub(7)
                .saturating_add(world.government)
                .min(15);
        }
        
        // Generate tech level
        let mut tech_dm = 0i32;
        match world.starport {
            'A' => tech_dm += 6,
            'B' => tech_dm += 4,
            'C' => tech_dm += 2,
            'X' => tech_dm -= 4,
            _ => {}
        }
        
        if world.size <= 1 { tech_dm += 2; }
        else if world.size <= 4 { tech_dm += 1; }
        
        if world.atmosphere <= 3 || world.atmosphere >= 10 { tech_dm += 1; }
        
        if world.hydrographics == 9 { tech_dm += 1; }
        else if world.hydrographics == 10 { tech_dm += 2; }
        
        if world.population >= 1 && world.population <= 5 { tech_dm += 1; }
        else if world.population == 9 { tech_dm += 2; }
        else if world.population == 10 { tech_dm += 4; }
        
        if world.government == 0 || world.government == 5 { tech_dm += 1; }
        else if world.government == 13 { tech_dm -= 2; }
        
        world.tech_level = ((rng::d6()? as i32) + tech_dm).max(0).min(15) as u8;
        
        // Set temperature (simplified for now)
        world.temperature = match rng::roll_2d6()? {
            2..=3 => Temperature::Frozen,
            4..=5 => Temperature::Cold,
            6..=8 => Temperature::Temperate,
            9..=10 => Temperature::Hot,
            _ => Temperature::Roasting,
        };
        
        // Generate bases
        if world.starport == 'A' || world.starport == 'B' {
            if rng::roll_2d6()? >= 8 {
                world.bases.push(Base::Naval);
            }
        }
        
        if world.starport != 'E' && world.starport != 'X' {
            if world.starport == 'A' && rng::roll_2d6()? >= 10 {
                world.bases.push(Base::Scout);
            } else if world.starport == 'B' && rng::roll_2d6()? >= 9 {
                world.bases.push(Base::Scout);
            } else if world.starport == 'C' && rng::roll_2d6()? >= 8 {
                world.bases.push(Base::Scout);
            } else if world.starport == 'D' && rng::roll_2d6()? >= 7 {
                world.bases.push(Base::Scout);
            }
        }
        
        // Calculate trade codes
        world.trade_codes = TradeCode::calculate(&world);
        
        // Generate factions
        world.factions = Self::generate_factions(world.population, world.law_level)?;
        
        // Update UWP
        world.update_uwp();
        
        // Assign a name from the list if available
        if !self.names.is_empty() {
            let idx = rng::roll_range(self.names.len())?;
            world.name = self.names[idx].clone();
        } else {
            world.name = format!("World-{}", world.coords());
        }
        
        Ok(world)
    }
    
    fn generate_factions(population: u8, law_level: u8) -> Result<Vec<String>> {
        if population == 0 {
            return Ok(vec![]);
        }
        
        let mut num_factions = rng::roll_range(3)? + 1; // 1-3, but minimum 3
        if num_factions < 3 {
            num_factions = 3;
        }
        
        // Adjust based on law level
        if law_level == 0 || law_level == 7 {
            num_factions += 1;
        }
        if law_level > 9 {
            num_factions = num_factions.saturating_sub(1);
        }
        
        // Faction types: O=Other, F=Faction, M=Military, N=Noble, S=Syndicate, P=Pirate
        let faction_types = vec!["O", "O", "O", "O", "F", "F", "M", "M", "N", "N", "S", "S", "P"];
        let mut factions = Vec::new();
        
        for _ in 0..num_factions {
            let roll = rng::roll_2d6()? as usize;
            let faction = faction_types[roll.min(faction_types.len() - 1)].to_string();
            factions.push(faction);
        }
        
        Ok(factions)
    }
}