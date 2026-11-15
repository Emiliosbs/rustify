# 3. Python class → struct + impl

Input (Python):

```python
class Counter:
    def __init__(self):
        self.count = 0
    def inc(self):
        self.count += 1
        return self.count
```

Output (Rust) — entire emitted response:

```rust
struct Counter { count: u32 }

impl Counter {
    fn new() -> Self { Self { count: 0 } }
    fn inc(&mut self) -> u32 { self.count += 1; self.count }
}
```
