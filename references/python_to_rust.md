# Python -> Rust Mapping Tables

Reference file. Read this when the input is Python.

## Table of contents
1. Primitive types
2. Collections
3. Strings
4. Control flow
5. Functions
6. Classes and OO
7. Error handling
8. Async and concurrency
9. Modules and imports
10. Decorators and metaprogramming
11. Generators and iterators
12. Common stdlib mappings
13. NumPy / common third-party mappings

## 1. Primitive types

| Python | Rust | Notes |
|---|---|---|
| `int` (small) | `i32` | default integer width |
| `int` (large, arbitrary precision) | `i64` or `num_bigint::BigInt` | Rust has no bignum in std |
| `float` | `f64` | default float width |
| `bool` | `bool` | identical semantics |
| `None` (singleton) | `()` as unit OR `Option::None` | depends on context |
| `None` as "no value" return | `()` | unit type |
| `None` as "missing value" | `Option<T>::None` | null-safety |
| `True` / `False` | `true` / `false` | lowercase |
| `complex` | `num_complex::Complex64` | external crate |
| `bytes` | `&[u8]` / `Vec<u8>` | borrowed / owned |
| `bytearray` | `Vec<u8>` | growable |
| `Ellipsis` (`...`) | no equivalent | use a custom marker enum |

## 2. Collections

| Python | Rust | Notes |
|---|---|---|
| `list` | `Vec<T>` | dynamic array, owns elements |
| `tuple` (fixed arity) | `(T1, T2, ...)` | tuple type |
| `tuple` (homogeneous, var arity) | `&[T]` / `Vec<T>` | use slice |
| `dict` | `HashMap<K, V>` | hash map, owns k/v |
| `dict` (ordered) | `BTreeMap<K, V>` or `indexmap::IndexMap` | ordered |
| `set` | `HashSet<T>` | |
| `frozenset` | `HashSet<T>` with no `mut` | borrow-only access |
| `collections.deque` | `VecDeque<T>` | double-ended queue |
| `collections.Counter` | `HashMap<T, usize>` | |
| `collections.OrderedDict` | `indexmap::IndexMap` | external crate |
| `collections.defaultdict` | `HashMap<K, V>` + `.or_insert_with(default)` | |
| `collections.namedtuple` | `struct` with named fields + `#[derive(Debug, Clone, PartialEq)]` | |
| `collections.ChainMap` | chain of `HashMap`s manually, or `itertools::chain` | |
| `array.array('i', ...)` | `Vec<i32>` | |
| `range(n)` | `0..n` | Range type |
| `range(a, b)` | `a..b` | |
| `range(a, b, step)` | `(a..b).step_by(step)` | |
| `enumerate(xs)` | `xs.iter().enumerate()` | |
| `zip(a, b)` | `a.iter().zip(b.iter())` | |
| `map(f, xs)` | `xs.iter().map(f)` | |
| `filter(p, xs)` | `xs.iter().filter(p)` | |

## 3. Strings

| Python | Rust | Notes |
|---|---|---|
| `str` literal | `&'static str` | borrowed, immutable, statically allocated |
| `str` built at runtime | `String` | owned, growable, heap-allocated |
| function param taking str | `&str` | borrows, works for both `String` and `&str` |
| field storing str | `String` | owns |
| f-string `f"{x}"` | `format!("{x}")` | |
| f-string with format spec `f"{x:.2}"` | `format!("{x:.2}")` | |
| `"\n".join(xs)` | `xs.collect::<Vec<_>>().join("\n")` | |
| `s.split(",")` | `s.split(',')` | |
| `s.splitlines()` | `s.lines()` | |
| `s.strip()` | `s.trim()` | |
| `s.lower()` | `s.to_lowercase()` | |
| `s.upper()` | `s.to_uppercase()` | |
| `s.replace(a, b)` | `s.replace(a, b)` | |
| `s.startswith(p)` | `s.starts_with(p)` | |
| `s.endswith(p)` | `s.ends_with(p)` | |
| `s[i]` | `s.chars().nth(i)` (O(n)) or `s.as_bytes()[i]` (bytes) | Rust strings are UTF-8, no O(1) char index |
| `len(s)` | `s.len()` (bytes) or `s.chars().count()` (chars) | |
| `s.encode('utf-8')` | `s.as_bytes()` | |
| `b"..."` literal | `b"..."` | identical syntax, type `&[u8; N]` |
| raw string `r"..."` | `r"..."` | identical syntax |
| `chr(n)` | `char::from_u32(n)` | returns `Option<char>` |
| `ord(c)` | `c as u32` | |

