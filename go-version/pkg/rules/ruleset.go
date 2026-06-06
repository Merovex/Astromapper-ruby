package rules

import (
	"embed"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"gopkg.in/yaml.v3"
)

//go:embed builtin/*.yml
var builtinFS embed.FS

var wordRe = regexp.MustCompile(`^\w+$`)

// Ruleset is the data-driven definition of a generation system (Traveller 5,
// Cepheus, house rules…), loaded from rules/<name>.yml. It mirrors the Ruby
// Astromapper::Rules::Ruleset: trade codes, UWP step formulas, starport/base/tech
// tables, and the algorithmic-module wiring.
type Ruleset struct {
	name       string
	data       map[string]any
	tradeOrder []string        // output order, preserved from the YAML
	tradeCond  map[string]Node // compiled trade-code conditions
	compiled   map[string]Node // cache of UWP step exprs (read-only after Load)
}

// Load resolves a ruleset by name, searching the project's rules/ dir first, then
// the embedded built-ins, and applies `extends:` inheritance before validating.
func Load(name, projectRoot string) (*Ruleset, error) {
	data, order, definesTrade, err := loadMerged(name, projectRoot, map[string]bool{})
	if err != nil {
		return nil, err
	}
	rs, err := newRuleset(name, data, order, definesTrade)
	if err != nil {
		return nil, err
	}
	if err := rs.Validate(); err != nil {
		return nil, err
	}
	return rs, nil
}

// loadMerged reads one ruleset file and folds in its parent (extends), returning the
// merged data, the resolved trade-code order, and whether trade order was set here.
func loadMerged(name, projectRoot string, seen map[string]bool) (map[string]any, []string, bool, error) {
	if seen[name] {
		return nil, nil, false, fmt.Errorf("ruleset %q has a cyclic extends chain", name)
	}
	seen[name] = true

	raw, err := readRuleFile(name, projectRoot)
	if err != nil {
		return nil, nil, false, err
	}

	var data map[string]any
	if err := yaml.Unmarshal(raw, &data); err != nil {
		return nil, nil, false, fmt.Errorf("ruleset %q: %w", name, err)
	}
	if data == nil {
		data = map[string]any{}
	}

	// Ordered trade-code keys come from whichever file declares them (`trade_codes`
	// or the wholesale-replace `trade_codes!`).
	order := orderedKeys(raw, "trade_codes!")
	definesTrade := order != nil
	if order == nil {
		order = orderedKeys(raw, "trade_codes")
		definesTrade = order != nil
	}

	if base, ok := data["extends"].(string); ok && base != "" {
		pData, pOrder, _, err := loadMerged(base, projectRoot, seen)
		if err != nil {
			return nil, nil, false, err
		}
		data = deepMerge(pData, data)
		if !definesTrade { // inherit the parent's order if the child didn't set its own
			order = pOrder
		}
	}
	return data, order, definesTrade, nil
}

// readRuleFile prefers a project override, then the embedded built-in.
func readRuleFile(name, projectRoot string) ([]byte, error) {
	if projectRoot != "" {
		p := filepath.Join(projectRoot, "rules", name+".yml")
		if b, err := os.ReadFile(p); err == nil {
			return b, nil
		}
	}
	if b, err := builtinFS.ReadFile("builtin/" + name + ".yml"); err == nil {
		return b, nil
	}
	return nil, fmt.Errorf("unknown ruleset %q (no project rules/%s.yml and no built-in)", name, name)
}

// deepMerge folds child b over parent a. A child key ending in "!" replaces the
// parent value wholesale instead of deep-merging.
func deepMerge(a, b map[string]any) map[string]any {
	out := make(map[string]any, len(a))
	for k, v := range a {
		out[k] = v
	}
	for k, bv := range b {
		if strings.HasSuffix(k, "!") {
			out[strings.TrimSuffix(k, "!")] = bv
			continue
		}
		if av, ok := out[k]; ok {
			if am, aok := av.(map[string]any); aok {
				if bm, bok := bv.(map[string]any); bok {
					out[k] = deepMerge(am, bm)
					continue
				}
			}
		}
		out[k] = bv
	}
	return out
}

// orderedKeys returns the child keys of the named top-level mapping, in document
// order (Go maps lose order, so trade-code output order is taken from the YAML node).
func orderedKeys(raw []byte, mapKey string) []string {
	var doc yaml.Node
	if yaml.Unmarshal(raw, &doc) != nil || len(doc.Content) == 0 {
		return nil
	}
	root := doc.Content[0] // mapping node
	for i := 0; i+1 < len(root.Content); i += 2 {
		if root.Content[i].Value == mapKey {
			m := root.Content[i+1]
			keys := make([]string, 0, len(m.Content)/2)
			for j := 0; j+1 < len(m.Content); j += 2 {
				keys = append(keys, m.Content[j].Value)
			}
			return keys
		}
	}
	return nil
}

