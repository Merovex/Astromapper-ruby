use serde::{Deserialize, Serialize};
use crate::models::World;

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub enum TradeCode {
    Agricultural,
    Asteroid,
    Barren,
    Desert,
    FluidOceans,
    Garden,
    HighPop,
    HighTech,
    IceCapped,
    Industrial,
    LowPop,
    LowTech,
    NonAgricultural,
    NonIndustrial,
    Poor,
    Rich,
    Vacuum,
    WaterWorld,
}

impl TradeCode {
    pub fn to_code(&self) -> &'static str {
        match self {
            TradeCode::Agricultural => "Ag",
            TradeCode::Asteroid => "As",
            TradeCode::Barren => "Ba",
            TradeCode::Desert => "De",
            TradeCode::FluidOceans => "Fl",
            TradeCode::Garden => "Ga",
            TradeCode::HighPop => "Hi",
            TradeCode::HighTech => "Ht",
            TradeCode::IceCapped => "Ic",
            TradeCode::Industrial => "In",
            TradeCode::LowPop => "Lo",
            TradeCode::LowTech => "Lt",
            TradeCode::NonAgricultural => "Na",
            TradeCode::NonIndustrial => "Ni",
            TradeCode::Poor => "Po",
            TradeCode::Rich => "Ri",
            TradeCode::Vacuum => "Va",
            TradeCode::WaterWorld => "Wa",
        }
    }
    
    pub fn calculate(world: &World) -> Vec<String> {
        let mut codes = Vec::new();
        
        // Agricultural: Atm 4-9, Hydro 4-8, Pop 5-7
        if (4..=9).contains(&world.atmosphere) 
            && (4..=8).contains(&world.hydrographics) 
            && (5..=7).contains(&world.population) {
            codes.push(TradeCode::Agricultural.to_code().to_string());
        }
        
        // Asteroid: Size 0, Atm 0, Hydro 0
        if world.size == 0 && world.atmosphere == 0 && world.hydrographics == 0 {
            codes.push(TradeCode::Asteroid.to_code().to_string());
        }
        
        // Barren: Pop 0, Gov 0, Law 0
        if world.population == 0 && world.government == 0 && world.law_level == 0 {
            codes.push(TradeCode::Barren.to_code().to_string());
        }
        
        // Desert: Atm 2-9, Hydro 0
        if world.atmosphere >= 2 && world.atmosphere <= 9 && world.hydrographics == 0 {
            codes.push(TradeCode::Desert.to_code().to_string());
        }
        
        // Fluid Oceans: Atm 10+, Hydro 1+
        if world.atmosphere >= 10 && world.hydrographics >= 1 {
            codes.push(TradeCode::FluidOceans.to_code().to_string());
        }
        
        // Garden: Size 5-9, Atm 4-9, Hydro 4-8
        if (5..=9).contains(&world.size)
            && (4..=9).contains(&world.atmosphere)
            && (4..=8).contains(&world.hydrographics) {
            codes.push(TradeCode::Garden.to_code().to_string());
        }
        
        // High Population: Pop 9+
        if world.population >= 9 {
            codes.push(TradeCode::HighPop.to_code().to_string());
        }
        
        // High Tech: Tech 12+
        if world.tech_level >= 12 {
            codes.push(TradeCode::HighTech.to_code().to_string());
        }
        
        // Ice-Capped: Atm 0-1, Hydro 1+
        if world.atmosphere <= 1 && world.hydrographics >= 1 {
            codes.push(TradeCode::IceCapped.to_code().to_string());
        }
        
        // Industrial: Atm 0-2 or 4 or 7 or 9, Pop 9+
        if (world.atmosphere <= 2 || world.atmosphere == 4 || world.atmosphere == 7 || world.atmosphere == 9) 
            && world.population >= 9 {
            codes.push(TradeCode::Industrial.to_code().to_string());
        }
        
        // Low Population: Pop 1-3
        if world.population >= 1 && world.population <= 3 {
            codes.push(TradeCode::LowPop.to_code().to_string());
        }
        
        // Low Tech: Tech 5-
        if world.tech_level <= 5 {
            codes.push(TradeCode::LowTech.to_code().to_string());
        }
        
        // Non-Agricultural: Atm 0-3, Hydro 0-3, Pop 6+
        if world.atmosphere <= 3 && world.hydrographics <= 3 && world.population >= 6 {
            codes.push(TradeCode::NonAgricultural.to_code().to_string());
        }
        
        // Non-Industrial: Pop 4-6
        if world.population >= 4 && world.population <= 6 {
            codes.push(TradeCode::NonIndustrial.to_code().to_string());
        }
        
        // Poor: Atm 2-5, Hydro 0-3
        if (2..=5).contains(&world.atmosphere) && world.hydrographics <= 3 {
            codes.push(TradeCode::Poor.to_code().to_string());
        }
        
        // Rich: Atm 6 or 8, Pop 6-8, Gov 4-9
        if (world.atmosphere == 6 || world.atmosphere == 8) 
            && (6..=8).contains(&world.population)
            && (4..=9).contains(&world.government) {
            codes.push(TradeCode::Rich.to_code().to_string());
        }
        
        // Vacuum: Atm 0
        if world.atmosphere == 0 {
            codes.push(TradeCode::Vacuum.to_code().to_string());
        }
        
        // Water World: Hydro 10
        if world.hydrographics == 10 {
            codes.push(TradeCode::WaterWorld.to_code().to_string());
        }
        
        codes
    }
}