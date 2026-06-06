//! A sandboxed expression evaluator for ruleset rules — the Rust port of the Ruby
//! Astromapper::Rules::Expr (and the Go pkg/rules expr). Supports integer & string
//! literals, named variables, dice (`2d6`, `flux`), arithmetic (+ - * /), comparisons
//! (== != < <= > >=), and booleans (and / or / not), with parentheses.
//!
//! SECURITY: this is a hand-written tokenizer + recursive-descent parser. It never
//! evaluates arbitrary code — only arithmetic, comparisons, dice, and lookups in a
//! caller-supplied context are possible. A `rules/*.yml` file is data, not a program.

use std::collections::HashMap;

use crate::rng;

/// A runtime value: integer, boolean, or string.
#[derive(Clone, Debug, PartialEq)]
pub enum Value {
    Int(i64),
    Bool(bool),
    Str(String),
}

impl Value {
    pub fn from_int<T: Into<i64>>(n: T) -> Value {
        Value::Int(n.into())
    }
    pub fn from_str(s: &str) -> Value {
        Value::Str(s.to_string())
    }
    pub fn as_int(&self) -> i64 {
        match self {
            Value::Int(n) => *n,
            Value::Bool(true) => 1,
            _ => 0,
        }
    }
    pub fn truthy(&self) -> bool {
        !matches!(self, Value::Bool(false))
    }
}

/// Context of named variables passed to `eval`.
pub type Context = HashMap<String, Value>;

/// A compiled expression node.
#[derive(Clone, Debug)]
pub enum Node {
    Num(i64),
    Str(String),
    Var(String),
    Dice(u32, u32),
    Flux,
    Neg(Box<Node>),
    Not(Box<Node>),
    And(Box<Node>, Box<Node>),
    Or(Box<Node>, Box<Node>),
    Cmp(String, Box<Node>, Box<Node>),
    Arith(char, Box<Node>, Box<Node>),
}

impl Node {
    /// Evaluate against a context. Dice/flux draw from the thread-local RNG.
    pub fn eval(&self, ctx: &Context) -> Value {
        match self {
            Node::Num(n) => Value::Int(*n),
            Node::Str(s) => Value::Str(s.clone()),
            Node::Var(k) => ctx.get(k).cloned().unwrap_or(Value::Int(0)),
            Node::Dice(n, sides) => Value::Int(rng::roll(*n, *sides).unwrap_or(0) as i64),
            Node::Flux => {
                let a = rng::roll(1, 6).unwrap_or(0) as i64;
                let b = rng::roll(1, 6).unwrap_or(0) as i64;
                Value::Int(a - b)
            }
            Node::Neg(x) => Value::Int(-x.eval(ctx).as_int()),
            Node::Not(x) => Value::Bool(!x.eval(ctx).truthy()),
            Node::And(l, r) => Value::Bool(l.eval(ctx).truthy() && r.eval(ctx).truthy()),
            Node::Or(l, r) => Value::Bool(l.eval(ctx).truthy() || r.eval(ctx).truthy()),
            Node::Cmp(op, l, r) => Value::Bool(compare(op, &l.eval(ctx), &r.eval(ctx))),
            Node::Arith(op, l, r) => {
                let a = l.eval(ctx).as_int();
                let b = r.eval(ctx).as_int();
                Value::Int(match op {
                    '+' => a + b,
                    '-' => a - b,
                    '*' => a * b,
                    _ => {
                        if b == 0 {
                            0
                        } else {
                            a / b
                        }
                    }
                })
            }
        }
    }

    /// Convenience: evaluate and return whether the result is boolean-true.
    pub fn is_true(&self, ctx: &Context) -> bool {
        matches!(self.eval(ctx), Value::Bool(true))
    }
}

fn compare(op: &str, a: &Value, b: &Value) -> bool {
    match op {
        "==" => values_equal(a, b),
        "!=" => !values_equal(a, b),
        "<" => a.as_int() < b.as_int(),
        "<=" => a.as_int() <= b.as_int(),
        ">" => a.as_int() > b.as_int(),
        ">=" => a.as_int() >= b.as_int(),
        _ => false,
    }
}

fn values_equal(a: &Value, b: &Value) -> bool {
    match (a, b) {
        (Value::Str(x), Value::Str(y)) => x == y,
        (Value::Str(_), _) | (_, Value::Str(_)) => false,
        _ => a.as_int() == b.as_int(),
    }
}

