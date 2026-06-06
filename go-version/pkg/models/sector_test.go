package models

import "testing"

func TestPruneIsolated(t *testing.T) {
	s := NewSector("t", 32, 40)
	// PruneIsolated reads each volume's 1-based Column/Row; grid index is 0-based.
	put := func(c, r int) {
		s.SetVolume(c-1, r-1, &Volume{Column: c, Row: r})
	}
	put(1, 1)
	put(2, 1)
	put(1, 2)   // a 3-system cluster (all within jump <= 4)
	put(20, 30) // a lone system, far from everything

	s.PruneIsolated(4)

	get := func(c, r int) *Volume { return s.GetVolume(c-1, r-1) }
	if get(1, 1) == nil || get(2, 1) == nil || get(1, 2) == nil {
		t.Error("clustered systems should survive pruning")
	}
	if get(20, 30) != nil {
		t.Error("an isolated system should be pruned")
	}
}
