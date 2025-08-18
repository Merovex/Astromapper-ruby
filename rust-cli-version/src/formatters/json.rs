use serde_json;
use crate::models::{Sector, Volume};
use crate::Result;

pub struct JsonFormatter;

impl JsonFormatter {
    pub fn format_sector(sector: &Sector) -> Result<String> {
        Ok(serde_json::to_string_pretty(sector)?)
    }
    
    pub fn format_volume(volume: &Volume) -> Result<String> {
        Ok(serde_json::to_string_pretty(volume)?)
    }
}