/// Compile a source string into a reusable Node.
pub fn compile(src: &str) -> Result<Node, String> {
    let tokens = tokenize(src)?;
    let mut p = Parser { tokens, pos: 0 };
    let node = p.parse_or()?;
    if !matches!(p.peek(), Token::End) {
        return Err(format!("unexpected token {:?}", p.peek()));
    }
    Ok(node)
}

// ---- tokenizer ----------------------------------------------------------

#[derive(Clone, Debug, PartialEq)]
enum Token {
    Dice(u32, u32),
    Num(i64),
    Str(String),
    Op(String),
    Kw(String),
    Var(String),
    End,
}

fn tokenize(src: &str) -> Result<Vec<Token>, String> {
    let chars: Vec<char> = src.chars().collect();
    let mut i = 0;
    let mut toks = Vec::new();
    while i < chars.len() {
        let c = chars[i];
        if c.is_whitespace() {
            i += 1;
            continue;
        }
        if c.is_ascii_digit() {
            let start = i;
            while i < chars.len() && chars[i].is_ascii_digit() {
                i += 1;
            }
            // dice? digits 'd' digits
            if i < chars.len() && chars[i] == 'd' && i + 1 < chars.len() && chars[i + 1].is_ascii_digit() {
                let n: u32 = chars[start..i].iter().collect::<String>().parse().unwrap();
                i += 1; // skip 'd'
                let ds = i;
                while i < chars.len() && chars[i].is_ascii_digit() {
                    i += 1;
                }
                let sides: u32 = chars[ds..i].iter().collect::<String>().parse().unwrap();
                toks.push(Token::Dice(n, sides));
            } else {
                let n: i64 = chars[start..i].iter().collect::<String>().parse().unwrap();
                toks.push(Token::Num(n));
            }
            continue;
        }
        if c == '\'' {
            i += 1;
            let start = i;
            while i < chars.len() && chars[i] != '\'' {
                i += 1;
            }
            if i >= chars.len() {
                return Err("unterminated string".to_string());
            }
            let s: String = chars[start..i].iter().collect();
            i += 1; // closing quote
            toks.push(Token::Str(s));
            continue;
        }
        // two-char operators
        let two: String = chars[i..(i + 2).min(chars.len())].iter().collect();
        if two == "==" || two == "!=" || two == "<=" || two == ">=" {
            toks.push(Token::Op(two));
            i += 2;
            continue;
        }
        if "<>()+-*/".contains(c) {
            toks.push(Token::Op(c.to_string()));
            i += 1;
            continue;
        }
        if c.is_alphabetic() || c == '_' {
            let start = i;
            while i < chars.len() && (chars[i].is_alphanumeric() || chars[i] == '_') {
                i += 1;
            }
            let w: String = chars[start..i].iter().collect();
            if matches!(w.as_str(), "and" | "or" | "not" | "flux") {
                toks.push(Token::Kw(w));
            } else {
                toks.push(Token::Var(w));
            }
            continue;
        }
        return Err(format!("bad character {:?} in expression", c));
    }
    toks.push(Token::End);
    Ok(toks)
}

// ---- parser (recursive descent) ----------------------------------------
// or > and > not > comparison > additive > multiplicative > unary > primary

struct Parser {
    tokens: Vec<Token>,
    pos: usize,
}

impl Parser {
    fn peek(&self) -> &Token {
        &self.tokens[self.pos]
    }
    fn bump(&mut self) -> Token {
        let t = self.tokens[self.pos].clone();
        self.pos += 1;
        t
    }
    fn accept_op(&mut self, op: &str) -> bool {
        if matches!(self.peek(), Token::Op(s) if s == op) {
            self.pos += 1;
            true
        } else {
            false
        }
    }
    fn accept_kw(&mut self, kw: &str) -> bool {
        if matches!(self.peek(), Token::Kw(s) if s == kw) {
            self.pos += 1;
            true
        } else {
            false
        }
    }

    fn parse_or(&mut self) -> Result<Node, String> {
        let mut node = self.parse_and()?;
        while self.accept_kw("or") {
            let rhs = self.parse_and()?;
            node = Node::Or(Box::new(node), Box::new(rhs));
        }
        Ok(node)
    }

    fn parse_and(&mut self) -> Result<Node, String> {
        let mut node = self.parse_not()?;
        while self.accept_kw("and") {
            let rhs = self.parse_not()?;
            node = Node::And(Box::new(node), Box::new(rhs));
        }
        Ok(node)
    }

