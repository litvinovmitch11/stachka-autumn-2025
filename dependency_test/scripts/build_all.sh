#!/bin/bash

# build_all.sh - Сборка всех тестовых бинарников

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$PROJECT_ROOT/src"
BUILD_DIR="$PROJECT_ROOT/builds"

mkdir -p "$BUILD_DIR/gcc" "$BUILD_DIR/gc" "$BUILD_DIR/gccgo"

echo "Сборка тестовых бинарников..."
echo "=============================="

# Сборка C++ (GCC)
echo "C++ (GCC)..."
g++ -O3 -o "$BUILD_DIR/gcc/speed_test" "$SRC_DIR/cpp/main.cpp"

# Сборка Go (GC)
echo "Go (GC)..."
go build -o "$BUILD_DIR/gc/speed_test" "$SRC_DIR/golang/main.go"

# Сборка Go (GCCGO)
echo "Go (GCCGO)..."
gccgo -O3 -o "$BUILD_DIR/gccgo/speed_test" "$SRC_DIR/golang/main.go"

echo "Все бинарники собраны!"
