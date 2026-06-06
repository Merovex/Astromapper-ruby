//! Thread-local active generation settings — the Rust analog of the Ruby globals /
//! Go package vars. Set once before generating (CLI or tests); a sector is built on
//! one thread, mirroring the thread-local RNG.

use std::cell::RefCell;
use std::rc::Rc;

use super::Ruleset;

thread_local! {
    static RULESET: RefCell<Option<Rc<Ruleset>>> = const { RefCell::new(None) };
    static GENRE: RefCell<String> = RefCell::new(String::from("normal"));
    static SOPHONTS: RefCell<String> = RefCell::new(String::from("human"));
}

pub fn set_ruleset(rs: Ruleset) {
    RULESET.with(|r| *r.borrow_mut() = Some(Rc::new(rs)));
}

/// The active ruleset, lazily loading the built-in t5 if none was set.
pub fn ruleset() -> Rc<Ruleset> {
    RULESET.with(|r| {
        if r.borrow().is_none() {
            let rs = Ruleset::load("t5", "").expect("default t5 ruleset");
            *r.borrow_mut() = Some(Rc::new(rs));
        }
        r.borrow().as_ref().unwrap().clone()
    })
}

pub fn set_genre(g: &str) {
    let g = g.to_lowercase();
    GENRE.with(|x| *x.borrow_mut() = if g.is_empty() { "normal".into() } else { g });
}

pub fn genre() -> String {
    GENRE.with(|x| x.borrow().clone())
}

pub fn set_sophonts(s: &str) {
    SOPHONTS.with(|x| *x.borrow_mut() = s.to_lowercase());
}

pub fn sophonts() -> String {
    SOPHONTS.with(|x| x.borrow().clone())
}
