#!/bin/bash

# benchmark_simple.sh - Скрипт с JSON логами для машинной обработки

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$PROJECT_ROOT/src"
BUILD_DIR="$PROJECT_ROOT/builds"
LOG_DIR="$PROJECT_ROOT/logs"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
JSON_LOG="$LOG_DIR/$TIMESTAMP.json"

# Функция для извлечения значения по шаблону
extract_value() {
    local content="$1"
    local pattern="$2"
    echo "$content" | grep -oE "$pattern" | head -1
}

run_benchmark() {
    local name=$1
    local binary=$2
    
    echo "Запуск $name..." >&2
    
    # Запускаем программу и сохраняем вывод
    local program_output
    program_output=$("$binary" 2>&1)
    
    # Замеряем время выполнения
    local time_output
    time_output=$(/usr/bin/time -v "$binary" 2>&1 >/dev/null)
    
    # Парсим результаты программы
    local result=$(extract_value "$program_output" "Result: [0-9]+")
    result=$(extract_value "$result" "[0-9]+")
    
    local exec_time=$(extract_value "$program_output" "Time: [^[:space:]]+")
    exec_time=${exec_time#Time: }
    
    # Парсим системные метрики
    local user_time=$(extract_value "$time_output" "User time \\(seconds\\): [0-9.]+")
    user_time=${user_time#User time (seconds): }
    
    local system_time=$(extract_value "$time_output" "System time \\(seconds\\): [0-9.]+") 
    system_time=${system_time#System time (seconds): }
    
    local max_rss=$(extract_value "$time_output" "Maximum resident set size \\(kbytes\\): [0-9]+")
    max_rss=${max_rss#Maximum resident set size (kbytes): }
    
    local exit_status=$(extract_value "$time_output" "Exit status: [0-9]+")
    exit_status=${exit_status#Exit status: }
    
    # Конвертируем время в секунды
    local exec_time_seconds=0
    if [[ "$exec_time" == *"ms" ]]; then
        exec_time_seconds=$(echo "$exec_time" | sed 's/ms//' | awk '{print $1/1000}')
    elif [[ "$exec_time" == *"µs" ]]; then
        exec_time_seconds=$(echo "$exec_time" | sed 's/µs//' | awk '{print $1/1000000}')
    elif [[ "$exec_time" == *"ns" ]]; then
        exec_time_seconds=$(echo "$exec_time" | sed 's/ns//' | awk '{print $1/1000000000}')
    else
        exec_time_seconds=$(echo "$exec_time" | sed 's/s//')
    fi
    
    # Значения по умолчанию
    result=${result:-"0"}
    exec_time=${exec_time:-"0s"}
    user_time=${user_time:-"0"}
    system_time=${system_time:-"0"}
    max_rss=${max_rss:-"0"}
    exit_status=${exit_status:-"0"}
    exec_time_seconds=${exec_time_seconds:-"0"}
    
    cat << EOF
    {
        "name": "$name",
        "binary": "$binary",
        "result": "$result",
        "execution_time": "$exec_time",
        "execution_time_seconds": $exec_time_seconds,
        "user_time": $user_time,
        "system_time": $system_time,
        "max_rss_kb": $max_rss,
        "exit_status": $exit_status
    }
EOF
}

# Сборка
echo "Сборка проектов..."
g++ -O3 -o "$BUILD_DIR/gcc/fib_cpp" "$SRC_DIR/cpp/main.cpp"
go build -o "$BUILD_DIR/gc/fib_gc" "$SRC_DIR/golang/main.go"
gccgo -O3 -o "$BUILD_DIR/gccgo/fib_gccgo" "$SRC_DIR/golang/main.go"

# Генерация JSON
echo "{" > "$JSON_LOG"
echo '  "system_info": {' >> "$JSON_LOG"
echo "    \"timestamp\": \"$TIMESTAMP\"," >> "$JSON_LOG"
echo "    \"hostname\": \"$(hostname)\"," >> "$JSON_LOG"
echo "    \"cpu\": \"$(grep -m 1 "model name" /proc/cpuinfo | cut -d: -f2 | sed 's/^[ \t]*//')\"," >> "$JSON_LOG"
echo "    \"memory\": \"$(free -h | grep Mem: | awk '{print $2}')\"," >> "$JSON_LOG"
echo "    \"os\": \"$(uname -s)\"," >> "$JSON_LOG"
echo "    \"kernel\": \"$(uname -r)\"" >> "$JSON_LOG"
echo "  }," >> "$JSON_LOG"
echo '  "benchmarks": [' >> "$JSON_LOG"

builds=("gcc:C++ (GCC):fib_cpp" "gc:Go (GC):fib_gc" "gccgo:Go (GCCGO):fib_gccgo")

for ((i=0; i<${#builds[@]}; i++)); do
    IFS=':' read -r dir name binary <<< "${builds[i]}"
    run_benchmark "$name" "$BUILD_DIR/$dir/$binary" >> "$JSON_LOG"
    [ $i -lt $((${#builds[@]} - 1)) ] && echo "," >> "$JSON_LOG"
done

echo "  ]" >> "$JSON_LOG"
echo "}" >> "$JSON_LOG"

# Результаты
echo ""
echo "Результаты:"
if command -v jq >/dev/null; then
    jq -r '.benchmarks[] | "\(.name): \(.execution_time) (\(.execution_time_seconds * 1000 | floor)ms)"' "$JSON_LOG"
else
    grep -A 10 -B 2 '"name"' "$JSON_LOG" | sed 's/^[[:space:]]*//'
fi

echo ""
echo "Лог сохранен:"
echo $JSON_LOG
