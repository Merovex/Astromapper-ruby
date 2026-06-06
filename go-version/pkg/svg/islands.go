package svg

import (
	"math"
	"sort"
)

// Island borders — a Go port of Ruby's Astromapper::Islands. Clusters nearby system
// hexes, hugs each cluster with a contiguous territory, and traces its perimeter
// along the hex grid. Pure geometry; the maths matches Svg.centerOf so borders land
// exactly on the grid.

var islandPalette = []string{
	"#e6194B", "#3cb44b", "#4363d8", "#f58231", "#911eb4", "#42d4f4", "#f032e6", "#bfef45",
	"#469990", "#9A6324", "#800000", "#808000", "#000075", "#e6beff",
}

type point struct{ X, Y int }
type hexCell struct{ C, R int }

// island is one cluster's coloured border, as closed polygon rings.
type island struct {
	Colour string
	Loops  [][]point
	Size   int
}

func absInt(n int) int {
	if n < 0 {
		return -n
	}
	return n
}

func islandCentre(col, row int, side, factor float64) (float64, float64) {
	x := side + float64(col-1)*side*1.5
	y := float64(row-1)*side*factor + side*factor/(1+float64(col%2))
	return x, y
}

// islandJump is Traveller hex distance with even columns carrying the +1 offset, so
// the metric matches islandCentre's column parity.
func islandJump(a, b hexCell) int {
	ay2 := a.R * 2
	if a.C%2 == 0 {
		ay2++
	}
	by2 := b.R * 2
	if b.C%2 == 0 {
		by2++
	}
	dx := absInt(b.C - a.C)
	dy := absInt(by2 - ay2)
	return int(math.Round(float64(dx) + math.Max(0, float64(dy-dx)/2.0)))
}

func pointLess(a, b point) bool {
	if a.X != b.X {
		return a.X < b.X
	}
	return a.Y < b.Y
}

func edgeKey(a, b point) [2]point {
	if pointLess(b, a) {
		return [2]point{b, a}
	}
	return [2]point{a, b}
}

// chainLoops turns an unordered bag of perimeter edges into ordered closed rings.
func chainLoops(edges [][2]point) [][]point {
	adj := map[point][]point{}
	for _, e := range edges {
		adj[e[0]] = append(adj[e[0]], e[1])
		adj[e[1]] = append(adj[e[1]], e[0])
	}
	used := map[[2]point]bool{}
	var loops [][]point
	for _, e := range edges {
		ek := edgeKey(e[0], e[1])
		if used[ek] {
			continue
		}
		used[ek] = true
		start := e[0]
		ring := []point{start}
		prev, cur := start, e[1]
		for cur != start {
			next, found := point{}, false
			for _, n := range adj[cur] {
				if n != prev && !used[edgeKey(cur, n)] {
					next, found = n, true
					break
				}
			}
			if !found {
				for _, n := range adj[cur] {
					if !used[edgeKey(cur, n)] {
						next, found = n, true
						break
					}
				}
			}
			if !found {
				break
			}
			used[edgeKey(cur, next)] = true
			ring = append(ring, cur)
			prev, cur = cur, next
		}
		if len(ring) >= 3 {
			loops = append(loops, ring)
		}
	}
	return loops
}