    fn parse_not(&mut self) -> Result<Node, String> {
        if self.accept_kw("not") {
            return Ok(Node::Not(Box::new(self.parse_not()?)));
        }
        self.parse_cmp()
    }

    fn parse_cmp(&mut self) -> Result<Node, String> {
        let node = self.parse_add()?;
        for op in ["==", "!=", "<=", ">=", "<", ">"] {
            if self.accept_op(op) {
                let rhs = self.parse_add()?;
                return Ok(Node::Cmp(op.to_string(), Box::new(node), Box::new(rhs)));
            }
        }
        Ok(node)
    }

    fn parse_add(&mut self) -> Result<Node, String> {
        let mut node = self.parse_mul()?;
        loop {
            let op = if self.accept_op("+") {
                '+'
            } else if self.accept_op("-") {
                '-'
            } else {
                break;
            };
            let rhs = self.parse_mul()?;
            node = Node::Arith(op, Box::new(node), Box::new(rhs));
        }
        Ok(node)
    }

    fn parse_mul(&mut self) -> Result<Node, String> {
        let mut node = self.parse_unary()?;
        loop {
            let op = if self.accept_op("*") {
                '*'
            } else if self.accept_op("/") {
                '/'
            } else {
                break;
            };
            let rhs = self.parse_unary()?;
            node = Node::Arith(op, Box::new(node), Box::new(rhs));
        }
        Ok(node)
    }

    fn parse_unary(&mut self) -> Result<Node, String> {
        if self.accept_op("-") {
            return Ok(Node::Neg(Box::new(self.parse_unary()?)));
        }
        self.parse_primary()
    }

    fn parse_primary(&mut self) -> Result<Node, String> {
        match self.bump() {
            Token::Num(n) => Ok(Node::Num(n)),
            Token::Str(s) => Ok(Node::Str(s)),
            Token::Dice(n, sides) => Ok(Node::Dice(n, sides)),
            Token::Kw(k) if k == "flux" => Ok(Node::Flux),
            Token::Var(v) => Ok(Node::Var(v)),
            Token::Op(ref o) if o == "(" => {
                let node = self.parse_or()?;
                if !self.accept_op(")") {
                    return Err("missing ')'".to_string());
                }
                Ok(node)
            }
            other => Err(format!("unexpected token {:?}", other)),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn ev(src: &str) -> Value {
        compile(src).unwrap().eval(&Context::new())
    }

    #[test]
    fn arithmetic() {
        assert_eq!(ev("2+3").as_int(), 5);
        assert_eq!(ev("10-3").as_int(), 7);
        assert_eq!(ev("2*3").as_int(), 6);
        assert_eq!(ev("-(2+2)").as_int(), -4);
        assert_eq!(ev("2*3+1").as_int(), 7);
    }

    #[test]
    fn comparisons_and_booleans() {
        assert_eq!(ev("5>=2 and 5<=9"), Value::Bool(true));
        assert_eq!(ev("5>9 or 1>9"), Value::Bool(false));
        assert_eq!(ev("not 5>9"), Value::Bool(true));
        assert_eq!(ev("(1==1) and (2==2)"), Value::Bool(true));
    }

    #[test]
    fn variables_and_strings() {
        let cond = compile("atmo>=2 and atmo<=9 and hydro==0").unwrap();
        let mut ctx = Context::new();
        ctx.insert("atmo".into(), Value::Int(5));
        ctx.insert("hydro".into(), Value::Int(0));
        assert_eq!(cond.eval(&ctx), Value::Bool(true));
        ctx.insert("hydro".into(), Value::Int(4));
        assert_eq!(cond.eval(&ctx), Value::Bool(false));

        let mut pctx = Context::new();
        pctx.insert("port".into(), Value::Str("X".into()));
        assert_eq!(compile("port=='X'").unwrap().eval(&pctx), Value::Bool(true));
    }

    #[test]
    fn dice_in_range() {
        rng::init_rng("expr-dice");
        let two = compile("2d6-2").unwrap();
        let flux = compile("flux").unwrap();
        for _ in 0..500 {
            let v = two.eval(&Context::new()).as_int();
            assert!((0..=10).contains(&v));
            let f = flux.eval(&Context::new()).as_int();
            assert!((-5..=5).contains(&f));
        }
    }

    #[test]
    fn rejects_bad_input() {
        assert!(compile("1 +").is_err());
        assert!(compile("((1)").is_err());
        assert!(compile("2 @ 3").is_err());
    }
}
