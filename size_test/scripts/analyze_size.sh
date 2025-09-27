#!/bin/bash

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/builds"
LOG_DIR="$PROJECT_ROOT/logs"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
REPORT_FILE="$LOG_DIR/size_analysis_$TIMESTAMP.json"

mkdir -p "$LOG_DIR"

echo "Анализ размера бинарников..."

# Функция анализа бинарника
analyze_binary() {
    local binary_path=$1
    local binary_name=$(basename "$binary_path")
    local compiler=$2
    local optimization=$3
    local language=$4
    local complexity=$5
    
    if [[ ! -f "$binary_path" ]]; then
        echo "Файл не найден: $binary_path"
        return 1
    fi
    
    local size_bytes=$(stat -c%s "$binary_path")
    local size_kb=$((size_bytes / 1024))
    local size_mb=$((size_bytes / 1024 / 1024))
    
    # Анализ секций
    local text_size=0
    local data_size=0
    local bss_size=0
    
    if command -v size >/dev/null 2>&1; then
        local size_output=$(size "$binary_path" 2>/dev/null | tail -1)
        text_size=$(echo $size_output | awk '{print $1}')
        data_size=$(echo $size_output | awk '{print $2}')
        bss_size=$(echo $size_output | awk '{print $3}')
    fi
    
    # Анализ динамических библиотек - исправленная версия
    local dynamic_libs_count=0
    if command -v ldd >/dev/null 2>&1 && file "$binary_path" | grep -q "dynamic"; then
        dynamic_libs_count=$(ldd "$binary_path" 2>/dev/null | grep "=>" | wc -l)
    fi
    
    # Анализ символов
    local symbol_count=0
    if command -v nm >/dev/null 2>&1; then
        symbol_count=$(nm "$binary_path" 2>/dev/null | wc -l 2>/dev/null || echo "0")
    fi
    
    cat << EOF
    {
        "name": "$binary_name",
        "path": "$binary_path",
        "compiler": "$compiler",
        "optimization": "$optimization",
        "language": "$language",
        "complexity": "$complexity",
        "size_bytes": $size_bytes,
        "size_kb": $size_kb,
        "size_mb": $size_mb,
        "sections": {
            "text": $text_size,
            "data": $data_size,
            "bss": $bss_size
        },
        "dynamic_libs_count": $dynamic_libs_count,
        "symbol_count": $symbol_count
    }
EOF
}

# Генерация JSON отчета
echo "[" > "$REPORT_FILE"

first=true
for binary in \
    "$BUILD_DIR/gcc/simple_cpp:gcc:O0:C++:simple" \
    "$BUILD_DIR/gcc/simple_cpp_O3:gcc:O3:C++:simple" \
    "$BUILD_DIR/gcc/complex_cpp:gcc:O0:C++:complex" \
    "$BUILD_DIR/gcc/complex_cpp_O3:gcc:O3:C++:complex" \
    "$BUILD_DIR/gc/simple_go:gc:strip:Go:simple" \
    "$BUILD_DIR/gc/simple_go_default:gc:default:Go:simple" \
    "$BUILD_DIR/gc/complex_go:gc:strip:Go:complex" \
    "$BUILD_DIR/gc/complex_go_default:gc:default:Go:complex" \
    "$BUILD_DIR/gccgo/simple_gccgo:gccgo:O0:Go:simple" \
    "$BUILD_DIR/gccgo/simple_gccgo_O3:gccgo:O3:Go:simple" \
    "$BUILD_DIR/gccgo/complex_gccgo:gccgo:O0:Go:complex" \
    "$BUILD_DIR/gccgo/complex_gccgo_O3:gccgo:O3:Go:complex"
do
    IFS=':' read -r path compiler optimization language complexity <<< "$binary"
    
    if [[ "$first" != true ]]; then
        echo "," >> "$REPORT_FILE"
    fi
    first=false
    
    analyze_binary "$path" "$compiler" "$optimization" "$language" "$complexity" >> "$REPORT_FILE"
done

echo "]" >> "$REPORT_FILE"

echo "Анализ завершен! Отчет: $REPORT_FILE"
