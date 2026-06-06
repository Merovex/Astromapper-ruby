use serde::{Deserialize, Serialize, Serializer};
use serde::ser::SerializeStruct;
use std::collections::BTreeMap;
use crate::models::Volume;

/// Traveller hex jump distance between 1-based hex coordinates, with even columns
/// carrying the +1 offset so the metric matches the map geometry. Shared by isolation
/// pruning and (later) island clustering.
pub fn hex_jump(c1: i64, r1: i64, c2: i64, r2: i64) -> i64 {
    let ay2 = r1 * 2 + if c1 % 2 == 0 { 1 } else { 0 };
    let by2 = r2 * 2 + if c2 % 2 == 0 { 1 } else { 0 };
    let dx = (c2 - c1).abs();
    let dy = (by2 - ay2).abs();
    (dx as f64 + (((dy - dx) as f64) / 2.0).max(0.0)).round() as i64
}

#[derive(Debug, Clone, Deserialize)]
pub struct Sector {
    pub name: String,
    pub width: usize,
    pub height: usize,
    pub volumes: Vec<Vec<Option<Volume>>>,
    #[serde(skip)]
    pub ruleset_title: String, // names the active ruleset in the legends
}

impl Serialize for Sector {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        // Convert 2D array to BTreeMap with zero-padded coordinate keys
        let mut volumes_map = BTreeMap::new();
        for row in 0..self.height {
            for col in 0..self.width {
                if let Some(ref volume) = self.volumes[row][col] {
                    if !volume.is_empty() {
                        // Create zero-padded key: XXYY where XX is column+1, YY is row+1
                        // Using 1-based coordinates to match Traveller convention
                        let key = format!("{:02}{:02}", col + 1, row + 1);
                        volumes_map.insert(key, volume);
                    }
                }
            }
        }
        
        // Serialize as a struct with volumes as a map
        let mut state = serializer.serialize_struct("Sector", 4)?;
        state.serialize_field("name", &self.name)?;
        state.serialize_field("volumes", &volumes_map)?;
        state.serialize_field("width", &self.width)?;
        state.serialize_field("height", &self.height)?;
        state.end()
    }
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
            ruleset_title: String::new(),
        }
    }

    /// Render the sector as a tab-delimited T5 Second Survey file (TravellerMap
    /// compatible) with a #-commented, ruleset-named legend. Mirrors Ruby/Go to_tab.
    pub fn to_tab(&self, allegiance: &str) -> String {
        let allegiance = if allegiance.is_empty() { "Na" } else { allegiance };
        let cols = [
            "Sector", "SS", "Hex", "Name", "UWP", "Bases", "Remarks", "Zone", "PBG",
            "Allegiance", "Stars", "{Ix}", "(Ex)", "[Cx]", "Nobility", "W", "RU",
        ];
        let mut out = format!(
            "# Sector: {} -- T5 Second Survey (tab-delimited). Lines beginning with # are comments.\n",
            self.name
        );
        if !self.ruleset_title.is_empty() {
            out.push_str(&format!("# Ruleset: {}\n", self.ruleset_title));
        }
        out.push_str(&format!("# COLUMNS: {}\n#\n", cols.join(" ")));
        out.push_str(&cols.join("\t"));
        out.push('\n');
        for row in 0..self.height {
            for col in 0..self.width {
                if let Some(v) = &self.volumes[row][col] {
                    if !v.is_empty() {
                        out.push_str(&v.to_tab(&self.name, allegiance));
                        out.push('\n');
                    }
                }
            }
        }
        out
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

    /// Remove systems with no neighbour within `threshold` jumps — lone stars no
    /// route can reach. One pass suffices (isolation is symmetric). Mirrors the Ruby
    /// prune_isolated! and the Go Sector.PruneIsolated.
    pub fn prune_isolated(&mut self, threshold: i64) {
        // (grid_row, grid_col, 1-based hex col, 1-based hex row) of each system.
        let mut systems: Vec<(usize, usize, i64, i64)> = Vec::new();
        for row in 0..self.height {
            for col in 0..self.width {
                if let Some(v) = &self.volumes[row][col] {
                    if !v.is_empty() {
                        systems.push((row, col, (col + 1) as i64, (row + 1) as i64));
                    }
                }
            }
        }
        for &(row, col, c, r) in &systems {
            let has_neighbour = systems.iter().any(|&(_, _, c2, r2)| {
                (c2 != c || r2 != r) && hex_jump(c, r, c2, r2) <= threshold
            });
            if !has_neighbour {
                self.volumes[row][col] = None;
            }
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
        if !self.ruleset_title.is_empty() {
            output.push_str(&format!("# Ruleset: {}\n", self.ruleset_title));
        }
        output.push_str("# 32 columns x 40 rows\n");
        output.push_str("Location UWP       Temp Bases TC          Factions     Stars         Orbits        Name\n");
        output.push_str("-------- --------- ---- ----- ----------- ------------ ------------- ------------- ----\n");
        
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
#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::World;

    #[test]
    fn prune_isolated_removes_lone_systems() {
        let mut s = Sector::new("t".into(), 32, 40);
        let mut put = |c: usize, r: usize| {
            let mut v = Volume::new(r - 1, c - 1);
            v.world = Some(World::new(r - 1, c - 1));
            s.set_volume(r - 1, c - 1, v);
        };
        put(1, 1);
        put(2, 1);
        put(1, 2); // a 3-system cluster (all within jump <= 4)
        put(20, 30); // a lone system, far from everything

        s.prune_isolated(4);
        assert!(s.get_volume(0, 0).is_some(), "clustered systems should survive");
        assert!(s.get_volume(29, 19).is_none(), "isolated system should be pruned");
    }
}
