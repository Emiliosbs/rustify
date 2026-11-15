---
name: py-c-to-rust
description: >-
  Transform Python or C source code into idiomatic, compiling Rust using the
  least possible tokens. Use this skill whenever the user asks to convert, port,
  rewrite, translate, migrate, transpile, or rust-ify any Python or C code,
  file, snippet, module, library, function, struct, class, or algorithm into
  Rust. Also trigger on phrases like "rewrite in Rust", "convert to Rust", "make
  this Rust", "Rust equivalent of", "port to Rust", "Rust version of", or when
  the user shows Python/C code and asks for Rust. Covers any size from a single
  function to a full module. The skill uses an investigation-first methodology:
  it analyzes memory model, syntax, semantics, and paradigm differences between
  source and target, then applies a Decompose-Map-Emit pipeline that suppresses
  source-echoing, prose narration, and trial-and-error borrow-checker
  iterations.
---

# Python/C -> Rust Token-Efficient Transpiler

## Mission
Convert any Python or C source into idiomatic Rust that compiles and behaves equivalently, while consuming the FEWEST possible output tokens.

## Why this skill exists
LLM token budgets are the bottleneck for large migrations. Naive conversion wastes tokens on four sources this skill eliminates:

1. Echoing the source code back to the user
2. Verbose prose explanations of every line
3. Iterating through failed borrow-checker attempts in the visible output
4. Repeating imports and boilerplate

The fix is a **DME pipeline** (Decompose -> Map -> Emit) backed by pre-built lookup tables.

## Investigation first (the core methodology)
Before writing any Rust, mentally run four orthogonal analyses on the source. Each analysis answers one question that determines a Rust design decision:

1. **Memory model** - How does the source manage memory? Python = tracing GC + refcounting on objects. C = manual `malloc`/`free` with raw pointers and no aliasing tracking. Rust = ownership + borrowing + RAII. This analysis decides whether each heap value becomes `T`, `Box<T>`, `Vec<T>`, `Rc<T>`/`Arc<T>`, `&T`/`&mut T`, or `*const T`/`*mut T` (unsafe).
2. **Syntax** - Surface tokens. `def` vs `fn`, `:` types vs `->`, `NULL` vs `None`, `#include` vs `use`. Translated 1:1 from lookup tables.
3. **Semantics** - Hidden control flow. Python exceptions (thrown anywhere, caught anywhere) -> Rust `Result<T,E>` (must be in the signature). Python `with` -> Rust RAII scope-drop. C `goto cleanup` -> Rust `?` + Drop. C `setjmp/longjmp` -> Rust `Result` propagation.
4. **Paradigm** - Python OO inheritance -> Rust composition + traits. Python duck typing -> Rust trait bounds. Python metaclasses -> Rust builder + derive macros. C function-pointer vtables -> Rust `dyn Trait` or `enum` dispatch. C preprocessor macros -> Rust `const` / `macro_rules!` / `cfg`.

These four analyses are the *reason* the mapping tables in the reference files exist. When in doubt about an edge case not in the tables, re-run the four analyses on the construct and the correct Rust shape falls out.

## When to load reference files
- For Python input -> read `references/python_to_rust.md` (types, control flow, classes, errors, async, stdlib).
- For C input -> read `references/c_to_rust.md` (pointer ownership inference rules, struct/union/typedef mapping, malloc->Box, function pointers -> closures, `#define` -> macro_rules).
- When output feels un-idiomatic -> read `references/idioms.md` (iterator chains, builder, From/Into, newtype, RAII guards).
- Before finalizing output -> read `references/token_efficiency.md` (compression rules and anti-patterns).

Load only the file(s) matching the source language. Do not preload all four.

## The DME pipeline (run for every input)

### Stage D - Decompose (silent)
Read the source. Produce a compact internal AST summary: one line per logical block in the form

`<kind>: <name> | in: <types> | out: <type> | mem: <ownership> | side: <effects>`

Kinds: `fn`, `struct`, `class`, `enum`, `const`, `macro`, `mod`, `trait`, `impl`.

DO NOT echo the source. DO NOT print this summary unless the user explicitly asks.