## 4. Control flow

| Python | Rust | Notes |
|---|---|---|
| `if c: ... elif c2: ... else: ...` | `if c { ... } else if c2 { ... } else { ... }` | braces mandatory, no parens around condition |
| `for x in xs:` | `for x in &xs { ... }` (borrow) or `for x in xs { ... }` (consume) | choose borrow vs consume |
| `for i in range(n):` | `for i in 0..n { ... }` | |
| `while c:` | `while c { ... }` | |
| `while True:` | `loop { ... }` | infinite loop |
| `break` | `break` | |
| `continue` | `continue` | |
| `break` with value from `while True` | `break v` from `loop` | `loop` can yield a value |
| `match x:` (3.10+) | `match x { ... }` | Rust's match is exhaustive |
| `pass` | (empty block `()` or omit) | |
| `with ctx as v:` | `let v = ctx;` + Drop impl | RAII scope |
| `try: ... finally:` | `Drop` trait (automatic) | deterministic cleanup |
| `assert cond` | `assert!(cond)` | |
| `assert cond, msg` | `assert!(cond, "{}", msg)` | |
| `raise` | `return Err(...)` | explicit error return |
| `raise ExceptionClass(msg)` | `return Err(MyError::Variant(msg))` | |
| `try: ... except E as e: ...` | `match result { Err(e @ E { .. }) => ..., _ => ... }` or `?` | |
| ternary `a if c else b` | `if c { a } else { b }` | |
| `and` / `or` | `&&` / `\|\|` | short-circuit, same semantics |
| `not x` | `!x` | |
| `is None` | `.is_none()` | |
| `is not None` | `.is_some()` | |
| `in` (membership) | `.contains(&x)` | |
| `del x` | `drop(x);` | rarely needed; scope-drop is automatic |

## 5. Functions

| Python | Rust | Notes |
|---|---|---|
| `def f(x: int) -> int:` | `fn f(x: i32) -> i32 { ... }` | explicit types recommended |
| `def f():` (no return) | `fn f() { ... }` or `fn f() -> () { ... }` | unit return |
| default arg `def f(x=0):` | `fn f(x: i32) -> i32` + caller passes default | Rust has no default args; use builder or two fns |
| keyword args `def f(*, name):` | `struct FArgs { name: T }` + `fn f(args: FArgs)` | |
| `*args` | `&[T]` / slice | variadic not supported |
| `**kwargs` | `HashMap<String, Value>` or `serde_json::Value` / `serde_json::Map` | |
| `lambda x: x*2` | `\|x\| x * 2` | closure |
| nested function (closure) | nested `fn` does not capture; use closure `let f = \|x\| ...` | |
| `functools.partial(f, x)` | `move \|y\| f(x, y)` | |
| `@staticmethod` | free fn in `impl` block (no `self`) | |
| `@classmethod` | associated fn `fn f() -> Self` or taking no `self` | |
| type hints `x: List[int]` | `x: Vec<i32>` | directly transferred |
| `typing.Optional[T]` | `Option<T>` | |
| `typing.Union[A, B]` | `enum` with variants or trait object `Box<dyn Trait>` | |
| `typing.Callable[[X], Y]` | `impl Fn(X) -> Y` or `fn(X) -> Y` | |
| `typing.Any` | `Box<dyn Any>` (rarely idiomatic) or generic `T` | |

## 6. Classes and OO

