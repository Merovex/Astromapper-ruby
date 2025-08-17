use serde::{Deserialize, Serialize};
use crate::models::World;

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub enum OrbitType {
    Empty,
    World,
    GasGiant,
    Belt,
    Hostile,
    Rockball,
}

pub trait Orbit {
    fn orbit_number(&self) -> u8;
    fn au(&self) -> f64;
    fn orbit_type(&self) -> OrbitType;
    fn to_ascii(&self) -> String;
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum OrbitContent {
    Empty(EmptyOrbit),
    World(WorldOrbit),
    GasGiant(GasGiant),
    Belt(Belt),
    Hostile(Hostile),
    Rockball(Rockball),
}

impl Orbit for OrbitContent {
    fn orbit_number(&self) -> u8 {
        match self {
            OrbitContent::Empty(o) => o.orbit_number(),
            OrbitContent::World(o) => o.orbit_number(),
            OrbitContent::GasGiant(o) => o.orbit_number(),
            OrbitContent::Belt(o) => o.orbit_number(),
            OrbitContent::Hostile(o) => o.orbit_number(),
            OrbitContent::Rockball(o) => o.orbit_number(),
        }
    }
    
    fn au(&self) -> f64 {
        match self {
            OrbitContent::Empty(o) => o.au(),
            OrbitContent::World(o) => o.au(),
            OrbitContent::GasGiant(o) => o.au(),
            OrbitContent::Belt(o) => o.au(),
            OrbitContent::Hostile(o) => o.au(),
            OrbitContent::Rockball(o) => o.au(),
        }
    }
    
    fn orbit_type(&self) -> OrbitType {
        match self {
            OrbitContent::Empty(o) => o.orbit_type(),
            OrbitContent::World(o) => o.orbit_type(),
            OrbitContent::GasGiant(o) => o.orbit_type(),
            OrbitContent::Belt(o) => o.orbit_type(),
            OrbitContent::Hostile(o) => o.orbit_type(),
            OrbitContent::Rockball(o) => o.orbit_type(),
        }
    }
    
    fn to_ascii(&self) -> String {
        match self {
            OrbitContent::Empty(o) => o.to_ascii(),
            OrbitContent::World(o) => o.to_ascii(),
            OrbitContent::GasGiant(o) => o.to_ascii(),
            OrbitContent::Belt(o) => o.to_ascii(),
            OrbitContent::Hostile(o) => o.to_ascii(),
            OrbitContent::Rockball(o) => o.to_ascii(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EmptyOrbit {
    pub orbit_number: u8,
    pub au: f64,
}

impl Orbit for EmptyOrbit {
    fn orbit_number(&self) -> u8 { self.orbit_number }
    fn au(&self) -> f64 { self.au }
    fn orbit_type(&self) -> OrbitType { OrbitType::Empty }
    fn to_ascii(&self) -> String { "-".to_string() }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WorldOrbit {
    pub orbit_number: u8,
    pub au: f64,
    pub world: World,
}

impl Orbit for WorldOrbit {
    fn orbit_number(&self) -> u8 { self.orbit_number }
    fn au(&self) -> f64 { self.au }
    fn orbit_type(&self) -> OrbitType { OrbitType::World }
    fn to_ascii(&self) -> String { "W".to_string() }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GasGiant {
    pub orbit_number: u8,
    pub au: f64,
    pub size: GiantSize,
    pub moons: Vec<Moon>,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub enum GiantSize {
    Small,
    Large,
}

impl Orbit for GasGiant {
    fn orbit_number(&self) -> u8 { self.orbit_number }
    fn au(&self) -> f64 { self.au }
    fn orbit_type(&self) -> OrbitType { OrbitType::GasGiant }
    fn to_ascii(&self) -> String {
        match self.size {
            GiantSize::Small => "G".to_string(),
            GiantSize::Large => "G".to_string(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Belt {
    pub orbit_number: u8,
    pub au: f64,
}

impl Orbit for Belt {
    fn orbit_number(&self) -> u8 { self.orbit_number }
    fn au(&self) -> f64 { self.au }
    fn orbit_type(&self) -> OrbitType { OrbitType::Belt }
    fn to_ascii(&self) -> String { "B".to_string() }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Hostile {
    pub orbit_number: u8,
    pub au: f64,
    pub atmosphere: u8,
    pub hydrographics: u8,
}

impl Orbit for Hostile {
    fn orbit_number(&self) -> u8 { self.orbit_number }
    fn au(&self) -> f64 { self.au }
    fn orbit_type(&self) -> OrbitType { OrbitType::Hostile }
    fn to_ascii(&self) -> String { "H".to_string() }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Rockball {
    pub orbit_number: u8,
    pub au: f64,
}

impl Orbit for Rockball {
    fn orbit_number(&self) -> u8 { self.orbit_number }
    fn au(&self) -> f64 { self.au }
    fn orbit_type(&self) -> OrbitType { OrbitType::Rockball }
    fn to_ascii(&self) -> String { "R".to_string() }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Moon {
    pub orbit: u8,
    pub size: u8,
}