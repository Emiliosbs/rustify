# 2. C malloc/free → Box

Input (C):

```c
Node* n = malloc(sizeof(Node));
n->val = 1;
...
free(n);
```

Output (Rust) — entire emitted response:

```rust
let mut n = Box::new(Node { val: 1 });
// dropped automatically at end of scope
```