Example - this Python:
```python
def process(items: list[dict]) -> int:
    total = 0
    for item in items:
        total += item["price"] * item["qty"]
    return total
```
Decomposes internally to:
`fn: process | in: Vec<HashMap<&str,i64>> | out: i64 | mem: borrow | side: none`

### Stage M - Map (apply tables)
For each decomposed item, apply the mapping rules from the matching reference file. The most-used mappings:

#### Memory-model translation (the heart of the skill)
Classify every heap-allocated value:

| Source pattern | Rust type | Why |
|---|---|---|
| Python local that does not escape | stack `T` | no allocation needed |
| Python `list` | `Vec<T>` | grows, owns elements |
| Python `dict` | `HashMap<K,V>` | owns k/v |
| Python `set` | `HashSet<T>` | owns |
| Python value shared by multiple owners | `Rc<T>` / `Arc<T>` | refcount emulates GC |
| Python value with possible cycles | `Rc<RefCell<T>>` / `Arc<Mutex<T>>` | interior mutability |
| Python `Optional`/`None` | `Option<T>` | null-safety |
| C `malloc` + single owner, freed in same scope | `Box<T>` | RAII replaces `free` |
| C `malloc` + array, runtime size | `Vec<T>` | bounds-checked |
| C array, compile-time size | `[T; N]` | stack array |
| C pointer only read | `&T` | shared borrow |
| C pointer read and written | `&mut T` | exclusive borrow |
| C pointer stored in struct, freed elsewhere | `Box<T>` (if owned) / raw `*mut T` (if not) | match lifetime |
| C `char*` literal | `&'static str` | borrowed static |
| C `char*` built at runtime | `String` | owned, growable |
| C function pointer | `fn(U) -> V` or `Box<dyn Fn(U)->V>` | function pointer / closure |
| C `void*` | `enum` of variants or generic `T` | model the actual union |
| Shared across threads (`_Atomic`/locked) | `Arc<Mutex<T>>` | thread-safe shared mut |
| Hardware/FFI pointer | `*const T` / `*mut T` in `unsafe` | last resort |

The C reference file contains the full ownership-inference algorithm (Crown-style): if a pointer owns a heap object at *any* point in its scope, retype it to `Box<T>` (wrapped in `Option` if it can be `NULL`); if it is only read, retype to `&T`; if it is read and written but does not own, retype to `&mut T`; output parameters become `&mut T` to enable borrowing while preserving caller ownership.

#### Syntax/semantics quick map
Python -> Rust: `def` -> `fn`, `: T` -> `-> T`, `None` return -> `()`, `True/False` -> `true/false`, `self` -> `&self`/`&mut self`/`self`, `class X:` -> `struct X` + `impl X`, `__init__` -> `fn new() -> Self`, `try/except` -> `Result<T,E>` + `?`, `raise` -> `return Err(...)`, `with` -> RAII scope, `for x in xs` -> `for x in &xs` or `xs.iter().for_each(...)`, list comprehension -> `xs.iter().filter(...).map(...).collect()`, dict comprehension -> `.collect::<HashMap<_,_>>()`, lambda -> `|x| ...`, generator -> `impl Iterator<Item=T>`, `@decorator` -> wrapper fn or attribute macro, `isinstance` -> pattern match / trait bound, `*args` -> `&[T]`, `**kwargs` -> struct or `HashMap<&str, Value>`.

C -> Rust: `int` -> `i32`, `unsigned` -> `u32`, `size_t` -> `usize`, `void` return -> `()`, `NULL` -> `Option::None` or `ptr::null_mut()`, `struct X {...}` -> `struct X {...}` (`#[repr(C)]` for FFI), `typedef` -> `type`, `union` -> `union` with `unsafe` accessor OR `enum` with data, `enum` -> `enum`, `switch` -> `match`, `goto` -> restructure into loops/`match` (no goto in Rust), `#define X 5` -> `const X: i32 = 5;`, `#define MIN(a,b)` -> `std::cmp::min`, `#include` -> `use`, `static` -> `static`/`LazyLock`, `extern` -> `extern "C"`, `printf` -> `println!`/`format!`, `malloc` -> `Box::new`/`Vec::with_capacity`, `free` -> dropped automatically, `memcpy` -> `.copy_from_slice()`, `assert` -> `assert!`/`debug_assert!`, `exit()` -> `std::process::exit()`.

