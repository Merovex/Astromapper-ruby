package rng

import (
	"hash/fnv"
	"math/rand"
)

type RNG struct {
	*rand.Rand
	seed int64
}

func New(seedString string) *RNG {
	seed := stringToSeed(seedString)
	source := rand.NewSource(seed)
	return &RNG{
		Rand: rand.New(source),
		seed: seed,
	}
}

func stringToSeed(s string) int64 {
	h := fnv.New64a()
	h.Write([]byte(s))
	return int64(h.Sum64())
}

func (r *RNG) GetSeed() int64 {
	return r.seed
}

func (r *RNG) Roll(dice, sides int) int {
	total := 0
	for i := 0; i < dice; i++ {
		total += r.Intn(sides) + 1
	}
	return total
}

func (r *RNG) D6() int {
	return r.Roll(1, 6)
}

func (r *RNG) TwoD6() int {
	return r.Roll(2, 6)
}

func (r *RNG) ThreeD6() int {
	return r.Roll(3, 6)
}

func (r *RNG) D100() int {
	return r.Roll(1, 100)
}

func (r *RNG) FluxRoll() int {
	return r.D6() - r.D6()
}