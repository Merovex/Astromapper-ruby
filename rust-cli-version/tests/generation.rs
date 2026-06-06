//! Integration tests for ruleset-driven generation: the genre stellar model and
//! cepheus divergence, mirroring the Ruby/Go suites.

use astromapper_core::builders::StarBuilder;
use astromapper_core::models::StarType;
use astromapper_core::rng;
use astromapper_core::rules::{runtime, Ruleset};

fn census(genre: &str) -> (f64, f64) {
    runtime::set_ruleset(Ruleset::load("t5", "").unwrap());
    runtime::set_genre(genre);
    runtime::set_sophonts("human");
    rng::init_rng(&format!("genre-{genre}"));
    let total = 200;
    let (mut fgk, mut m) = (0, 0);
    for _ in 0..total {
        let star = StarBuilder::build_primary().unwrap();
        match star.star_type {
            StarType::F | StarType::G | StarType::K => fgk += 1,
            StarType::M => m += 1,
            _ => {}
        }
    }
    (fgk as f64 / total as f64, m as f64 / total as f64)
}

#[test]
fn genre_stellar_model() {
    let (opera_fgk, _) = census("opera");
    let (normal_fgk, _) = census("normal");
    let (firm_fgk, firm_m) = census("firm");

    assert!(
        opera_fgk > normal_fgk,
        "opera FGK {opera_fgk:.2} should exceed normal {normal_fgk:.2}"
    );
    assert!(
        opera_fgk > firm_fgk,
        "opera FGK {opera_fgk:.2} should exceed firm {firm_fgk:.2}"
    );
    assert!(firm_m > 0.5, "firm should be M-dwarf-heavy, got {firm_m:.2}");
}
