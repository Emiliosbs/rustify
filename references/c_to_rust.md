# C -> Rust Mapping Tables

Reference file. Read this when the input is C.

The hard part of C -> Rust is not syntax; it is **pointer ownership inference**. The same C pointer can mean "I own this and must free it", "I'm just borrowing it read-only", "I'm borrowing it for mutation", or "I'm holding a raw hardware address". Rust makes you say which. The first section is an ownership-inference procedure (modeled on Crown / c2rust follow-up work); the rest is straightforward mapping tables.

## Table of contents
1. Pointer ownership inference procedure
2. Primitive types
3. Operators
4. Control flow
5. Functions
6. Structs, unions, enums, typedef
7. Memory management
8. Preprocessor (`#define`, `#include`, `#if`)
9. Function pointers and callbacks
10. Strings
11. I/O and stdlib
12. Concurrency
13. FFI: when to keep `unsafe`

## 1. Pointer ownership inference procedure

For every pointer in the C source, classify it before choosing the Rust type:

**Step 1: Does it own a heap object?**
A pointer *owns* if any of these hold:
- It is the result of `malloc`/`calloc`/`realloc` and is later `free`d through this same variable (or assigned into a struct field that owns it).
- It is assigned the result of a function that returns a fresh allocation ("`char* make_thing()`").
- It is stored in a struct field and that struct's destructor would free it.

If yes -> retype to `Box<T>` (single owner) or `Vec<T>` (array).
If the pointer can also be `NULL`, wrap in `Option<Box<T>>`.

**Step 2: If not owning, is it used to mutate the pointee?**
- Yes (any write `*p = ...` or `p->field = ...`) -> retype to `&mut T`.
- No (read only) -> retype to `&T`.

