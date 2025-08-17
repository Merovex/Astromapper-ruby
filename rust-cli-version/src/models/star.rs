use serde::{Deserialize, Serialize};
use std::fmt;

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub enum StarType {
    O, B, A, F, G, K, M, D, // D for brown dwarf
}

impl fmt::Display for StarType {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            StarType::O => write!(f, "O"),
            StarType::B => write!(f, "B"),
            StarType::A => write!(f, "A"),
            StarType::F => write!(f, "F"),
            StarType::G => write!(f, "G"),
            StarType::K => write!(f, "K"),
            StarType::M => write!(f, "M"),
            StarType::D => write!(f, "D"),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub enum StarSize {
    Ia,  // Bright supergiant
    Ib,  // Supergiant
    II,  // Bright giant
    III, // Giant
    IV,  // Subgiant
    V,   // Main sequence
    VI,  // Subdwarf
    D,   // White dwarf
}

impl fmt::Display for StarSize {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            StarSize::Ia => write!(f, "Ia"),
            StarSize::Ib => write!(f, "Ib"),
            StarSize::II => write!(f, "II"),
            StarSize::III => write!(f, "III"),
            StarSize::IV => write!(f, "IV"),
            StarSize::V => write!(f, "V"),
            StarSize::VI => write!(f, "VI"),
            StarSize::D => write!(f, "D"),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Star {
    pub star_type: StarType,
    pub star_size: StarSize,
    pub spectral: String,
    pub is_primary: bool,
    pub orbit_number: u8,
    pub companions: Vec<Star>,
    pub orbits: Vec<crate::models::OrbitContent>,
    pub mass: f64,
    pub luminosity: f64,
    pub temperature: u32,
    pub bode_constant: f64,
}

impl Star {
    pub fn new(star_type: StarType, star_size: StarSize, is_primary: bool) -> Self {
        Star {
            star_type,
            star_size,
            spectral: format!("{}{}", star_type, 5),
            is_primary,
            orbit_number: 0,
            companions: Vec::new(),
            orbits: Vec::new(),
            mass: 1.0,
            luminosity: 1.0,
            temperature: 5800,
            bode_constant: 0.3,
        }
    }
    
    pub fn orbit_to_au(&self, orbit: u8) -> f64 {
        self.bode_constant * 2.0_f64.powi(orbit as i32)
    }
    
    pub fn au_to_orbit(&self, au: f64) -> u8 {
        if au <= 0.0 {
            return 0;
        }
        ((au / self.bode_constant).ln() / 2.0_f64.ln()).round() as u8
    }
    
    pub fn inner_limit(&self) -> f64 {
        // Simplified calculation
        0.1 * self.mass
    }
    
    pub fn outer_limit(&self) -> f64 {
        // Simplified calculation
        40.0 * self.mass
    }
    
    pub fn biozone(&self) -> (f64, f64) {
        let inner = 0.95 * self.luminosity.sqrt();
        let outer = 1.35 * self.luminosity.sqrt();
        (inner, outer)
    }
    
    pub fn to_string(&self) -> String {
        format!("{}{}", self.spectral, self.star_size)
    }
}