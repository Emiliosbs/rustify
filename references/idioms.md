# Idiomatic Rust Shortcuts

Reference file. Read this when the output feels un-idiomatic or when you suspect a verbose translation exists.

Each idiom below is both **more idiomatic** and **fewer tokens** than the naive translation.

## 1. Iterator chains over accumulator loops

```rust
// NAIVE - 6 lines, ~80 tokens
let mut result = Vec::new();
for x in &items {
    if *x > 0 {
        result.push(x * 2);
    }
}

// IDIOMATIC - ~30 tokens
let result: Vec<_> = items.iter().copied().filter(|&x| x > 0).map(|x| x * 2).collect();
```

Common chain vocabulary: `iter()`, `into_iter()`, `copied()`, `cloned()`, `filter()`, `map()`, `enumerate()`, `zip()`, `take()`, `skip()`, `rev()`, `sum()`, `min()`, `max()`, `any()`, `all()`, `collect()`.

## 2. `?` over `match` for error propagation

```rust
// NAIVE
let v = match g() { Ok(v) => v, Err(e) => return Err(e.into()) };

// IDIOMATIC
let v = g()?;
```

## 3. `if let` / `let-else` over single-arm `match`

```rust
if let Some(x) = opt { use(x); }
let Some(x) = opt else { return; };
```

## 4. Builder pattern (Python kwargs / metaclass-style construction)

When the source uses many constructor arguments or optional config:

```rust
struct Server { host: String, port: u16, tls: bool }

struct ServerBuilder { host: String, port: u16, tls: bool }

impl Server {
    fn builder() -> ServerBuilder { ServerBuilder { host: "localhost".into(), port: 8080, tls: false } }
}

impl ServerBuilder {
    fn host(mut self, h: impl Into<String>) -> Self { self.host = h.into(); self }
    fn port(mut self, p: u16) -> Self { self.port = p; self }
    fn tls(mut self, on: bool) -> Self { self.tls = on; self }
    fn build(self) -> Server { Server { host: self.host, port: self.port, tls: self.tls } }
}
```

## 5. `From`/`Into` over wrapper functions

```rust
// NAIVE
fn user_from_row(id: u64, name: &str) -> User { User { id, name: name.to_string() } }

// IDIOMATIC
struct User { id: u64, name: String }

impl From<(u64, &str)> for User {
    fn from((id, name): (u64, &str)) -> Self { Self { id, name: name.into() } }
}
```

Then any caller site gets `.into()` for free, and `?` auto-converts errors via `#[from]` in `thiserror`.

## 6. Newtype over primitives

```rust
struct Meters(f64);
struct Seconds(f64);

fn speed(d: Meters, t: Seconds) -> MetersPerSecond { MetersPerSecond(d.0 / t.0) }
```

Replaces C/Python comments like "x is in meters" with types the compiler enforces. Use `pub struct X(pub T)` to avoid accessor boilerplate.

## 7. RAII guards over try/finally

Anything acquired-then-released becomes a guard type with `Drop`:

```rust
struct Timer(std::time::Instant);

impl Timer {
    fn start() -> Self { Self(std::time::Instant::now()) }
}

impl Drop for Timer {
    fn drop(&mut self) { eprintln!("took {:?}", self.0.elapsed()); }
}
```

Covers: file handles, locks (`MutexGuard`), Python `with`, C cleanup paths.

## 8. `impl Trait` over `Box<dyn Trait>` when possible

```rust
fn apply(f: impl Fn(i32) -> i32) -> i32 { f(1) }          // static dispatch, no alloc
fn store(f: Box<dyn Fn(i32) -> i32>) { ... }              // only when actually stored
```

## 9. Derive over manual impls

```rust
#[derive(Debug, Clone, PartialEq, Eq, Hash, Default)]
struct Point { x: i32, y: i32 }
```

`Default` derive replaces manual "empty constructor"; `Debug` replaces `__repr__`; `PartialEq` replaces `__eq__`.

## 10. Range expressions and slicing

```rust
let mid = &xs[1..3];          // slice, no copy
let tail = &xs[1..];
let last = *xs.last().unwrap();  // or .ok_or(...)? in fallible code
```

## Quick self-test

If your translation contains all of: a `for` loop with a `Vec` accumulator, a full `match` on `Result` whose Err arm just returns, and a manual `Debug` impl — rewrite with idioms 1, 2, and 9.
