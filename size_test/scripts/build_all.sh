#!/bin/bash

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$PROJECT_ROOT/src"
BUILD_DIR="$PROJECT_ROOT/builds"

mkdir -p "$BUILD_DIR/gc" "$BUILD_DIR/gccgo" "$BUILD_DIR/gcc"

echo "Сборка всех бинарников..."

# C++ сборки
echo "Сборка C++..."
g++ -O0 -o "$BUILD_DIR/gcc/simple_cpp" "$SRC_DIR/cpp/simple.cpp"
g++ -O3 -o "$BUILD_DIR/gcc/simple_cpp_O3" "$SRC_DIR/cpp/simple.cpp"
g++ -O0 -o "$BUILD_DIR/gcc/complex_cpp" "$SRC_DIR/cpp/complex.cpp" 
g++ -O3 -o "$BUILD_DIR/gcc/complex_cpp_O3" "$SRC_DIR/cpp/complex.cpp"

# Go сборки (gc)
echo "Сборка Go (gc)..."
go build -ldflags="-s -w" -o "$BUILD_DIR/gc/simple_go" "$SRC_DIR/golang/simple/simple.go"
go build -o "$BUILD_DIR/gc/simple_go_default" "$SRC_DIR/golang/simple/simple.go"
go build -ldflags="-s -w" -o "$BUILD_DIR/gc/complex_go" "$SRC_DIR/golang/complex/complex.go"
go build -o "$BUILD_DIR/gc/complex_go_default" "$SRC_DIR/golang/complex/complex.go"

# Go сборки (gccgo)
echo "Сборка Go (gccgo)..."
gccgo -O0 -o "$BUILD_DIR/gccgo/simple_gccgo" "$SRC_DIR/golang/simple/simple.go"
gccgo -O3 -o "$BUILD_DIR/gccgo/simple_gccgo_O3" "$SRC_DIR/golang/simple/simple.go"
gccgo -O0 -o "$BUILD_DIR/gccgo/complex_gccgo" "$SRC_DIR/golang/complex/complex.go"
gccgo -O3 -o "$BUILD_DIR/gccgo/complex_gccgo_O3" "$SRC_DIR/golang/complex/complex.go"

echo "Сборка завершена!"
