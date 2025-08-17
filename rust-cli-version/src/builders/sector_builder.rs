use crate::models::Sector;
use crate::error::Result;
use crate::builders::VolumeBuilder;
use crate::rng;

pub struct SectorBuilder {
    name: String,
    width: usize,
    height: usize,
    density: f64,
}

impl SectorBuilder {
    pub fn new(name: String, width: usize, height: usize, density: f64) -> Self {
        SectorBuilder {
            name,
            width,
            height,
            density,
        }
    }
    
    pub fn build(self) -> Result<Sector> {
        let mut sector = Sector::new(self.name, self.width, self.height);
        
        // Generate volumes based on density
        for row in 0..self.height {
            for col in 0..self.width {
                if rng::roll_float()? < self.density {
                    let volume = VolumeBuilder::new(row, col).build()?;
                    sector.set_volume(row, col, volume);
                }
            }
        }
        
        Ok(sector)
    }
}