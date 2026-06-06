// Package rules is the data-driven generation engine: a sandboxed expression
// evaluator (this file) plus a ruleset loader (ruleset.go). It mirrors the Ruby
// Astromapper::Rules package so the same rules/<name>.yml definitions drive both
// implementations (per-language reproducible, not byte-identical across languages).
package rules

import (
	"fmt"
	"regexp"
	"strconv"
	"strings"
)

// Roller supplies dice randomness. *rng.RNG satisfies it (via embedded *rand.Rand),
// and tests can pass any Intn provider. nil is fine for dice-free expressions
// (trade-code conditions); evaluating a dice node with a nil Roller panics.
type Roller interface {
	Intn(n int) int
}

// Node is a compiled expression: call it with a context of variables (size, atmo,
// port, temp, …) and a Roller. The result is an int, bool, or string.
type Node func(ctx map[string]any, r Roller) any

// Compile parses src once into a reusable Node.
//
// SECURITY: this is a hand-written recursive-descent parser/evaluator. It never
// reflects, calls functions by name, or otherwise executes Go — only arithmetic,
// comparisons, dice, and lookups in the caller-supplied context are possible. That
// is the point: a rules/*.yml file is data, not executable code.
func Compile(src string) (Node, error) {
	toks, err := tokenize(src)
	if err != nil {
		return nil, err
	}
	p := &parser{toks: toks}
	node, err := p.parse()
	if err != nil {
		return nil, err
	}
	return node, nil
}

// MustCompile is Compile that panics on error — for package-level/known-good exprs.
func MustCompile(src string) Node {
	n, err := Compile(src)
	if err != nil {
		panic(fmt.Sprintf("rules: bad expression %q: %v", src, err))
	}
	return n
}

// Evaluate compiles and runs src in one shot.
func Evaluate(src string, ctx map[string]any, r Roller) (any, error) {
	n, err := Compile(src)
	if err != nil {
		return nil, err
	}
	return n(ctx, r), nil
}

// ---- values -------------------------------------------------------------

func truthy(v any) bool { return v != nil && v != false }

func toInt(v any) int {
	switch n := v.(type) {
	case int:
		return n
	case int64:
		return int(n)
	case float64:
		return int(n)
	case bool:
		if n {
			return 1
		}
		return 0
	default:
		return 0
	}
}

func compare(op string, a, b any) bool {
	switch op {
	case "==":
		return equal(a, b)
	case "!=":
		return !equal(a, b)
	case "<":
		return toInt(a) < toInt(b)
	case "<=":
		return toInt(a) <= toInt(b)
	case ">":
		return toInt(a) > toInt(b)
	case ">=":
		return toInt(a) >= toInt(b)
	}
	return false
}

// equal compares like-typed values; strings by value, everything else by int.
func equal(a, b any) bool {
	as, aok := a.(string)
	bs, bok := b.(string)
	if aok || bok {
		return aok && bok && as == bs
	}
	return toInt(a) == toInt(b)
}

func rollDice(spec string, r Roller) int {
	d := strings.IndexByte(spec, 'd')
	n, _ := strconv.Atoi(spec[:d])
	sides, _ := strconv.Atoi(spec[d+1:])
	total := 0
	for i := 0; i < n; i++ {
		total += r.Intn(sides) + 1
	}
	return total
}

// ---- tokenizer ----------------------------------------------------------

type tokKind int

const (
	tDice tokKind = iota
	tNum
	tStr
	tOp
	tKw
	tVar
	tEnd
)

type token struct {
	kind tokKind
	s    string
	n    int
}

var tokenRe = regexp.MustCompile(`^\s*(?:(\d+d\d+)|(\d+)|'([^']*)'|(==|!=|<=|>=|[<>()+\-*/])|([A-Za-z_]\w*))`)

var keywords = map[string]bool{"and": true, "or": true, "not": true, "flux": true}

func tokenize(src string) ([]token, error) {
	var toks []token
	rest := src
	for strings.TrimSpace(rest) != "" {
		m := tokenRe.FindStringSubmatch(rest)
		if m == nil {
			return nil, fmt.Errorf("bad expression near %q", strings.TrimSpace(rest))
		}
		rest = rest[len(m[0]):]
		switch {
		case m[1] != "":
			toks = append(toks, token{kind: tDice, s: m[1]})
		case m[2] != "":
			n, _ := strconv.Atoi(m[2])
			toks = append(toks, token{kind: tNum, n: n})
		case m[4] != "":
			toks = append(toks, token{kind: tOp, s: m[4]})
		case m[5] != "":
			if keywords[m[5]] {
				toks = append(toks, token{kind: tKw, s: m[5]})
			} else {
				toks = append(toks, token{kind: tVar, s: m[5]})
			}
		default:
			// group 3 (quoted string) — may legitimately be empty ('')
			toks = append(toks, token{kind: tStr, s: m[3]})
		}
	}
	toks = append(toks, token{kind: tEnd})
	return toks, nil
}

// ---- parser (recursive descent) ----------------------------------------
// or > and > not > comparison > additive > multiplicative > unary > primary

type parser struct {
	toks []token
	i    int
}

func (p *parser) peek() token { return p.toks[p.i] }
func (p *parser) take() token { t := p.toks[p.i]; p.i++; return t }

