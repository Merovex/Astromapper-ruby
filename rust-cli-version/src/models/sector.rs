use serde::{Deserialize, Serialize};
use crate::models::Volume;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Sector {
    pub name: String,
    pub width: usize,
    pub height: usize,
    pub volumes: Vec<Vec<Option<Volume>>>,
}

impl Sector {
    pub fn new(name: String, width: usize, height: usize) -> Self {
        let mut volumes = Vec::with_capacity(height);
        for _ in 0..height {
            volumes.push(vec![None; width]);
        }
        
        Sector {
            name,
            width,
            height,
            volumes,
        }
    }
    
    pub fn set_volume(&mut self, row: usize, col: usize, volume: Volume) {
        if row < self.height && col < self.width {
            self.volumes[row][col] = Some(volume);
        }
    }
    
    pub fn get_volume(&self, row: usize, col: usize) -> Option<&Volume> {
        if row < self.height && col < self.width {
            self.volumes[row][col].as_ref()
        } else {
            None
        }
    }
    
    pub fn system_count(&self) -> usize {
        self.volumes.iter()
            .flat_map(|row| row.iter())
            .filter(|v| v.is_some() && !v.as_ref().unwrap().is_empty())
            .count()
    }
    
    pub fn to_ascii(&self) -> String {
        let mut output = String::new();
        
        // Header
        output.push_str(&format!("# Sector: {}\n", self.name));
        output.push_str("# 32 columns x 40 rows\n");
        output.push_str("Location UWP         Temp Bases TC          Factions     Stars         Orbits        Name\n");
        output.push_str("-------- ----------- ---- ----- ----------- ------------ ------------- ------------- ----\n");
        
        // Process by subsector (4x4 grid of 8x10 subsectors)
        for subsector_row in 0..4 {
            for subsector_col in 0..4 {
                let subsector_letter = (b'A' + (subsector_row * 4 + subsector_col) as u8) as char;
                output.push_str(&format!("\n# Subsector {}\n", subsector_letter));
                
                // Each subsector is 8 columns x 10 rows
                for local_row in 0..10 {
                    for local_col in 0..8 {
                        let row = subsector_row * 10 + local_row;
                        let col = subsector_col * 8 + local_col;
                        
                        if let Some(volume) = self.get_volume(row, col) {
                            if !volume.is_empty() {
                                output.push_str(&volume.to_ascii());
                                output.push('\n');
                            }
                        }
                    }
                }
            }
        }
        
        output
    }
}