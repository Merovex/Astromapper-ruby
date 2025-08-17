// Planet names will be added here
pub fn get_planet_names() -> Vec<String> {
    vec![
        "Andoria", "Betazed", "Cardassia", "Deneb", "Earth",
        "Ferenginar", "Galifrey", "Haven", "Izar", "Janus",
        "Krypton", "Luna", "Mars", "Naboo", "Orion",
        "Pandora", "Qo'noS", "Risa", "Solaria", "Terminus",
        "Ultima", "Vulcan", "Westeros", "Xandar", "Yavin",
        "Zephyr",
    ].iter().map(|s| s.to_string()).collect()
}