func (p *parser) accept(kind tokKind, val string) (token, bool) {
	t := p.peek()
	if t.kind == kind && (val == "" || t.s == val) {
		return p.take(), true
	}
	return token{}, false
}

func (p *parser) parse() (Node, error) {
	node, err := p.parseOr()
	if err != nil {
		return nil, err
	}
	if p.peek().kind != tEnd {
		return nil, fmt.Errorf("unexpected token %q", p.peek().s)
	}
	return node, nil
}

func (p *parser) parseOr() (Node, error) {
	node, err := p.parseAnd()
	if err != nil {
		return nil, err
	}
	for _, ok := p.accept(tKw, "or"); ok; _, ok = p.accept(tKw, "or") {
		rhs, err := p.parseAnd()
		if err != nil {
			return nil, err
		}
		l, r := node, rhs
		node = func(ctx map[string]any, rl Roller) any { return truthy(l(ctx, rl)) || truthy(r(ctx, rl)) }
	}
	return node, nil
}

func (p *parser) parseAnd() (Node, error) {
	node, err := p.parseNot()
	if err != nil {
		return nil, err
	}
	for _, ok := p.accept(tKw, "and"); ok; _, ok = p.accept(tKw, "and") {
		rhs, err := p.parseNot()
		if err != nil {
			return nil, err
		}
		l, r := node, rhs
		node = func(ctx map[string]any, rl Roller) any { return truthy(l(ctx, rl)) && truthy(r(ctx, rl)) }
	}
	return node, nil
}

func (p *parser) parseNot() (Node, error) {
	if _, ok := p.accept(tKw, "not"); ok {
		inner, err := p.parseNot()
		if err != nil {
			return nil, err
		}
		return func(ctx map[string]any, r Roller) any { return !truthy(inner(ctx, r)) }, nil
	}
	return p.parseCmp()
}

func (p *parser) parseCmp() (Node, error) {
	node, err := p.parseAdd()
	if err != nil {
		return nil, err
	}
	for _, op := range []string{"==", "!=", "<=", ">=", "<", ">"} {
		if t, ok := p.accept(tOp, op); ok {
			rhs, err := p.parseAdd()
			if err != nil {
				return nil, err
			}
			l, r, o := node, rhs, t.s
			return func(ctx map[string]any, rl Roller) any { return compare(o, l(ctx, rl), r(ctx, rl)) }, nil
		}
	}
	return node, nil
}

func (p *parser) parseAdd() (Node, error) {
	node, err := p.parseMul()
	if err != nil {
		return nil, err
	}
	for {
		t, ok := p.accept(tOp, "+")
		if !ok {
			if t, ok = p.accept(tOp, "-"); !ok {
				break
			}
		}
		rhs, err := p.parseMul()
		if err != nil {
			return nil, err
		}
		node = arith(t.s, node, rhs)
	}
	return node, nil
}

func (p *parser) parseMul() (Node, error) {
	node, err := p.parseUnary()
	if err != nil {
		return nil, err
	}
	for {
		t, ok := p.accept(tOp, "*")
		if !ok {
			if t, ok = p.accept(tOp, "/"); !ok {
				break
			}
		}
		rhs, err := p.parseUnary()
		if err != nil {
			return nil, err
		}
		node = arith(t.s, node, rhs)
	}
	return node, nil
}

func (p *parser) parseUnary() (Node, error) {
	if _, ok := p.accept(tOp, "-"); ok {
		inner, err := p.parseUnary()
		if err != nil {
			return nil, err
		}
		return func(ctx map[string]any, r Roller) any { return -toInt(inner(ctx, r)) }, nil
	}
	return p.parsePrimary()
}

func (p *parser) parsePrimary() (Node, error) {
	if t, ok := p.accept(tNum, ""); ok {
		v := t.n
		return func(map[string]any, Roller) any { return v }, nil
	}
	if t, ok := p.accept(tStr, ""); ok {
		v := t.s
		return func(map[string]any, Roller) any { return v }, nil
	}
	if t, ok := p.accept(tDice, ""); ok {
		spec := t.s
		return func(_ map[string]any, r Roller) any { return rollDice(spec, r) }, nil
	}
	if _, ok := p.accept(tKw, "flux"); ok {
		return func(_ map[string]any, r Roller) any { return (r.Intn(6) + 1) - (r.Intn(6) + 1) }, nil
	}
	if t, ok := p.accept(tVar, ""); ok {
		k := t.s
		return func(ctx map[string]any, _ Roller) any { return ctx[k] }, nil
	}
	if _, ok := p.accept(tOp, "("); ok {
		node, err := p.parseOr()
		if err != nil {
			return nil, err
		}
		if _, ok := p.accept(tOp, ")"); !ok {
			return nil, fmt.Errorf("missing ')'")
		}
		return node, nil
	}
	return nil, fmt.Errorf("unexpected token %q", p.peek().s)
}

func arith(op string, l, r Node) Node {
	return func(ctx map[string]any, rl Roller) any {
		a, b := toInt(l(ctx, rl)), toInt(r(ctx, rl))
		switch op {
		case "+":
			return a + b
		case "-":
			return a - b
		case "*":
			return a * b
		default:
			return a / b
		}
	}
}
