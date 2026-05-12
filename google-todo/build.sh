#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
echo "Building Google Todo Sync Rust backend in $DIR..."
cd "$DIR/backend"
cargo build --release
cp target/release/google-todo-sync "$DIR/google-todo-sync"
echo "Built successfully."
