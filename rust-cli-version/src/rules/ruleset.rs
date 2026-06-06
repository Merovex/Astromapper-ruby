//! The data-driven ruleset loader — Rust port of Ruby Astromapper::Rules::Ruleset
//! and Go pkg/rules. Loads `rules/<name>.yml` (embedded built-ins, with project-dir
//! override), resolves `extends:` inheritance, and exposes trade codes, UWP step
//! formulas, and the starport/tech/base tables. serde_yaml::Mapping preserves key
//! order, so trade-code output order follows the YAML.

use std::collections::HashMap;
use std::fs;
use std::path::Path;

use serde_yaml::Value as Yaml;

use super::expr::{self, Context, Node, Value};

pub struct Ruleset {
    name: String,
    data: Yaml,
    trade: Vec<(String, Node)>, // compiled trade conditions, in YAML order
    uwp_cache: HashMap<String, Node>,
}

fn builtin(name: &str) -> Option<&'static str> {
    match name {
        "t5" => Some(include_str!("builtin/t5.yml")),
        "cepheus" => Some(include_str!("builtin/cepheus.yml")),
        _ => None,
    }
}

impl Ruleset {
    /// Load a ruleset by name: project `rules/<name>.yml` first, then the built-in,
    /// applying `extends:` before validating.
    pub fn load(name: &str, project_root: &str) -> Result<Ruleset, String> {
        let data = load_merged(name, project_root, &mut Vec::new())?;
        let rs = Ruleset::build(name.to_string(), data)?;
        rs.validate()?;
        Ok(rs)
    }

    fn build(name: String, data: Yaml) -> Result<Ruleset, String> {
        let mut trade = Vec::new();
        if let Some(tc) = data.get("trade_codes").and_then(|v| v.as_mapping()) {
            for (k, v) in tc.iter() {
                if let (Some(code), Some(cond)) = (k.as_str(), v.as_str()) {
                    let node = expr::compile(cond)
                        .map_err(|e| format!("ruleset {name:?}: trade code {code}: {e}"))?;
                    trade.push((code.to_string(), node));
                }
            }
        }
        let mut uwp_cache = HashMap::new();
        if let Some(uwp) = data.get("uwp").and_then(|v| v.as_mapping()) {
            for (k, spec) in uwp.iter() {
                let step = match k.as_str() {
                    Some(s) => s,
                    None => continue,
                };
                let mut cache = |key: String, src: &str| -> Result<(), String> {
                    let node =
                        expr::compile(src).map_err(|e| format!("ruleset {name:?}: {key}: {e}"))?;
                    uwp_cache.insert(key, node);
                    Ok(())
                };
                for key in ["zero_when", "roll"] {
                    if let Some(s) = spec.get(key).and_then(|x| x.as_str()) {
                        cache(format!("uwp/{step}/{key}"), s)?;
                    }
                }
                if let Some(rr) = spec.get("reroll").and_then(|x| x.as_mapping()) {
                    for key in ["when", "with"] {
                        if let Some(s) = rr.get(key).and_then(|x| x.as_str()) {
                            cache(format!("uwp/{step}/reroll/{key}"), s)?;
                        }
                    }
                }
                if let Some(adj) = spec.get("adjust").and_then(|x| x.as_sequence()) {
                    for (i, a) in adj.iter().enumerate() {
                        if let Some(s) = a.get("when").and_then(|x| x.as_str()) {
                            cache(format!("uwp/{step}/adjust/{i}"), s)?;
                        }
                    }
                }
            }
        }
        Ok(Ruleset {
            name,
            data,
            trade,
            uwp_cache,
        })
    }

    pub fn name(&self) -> &str {
        &self.name
    }

    /// Human-facing name (the YAML `name:` field), falling back to the file slug.
    pub fn title(&self) -> String {
        self.data
            .get("name")
            .and_then(|v| v.as_str())
            .filter(|s| !s.is_empty())
            .unwrap_or(&self.name)
            .to_string()
    }