func newRuleset(name string, data map[string]any, order []string, _ bool) (*Ruleset, error) {
	rs := &Ruleset{name: name, data: data, tradeOrder: order, tradeCond: map[string]Node{}, compiled: map[string]Node{}}

	// Compile trade-code conditions.
	if tc, ok := data["trade_codes"].(map[string]any); ok {
		for code, cond := range tc {
			node, err := Compile(toStr(cond))
			if err != nil {
				return nil, fmt.Errorf("ruleset %q: trade code %s: %w", name, code, err)
			}
			rs.tradeCond[code] = node
		}
	}
	// Precompile UWP step exprs so UWPStep is allocation-light and concurrency-safe.
	if uwp, ok := data["uwp"].(map[string]any); ok {
		for step, raw := range uwp {
			spec, ok := raw.(map[string]any)
			if !ok {
				continue
			}
			for _, key := range []string{"zero_when", "roll"} {
				if s, ok := spec[key].(string); ok {
					if err := rs.cache("uwp/"+step+"/"+key, s); err != nil {
						return nil, err
					}
				}
			}
			if rr, ok := spec["reroll"].(map[string]any); ok {
				for _, key := range []string{"when", "with"} {
					if s, ok := rr[key].(string); ok {
						if err := rs.cache("uwp/"+step+"/reroll/"+key, s); err != nil {
							return nil, err
						}
					}
				}
			}
			if adj, ok := spec["adjust"].([]any); ok {
				for i, a := range adj {
					if am, ok := a.(map[string]any); ok {
						if s, ok := am["when"].(string); ok {
							if err := rs.cache(fmt.Sprintf("uwp/%s/adjust/%d", step, i), s); err != nil {
								return nil, err
							}
						}
					}
				}
			}
		}
	}
	return rs, nil
}

func (rs *Ruleset) cache(key, src string) error {
	node, err := Compile(src)
	if err != nil {
		return fmt.Errorf("ruleset %q: %s: %w", rs.name, key, err)
	}
	rs.compiled[key] = node
	return nil
}

// Name is the file slug; Title is the human-facing name (the YAML `name:` field).
func (rs *Ruleset) Name() string { return rs.name }

func (rs *Ruleset) Title() string {
	if s, ok := rs.data["name"].(string); ok && s != "" {
		return s
	}
	return rs.name
}

// Validate fails fast on a malformed ruleset, reporting every problem at once.
func (rs *Ruleset) Validate() error {
	var errs []string
	if s, ok := rs.data["hex"].(string); !ok || s == "" {
		errs = append(errs, "missing `hex` alphabet")
	}
	uwp, _ := rs.data["uwp"].(map[string]any)
	for _, step := range []string{"size", "atmo", "hydro", "pop", "gov", "law"} {
		spec, ok := uwp[step].(map[string]any)
		if !ok {
			errs = append(errs, "uwp."+step+": missing")
			continue
		}
		if _, ok := spec["roll"].(string); !ok {
			errs = append(errs, "uwp."+step+": no `roll`")
		}
	}
	if sp, ok := rs.data["starport"].(map[string]any); !ok {
		errs = append(errs, "missing `starport.table`")
	} else if _, ok := sp["table"].([]any); !ok {
		errs = append(errs, "missing `starport.table`")
	}
	for _, slot := range []string{"extensions", "climate", "native"} {
		if _, err := rs.ModuleFor(slot); err != nil {
			errs = append(errs, err.Error())
		}
	}
	if len(errs) > 0 {
		return fmt.Errorf("ruleset %q is invalid:\n- %s", rs.name, strings.Join(errs, "\n- "))
	}
	return nil
}

// TradeCodes returns the world's trade classifications, in YAML (output) order.
func (rs *Ruleset) TradeCodes(ctx map[string]any) []string {
	out := []string{}
	for _, code := range rs.tradeOrder {
		if node, ok := rs.tradeCond[code]; ok && node(ctx, nil) == true {
			out = append(out, code)
		}
	}
	return out
}

// Starport returns the starport letter for an orientation roll (clamped to the table).
func (rs *Ruleset) Starport(roll int) string {
	sp, _ := rs.data["starport"].(map[string]any)
	arr, _ := sp["table"].([]any)
	if len(arr) == 0 {
		return "X"
	}
	if roll < 0 {
		roll = 0
	}
	if roll > len(arr)-1 {
		roll = len(arr) - 1
	}
	return toStr(arr[roll])
}

