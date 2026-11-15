# 5. C callback → closure generic

Input (C):

```c
void apply(int* xs, size_t n, int (*f)(int)) {
    for (size_t i = 0; i < n; i++) xs[i] = f(xs[i]);
}
```

Output (Rust) — entire emitted response:

```rust
fn apply<F: Fn(i32) -> i32>(xs: &mut [i32], f: F) {
    for x in xs.iter_mut() { *x = f(*x); }
}
```

Notes:
- The length parameter disappears: the slice carries it.
