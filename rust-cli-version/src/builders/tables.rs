use crate::models::{StarType, StarSize};

// Star generation tables
pub const STAR_TYPE_TABLE: &[StarType] = &[
    StarType::B, StarType::B, 
    StarType::A, 
    StarType::M, StarType::M, StarType::M, StarType::M, StarType::M,
    StarType::K, 
    StarType::G, 
    StarType::F, StarType::F, StarType::F,
];

pub const STAR_SIZE_TABLE: &[StarSize] = &[
    StarSize::II,  // 0 - never used
    StarSize::III, // 1
    StarSize::III, // 2
    StarSize::IV,  // 3
    StarSize::IV,  // 4
    StarSize::V,   // 5
    StarSize::V,   // 6
    StarSize::V,   // 7
    StarSize::V,   // 8
    StarSize::V,   // 9
    StarSize::V,   // 10
    StarSize::VI,  // 11
    StarSize::D,   // 12 - Brown Dwarf
];

pub const COMPANION_TYPE_TABLE: &[StarType] = &[
    StarType::D,  // 0 - never used
    StarType::D,  // 1 - never used
    StarType::B, 
    StarType::A,
    StarType::F, StarType::F,
    StarType::G, StarType::G,
    StarType::K, StarType::K,
    StarType::M, StarType::M, StarType::M,
];

pub const COMPANION_SIZE_TABLE: &[StarSize] = &[
    StarSize::D,   // 0 - never used
    StarSize::III, // 1
    StarSize::III, // 2
    StarSize::IV,  // 3
    StarSize::IV,  // 4
    StarSize::D,   // 5 - Brown Dwarf
    StarSize::D,   // 6 - Brown Dwarf
    StarSize::V,   // 7
    StarSize::V,   // 8
    StarSize::VI,  // 9
    StarSize::D,   // 10 - Brown Dwarf
    StarSize::D,   // 11 - Brown Dwarf
    StarSize::D,   // 12 - Brown Dwarf
];

pub const COMPANION_SEPARATION: &[f64] = &[
    0.05, 0.05, 0.5, 0.5, 0.5, 2.0, 2.0, 10.0, 10.0, 10.0,
    50.0, 50.0, 50.0, 50.0, 50.0, 50.0, 50.0, 50.0, 50.0, 50.0,
];

pub const BODE_RATIOS: &[f64] = &[
    0.3, 0.3, 0.3, 0.3, 0.35, 0.35, 0.35, 0.4, 0.4, 0.4, 0.4
];

// World generation tables
pub const STARPORT_TABLE: &[char] = &[
    'X', 'X', 'E', 'E', 'D', 'D', 'C', 'C', 'B', 'B', 'A', 'A', 'A'
];

pub const SIZE_TABLE: &[u8] = &[
    0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 10
];

// Atmosphere based on size
pub fn atmosphere_table(size: u8) -> Vec<u8> {
    if size == 0 {
        vec![0]
    } else if size <= 2 {
        vec![0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 10, 10, 10]
    } else {
        vec![0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
    }
}

// Hydrographics based on atmosphere
pub fn hydrographics_table(atm: u8) -> Vec<u8> {
    if atm <= 1 || atm >= 10 {
        vec![0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    } else {
        vec![0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    }
}

// Temperature based on orbit position and star luminosity
pub fn temperature_dm(orbit: u8, luminosity: f64) -> i32 {
    let base = if orbit == 0 { 
        12 
    } else if orbit == 1 { 
        8 
    } else if orbit == 2 { 
        6 
    } else if orbit == 3 { 
        4 
    } else if orbit == 4 { 
        2 
    } else if orbit == 5 { 
        0 
    } else if orbit <= 7 { 
        -2 
    } else if orbit <= 9 { 
        -4 
    } else { 
        -6 
    };
    
    let lum_mod = if luminosity > 2.0 {
        4
    } else if luminosity > 1.0 {
        2
    } else if luminosity < 0.5 {
        -2
    } else {
        0
    };
    
    base + lum_mod
}