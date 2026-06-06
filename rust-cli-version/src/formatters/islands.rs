//! Island border geometry — Rust port of Ruby Astromapper::Islands and Go
//! pkg/svg/islands.go. Clusters nearby system hexes, hugs each with a contiguous
//! territory, and traces the perimeter along the hex grid. Pure geometry; the maths
//! matches SvgGenerator::center_of so borders land exactly on the grid.

use std::collections::{HashMap, HashSet};

use crate::models::sector::hex_jump;

pub const PALETTE: [&str; 14] = [
    "#e6194B", "#3cb44b", "#4363d8", "#f58231", "#911eb4", "#42d4f4", "#f032e6", "#bfef45",
    "#469990", "#9A6324", "#800000", "#808000", "#000075", "#e6beff",
];

type Hex = (i64, i64);
type Pt = (i64, i64);

pub struct Island {
    pub colour: String,
    pub loops: Vec<Vec<Pt>>,
    pub size: usize,
}

fn centre(c: i64, r: i64, side: f64, factor: f64) -> (f64, f64) {
    let x = side + (c - 1) as f64 * side * 1.5;
    let y = (r - 1) as f64 * side * factor + side * factor / (1.0 + (c % 2) as f64);
    (x, y)
}

fn find(parent: &HashMap<Hex, Hex>, mut x: Hex) -> Hex {
    while parent[&x] != x {
        x = parent[&x];
    }
    x
}

fn edge_key(a: Pt, b: Pt) -> (Pt, Pt) {
    if a <= b {
        (a, b)
    } else {
        (b, a)
    }
}

fn neighbours(c: i64, r: i64, cols: i64, rows: i64) -> Vec<Hex> {
    let mut out = Vec::new();
    for nc in (c - 1)..=(c + 1) {
        if nc < 1 || nc > cols {
            continue;
        }
        for nr in (r - 1)..=(r + 1) {
            if nr < 1 || nr > rows {
                continue;
            }
            if (nc != c || nr != r) && hex_jump(c, r, nc, nr) == 1 {
                out.push((nc, nr));
            }
        }
    }
    out
}

fn build_territory(systems: &[Hex], cols: i64, rows: i64) -> HashSet<Hex> {
    let mut territory: HashSet<Hex> = systems.iter().copied().collect();
    let mut adj: HashMap<Hex, i32> = HashMap::new();
    for &(sc, sr) in systems {
        for c in (sc - 2)..=(sc + 2) {
            if c < 1 || c > cols {
                continue;
            }
            for r in (sr - 2)..=(sr + 2) {
                if r < 1 || r > rows {
                    continue;
                }
                if hex_jump(sc, sr, c, r) == 1 {
                    *adj.entry((c, r)).or_insert(0) += 1;
                }
            }
        }
    }
    for (h, n) in &adj {
        if *n >= 2 {
            territory.insert(*h);
        }
    }
    loop {
        let mut candidates: HashSet<Hex> = HashSet::new();
        for &(c, r) in &territory {
            for n in neighbours(c, r, cols, rows) {
                if !territory.contains(&n) {
                    candidates.insert(n);
                }
            }
        }
        let mut add = Vec::new();
        for &h in &candidates {
            let cnt = neighbours(h.0, h.1, cols, rows)
                .iter()
                .filter(|n| territory.contains(n))
                .count();
            if cnt >= 3 {
                add.push(h);
            }
        }
        if add.is_empty() {
            break;
        }
        for h in add {
            territory.insert(h);
        }
    }
    territory
}

fn min_jump(h: Hex, cluster: &[Hex]) -> i64 {
    cluster
        .iter()
        .map(|&(c, r)| hex_jump(h.0, h.1, c, r))
        .min()
        .unwrap_or(i64::MAX)
}

/// Chain an unordered bag of perimeter edges into ordered closed rings.
fn chain_loops(edges: &[(Pt, Pt)]) -> Vec<Vec<Pt>> {
    let mut adj: HashMap<Pt, Vec<Pt>> = HashMap::new();
    for &(a, b) in edges {
        adj.entry(a).or_default().push(b);
        adj.entry(b).or_default().push(a);
    }
    let mut used: HashSet<(Pt, Pt)> = HashSet::new();
    let mut loops = Vec::new();
    for &(a, b) in edges {
        let ek = edge_key(a, b);
        if used.contains(&ek) {
            continue;
        }
        used.insert(ek);
        let start = a;
        let mut ring = vec![start];
        let (mut prev, mut cur) = (a, b);
        while cur != start {
            let next = adj.get(&cur).and_then(|ns| {
                ns.iter()
                    .find(|&&n| n != prev && !used.contains(&edge_key(cur, n)))
                    .or_else(|| ns.iter().find(|&&n| !used.contains(&edge_key(cur, n))))
                    .copied()
            });
            let next = match next {
                Some(n) => n,
                None => break,
            };
            used.insert(edge_key(cur, next));
            ring.push(cur);
            prev = cur;
            cur = next;
        }
        if ring.len() >= 3 {
            loops.push(ring);
        }
    }
    loops
}