    pub fn validate(&self) -> Result<(), String> {
        let mut errs = Vec::new();
        if self.data.get("hex").and_then(|v| v.as_str()).map_or(true, |s| s.is_empty()) {
            errs.push("missing `hex` alphabet".to_string());
        }
        for step in ["size", "atmo", "hydro", "pop", "gov", "law"] {
            let spec = self.data.get("uwp").and_then(|u| u.get(step));
            match spec {
                Some(s) if s.get("roll").and_then(|r| r.as_str()).is_some() => {}
                Some(_) => errs.push(format!("uwp.{step}: no `roll`")),
                None => errs.push(format!("uwp.{step}: missing")),
            }
        }
        if self
            .data
            .get("starport")
            .and_then(|s| s.get("table"))
            .and_then(|t| t.as_sequence())
            .is_none()
        {
            errs.push("missing `starport.table`".to_string());
        }
        for slot in ["extensions", "climate", "native"] {
            if let Err(e) = self.module_for(slot) {
                errs.push(e);
            }
        }
        if errs.is_empty() {
            Ok(())
        } else {
            Err(format!(
                "ruleset {:?} is invalid:\n- {}",
                self.name,
                errs.join("\n- ")
            ))
        }
    }

    pub fn trade_codes(&self, ctx: &Context) -> Vec<String> {
        self.trade
            .iter()
            .filter(|(_, node)| node.is_true(ctx))
            .map(|(code, _)| code.clone())
            .collect()
    }

    pub fn starport(&self, roll: i64) -> String {
        match self
            .data
            .get("starport")
            .and_then(|s| s.get("table"))
            .and_then(|t| t.as_sequence())
        {
            Some(arr) if !arr.is_empty() => {
                let idx = roll.clamp(0, (arr.len() - 1) as i64) as usize;
                arr[idx].as_str().unwrap_or("X").to_string()
            }
            _ => "X".to_string(),
        }
    }

    pub fn tech_dm(&self, ctx: &Context) -> i64 {
        let t = match self.data.get("tech_dm") {
            Some(v) => v,
            None => return 0,
        };
        let mut dm = 0i64;
        if let Some(Value::Str(p)) = ctx.get("port") {
            if let Some(v) = t.get("port").and_then(|m| m.get(p.as_str())) {
                dm += v.as_i64().unwrap_or(0);
            }
        }
        for k in ["size", "atmo", "hydro", "pop", "gov"] {
            if let Some(arr) = t.get(k).and_then(|a| a.as_sequence()) {
                let i = ctx.get(k).map(|v| v.as_int()).unwrap_or(0);
                if i >= 0 && (i as usize) < arr.len() {
                    dm += arr[i as usize].as_i64().unwrap_or(0);
                }
            }
        }
        dm
    }

    pub fn base_threshold(&self, kind: &str, port: &str) -> Option<i64> {
        self.data
            .get("bases")
            .and_then(|b| b.get(kind))
            .and_then(|m| m.get(port))
            .and_then(|v| v.as_i64())
    }

    pub fn base_meets(&self, roll: i64, threshold: i64) -> bool {
        let op = self
            .data
            .get("bases")
            .and_then(|b| b.get("op"))
            .and_then(|o| o.as_str())
            .unwrap_or("<=");
        match op {
            ">=" => roll >= threshold,
            ">" => roll > threshold,
            "<" => roll < threshold,
            "==" => roll == threshold,
            _ => roll <= threshold,
        }
    }

    pub fn module_for(&self, slot: &str) -> Result<String, String> {
        let name = self
            .data
            .get("modules")
            .and_then(|m| m.get(slot))
            .and_then(|v| v.as_str())
            .map(|s| s.to_lowercase())
            .filter(|s| !s.is_empty())
            .unwrap_or_else(|| "t5".to_string());
        if name.is_empty() || !name.chars().all(|c| c.is_alphanumeric() || c == '_') {
            return Err(format!(
                "ruleset {:?}: bad module name {name:?} for {slot}",
                self.name
            ));
        }
        Ok(name)
    }

