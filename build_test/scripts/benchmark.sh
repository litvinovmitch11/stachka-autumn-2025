#!/bin/bash

# build_speed.sh - Анализ скорости сборки компиляторов

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$PROJECT_ROOT/src"
BUILD_DIR="$PROJECT_ROOT/builds"
LOG_DIR="$PROJECT_ROOT/logs"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
JSON_LOG="$LOG_DIR/build_speed_$TIMESTAMP.json"

mkdir -p "$BUILD_DIR/gcc" "$BUILD_DIR/gc" "$BUILD_DIR/gccgo" "$LOG_DIR"

echo "Анализ скорости сборки компиляторов"
echo "==================================="

# Функция для замера времени сборки (многократный запуск)
measure_build_time() {
    local name=$1
    local build_cmd=$2
    local output_file=$3
    
    echo "Тестирование $name (10 запусков)..." >&2
    
    local total_real=0
    local total_user=0
    local total_sys=0
    local iterations=10
    
    for ((i=1; i<=iterations; i++)); do
        # Очищаем предыдущую сборку
        rm -f "$output_file"
        
        # Замеряем время выполнения
        local time_output
        time_output=$( { time eval "$build_cmd" 2>&1 > /dev/null; } 2>&1 )
        
        # Парсим время и конвертируем в секунды
        local real_time=$(echo "$time_output" | grep real | awk '{print $2}')
        local real_seconds=$(echo "$real_time" | awk -F'm' '{print $1 * 60 + $2}' | sed 's/s//')
        local user_seconds=$(echo "$time_output" | grep user | awk '{print $2}' | awk -F'm' '{print $1 * 60 + $2}' | sed 's/s//')
        local sys_seconds=$(echo "$time_output" | grep sys | awk '{print $2}' | awk -F'm' '{print $1 * 60 + $2}' | sed 's/s//')
        
        total_real=$(echo "$total_real + $real_seconds" | bc -l)
        total_user=$(echo "$total_user + $user_seconds" | bc -l)
        total_sys=$(echo "$total_sys + $sys_seconds" | bc -l)
    done
    
    # Вычисляем среднее время
    local avg_real=$(echo "scale=3; $total_real / $iterations" | bc -l)
    local avg_user=$(echo "scale=3; $total_user / $iterations" | bc -l)
    local avg_sys=$(echo "scale=3; $total_sys / $iterations" | bc -l)
    
    # Получаем размер бинарника
    local size=0
    if [[ -f "$output_file" ]]; then
        size=$(stat -c%s "$output_file")
    fi
    
    # Форматируем время для вывода
    local real_str=$(printf "%.3fs" $avg_real)
    local user_str=$(printf "%.3fs" $avg_user)
    local sys_str=$(printf "%.3fs" $avg_sys)
    
    cat << EOF
    {
        "compiler": "$name",
        "real_time": "$real_str",
        "user_time": "$user_str", 
        "sys_time": "$sys_str",
        "iterations": $iterations,
        "output_size": $size
    }
EOF
}

# Создаем JSON лог
echo "{" > "$JSON_LOG"
echo '  "system_info": {' >> "$JSON_LOG"
echo "    \"timestamp\": \"$TIMESTAMP\"," >> "$JSON_LOG"
echo "    \"hostname\": \"$(hostname)\"," >> "$JSON_LOG"
echo "    \"cpu\": \"$(grep -m 1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^[[:space:]]*//')\"," >> "$JSON_LOG"
echo "    \"os\": \"$(uname -s)\"," >> "$JSON_LOG"
echo "    \"kernel\": \"$(uname -r)\"" >> "$JSON_LOG"
echo "  }," >> "$JSON_LOG"
echo '  "build_times": [' >> "$JSON_LOG"

# Замер времени для каждого компилятора
echo "C++ (GCC)..." >&2
result1=$(measure_build_time "C++ (GCC)" "g++ -O3 -o $BUILD_DIR/gcc/speed_test $SRC_DIR/cpp/main.cpp" "$BUILD_DIR/gcc/speed_test")
echo "$result1" >> "$JSON_LOG"

echo "," >> "$JSON_LOG"

echo "Go (GC)..." >&2
result2=$(measure_build_time "Go (GC)" "go build -o $BUILD_DIR/gc/speed_test $SRC_DIR/golang/main.go" "$BUILD_DIR/gc/speed_test")
echo "$result2" >> "$JSON_LOG"

echo "," >> "$JSON_LOG"

echo "Go (GCCGO)..." >&2
result3=$(measure_build_time "Go (GCCGO)" "gccgo -O3 -o $BUILD_DIR/gccgo/speed_test $SRC_DIR/golang/main.go" "$BUILD_DIR/gccgo/speed_test")
echo "$result3" >> "$JSON_LOG"

echo "  ]" >> "$JSON_LOG"
echo "}" >> "$JSON_LOG"

echo ""
echo "Результаты скорости сборки:"
echo "==========================="

echo "Среднее время сборки (10 запусков):"
jq -r '.build_times[] | "\(.compiler): \(.real_time) (user: \(.user_time), sys: \(.sys_time))"' "$JSON_LOG"

echo ""
echo "Размеры бинарников:"
jq -r '.build_times[] | "\(.compiler): \(.output_size / 1024 | floor) KB"' "$JSON_LOG"

echo ""
echo "Сравнение:"
jq -r '.build_times | sort_by(.real_time | sub("s"; "") | tonumber) | .[] | "\(.compiler): \(.real_time)"' "$JSON_LOG" | head -1 | sed 's/^/Самый быстрый: /'
jq -r '.build_times | sort_by(.output_size) | .[] | "\(.compiler): \(.output_size / 1024 | floor) KB"' "$JSON_LOG" | head -1 | sed 's/^/Самый маленький: /'

echo ""
echo "Лог сохранен: $JSON_LOG"