// Borders clusters the system hexes and returns each island's coloured perimeter.
func Borders(hexes []hexCell, side, factor float64, cols, rows, threshold, minSize int) []island {
	seen := map[hexCell]bool{}
	uniq := hexes[:0:0]
	for _, h := range hexes {
		if !seen[h] {
			seen[h] = true
			uniq = append(uniq, h)
		}
	}
	hexes = uniq
	if len(hexes) == 0 {
		return nil
	}

	// Union-find over jump <= threshold.
	parent := map[hexCell]hexCell{}
	for _, h := range hexes {
		parent[h] = h
	}
	var find func(hexCell) hexCell
	find = func(x hexCell) hexCell {
		for parent[x] != x {
			x = parent[x]
		}
		return x
	}
	for i := 0; i < len(hexes); i++ {
		for j := i + 1; j < len(hexes); j++ {
			if islandJump(hexes[i], hexes[j]) <= threshold {
				ri, rj := find(hexes[i]), find(hexes[j])
				if ri != rj {
					parent[ri] = rj
				}
			}
		}
	}
	// Group by root, preserving first-appearance order for stable colours.
	groups := map[hexCell][]hexCell{}
	var roots []hexCell
	for _, h := range hexes {
		r := find(h)
		if _, ok := groups[r]; !ok {
			roots = append(roots, r)
		}
		groups[r] = append(groups[r], h)
	}
	var clusters [][]hexCell
	for _, r := range roots {
		if len(groups[r]) >= minSize {
			clusters = append(clusters, groups[r])
		}
	}
	if len(clusters) == 0 {
		return nil
	}

	halfW := side / 2.0
	halfH := side * factor / 2.0
	corners := [6][2]float64{{side, 0}, {halfW, halfH}, {-halfW, halfH}, {-side, 0}, {-halfW, -halfH}, {halfW, -halfH}}

	neighbours := func(c, r int) []hexCell {
		var out []hexCell
		for nc := c - 1; nc <= c+1; nc++ {
			if nc < 1 || nc > cols {
				continue
			}
			for nr := r - 1; nr <= r+1; nr++ {
				if nr < 1 || nr > rows {
					continue
				}
				if nc == c && nr == r {
					continue
				}
				if islandJump(hexCell{c, r}, hexCell{nc, nr}) == 1 {
					out = append(out, hexCell{nc, nr})
				}
			}
		}
		return out
	}

	buildTerritory := func(systems []hexCell) map[hexCell]bool {
		territory := map[hexCell]bool{}
		for _, s := range systems {
			territory[s] = true
		}
		adj := map[hexCell]int{}
		for _, s := range systems {
			for c := s.C - 2; c <= s.C+2; c++ {
				if c < 1 || c > cols {
					continue
				}
				for r := s.R - 2; r <= s.R+2; r++ {
					if r < 1 || r > rows {
						continue
					}
					if islandJump(s, hexCell{c, r}) == 1 {
						adj[hexCell{c, r}]++
					}
				}
			}
		}
		for h, n := range adj {
			if n >= 2 {
				territory[h] = true
			}
		}
		for {
			candidates := map[hexCell]bool{}
			for h := range territory {
				for _, n := range neighbours(h.C, h.R) {
					if !territory[n] {
						candidates[n] = true
					}
				}
			}
			var add []hexCell
			for h := range candidates {
				cnt := 0
				for _, n := range neighbours(h.C, h.R) {
					if territory[n] {
						cnt++
					}
				}
				if cnt >= 3 {
					add = append(add, h)
				}
			}
			if len(add) == 0 {
				break
			}
			for _, h := range add {
				territory[h] = true
			}
		}
		return territory
	}

	minJumpToCluster := func(h hexCell, cluster []hexCell) int {
		best := math.MaxInt
		for _, s := range cluster {
			if d := islandJump(h, s); d < best {
				best = d
			}
		}
		return best
	}

	// Build territories, then give any hex claimed by two islands to the nearest cluster.
	territories := make([]map[hexCell]bool, len(clusters))
	for i, c := range clusters {
		territories[i] = buildTerritory(c)
	}
	owner := map[hexCell][]int{}
	for i, t := range territories {
		for h := range t {
			owner[h] = append(owner[h], i)
		}
	}
	for h, ids := range owner {
		if len(ids) <= 1 {
			continue
		}
		sort.Ints(ids) // tie-break on the lowest cluster index, like Ruby's min_by
		keep, best := ids[0], minJumpToCluster(h, clusters[ids[0]])
		for _, id := range ids[1:] {
			if d := minJumpToCluster(h, clusters[id]); d < best {
				best, keep = d, id
			}
		}
		for _, id := range ids {
			if id != keep {
				delete(territories[id], h)
			}
		}
	}

	// Trace each perimeter: every hex contributes 6 edges; shared edges cancel.
	out := make([]island, 0, len(clusters))
	for i, territory := range territories {
		edges := map[[2]point]int{}
		raw := map[[2]point][2]point{}
		for h := range territory {
			cx, cy := islandCentre(h.C, h.R, side, factor)
			var pts [6]point
			for k, c := range corners {
				pts[k] = point{int(math.Round(cx + c[0])), int(math.Round(cy + c[1]))}
			}
			for k := 0; k < 6; k++ {
				a, b := pts[k], pts[(k+1)%6]
				key := edgeKey(a, b)
				edges[key]++
				raw[key] = [2]point{a, b}
			}
		}
		var border [][2]point
		for k, n := range edges {
			if n == 1 {
				border = append(border, raw[k])
			}
		}
		out = append(out, island{
			Colour: islandPalette[i%len(islandPalette)],
			Loops:  chainLoops(border),
			Size:   len(clusters[i]),
		})
	}
	return out
}
