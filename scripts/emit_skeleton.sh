#!/usr/bin/env bash
# Scaffold a minimal Cargo binary crate so the skill does not have to emit boilerplate.
# Usage: emit_skeleton.sh <name>
set -euo pipefail

name="${1:?usage: emit_skeleton.sh <name>}"

if [ -e "$name" ]; then
  echo "error: '$name' already exists" >&2
  exit 1
fi

mkdir -p "$name/src"

cat > "$name/Cargo.toml" <<EOF
[package]
name = "$name"
version = "0.1.0"
edition = "2021"

[dependencies]
EOF

cat > "$name/src/main.rs" <<'EOF'
fn main() {
    println!("Hello, world!");
}
EOF

echo "scaffolded ./$name (Cargo.toml + src/main.rs)"
