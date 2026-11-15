# Token Efficiency Rules

Reference file. Read this before finalizing any output.

## The goal
The output of this skill is consumed by humans AND by future LLM calls in the user's pipeline. Every token you emit costs the user money (inference compute) and the receiver's attention. The Rust code IS the deliverable. Everything else is overhead.

## Hard rules

### 1. Never echo the source
The user has the Python/C input. Do not restate it. Do not paste snippets of it as part of an "explanation". If you must refer to a source line by content, paraphrase in 4 words or fewer.

### 2. No preamble
BAD:
```
Here is the Rust conversion of your Python code. I translated the list comprehension to an iterator chain, used `?` for error propagation, and added a custom error enum.
```

GOOD:
```rust
let result: Vec<_> = items.iter().copied().filter(|&x| x > 0).map(|x| x * 2).collect();
```

Just emit the code block.

### 3. No narration between code blocks
If you must emit multiple code blocks (code + Cargo.toml), separate them with one blank line and nothing else. No "And here is the Cargo.toml:".

### 4. Use iterator chains, not 6-line `for` loops
A 6-line loop with a mutable accumulator and a conditional append is ~80 tokens. The equivalent iterator chain is ~30. Always prefer:
```rust
let result: Vec<_> = items.iter().copied().filter(|&x| x > 0).map(|x| x * 2).collect();
```

### 5. Use `?`, not `match`
```rust
// BAD - 35 tokens
let v = match g() {
    Ok(v) => v,
    Err(e) => return Err(e.into()),
};

// GOOD - 8 tokens
let v = g()?;
```

### 6. Use `if let`, not `match` with one arm + `_`
```rust
// BAD
match opt {
    Some(x) => { use(x); }
    _ => {}
}

// GOOD
if let Some(x) = opt { use(x); }
```

Even better, `let-else`:
```rust
let Some(x) = opt else { return; };
use(x);
```

### 7. Derive aggressively
```rust
// BAD - 60+ tokens of manual impl
impl std::fmt::Debug for Foo {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("Foo").field("a", &self.a).field("b", &self.b).finish()
    }
}
impl PartialEq for Foo {
    fn eq(&self, other: &Self) -> bool { self.a == other.a && self.b == other.b }
}

// GOOD - 6 tokens
#[derive(Debug, PartialEq)]
struct Foo { a: i32, b: String }
```

### 8. Use `Self` in `impl`
```rust
// BAD
impl Foo {
    fn new() -> Foo { Foo { x: 0 } }
}

// GOOD
impl Foo {
    fn new() -> Self { Self { x: 0 } }
}
```

### 9. Take `impl Into<String>` for string params
This avoids a `.to_string()` call at every call site for `&str` callers:
```rust
fn greet(name: impl Into<String>) -> String { format!("hi {}", name.into()) }
```

But for a single internal call, just `&str` is shorter:
```rust
fn greet(name: &str) -> String { format!("hi {}", name) }
```

Pick based on caller convenience. For internal/private code prefer `&str`.

### 10. Use `Default::default()` when the type is obvious
```rust
let mut map: HashMap<&str, i32> = Default::default();
// instead of
let mut map: HashMap<&str, i32> = HashMap::new();
```

Same token count, but `Default::default()` is more uniform across types.

### 11. Slice instead of `Vec` for params
If a function only reads, `&[T]` is shorter than `Vec<T>` and accepts both:
```rust
fn sum(xs: &[i32]) -> i32 { xs.iter().sum() }
```

### 12. Drop unused `mut`
```rust
let mut x = 5; // if x is never reassigned, drop mut
```

Compiler warns; pre-empt the warning.

### 13. Use `()` over `void`, omit `-> ()` when return is unit
```rust
fn log(msg: &str) { println!("{}", msg); }   // not: fn log(msg: &str) -> () { ... }
```

### 14. One import line per `use`
```rust
use std::{collections::HashMap, fs::File, io::Read};
```
is denser than three separate `use` lines.

### 15. No `// TODO` or `// FIXME` placeholders
If something cannot be translated, explain in a Notes section after the code, not in a comment in the code.

### 16. No `#[allow(...)]` attributes
Fix the warning, do not suppress it. The exception is FFI stubs where `#[allow(non_camel_case_types)]` matches the C ABI.

### 17. No trailing `;` after block expressions
```rust
let x = { foo(); bar() };     // BAD: bar();   <- changes the type to ()
let x = { foo(); bar() }      // GOOD
```

### 18. Use `format!` for string building, not `push_str` chains
```rust
let s = format!("{}-{}-{}", a, b, c);
// instead of
let mut s = String::new(); s.push_str(&a.to_string()); s.push('-'); ...
```

### 19. Use `to_string()` only when you actually need `String`
For `&str` params, just pass the `&str`. For a one-shot format, `format!` returns `String` already.

### 20. No closing remarks
No "Hope this helps!", no "Let me know if you'd like changes.", no "This Rust code should compile and behave equivalently to your Python code.".

The code IS the answer.

## Structural compression

### Multi-function source -> one `impl` block, not many
If the source has a class with 5 methods, emit one `impl Foo { ... }` block with all 5 methods inside, not 5 separate blocks.

### Group imports
```rust
use std::{collections::{HashMap, HashSet}, fs::File, io::{Read, Write}};
```

### Use associated constants, not module-level consts, when they belong to a type
```rust
struct Config {
    const MAX_RETRIES: u32 = 3;
    // ... fields ...
}
```
Wait - that syntax is not valid Rust. Use:
```rust
struct Config { /* fields */ }
impl Config {
    const MAX_RETRIES: u32 = 3;
}
```

### Avoid `Box<T>` for stack-sized data
`Box::new(5_i32)` is silly. Just `5_i32`.

### Prefer `[T; N]` over `Vec<T>` when N is known at compile time
```rust
let xs: [i32; 3] = [1, 2, 3];
```
saves heap allocation and tokens vs `vec![1, 2, 3]`.

## When verbose is correct

Some cases warrant a tiny amount of extra prose AFTER the code:

1. **The translation required a non-obvious ownership decision** (e.g. chose `Rc<RefCell<T>>` over `&mut T` because of cycles). Mention it in one line.
2. **The translation required `unsafe` for non-FFI reasons**. Add a `// SAFETY:` comment in the code, AND mention in a Notes section why.
3. **The source had a bug that you fixed during translation** (e.g. off-by-one that Rust's bounds checking would catch). Mention it.
4. **A source feature was dropped** because Rust has no safe equivalent (e.g. `goto`, certain metaclass tricks). Mention it so the user knows.

These notes go in a `## Notes` section AFTER the code block, maximum 5 lines. No other prose.

## Output shape (canonical)

A canonical skill output looks like:

````
```rust
<code>
```
````

Or, if a Cargo.toml is needed:

````
```rust
<code>
```

```toml
[package]
name = "..."
version = "0.1.0"
edition = "2021"

[dependencies]
...
```
````

Or, if notes are needed:

````
```rust
<code>
```

## Notes
- Chose `Rc<RefCell<T>>` for `graph` because the source uses bidirectional edges.
- `unsafe` block in `read_mmio`: required for volatile hardware read; invariant: address is mapped.

````

That's the entire output shape. Do not deviate without reason.

## Self-check before emitting

Count the tokens of your planned output. If you wrote more than ~1.5x the token count of the source, you are being verbose. Apply rules 1-20 until under the budget.
