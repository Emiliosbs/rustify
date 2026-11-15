# 4. Exception → Result + thiserror

Input (Python):

```python
class NotFoundError(Exception): pass
def find_user(uid):
    if uid not in users: raise NotFoundError(uid)
    return users[uid]
```

Output (Rust) — entire emitted response:

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

Notes:
- Custom exception hierarchy → typed `enum` + `thiserror`; exceptions appear in the signature as `Result<T, E>`.
