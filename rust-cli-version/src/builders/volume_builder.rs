use crate::models::Volume;
use crate::error::Result;
use crate::builders::WorldBuilder;
use crate::data::get_planet_names;

pub struct VolumeBuilder {
    row: usize,
    col: usize,
}

impl VolumeBuilder {
    pub fn new(row: usize, col: usize) -> Self {
        VolumeBuilder { row, col }
    }
    
    pub fn build(self) -> Result<Volume> {
        let mut volume = Volume::new(self.row, self.col);
        
        // Get planet names
        let names = get_planet_names();
        
        // For now, just generate a world
        // TODO: Add star system generation
        let world = WorldBuilder::new(self.row, self.col)
            .with_names(names)
            .build()?;
        volume.world = Some(world);
        
        Ok(volume)
    }
}