// TechDM sums the tech-level die modifiers from the port map and per-digit arrays.
func (rs *Ruleset) TechDM(ctx map[string]any) int {
	t, _ := rs.data["tech_dm"].(map[string]any)
	dm := 0
	if pm, ok := t["port"].(map[string]any); ok {
		if v, ok := pm[toStr(ctx["port"])]; ok {
			dm += toInt(v)
		}
	}
	for _, k := range []string{"size", "atmo", "hydro", "pop", "gov"} {
		if arr, ok := t[k].([]any); ok {
			if i := toInt(ctx[k]); i >= 0 && i < len(arr) {
				dm += toInt(arr[i])
			}
		}
	}
	return dm
}

// BaseThreshold returns the 2D threshold for a base at this starport (ok=false if
// the port can't host it).
func (rs *Ruleset) BaseThreshold(kind, port string) (int, bool) {
	b, _ := rs.data["bases"].(map[string]any)
	m, ok := b[kind].(map[string]any)
	if !ok {
		return 0, false
	}
	v, ok := m[port]
	if !ok {
		return 0, false
	}
	return toInt(v), true
}

// BaseMeets applies the ruleset's base comparison (T5 `<=`, Cepheus `>=`).
func (rs *Ruleset) BaseMeets(roll, threshold int) bool {
	op := "<="
	if b, ok := rs.data["bases"].(map[string]any); ok {
		if o, ok := b["op"].(string); ok && o != "" {
			op = o
		}
	}
	return compare(op, roll, threshold)
}

// ModuleFor returns the code module wired to an algorithmic slot (default "t5",
// constrained to a word so it only resolves to a known module).
func (rs *Ruleset) ModuleFor(slot string) (string, error) {
	name := "t5"
	if m, ok := rs.data["modules"].(map[string]any); ok {
		if v, ok := m[slot]; ok && v != nil && toStr(v) != "" {
			name = strings.ToLower(toStr(v))
		}
	}
	if !wordRe.MatchString(name) {
		return "", fmt.Errorf("ruleset %q: bad module name %q for %s", rs.name, name, slot)
	}
	return name, nil
}

// UWPStep evaluates one UWP step (size/atmo/hydro/pop/gov/law) against ctx — the
// digits computed so far — handling zero_when / roll / reroll / adjust / clamp.
func (rs *Ruleset) UWPStep(name string, ctx map[string]any, r Roller) (int, error) {
	uwp, _ := rs.data["uwp"].(map[string]any)
	spec, ok := uwp[name].(map[string]any)
	if !ok {
		return 0, fmt.Errorf("ruleset %q has no UWP step %q", rs.name, name)
	}
	if zw := rs.compiled["uwp/"+name+"/zero_when"]; zw != nil && truthy(zw(ctx, r)) {
		return 0, nil
	}
	val := toInt(rs.compiled["uwp/"+name+"/roll"](ctx, r))

	if _, ok := spec["reroll"].(map[string]any); ok {
		cw := withVal(ctx, name, val)
		if w := rs.compiled["uwp/"+name+"/reroll/when"]; w != nil && truthy(w(cw, r)) {
			val = toInt(rs.compiled["uwp/"+name+"/reroll/with"](cw, r))
		}
	}
	if adj, ok := spec["adjust"].([]any); ok {
		for i, a := range adj {
			am, ok := a.(map[string]any)
			if !ok {
				continue
			}
			cw := withVal(ctx, name, val)
			if w := rs.compiled[fmt.Sprintf("uwp/%s/adjust/%d", name, i)]; w != nil && truthy(w(cw, r)) {
				if set, ok := am["set"]; ok {
					val = toInt(set)
				} else {
					val += toInt(am["delta"])
				}
			}
		}
	}
	if cl, ok := spec["clamp"].([]any); ok && len(cl) == 2 {
		lo, hi := toInt(cl[0]), toInt(cl[1])
		if val < lo {
			val = lo
		}
		if val > hi {
			val = hi
		}
	}
	return val, nil
}

func withVal(ctx map[string]any, k string, v int) map[string]any {
	cw := make(map[string]any, len(ctx)+1)
	for key, val := range ctx {
		cw[key] = val
	}
	cw[k] = v
	return cw
}

func toStr(v any) string {
	if s, ok := v.(string); ok {
		return s
	}
	return fmt.Sprintf("%v", v)
}
