# 6. C linked list → Option<Box<Node>>

Input (C):

```c
struct Node { int data; struct Node* next; };
void push(struct List* l, int d) {
    struct Node* n = malloc(sizeof(struct Node));
    n->data = d; n->next = l->head; l->head = n;
}
```

Output (Rust) — entire emitted response:

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