/// Cluster the system hexes and return each island's coloured perimeter.
pub fn borders(
    hexes: &[Hex],
    side: f64,
    factor: f64,
    cols: i64,
    rows: i64,
    threshold: i64,
    min_size: usize,
) -> Vec<Island> {
    let mut seen = HashSet::new();
    let mut uniq = Vec::new();
    for &h in hexes {
        if seen.insert(h) {
            uniq.push(h);
        }
    }
    if uniq.is_empty() {
        return Vec::new();
    }
    let hexes = uniq;

    // Union-find over jump <= threshold.
    let mut parent: HashMap<Hex, Hex> = hexes.iter().map(|&h| (h, h)).collect();
    for i in 0..hexes.len() {
        for j in (i + 1)..hexes.len() {
            if hex_jump(hexes[i].0, hexes[i].1, hexes[j].0, hexes[j].1) <= threshold {
                let (ri, rj) = (find(&parent, hexes[i]), find(&parent, hexes[j]));
                if ri != rj {
                    parent.insert(ri, rj);
                }
            }
        }
    }
    // Group by root, preserving first-appearance order for stable colours.
    let mut groups: HashMap<Hex, Vec<Hex>> = HashMap::new();
    let mut roots: Vec<Hex> = Vec::new();
    for &h in &hexes {
        let r = find(&parent, h);
        if !groups.contains_key(&r) {
            roots.push(r);
        }
        groups.entry(r).or_default().push(h);
    }
    let clusters: Vec<Vec<Hex>> = roots
        .iter()
        .filter_map(|r| {
            let g = &groups[r];
            (g.len() >= min_size).then(|| g.clone())
        })
        .collect();
    if clusters.is_empty() {
        return Vec::new();
    }

    // Territories, then give a hex claimed by two islands to the nearest cluster.
    let mut territories: Vec<HashSet<Hex>> =
        clusters.iter().map(|c| build_territory(c, cols, rows)).collect();
    let mut owner: HashMap<Hex, Vec<usize>> = HashMap::new();
    for (i, t) in territories.iter().enumerate() {
        for &h in t {
            owner.entry(h).or_default().push(i);
        }
    }
    let contested: Vec<(Hex, Vec<usize>)> =
        owner.into_iter().filter(|(_, ids)| ids.len() > 1).collect();
    for (h, mut ids) in contested {
        ids.sort();
        let keep = *ids.iter().min_by_key(|&&i| min_jump(h, &clusters[i])).unwrap();
        for i in ids {
            if i != keep {
                territories[i].remove(&h);
            }
        }
    }

    // Trace each perimeter: every hex contributes 6 edges; shared edges cancel.
    let half_w = side / 2.0;
    let half_h = side * factor / 2.0;
    let corners = [
        (side, 0.0),
        (half_w, half_h),
        (-half_w, half_h),
        (-side, 0.0),
        (-half_w, -half_h),
        (half_w, -half_h),
    ];
    let mut islands = Vec::new();
    for (i, territory) in territories.iter().enumerate() {
        let mut edges: HashMap<(Pt, Pt), i32> = HashMap::new();
        let mut raw: HashMap<(Pt, Pt), (Pt, Pt)> = HashMap::new();
        for &(c, r) in territory {
            let (cx, cy) = centre(c, r, side, factor);
            let pts: Vec<Pt> = corners
                .iter()
                .map(|&(dx, dy)| ((cx + dx).round() as i64, (cy + dy).round() as i64))
                .collect();
            for k in 0..6 {
                let a = pts[k];
                let b = pts[(k + 1) % 6];
                let key = edge_key(a, b);
                *edges.entry(key).or_insert(0) += 1;
                raw.insert(key, (a, b));
            }
        }
        let mut border: Vec<(Pt, Pt)> =
            edges.iter().filter(|(_, n)| **n == 1).map(|(k, _)| raw[k]).collect();
        border.sort(); // deterministic loop starts despite HashMap iteration order
        islands.push(Island {
            colour: PALETTE[i % PALETTE.len()].to_string(),
            loops: chain_loops(&border),
            size: clusters[i].len(),
        });
    }
    islands
}
