// Embed the names file at compile time
const NAMES_DATA: &str = include_str!("../names.txt");

pub fn get_planet_names() -> Vec<String> {
    NAMES_DATA
        .lines()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .collect()
}