    /// Evaluate one UWP step (size/atmo/hydro/pop/gov/law) against the prior digits.
    pub fn uwp_step(&self, name: &str, ctx: &Context) -> i64 {
        let spec = match self.data.get("uwp").and_then(|u| u.get(name)) {
            Some(s) => s,
            None => return 0,
        };
        if let Some(zw) = self.uwp_cache.get(&format!("uwp/{name}/zero_when")) {
            if zw.is_true(ctx) {
                return 0;
            }
        }
        let mut val = self
            .uwp_cache
            .get(&format!("uwp/{name}/roll"))
            .map(|n| n.eval(ctx).as_int())
            .unwrap_or(0);

        if spec.get("reroll").is_some() {
            let mut cw = ctx.clone();
            cw.insert(name.to_string(), Value::Int(val));
            if let Some(w) = self.uwp_cache.get(&format!("uwp/{name}/reroll/when")) {
                if w.is_true(&cw) {
                    if let Some(with) = self.uwp_cache.get(&format!("uwp/{name}/reroll/with")) {
                        val = with.eval(&cw).as_int();
                    }
                }
            }
        }
        if let Some(adj) = spec.get("adjust").and_then(|a| a.as_sequence()) {
            for (i, a) in adj.iter().enumerate() {
                let mut cw = ctx.clone();
                cw.insert(name.to_string(), Value::Int(val));
                if let Some(w) = self.uwp_cache.get(&format!("uwp/{name}/adjust/{i}")) {
                    if w.is_true(&cw) {
                        if let Some(set) = a.get("set").and_then(|s| s.as_i64()) {
                            val = set;
                        } else if let Some(delta) = a.get("delta").and_then(|d| d.as_i64()) {
                            val += delta;
                        }
                    }
                }
            }
        }
        if let Some(cl) = spec.get("clamp").and_then(|c| c.as_sequence()) {
            if cl.len() == 2 {
                let lo = cl[0].as_i64().unwrap_or(0);
                let hi = cl[1].as_i64().unwrap_or(0);
                val = val.clamp(lo, hi);
            }
        }
        val
    }
}

/// Read one ruleset file and fold in its parent (extends), child wins.
fn load_merged(name: &str, project_root: &str, seen: &mut Vec<String>) -> Result<Yaml, String> {
    if seen.iter().any(|n| n == name) {
        return Err(format!("ruleset {name:?} has a cyclic extends chain"));
    }
    seen.push(name.to_string());

    let raw = read_rule_file(name, project_root)?;
    let data: Yaml = serde_yaml::from_str(&raw).map_err(|e| format!("ruleset {name:?}: {e}"))?;

    if let Some(base) = data.get("extends").and_then(|v| v.as_str()) {
        let parent = load_merged(base, project_root, seen)?;
        return Ok(deep_merge(parent, data));
    }
    Ok(data)
}

fn read_rule_file(name: &str, project_root: &str) -> Result<String, String> {
    if !project_root.is_empty() {
        let p = Path::new(project_root).join("rules").join(format!("{name}.yml"));
        if let Ok(s) = fs::read_to_string(&p) {
            return Ok(s);
        }
    }
    builtin(name)
        .map(|s| s.to_string())
        .ok_or_else(|| format!("unknown ruleset {name:?} (no project rules/{name}.yml and no built-in)"))
}