| Python | Rust | Notes |
|---|---|---|
| `class Foo:` | `struct Foo { ... }` + `impl Foo { ... }` | data和行为 split |
| `class Foo(Base):` | composition: `struct Foo { base: Base, ... }` + `impl Foo` may delegate | no inheritance |
| `class Foo(ABC):` with abstract methods | `trait Foo` + `impl Foo for Concrete` | |
| `__init__` | `fn new(...) -> Self` | constructor convention |
| `__del__` | `impl Drop for Foo { fn drop(&mut self) { ... } }` | deterministic |
| `__repr__` | `impl std::fmt::Debug for Foo` (derive) | `Debug` ~= repr |
| `__str__` | `impl std::fmt::Display for Foo` | `Display` ~= str |
| `__eq__` | `impl PartialEq for Foo` (derive) | |
| `__hash__` | `impl Hash for Foo` (derive) | |
| `__lt__` | `impl PartialOrd for Foo` (derive) | |
| `__iter__` | `impl IntoIterator for Foo` or `impl Iterator for FooIter` | |
| `__len__` | `impl Foo { fn len(&self) -> usize }` (no built-in trait) | |
| `__getitem__(i)` | `impl std::ops::Index<I> for Foo` | |
| `__setitem__(i, v)` | `impl std::ops::IndexMut<I> for Foo` | |
| `__add__` | `impl std::ops::Add for Foo` | |
| `__mul__` | `impl std::ops::Mul for Foo` | |
| `__neg__` | `impl std::ops::Neg for Foo` | |
| `__contains__(x)` | `impl Foo { fn contains(&self, x: &T) -> bool }` | |
| `__enter__` / `__exit__` | RAII: `impl Drop` | scope-based |
| `@property` | `fn field(&self) -> &T` (getter) | |
| `@x.setter` | `fn set_x(&mut self, v: T)` or `fn x_mut(&mut self) -> &mut T` | |
| class variable | `static` in `impl` block or associated `const` | |
| instance variable (dynamic) | not idiomatic; struct fields must be declared | |
| duck typing | trait bound `T: Trait` | |
| `isinstance(x, T)` | `matches!(x, T::Variant { .. })` or trait method returning `&dyn Any` | |
| multiple inheritance | composition of multiple traits/structs | no diamond |

## 7. Error handling

| Python | Rust | Notes |
|---|---|---|
| `raise ValueError("msg")` | `return Err(MyErr::Variant("msg".into()))` | |
| `try: ... except ValueError: ...` | `match r { Err(e) => ..., Ok(v) => ... }` or `if let Err(e) = r { ... }` | |
| `try: ... except Exception:` (catch all) | `match r { Ok(v) => ..., Err(_) => ... }` | |
| exception propagation (implicit) | `?` operator (explicit, in signature) | |
| `raise X from Y` | `.map_err(\|e\| MyErr::From(e))` or `#[from]` with thiserror | |
| `finally:` cleanup | `impl Drop` or scope-bound guard | deterministic |
| `with open(p) as f:` | `let f = File::open(p)?;` + scope-drop | RAII |
| custom exception hierarchy | `enum AppError { ... }` + `#[derive(thiserror::Error)]` | |
| `assert cond, msg` | `assert!(cond, "{}", msg)` | panics |
| `sys.exit(n)` | `std::process::exit(n)` | |
| `try: ... except: pass` (swallow) | `let _ = r;` | explicit ignore |

For application code prefer `anyhow::Result` (boxed error, easy `?` propagation); for library code prefer `thiserror` (typed enum, `#[from]` auto-conversion).

## 8. Async and concurrency

| Python | Rust | Notes |
|---|---|---|
| `async def f():` | `async fn f() { ... }` | |
| `await x` | `x.await` | suffix, no parens |
| `asyncio.run(main())` | `tokio::main` attribute or `tokio::runtime::Runtime::new()?.block_on(main())` | |
| `asyncio.gather(*aws)` | `futures::future::join_all(aws).await` or `tokio::join!(a, b)` (fixed arity) | |
| `asyncio.create_task(c)` | `tokio::spawn(c)` | |
| `asyncio.Lock` | `tokio::sync::Mutex` | |
| `asyncio.Semaphore` | `tokio::sync::Semaphore` | |
| `asyncio.Queue` | `tokio::sync::mpsc::channel` | |
| `threading.Thread(target=f)` | `std::thread::spawn(f)` | |
| `threading.Lock` | `std::sync::Mutex` | |
| `threading.RLock` | `std::sync::RwLock` (write = exclusive) | |
| `concurrent.futures.ThreadPoolExecutor` | `rayon` thread pool or `std::thread::scope` | |
| `multiprocessing.Pool` | `rayon` or `std::process` + channels | |
| `queue.Queue` | `std::sync::mpsc::channel` | |
| `threading.local()` | `thread_local!` macro | |

