use serde::{Deserialize, Serialize};
use std::fmt;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct World {
    pub name: String,
    pub uwp: String,
    pub starport: char,
    pub size: u8,
    pub atmosphere: u8,
    pub hydrographics: u8,
    pub population: u8,
    pub government: u8,
    pub law_level: u8,
    pub tech_level: u8,
    pub temperature: Temperature,
    pub bases: Vec<Base>,
    pub trade_codes: Vec<String>,
    pub factions: Vec<String>,
    pub gas_giant: bool,
    pub row: usize,
    pub col: usize,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub enum Temperature {
    Frozen,
    Cold,
    Temperate,
    Hot,
    Roasting,
}

impl Temperature {
    pub fn to_code(&self) -> &'static str {
        match self {
            Temperature::Frozen => "F",
            Temperature::Cold => "C",
            Temperature::Temperate => "T",
            Temperature::Hot => "H",
            Temperature::Roasting => "R",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub enum Base {
    Naval,
    Scout,
    Research,
    TAS,
    Imperial,
    PirateBase,
}

impl Base {
    pub fn to_code(&self) -> &'static str {
        match self {
            Base::Naval => "N",
            Base::Scout => "S",
            Base::Research => "R",
            Base::TAS => "T",
            Base::Imperial => "I",
            Base::PirateBase => "P",
        }
    }
}

impl World {
    pub fn new(row: usize, col: usize) -> Self {
        World {
            name: String::new(),
            uwp: String::new(),
            starport: 'X',
            size: 0,
            atmosphere: 0,
            hydrographics: 0,
            population: 0,
            government: 0,
            law_level: 0,
            tech_level: 0,
            temperature: Temperature::Temperate,
            bases: Vec::new(),
            trade_codes: Vec::new(),
            factions: Vec::new(),
            gas_giant: false,
            row,
            col,
        }
    }
    
    pub fn coords(&self) -> String {
        format!("{:02}{:02}", self.col + 1, self.row + 1)
    }
    
    pub fn update_uwp(&mut self) {
        self.uwp = format!(
            "{}{:X}{:X}{:X}{:X}{:X}{:X}-{:X}",
            self.starport,
            self.size,
            self.atmosphere,
            self.hydrographics,
            self.population,
            self.government,
            self.law_level,
            self.tech_level
        );
    }
    
    pub fn bases_string(&self) -> String {
        if self.bases.is_empty() {
            ".".to_string()
        } else {
            self.bases.iter()
                .map(|b| b.to_code())
                .collect::<Vec<_>>()
                .join("")
        }
    }
    
    pub fn trade_codes_string(&self) -> String {
        if self.trade_codes.is_empty() {
            ".".to_string()
        } else {
            self.trade_codes.join(" ")
        }
    }
}

impl fmt::Display for World {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "{} {} {} {} {}",
            self.coords(),
            self.uwp,
            self.temperature.to_code(),
            self.bases_string(),
            self.trade_codes_string()
        )
    }
}