**Step 3: Special cases**
- Pointer stored in a struct field, *not* freed by the struct -> it is a *borrow*. Use `&'a T` with a lifetime parameter on the struct, OR if lifetimes get too complex, use `Rc<T>`/`Arc<T>` (shared ownership) or raw `*const T` (last resort, mark unsafe).
- Array pointer with runtime length -> `&[T]` (borrowed) or `Vec<T>` (owned). Pair with a length parameter; the Rust slice carries its own length so the function signature drops the length arg.
- Array pointer with compile-time length -> `[T; N]` or `&[T; N]`.
- Pointer passed as an *output parameter* (C idiom: caller passes `&result` to be filled) -> `&mut T` in Rust. Or, better, change the function to return `T` directly.
- Pointer to function -> see section 9.
- Pointer to `void` -> see below.
- Pointer that escapes to multiple threads or is shared long-term -> `Arc<T>` (immutable) or `Arc<Mutex<T>>` (mutable).
- Pointer into hardware/MMIO -> raw `*mut T` in `unsafe`, never `Box` (don't drop hardware).
- Pointer to `volatile` data -> raw `*mut T`, accessed via `ptr::read_volatile`/`write_volatile` in `unsafe`.

**Step 4: Handle `NULL` checks.**
C idiom: `if (p) { ... }` or `if (p == NULL) return;`. In Rust with `Option<Box<T>>` this becomes `if let Some(p) = &p { ... }` or `match &p { Some(p) => ..., None => ... }`.

**Step 5: Rewrite pointer dereferences.**
- `*p` for read of `&T` -> `*p` (still works) or `p.clone()` if you need an owned copy.
- `*p` for write of `&mut T` -> `*p = ...` (still works).
- `p->field` for `&T` -> `p.field`.
- `p->field` for `&mut T` -> `p.field = ...`.
- `p->field` for `Box<T>` read -> `p.field` (auto-deref).
- `p->field` for `Box<T>` write -> `p.field = ...` (auto-deref).
- `p->field` for `Option<Box<T>>` -> `p.as_ref().unwrap().field` (read) or `p.as_deref_mut().unwrap().field = ...` (write).
- `p[i]` for `T*` array -> `p[i]` works for slices `&[T]` and `&mut [T]`.
- `&p[i]` -> `&p[i]` (slice indexing returns a reference).
- `p + i` (pointer arithmetic) -> `&p[i]` (slice indexing); do not use raw pointer arithmetic on safe Rust.

**Worked example** (Crown-style, from bzip2 linked list):

C:
```c
typedef struct zzzz { Char* name; struct zzzz* link; } Cell;
Cell* aa = argList;
while (aa != NULL) {
    Cell* aa2 = aa->link;
    if (aa->name) free(aa->name);
    free(aa);
    aa = aa2;
}
```

Inference:
- `argList` -> owns; passed in but consumed here -> `argList: Option<Box<Cell>>` (owned, taken).
- `aa` -> owns (assigned from `argList`); loop var; reused each iter -> `Option<Box<Cell>>`.
- `aa->link` (`link` field) -> owns (next node) -> `Option<Box<Cell>>`.
- `aa->name` -> owns (freed explicitly) -> `*mut Char` is what c2rust would emit, but if `Char` is a string you'd model it as `Option<CString>` or `*mut libc::c_char` (raw, because we `free` it manually).
- `aa2` -> owns (assigned from `link.take()`); not freed in body but reassigned back to `aa` -> `Option<Box<Cell>>`.

Rust (idiomatic, not the c2rust output):
```rust
pub struct Cell {
    pub name: Option<std::ffi::CString>,
    pub link: Option<Box<Cell>>,
}

// frees the list
fn free_list(mut arg_list: Option<Box<Cell>>) {
    while let Some(mut cell) = arg_list {
        arg_list = cell.link.take();    // unlinks next, transfers ownership to arg_list
        // cell.name and cell itself are dropped here automatically
    }
}
```

This shows the *idiomatic* rewrite: the explicit `free` calls vanish because `Box`'s `Drop` does it. The `while let` pattern replaces the `while (aa != NULL)` idiom.

## 2. Primitive types

| C | Rust | Notes |
|---|---|---|
| `char` (as byte) | `i8` (signed) / `u8` (unsigned) | C `char` signedness is impl-defined; pick explicitly |
| `unsigned char` | `u8` | |
| `signed char` | `i8` | |
| `short` | `i16` | |
| `unsigned short` | `u16` | |
| `int` | `i32` | default |
| `unsigned int` / `unsigned` | `u32` | |
| `long` | `i64` (on 64-bit Linux) / `isize` (portable-ish) | varies by platform |
| `unsigned long` | `u64` / `usize` | |
| `long long` | `i64` | |
| `unsigned long long` | `u64` | |
| `size_t` | `usize` | |
| `ssize_t` | `isize` | |
| `ptrdiff_t` | `isize` | |
| `intptr_t` | `isize` | |
| `float` | `f32` | |
| `double` | `f64` | |
| `long double` | no direct equivalent | use `f64` or external crate |
| `_Bool` / `bool` (C99) | `bool` | |
| `void` (return) | `()` | unit type |
| `void` (param `f(void)`) | (omit params) `fn f()` | |
| `void*` | `enum` of variants / generic `T` / `Box<dyn Any>` (rare) | model the actual union |
| `NULL` | `Option::None` / `ptr::null_mut()` / `ptr::null()` | prefer `Option` |
| `EOF` | `-1i32` or `std::io::Result::Err` | |
| `FILE*` | `std::fs::File` (or `io::Read`/`io::Write` traits) | |
| `errno` | inspect the returned `io::Error` | Rust errors carry the kind |

## 3. Operators

| C | Rust | Notes |
|---|---|---|
| `a + b` | `a + b` | |
| `a - b` | `a - b` | |
| `a * b` | `a * b` | |
| `a / b` (ints) | `a / b` (panics on div by 0 in debug) | |
| `a % b` | `a % b` | |
| `a++` / `a--` | `a += 1` / `a -= 1` | no postfix inc/dec in Rust |
| `++a` / `--a` | `a += 1` / `a -= 1` (returns unit) | prefix inc/dec also gone |
| `a & b` (bitwise) | `a & b` | |
| `a \| b` (bitwise) | `a \| b` | |
| `a ^ b` | `a ^ b` | |
| `~a` | `!a` (bitwise NOT) | overloaded: `!` is bitwise on ints, logical on bools |
| `a << n` | `a << n` | |
| `a >> n` | `a >> n` | |
| `a && b` | `a && b` | |
| `a \|\| b` | `a \|\| b` | |
| `!a` (logical) | `!a` | |
| `a == b` | `a == b` | |
| `a != b` | `a != b` | |
| `a < b` etc. | identical | |
| `a = b` | `a = b` | requires `mut a` |
| `a += b` etc. | identical | |
| `a ? b : c` | `if a { b } else { c }` | |
| `sizeof(T)` | `std::mem::size_of::<T>()` | |
| `sizeof x` | `std::mem::size_of_val(&x)` | |
| `_Alignof(T)` | `std::mem::align_of::<T>()` | |
| `(T)x` (cast) | `x as T` | numeric casts; pointer casts need `as` and are unsafe for some |
| `(int*)p` (pointer cast) | `p as *mut i32` | unsafe to deref |
| `&x` | `&x` / `&mut x` | |
| `*p` | `*p` | |
| `p->field` | `p.field` (auto-deref) | |
| `a[i]` | `a[i]` | |
| `a, b` (comma operator) | `let _ = a; b` (statement) | rarely needed |

## 4. Control flow

| C | Rust | Notes |
|---|---|---|
| `if (c) { ... }` | `if c { ... }` | no parens, braces mandatory |
| `else if` | `else if` | |
| `else` | `else` | |
| `for (init; cond; step) { ... }` | `for i in init..end { ... }` or `while` + manual counter | |
| `while (c) { ... }` | `while c { ... }` | |
| `do { ... } while (c);` | `loop { ...; if !c { break; } }` | no do-while in Rust |
| `switch (x) { case A: ...; break; case B: ...; default: ...; }` | `match x { A => ..., B => ..., _ => ... }` | no fallthrough |
| `goto label;` | restructure into `?` + guards, or `loop`+`break 'label` | no real `goto` |
| labeled `goto` for nested break | `loop 'outer: { ... break 'outer v; }` | labeled loops |
| `break;` | `break;` / `break v;` (in `loop`) | |
| `continue;` | `continue;` | |
| `return x;` | `return x;` (or omit `return` for tail expression) | |
| `return;` (void) | `return;` or omit (unit tail) | |
| `assert(c)` | `assert!(c)` | panics |
| `exit(n)` | `std::process::exit(n)` | |
| `abort()` | `std::process::abort()` | |
| `atexit(f)` | no direct equivalent; use RAII / `Drop` | |

## 5. Functions

| C | Rust | Notes |
|---|---|---|
| `T f(U x) { ... }` | `fn f(x: U) -> T { ... }` | |
| `void f(U x) { ... }` | `fn f(x: U) { ... }` | |
| `T f(U x, V y)` | `fn f(x: U, y: V) -> T` | |
| `T* f(U x)` returning malloc'd | `fn f(x: U) -> Box<T>` (owning) or `Vec<T>` (array) | |
| `T f(void)` | `fn f() -> T` | |
| `void f(const T* x)` (read-only borrow) | `fn f(x: &T)` | |
| `void f(T* x)` (mutates through pointer) | `fn f(x: &mut T)` | |
| `void f(T* xs, size_t n)` (array + length) | `fn f(xs: &mut [T])` (slice carries length) | drop the `n` param |
| `T f(U x, ...)` (varargs) | no direct equivalent; use macro `macro_rules!` or slice `&[T]` | |
| `static T f(...)` (internal linkage) | `fn f(...)` (private by default in mod) | |
| `extern T f(...)` | `extern "C" fn f(...) -> T` or declare in `extern "C" { ... }` block | |
| `inline T f(...)` | `#[inline] fn f(...) -> T` | hint |
| `T f(U x) __attribute__((noreturn);` | `fn f(x: U) -> !` (never return) | diverging |
| function pointer `T (*f)(U)` | `fn(U) -> T` | function pointer type |
| callback with state `void f(void* ctx, int(*cb)(void*,int))` | `fn f<F: Fn(i32) -> i32>(cb: F)` or `fn f(cb: &dyn Fn(i32) -> i32)` | closures carry state |

## 6. Structs, unions, enums, typedef

| C | Rust | Notes |
|---|---|---|
| `struct X { int a; };` | `struct X { a: i32 }` | |
| `struct X { ... } x;` (var decl) | `let x = X { ... };` | |
| `struct X* p = malloc(sizeof(struct X));` | `let p = Box::new(X { ... });` | RAII frees |
| anonymous struct field `struct { int a; } x;` | `struct Anon { a: i32 }` (named) or tuple struct | Rust has no anon structs |
| `typedef struct X { ... } X;` | `struct X { ... }` (Rust: type name and struct name are same) | no separate typedef needed |
| `typedef struct X* XRef;` | `type XRef = Box<X>;` (if owning) or `type XRef<'a> = &'a X;` | |
| `typedef int myint;` | `type myint = i32;` | |
| `typedef struct { ... } Anon;` | `struct Anon { ... }` | give it a name |
| `union U { int i; float f; };` | `union U { i: i32, f: f32 }` (access requires `unsafe`) | OR model as `enum U { I(i32), F(f32) }` |
| `enum E { A, B, C };` | `enum E { A, B, C }` | Rust enums are real tagged unions |
| `enum E { A = 1, B = 2 };` | `#[repr(i32)] enum E { A = 1, B = 2 }` | explicit discriminant |
| enum used as bitmask `A \| B` | `bitflags!` macro or `[flags] enum` (use `bitflags` crate) | |
| bitfields `struct { int a: 3; int b: 5; };` | no native bitfield; manual getter/setter with shifts, or `bitfield` crate | |
| `struct X { char name[32]; };` (fixed array) | `struct X { name: [u8; 32] }` or `name: heapless::String<32>` | |
| `struct X { T* arr; size_t n; }` | `struct X { arr: Vec<T> }` (preferred) or `arr: Box<[T]>` | length tracked |
| flexible array member `struct X { int n; int data[]; };` | `struct X { data: Vec<i32> }` | dynamic, idiomatic |
| `struct X { void* ctx; };` (opaque) | `struct X { ctx: Box<dyn std::any::Any> }` or generic `struct X<T> { ctx: T }` | |

For FFI compatibility with C code that still uses your struct, add `#[repr(C)]` to preserve layout:

```rust
#[repr(C)]
pub struct X { pub a: i32 }
```

## 7. Memory management

| C | Rust | Notes |
|---|---|---|
| `malloc(n)` | `Box::new(T::default())` or `Vec::with_capacity(n)` | type-safe |
| `calloc(n, sz)` | `vec![0u8; n * sz]` or `vec![T::default(); n]` | zeroed |
| `realloc(p, n)` | `Vec::resize(n, T::default())` | |
| `free(p)` | (automatic, when owner goes out of scope) | |
| `memset(p, 0, n)` | `let buf = vec![0u8; n];` or `slice.fill(0)` | |
| `memcpy(dst, src, n)` | `dst[..n].copy_from_slice(&src[..n])` | bounds-checked |
| `memmove(dst, src, n)` | same; slices handle overlap if both are `&mut` carefully | |
| `memcmp(a, b, n)` | `a[..n] == b[..n]` | |
| `alloca(n)` | no equivalent; use stack array `[T; N]` (compile-time N) | |
| `strdup(s)` | `String::from(s)` or `s.to_string()` | |
| `strndup(s, n)` | `String::from_utf8_lossy(&s.as_bytes()[..n]).into_owned()` | |
| `aligned_alloc(align, sz)` | `Box::new_uninit` or `Vec::with_capacity` (alignment from type) | |

When you must keep raw `malloc` semantics (FFI), wrap the *minimum* scope in `unsafe` and add a `// SAFETY:` comment.

## 8. Preprocessor

| C preprocessor | Rust | Notes |
|---|---|---|
| `#include <stdio.h>` | (no equivalent for std) | std is implicit |
| `#include "foo.h"` | `mod foo;` (separate file) or `use crate::foo;` | |
| `#define X 5` (constant) | `const X: i32 = 5;` | |
| `#define X (1 + 2)` | `const X: i32 = 1 + 2;` (compile-time const eval) | |
| `#define MAX(a, b) ((a) > (b) ? (a) : (b))` | `std::cmp::max(a, b)` (function, no double-eval) | |
| `#define MIN(a, b)` | `std::cmp::min(a, b)` | |
| `#define ABS(a)` | `a.abs()` | |
| `#define SQ(x) ((x)*(x))` | inline fn `fn sq(x: T) -> T { x * x }` (no double-eval) | |
| `#define ASSERT(c, msg)` | `assert!(c, msg)` | |
| `#define DEBUG_PRINT(...)` printf(...) | `macro_rules! debug_print { ... }` | |
| token-paste `a ## b` | `paste::paste!` macro or manual | external crate |
| stringify `#x` | `stringify!(x)` | built-in |
| `#if defined(X)` | `#[cfg(X)]` | |
| `#ifdef X` | `#[cfg(X)]` | |
| `#ifndef X` | `#[cfg(not(X))]` | |
| `#if X > 5` | `#[cfg(all(X, target_X_gt_5))]` (rare) or runtime check | |
| `#elif` | no direct; use multiple `#[cfg(...)]` | |
| `#else` | `#[cfg(not(...))]` paired with `#[cfg(...)]` | |
| `#endif` | (implicit end of attribute) | |
| `#pragma once` | (implicit; one `mod` per file) | |
| `#pragma pack(push, 1)` | `#[repr(packed)]` | |
| `#pragma pack(pop)` | (remove attribute) | |
| `__FILE__` / `__LINE__` | `file!()` / `line!()` | built-in macros |
| `__FUNCTION__` | no direct equivalent | use `std::any::type_name` |
| `#error "msg"` | `compile_error!("msg");` | |
| `#undef X` | no direct equivalent (cfg is static) | |

## 9. Function pointers and callbacks

| C | Rust | Notes |
|---|---|---|
| `int (*f)(int)` | `fn(i32) -> i32` | non-capturing function pointer |
| `void qsort(...)` taking `int (*cmp)(const void*, const void*)` | `slice::sort_by(\|a, b\| ...)` | closures preferred |
| callback with user data `void f(void* ctx, void(*cb)(void*))` | `fn f<F: FnOnce()>(cb: F)` | closure captures context |
| `signal(SIGINT, handler)` where `handler` is `void(int)` | `signal_hook` crate (different API) | or roll your own with `extern "C"` |
| vtable struct of function pointers | `dyn Trait` (object-safe trait) or `enum` dispatch | prefer trait objects for safety |
| function pointer stored in struct field | `Box<dyn Fn() -> T>` (heap) or `fn() -> T` (pointer) | |
| `setjmp/longjmp` for error exits | restructure into `Result<T, E>` + `?` | do not use `setjmp` in Rust |

## 10. Strings

| C | Rust | Notes |
|---|---|---|
| `"hello"` (string literal) | `"hello"` (type `&'static str`) | |
| `"hello\n"` (with escape) | `"hello\n"` (same) | |
| `char* s` (read-only) | `&str` (borrowed) or `&CStr` (C-style, null-terminated) | |
| `char* s` (built at runtime) | `String` | |
| `const char* s` | `&str` / `&'static str` / `&CStr` | |
| `char s[]` array | `[u8; N]` / `&[u8]` | bytes, not UTF-8 |
| `char* s = "..."` then mutated | `String` (mutation OK) or `Vec<u8>` | |
| `strlen(s)` | `s.len()` (bytes) | |
| `strcpy(dst, src)` | `let dst = src.to_string();` (just clone) | |
| `strncpy(dst, src, n)` | `let dst = String::from_utf8_lossy(&src.as_bytes()[..n]).into_owned();` | |
| `strcat(dst, src)` | `dst.push_str(&src);` | |
| `strcmp(a, b)` | `a.cmp(&b)` (Ordering) or `a == b` | |
| `strncmp(a, b, n)` | `a[..n].cmp(&b[..n])` | |
| `strchr(s, c)` | `s.find(c)` (returns `Option<usize>`) | |
| `strstr(s, sub)` | `s.find(sub)` | |
| `strtok(s, delim)` | `s.split(...)` (iterator) | not thread-unsafe like strtok |
| `sprintf(buf, "%d", x)` | `format!("{}", x)` returns `String` | |
| `snprintf(buf, n, ...)` | `format!` then truncate, or use `itoa` crate for raw write | |
| `sscanf(s, "%d", &x)` | `s.parse::<i32>()` returns `Result` | |
| `printf("%s=%d\n", k, v)` | `println!("{}={}", k, v)` | |
| `fprintf(stderr, ...)` | `eprintln!(...)` | |
| `puts(s)` | `println!("{}", s)` | |
| `atoi(s)` | `s.parse::<i32>().unwrap_or(0)` | |
| `atof(s)` | `s.parse::<f64>().unwrap_or(0.0)` | |

If you need C ABI (null-terminated), use `std::ffi::CString` (owned) and `std::ffi::CStr` (borrowed). Convert via `CString::new(s)?` and `cstr.to_str()?`.

## 11. I/O and stdlib

| C | Rust | Notes |
|---|---|---|
| `printf(...)` | `println!(...)` / `print!(...)` | |
| `fopen(p, "r")` | `File::open(p)` | returns `io::Result` |
| `fopen(p, "w")` | `File::create(p)` | |
| `fopen(p, "a")` | `OpenOptions::new().append(true).open(p)` | |
| `fclose(f)` | (automatic on `Drop`) | |
| `fread(buf, sz, n, f)` | `f.read_exact(&mut buf)` | |
| `fwrite(buf, sz, n, f)` | `f.write_all(&buf)` | |
| `fgets(buf, n, f)` | `io::BufRead::read_line` | |
| `fgetc(f)` | `io::Read::read` on single byte | |
| `fputc(c, f)` | `io::Write::write_all(&[c])` | |
| `feof(f)` | check `Result` of read (returns 0 bytes at EOF) | |
| `ferror(f)` | inspect `io::Error` | |
| `fflush(f)` | `f.flush()` | |
| `fseek(f, off, SEEK_SET)` | `f.seek(SeekFrom::Start(off))` | |
| `ftell(f)` | `f.stream_position()` | |
| `remove(p)` | `std::fs::remove_file(p)` | |
| `rename(a, b)` | `std::fs::rename(a, b)` | |
| `perror(s)` | `eprintln!("{}: {}", s, err)` | |
| `qsort(arr, n, sz, cmp)` | `slice::sort_by(\|a, b\| ...)` | |
| `bsearch(key, arr, n, sz, cmp)` | `slice::binary_search_by(\|x\| ...)` | |
| `abs(x)` / `labs(x)` / `llabs(x)` | `x.abs()` | |
| `rand()` | `rand::thread_rng().gen()` (external crate) | |
| `srand(seed)` | `rand::thread_rng()` (auto-seeded) or explicit `StdRng::seed_from_u64` | |
| `time(NULL)` | `SystemTime::now().duration_since(UNIX_EPOCH)` | |
| `clock()` | `Instant::now()` elapsed | |
| `sleep(seconds)` | `thread::sleep(Duration::from_secs(seconds))` | |
| `getenv("X")` | `env::var("X")` (returns `Result`) | |
| `system(cmd)` | `Command::new("sh").arg("-c").arg(cmd).status()` | |
| `exit(n)` | `process::exit(n)` | |
| `malloc.h` / `stdlib.h` | implicit | |

## 12. Concurrency

| C | Rust | Notes |
|---|---|---|
| `pthread_create(...)` | `thread::spawn(\|\| ...)` | |
| `pthread_join(t)` | `JoinHandle::join()` | |
| `pthread_mutex_t` | `std::sync::Mutex` | |
| `pthread_mutex_lock(m)` | `m.lock().unwrap()` | |
| `pthread_mutex_unlock(m)` | (automatic when guard drops) | |
| `pthread_cond_t` | `std::sync::Condvar` | |
| `pthread_rwlock_t` | `std::sync::RwLock` | |
| `pthread_once` | `std::sync::Once` / `LazyLock` | |
| `_Atomic int` / `atomic_int` | `std::sync::atomic::AtomicI32` | |
| `atomic_load(p)` | `a.load(Ordering::SeqCst)` | |
| `atomic_store(p, v)` | `a.store(v, Ordering::SeqCst)` | |
| `atomic_compare_exchange_strong(...)` | `a.compare_exchange(...)` | |
| `volatile` | `ptr::read_volatile` / `ptr::write_volatile` (in `unsafe`) | |
| `thread_local` (C11) | `thread_local!` macro | |
| `sem_t` / `sem_post` / `sem_wait` | `std::sync::Semaphore` (deprecated) or `tokio::sync::Semaphore` | |
| thread barrier `pthread_barrier_t` | `std::sync::Barrier` | |

## 13. FFI: when to keep `unsafe`

Keep `unsafe` and raw pointers when:

- You are binding to an existing C library (`extern "C"` block, raw `*mut T` for opaque pointers).
- You need a stable ABI (`#[repr(C)]` structs passed across the FFI boundary).
- You access memory-mapped hardware / volatile registers.
- You implement a low-level primitive the standard library does not expose (e.g. a custom allocator, a lock-free data structure).
- You cast between unrelated pointer types (`*mut A as *mut B`).

In all other cases, the goal of this skill is to produce *safe* Rust. If a translation requires `unsafe` for non-FFI reasons, add a one-line `// SAFETY:` comment explaining the invariant the unsafe block relies on.

Example FFI binding for a C function `int do_thing(const char* path);`:

```rust
extern "C" {
    fn do_thing(path: *const std::os::raw::c_char) -> std::os::raw::c_int;
}

fn safe_do_thing(path: &str) -> std::io::Result<()> {
    let c_path = std::ffi::CString::new(path)
        .map_err(|_| std::io::Error::new(std::io::ErrorKind::InvalidInput, "nul in path"))?;
    // SAFETY: do_thing reads path as a null-terminated string and does not retain it.
    let rc = unsafe { do_thing(c_path.as_ptr()) };
    if rc == 0 { Ok(()) } else { Err(std::io::Error::from_raw_os_error(rc)) }
}
```

The pattern is always: build a safe Rust wrapper around the minimal `unsafe` FFI call, validate inputs at the boundary, return a `Result` to the caller.
