use crate::models::{Sector, Volume};

pub struct AsciiFormatter;

impl AsciiFormatter {
    pub fn format_sector(sector: &Sector) -> String {
        sector.to_ascii()
    }
    
    pub fn format_volume(volume: &Volume) -> String {
        volume.to_ascii()
    }
}