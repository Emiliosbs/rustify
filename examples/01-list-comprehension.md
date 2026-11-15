# 1. List comprehension → iterator chain

Input (Python):

```python
result = [x * 2 for x in items if x > 0]
```

Output (Rust) — entire emitted response:

```rust
let result: Vec<_> = items.iter().copied().filter(|&x| x > 0).map(|x| x * 2).collect();
```