#### Paradigm translation
- Python OO inheritance -> composition + traits (no class inheritance in Rust).
- Python duck typing -> trait bounds `T: Trait` or `impl Trait`.
- Python metaclasses / class decorators -> builder fn + derive macros.
- C preprocessor abuse -> `const` / `macro_rules!` / `cfg`.
- C function pointers as callbacks -> `Fn` / `FnMut` / `FnOnce` traits or `fn` pointer type.
- C tagged unions (`enum` + `struct`) -> idiomatic Rust `enum` with data variants.
- C vtables -> `dyn Trait` or `enum` dispatch.

### Stage E - Emit (compact, idiomatic Rust)
Output rules in priority order:

1. Output only the Rust code in a single fenced block. No "Here is the conversion..." preamble.
2. No line-by-line comments unless the user explicitly asks for them.
3. Use iterator chains over explicit `for` loops when natural: `xs.iter().filter(...).map(...).collect()`.
4. Use `?` for error propagation, not `match`.
5. Use `if let` / `while let` instead of `match` with one arm + wildcard when only one variant matters.
6. Derive what you can: `#[derive(Debug, Clone, PartialEq)]` saves manual impl tokens.
7. Prefer `into_iter()` / `cloned()` to avoid lifetime noise.
8. One `mod` per file; do not split unless the source is clearly multi-module.
9. Import only what is used; prefer `use std::collections::HashMap;` over wildcard.
10. For unsafe: wrap the *minimum* scope in `unsafe { }`, add a one-line `// SAFETY: ...` comment.

### Emitting Cargo.toml
Emit a `Cargo.toml` after the Rust code IF the source uses external libraries (e.g. Python `import numpy`, C `#include <openssl/ssl.h>`). Otherwise skip it. Keep it minimal:

```toml
[package]
name = "converted"
version = "0.1.0"
edition = "2021"

[dependencies]
# only what is actually used
```

## Workflow per input
1. Identify source language: Python (`def`, `: `) vs C (`int main`, `{}`, `#include`).
2. Read the matching reference file.
3. Run DME pipeline internally.
4. Emit Rust code in ONE fenced block. Optionally emit Cargo.toml in a second block.
5. If borrow-checker concerns are non-trivial, append a `## Notes` section AFTER the code (max 5 lines) listing: ownership decisions, unsafe blocks used, manual lifetime annotations.

## Token-efficiency hard rules
- Never restate the input. The user already has it.
- Never write "Let me translate this step by step." Just translate.
- Never include both a `match` and an `if let` for the same value.
- Never write a comment that repeats the code's behavior (`// increment i` over `i += 1`).
- Never emit dead code or `#[allow(dead_code)]` cruft.
- Never use `String` where `&str` suffices for a parameter.
- Never use `Box<T>` for stack-sized `Copy` values.
- Never use `Vec<T>` where `[T; N]` array suffices and N is known.
- One blank line between items, zero blank lines inside an item body.
- Use `Self` instead of repeating the type name in `impl` blocks.
- Use `Default::default()` only when the type is obvious from context.

## Edge cases
- Python `*args` / `**kwargs`: `&[T]` slice for args, struct or `HashMap<&str, Value>` for kwargs.
- Python decorators: if pure wrapper (`@property`, `@staticmethod`) -> use Rust method semantics; if transformation -> wrapper fn or macro.
- Python metaclasses: cannot translate directly; use a builder fn + trait.
- C `setjmp/longjmp`: restructure as `Result` propagation.
- C `union` with implicit discriminator: model as Rust `enum` with data variants.
- C `goto`-based error cleanup: use `?` + RAII guards; if you cannot, mark `unsafe` and explain in Notes.
- C macro with side effects (`#define MIN(a,b) ((a)<(b)?(a):(b))`): use `std::cmp::min` (a real fn, no double-eval).
- Python `asyncio`: add `tokio` to Cargo.toml and `#[tokio::main]` on `main`.
- C `volatile`: use `std::ptr::read_volatile` / `write_volatile` in `unsafe`.
- C function-pointer table (vtable): use `enum` dispatch or `dyn Trait`.
- C bitfields: there is no native bitfield in Rust; either pack manually with bit ops and a wrapper struct, or use the `bitfield` crate.

