package models

import "math"

// HexJump is the Traveller hex jump distance between two 1-based hex coordinates,
// with even columns carrying the +1 offset so the metric matches the map geometry
// (Svg.centerOf / island borders). Shared by isolation pruning and clustering.
func HexJump(c1, r1, c2, r2 int) int {
	ay2 := r1 * 2
	if c1%2 == 0 {
		ay2++
	}
	by2 := r2 * 2
	if c2%2 == 0 {
		by2++
	}
	dx := absInt(c2 - c1)
	dy := absInt(by2 - ay2)
	return int(math.Round(float64(dx) + math.Max(0, float64(dy-dx)/2.0)))
}

func absInt(n int) int {
	if n < 0 {
		return -n
	}
	return n
}