Rust async has no built-in runtime; add `tokio` to Cargo.toml. Most async code uses `tokio` features: `rt-multi-thread`, `macros`, `fs`, `net`, `sync`.

## 9. Modules and imports

| Python | Rust | Notes |
|---|---|---|
| `import foo` | `use foo;` (rare) or `foo::bar()` directly | |
| `from foo import bar` | `use foo::bar;` | |
| `from foo import bar as baz` | `use foo::bar as baz;` | |
| `import foo.bar.baz` | `use foo::bar::baz;` | |
| `__init__.py` | `mod.rs` (2018) or `foo/mod.rs` / `foo.rs` | |
| `if __name__ == "__main__":` | `fn main() { ... }` (only binary crate has main) | |
| `__all__` | no equivalent (visibility via `pub`) | |
| relative import `from . import x` | `use crate::x;` or `use super::x;` | |
| `sys.path` manipulation | `Cargo.toml` `[dependencies]` / `[patch]` | |

## 10. Decorators and metaprogramming

| Python | Rust | Notes |
|---|---|---|
| `@property` | getter method `fn x(&self) -> &T` | |
| `@staticmethod` | associated fn (no `self`) | |
| `@classmethod` | associated fn returning `Self` | |
| `@functools.wraps(f)` | no direct equivalent; closures keep their type | |
| `@dataclass` | `#[derive(Debug, Clone, PartialEq, Eq, Hash)]` + struct | |
| `@dataclass(frozen=True)` | derive + no `mut` access (borrow only) | |
| `@attrs` | same as dataclass + builder | |
| `@lru_cache(maxsize=N)` | `cached::SizedCache` or `moka` crate | |
| `@cached_property` | same as lru_cache, computed once | |
| decorator that wraps fn | write a wrapper closure / fn, or a `macro_rules!` | no first-class decorator syntax |
| `@functools.singledispatch` | trait + impl per type | |
| metaclass (custom class creation) | builder fn + derive macro | cannot be done at runtime in Rust |
| `type()` to inspect | `std::any::TypeId::of::<T>()` | |
| `getattr(obj, "x")` | no equivalent; use enum dispatch or `serde_json::Value` | |
| `eval("...")` | no built-in; use `syn` + `quote` (proc-macro) for compile-time | |

## 11. Generators and iterators

| Python | Rust | Notes |
|---|---|---|
| `def gen(): yield x` | `impl Iterator<Item = T>` + state machine, or `std::iter::from_fn(\|\| ...)` | |
| `yield x` inside loop | `Some(x)` returned from `next()` | |
| generator with `return` (StopIteration value) | not directly supported; encode final value in the `Item` enum | |
| `next(g)` | `g.next()` (returns `Option<T>`) | |
| `iter(xs)` | `xs.iter()` (borrows) or `xs.into_iter()` (consumes) | |
| `reversed(xs)` | `xs.iter().rev()` | |
| `(x for x in xs if p)` | `xs.iter().filter(\|&x\| p(x))` | |
| `(f(x) for x in xs)` | `xs.iter().map(\|&x\| f(x))` | |
| `sum(xs)` | `xs.iter().sum()` (type inference needed) | |
| `min(xs)` / `max(xs)` | `xs.iter().min()` / `xs.iter().max()` (returns `Option`) | |
| `any(xs)` / `all(xs)` | `xs.iter().any(\|&x\| ...)` / `.all(...)` | |
| `sorted(xs)` | `let mut v: Vec<_> = xs.collect(); v.sort();` | |
| `sorted(xs, key=...)` | `v.sort_by_key(\|x\| ...)` | |
| `itertools.chain(a, b)` | `a.chain(b)` | |
| `itertools.groupby(xs, key)` | group manually, or `itertools::group_by` | |