/// Deep-merge child `b` over parent `a`. A child key ending in `!` replaces the
/// parent value wholesale instead of deep-merging.
fn deep_merge(a: Yaml, b: Yaml) -> Yaml {
    match (a, b) {
        (Yaml::Mapping(mut am), Yaml::Mapping(bm)) => {
            for (k, bv) in bm {
                if let Yaml::String(ks) = &k {
                    if let Some(stripped) = ks.strip_suffix('!') {
                        am.insert(Yaml::String(stripped.to_string()), bv);
                        continue;
                    }
                }
                let merged = match am.get(&k) {
                    Some(av) if av.is_mapping() && bv.is_mapping() => deep_merge(av.clone(), bv),
                    _ => bv,
                };
                am.insert(k, merged);
            }
            Yaml::Mapping(am)
        }
        (_, b) => b,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn ctx(pairs: &[(&str, Value)]) -> Context {
        pairs.iter().map(|(k, v)| (k.to_string(), v.clone())).collect()
    }

    fn t5() -> Ruleset {
        Ruleset::load("t5", "").unwrap()
    }

    #[test]
    fn t5_trade_codes() {
        let rs = t5();
        let earth = ctx(&[
            ("size", Value::Int(8)), ("atmo", Value::Int(6)), ("hydro", Value::Int(7)),
            ("pop", Value::Int(7)), ("gov", Value::Int(5)), ("law", Value::Int(5)),
            ("tech", Value::Int(9)), ("port", Value::Str("A".into())), ("temp", Value::Str("T".into())),
        ]);
        assert_eq!(rs.trade_codes(&earth), vec!["Ga", "Ag", "Ri"]);
        let rock = ctx(&[
            ("size", Value::Int(0)), ("atmo", Value::Int(0)), ("hydro", Value::Int(0)),
            ("pop", Value::Int(0)), ("gov", Value::Int(0)), ("law", Value::Int(0)),
            ("tech", Value::Int(2)), ("port", Value::Str("X".into())), ("temp", Value::Str("T".into())),
        ]);
        assert_eq!(rs.trade_codes(&rock), vec!["As", "Va", "Ba", "Lt"]);
    }

    #[test]
    fn t5_tables() {
        let rs = t5();
        let want = ["A", "B", "C", "D", "E", "X"];
        for (i, roll) in [0, 5, 7, 9, 10, 12].iter().enumerate() {
            assert_eq!(rs.starport(*roll), want[i]);
        }
        assert_eq!(rs.starport(99), "X");
        let c = ctx(&[
            ("port", Value::Str("A".into())), ("size", Value::Int(0)), ("atmo", Value::Int(0)),
            ("hydro", Value::Int(0)), ("pop", Value::Int(0)), ("gov", Value::Int(0)),
        ]);
        assert_eq!(rs.tech_dm(&c), 10);
        assert_eq!(rs.base_threshold("naval", "A"), Some(6));
        assert_eq!(rs.base_threshold("naval", "C"), None);
    }

    #[test]
    fn uwp_driver() {
        rng::init_rng("uwp-test");
        let rs = t5();
        assert_eq!(rs.uwp_step("atmo", &ctx(&[("size", Value::Int(0))])), 0);
        for _ in 0..100 {
            assert_eq!(
                rs.uwp_step("hydro", &ctx(&[("size", Value::Int(1)), ("atmo", Value::Int(8))])),
                0
            );
        }
        for _ in 0..300 {
            let g = rs.uwp_step("gov", &ctx(&[("pop", Value::Int(15))]));
            assert!((0..=15).contains(&g));
            let l = rs.uwp_step("law", &ctx(&[("gov", Value::Int(15))]));
            assert!((0..=18).contains(&l));
        }
    }

    #[test]
    fn cepheus_inherits_and_overrides() {
        let cep = Ruleset::load("cepheus", "").unwrap();
        assert_eq!(cep.module_for("extensions").unwrap(), "none");
        assert_eq!(cep.module_for("climate").unwrap(), "t5");
        assert_eq!(cep.starport(2), "X");
        assert_eq!(cep.starport(12), "A");
        assert_eq!(cep.base_threshold("naval", "A"), Some(8));
        assert_eq!(cep.base_threshold("depot", "A"), None);
        assert!(cep.base_meets(8, 8));
    }

    #[test]
    fn validation_reports_problems() {
        let rs = Ruleset::build("broken".into(), serde_yaml::from_str("{}").unwrap()).unwrap();
        let err = rs.validate().unwrap_err();
        for want in ["hex", "uwp.size", "starport"] {
            assert!(err.contains(want), "error {err:?} missing {want:?}");
        }
    }

    use crate::rng;
}
