#!/bin/bash
set -e

echo "Building Google Todo Sync Rust backend..."
cd backend
cargo build --release
cp target/release/google-todo-sync ../google-todo-sync
echo "Built successfully."
