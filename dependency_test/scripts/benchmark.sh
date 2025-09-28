#!/bin/bash

# dependency_analysis.sh - Анализ зависимостей и линковки бинарников

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/builds"
LOG_DIR="$PROJECT_ROOT/logs"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
JSON_LOG="$LOG_DIR/dependency_analysis_$TIMESTAMP.json"

mkdir -p "$LOG_DIR"

echo "Анализ зависимостей и линковки бинарников"
echo "=========================================="


# Создаем JSON лог
echo "{" > "$JSON_LOG"
echo '  "system_info": {' >> "$JSON_LOG"
echo "    \"timestamp\": \"$TIMESTAMP\"," >> "$JSON_LOG"
echo "    \"hostname\": \"$(hostname)\"," >> "$JSON_LOG"
echo "    \"os\": \"$(uname -s)\"," >> "$JSON_LOG"
echo "    \"kernel\": \"$(uname -r)\"" >> "$JSON_LOG"
echo "  }," >> "$JSON_LOG"
echo '  "binaries": [' >> "$JSON_LOG"

# Функция анализа бинарника
analyze_binary() {
    local binary_path=$1
    local binary_name=$(basename "$binary_path")
    local compiler_dir=$(basename "$(dirname "$binary_path")")
    
    echo "Анализ $binary_name ($compiler_dir)..." >&2
    
    local size_bytes=$(stat -c%s "$binary_path" 2>/dev/null || echo "0")
    local size_kb=$((size_bytes / 1024))
    
    # Анализ типа файла
    local file_type=$(file "$binary_path" 2>/dev/null | cut -d: -f2- | sed 's/^ *//' || echo "Неизвестно")
    
    # Анализ динамических библиотек
    local dynamic_libs_count=0
    local linking_type="static"
    
    if ldd "$binary_path" &>/dev/null; then
        dynamic_libs_count=$(ldd "$binary_path" 2>/dev/null | grep "=>" | wc -l || echo "0")
        if [[ $dynamic_libs_count -gt 0 ]]; then
            linking_type="dynamic"
        else
            linking_type="static"
        fi
    fi
    
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
    
    cat << EOF
    {
        "name": "$binary_name",
        "compiler": "$compiler_dir",
        "path": "$binary_path",
        "size_bytes": $size_bytes,
        "size_kb": $size_kb,
        "file_type": "$file_type",
        "linking_type": "$linking_type",
        "dynamic_libs_count": $dynamic_libs_count,
        "sections": {
            "text": $text_size,
            "data": $data_size,
            "bss": $bss_size
        }
    }
EOF
}

# Анализируем все бинарники
binaries=(
    "$BUILD_DIR/gcc/speed_test"
    "$BUILD_DIR/gc/speed_test" 
    "$BUILD_DIR/gccgo/speed_test"
)

first=true
for binary in "${binaries[@]}"; do
    if [[ -f "$binary" ]] && [[ -x "$binary" ]]; then
        if [[ "$first" != true ]]; then
            echo "," >> "$JSON_LOG"
        fi
        first=false
        
        analyze_binary "$binary" >> "$JSON_LOG"
    fi
done

echo "  ]," >> "$JSON_LOG"

# Сводный анализ
echo '  "summary": {' >> "$JSON_LOG"
count=$(find "$BUILD_DIR" -name "speed_test" -type f -executable | wc -l)
echo "    \"total_binaries_analyzed\": $count," >> "$JSON_LOG"
echo '    "analysis_note": "Сравнение статической и динамической линковки в разных компиляторах"' >> "$JSON_LOG"
echo "  }" >> "$JSON_LOG"
echo "}" >> "$JSON_LOG"

echo ""
echo "Результаты анализа зависимостей:"
echo "================================"

if command -v jq >/dev/null 2>&1; then
    echo "Информация о бинарниках:"
    jq -r '.binaries[] | "\(.name) (\(.compiler)): \(.size_kb) KB, линковка: \(.linking_type), библиотек: \(.dynamic_libs_count)"' "$JSON_LOG"
    
    echo ""
    echo "Статистика по линковке:"
    static_count=$(jq '[.binaries[] | select(.linking_type == "static")] | length' "$JSON_LOG")
    dynamic_count=$(jq '[.binaries[] | select(.linking_type == "dynamic")] | length' "$JSON_LOG")
    echo "Статически слинковано: $static_count"
    echo "Динамически слинковано: $dynamic_count"
    
    echo ""
    echo "Сравнение размеров:"
    jq -r '.binaries[] | "\(.compiler)/\(.name): \(.size_kb) KB"' "$JSON_LOG" | sort -k2 -n
else
    echo "Для красивого вывода установите jq: sudo apt install jq"
    echo "Сырой JSON сохранен в: $JSON_LOG"
fi

echo ""
echo "Лог сохранен: $JSON_LOG"
