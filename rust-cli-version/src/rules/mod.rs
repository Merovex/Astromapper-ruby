//! Data-driven generation rules: a sandboxed expression evaluator (`expr`) plus a
//! ruleset loader (`ruleset`), mirroring the Ruby and Go implementations so all
//! three share the same `rules/<name>.yml` definitions.

pub mod expr;
pub mod ruleset;

pub use expr::{Context, Value};
pub use ruleset::Ruleset;