## When to deviate from idiomatic Rust
- FFI boundary with stable ABI -> `#[repr(C)]`, `extern "C"`, raw pointers in `unsafe`.
- Bit-exact memory layout required -> `#[repr(C)]` or `#[repr(packed)]`.
- Drop order matters -> explicit `drop(x);` or restructure.
- Hardware access / OS kernel -> `unsafe` raw pointer I/O is correct, not a failure.

## Compile-self-check (run mentally before emitting)
Before finalizing, scan for:
- Every `&` has a clear owner that outlives the borrow.
- Every `mut` is actually mutated; remove unused `mut`.
- Every `Result` is handled (`?`, `match`, or `.unwrap()` only in tests/main).
- Every generic has its bounds.
- No `String` returned where `&str` would do.
- No `Box<T>` for `Copy` types.
- No raw pointers unless FFI/unsafe was required by the source.

If any check fails, fix before emitting.

## After emitting
Stop. Do not append "Hope this helps!" or any closing remarks. The Rust code IS the answer.

If the user wants to iterate ("add comments", "explain the ownership", "make it more idiomatic"), then explain in prose - but only on explicit request.

## Bundled helper script
`scripts/emit_skeleton.sh <name>` scaffolds a minimal Cargo binary crate (Cargo.toml + src/main.rs) so the skill does not have to emit boilerplate. Run it from Bash when the user asks for a "full project", "compile this", "make it runnable", or similar. Do NOT run it for single-function conversions.

## Examples

### Example 1: Python list comprehension -> Rust iterator chain
Input (Python):
```python
result = [x * 2 for x in items if x > 0]
```
Output:
```rust
let result: Vec<_> = items.iter().copied().filter(|&x| x > 0).map(|x| x * 2).collect();
```

### Example 2: C malloc/free -> Box
Input (C):
```c
Node* n = malloc(sizeof(Node));
n->val = 1;
...
free(n);
```
Output:
```rust
let mut n = Box::new(Node { val: 1 });
// dropped automatically at end of scope
```

### Example 3: Python class with __init__ -> struct + impl
Input:
```python
class Counter:
    def __init__(self):
        self.count = 0
    def inc(self):
        self.count += 1
        return self.count
```
Output:
```rust
struct Counter { count: u32 }

impl Counter {
    fn new() -> Self { Self { count: 0 } }
    fn inc(&mut self) -> u32 { self.count += 1; self.count }
}
```

### Example 4: C function pointer callback -> closure generic
Input:
```c
void apply(int* xs, size_t n, int (*f)(int)) {
    for (size_t i = 0; i < n; i++) xs[i] = f(xs[i]);
}
```
Output:
```rust
fn apply<F: Fn(i32) -> i32>(xs: &mut [i32], f: F) {
    for x in xs.iter_mut() { *x = f(*x); }
}
```

### Example 5: Python try/except with custom exception -> Result + thiserror
Input:
```python
class NotFoundError(Exception): pass
def find_user(uid):
    if uid not in users: raise NotFoundError(uid)
    return users[uid]
```
Output:
```rust
use thiserror::Error;

#[derive(Debug, Error)]
pub enum AppError {
    #[error("user {0} not found")]
    NotFound(u64),
}

fn find_user(uid: u64) -> Result<User, AppError> {
    users.get(&uid).cloned().ok_or(AppError::NotFound(uid))
}
```

### Example 6: C singly-linked list with malloc -> Option<Box<Node>>
Input (C):
```c
struct Node { int data; struct Node* next; };
void push(struct List* l, int d) {
    struct Node* n = malloc(sizeof(struct Node));
    n->data = d; n->next = l->head; l->head = n;
}
```
Output:
```rust
struct Node { data: i32, next: Option<Box<Node>> }
struct List { head: Option<Box<Node>> }

impl List {
    fn push(&mut self, d: i32) {
        let mut n = Box::new(Node { data: d, next: None });
        n.next = self.head.take();
        self.head = Some(n);
    }
}
```

## Final reminder
The deliverable is the Rust code. Everything else is overhead. Cut overhead.