## 12. Common stdlib mappings

| Python module | Rust equivalent | Notes |
|---|---|---|
| `os.path.join(a, b)` | `std::path::Path::new(a).join(b)` | |
| `os.getcwd()` | `std::env::current_dir()` | |
| `os.environ["X"]` | `std::env::var("X")` | returns `Result` |
| `os.system(cmd)` | `std::process::Command::new(...).status()` | |
| `os.listdir(p)` | `std::fs::read_dir(p)` | returns iterator of `Result<DirEntry>` |
| `os.makedirs(p)` | `std::fs::create_dir_all(p)` | |
| `open(p, "r")` | `std::fs::File::open(p)` | |
| `open(p, "w")` | `std::fs::File::create(p)` | |
| `f.read()` | `fs::read_to_string(p)` or `f.read_to_end(&mut buf)` | |
| `f.write(s)` | `f.write_all(s.as_bytes())` | |
| `json.loads(s)` | `serde_json::from_str(&s)` | requires `serde_json` crate |
| `json.dumps(x)` | `serde_json::to_string(&x)` | |
| `re.match(p, s)` | `regex::Regex::new(p)?.find(s)` | requires `regex` crate |
| `math.sqrt(x)` | `x.sqrt()` | method on floats |
| `math.pi` | `std::f64::consts::PI` | |
| `random.random()` | `rand::random()` | requires `rand` crate |
| `random.randint(a, b)` | `rand::thread_rng().gen_range(a..=b)` | |
| `time.time()` | `std::time::SystemTime::now().duration_since(UNIX_EPOCH)` | |
| `time.sleep(s)` | `std::thread::sleep(Duration::from_secs_f64(s))` | |
| `datetime.datetime.now()` | `chrono::Local::now()` | requires `chrono` crate |
| `socket.socket()` | `std::net::TcpStream` / `TcpListener` | |
| `subprocess.run([...])` | `std::process::Command::new(...).output()` | |
| `argparse.ArgumentParser` | `clap` derive API | requires `clap` crate |
| `logging.getLogger(__name__)` | `log` crate facade + `env_logger` | |
| `pathlib.Path(p)` | `std::path::PathBuf::from(p)` | |
| `tempfile.NamedTemporaryFile` | `tempfile` crate | |
| `shutil.copy(a, b)` | `std::fs::copy(a, b)` | |
| `sys.argv` | `std::env::args().collect::<Vec<_>>()` | |
| `collections.defaultdict` | `HashMap::entry(k).or_insert_with(default)` | |
| `copy.deepcopy(x)` | `x.clone()` if `T: Clone` (shallow); deep needs manual or serde | |
| `pickle.loads(b)` | no built-in equivalent; use `serde` + `bincode`/`rmp-serde` | |

## 13. NumPy / common third-party mappings

| Python | Rust | Notes |
|---|---|---|
| `import numpy as np` | `use ndarray::Array2;` | requires `ndarray` crate |
| `np.array([[1,2],[3,4]])` | `Array2::from_shape_vec((2,2), vec![1,2,3,4]).unwrap()` | |
| `np.zeros((m, n))` | `Array2::zeros((m, n))` | |
| `np.dot(a, b)` | `a.dot(&b)` | |
| `np.mean(xs)` | `xs.mean()` (on ndarray) or manual `xs.iter().sum::<f64>() / xs.len() as f64` | |
| `import pandas as pd` | `use polars::prelude::*;` | requires `polars` crate |
| `import requests` | `reqwest::get(url).await?.text().await?` | requires `reqwest` (async) |
| `import flask` | `axum` / `actix-web` / `rocket` | |
| `import sqlalchemy` | `diesel` / `sqlx` / `sea-orm` | |
| `import pytest` | `#[test]` attribute + `cargo test` | built-in |
