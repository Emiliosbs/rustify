# Examples

Before/after pairs produced by the DME pipeline. The entire "Output" of each conversion is exactly what the skill emits — code only, no preamble, no per-line commentary.

| # | Example | Lesson |
|---|---|---|
| 1 | [List comprehension → iterator chain](01-list-comprehension.md) | one-liner beats 6-line loop |
| 2 | [C malloc/free → Box](02-malloc-to-box.md) | RAII replaces free |
| 3 | [Python class → struct + impl](03-class-to-struct.md) | data and behavior split |
| 4 | [Exception → Result + thiserror](04-exception-to-result.md) | errors in the signature |
| 5 | [C callback → closure generic](05-callback-to-closure.md) | closures carry state |
| 6 | [C linked list → Option<Box<Node>>](06-linked-list.md) | Option + Box model pointers |
