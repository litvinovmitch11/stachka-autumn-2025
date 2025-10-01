#!/bin/bash

# escape_analysis.sh - Анализ escape analysis в Go

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$PROJECT_ROOT/src"
BUILD_DIR="$PROJECT_ROOT/builds"
LOG_DIR="$PROJECT_ROOT/logs"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
JSON_LOG="$LOG_DIR/escape_analysis_$TIMESTAMP.json"

mkdir -p "$BUILD_DIR" "$LOG_DIR"

# Создаем JSON лог
echo "{" > "$JSON_LOG"
echo '  "system_info": {' >> "$JSON_LOG"
echo "    \"timestamp\": \"$TIMESTAMP\"," >> "$JSON_LOG"
echo "    \"hostname\": \"$(hostname)\"," >> "$JSON_LOG"
echo "    \"cpu\": \"$(grep -m 1 "model name" /proc/cpuinfo | cut -d: -f2 | sed 's/^[ \t]*//')\"," >> "$JSON_LOG"
echo "    \"os\": \"$(uname -s)\"," >> "$JSON_LOG"
echo "    \"kernel\": \"$(uname -r)\"" >> "$JSON_LOG"
echo "  }," >> "$JSON_LOG"
echo '  "analysis": {' >> "$JSON_LOG"

# Анализ escape analysis с gcflags="-m"
echo "Анализ escape analysis..."
ESCAPE_OUTPUT=$(go build -gcflags="-m" -o "$BUILD_DIR/main" "$SRC_DIR/golang/main.go" 2>&1)

echo "    \"escape_analysis\": {" >> "$JSON_LOG"
echo "      \"summary\": \"Анализ размещения переменных (Go показывает только escape в кучу)\"," >> "$JSON_LOG"
echo "      \"results\": [" >> "$JSON_LOG"

# Парсим результаты escape analysis
first_line=true
echo "$ESCAPE_OUTPUT" | grep -v "^#" | while IFS= read -r line; do
    if [[ -n "$line" ]]; then
        if [[ "$first_line" != true ]]; then
            echo "," >> "$JSON_LOG"
        fi
        first_line=false
        
        # Определяем тип анализа
        if [[ "$line" == *"escapes to heap"* ]]; then
            type="escape"
            description="Переменная размещается в куче"
        elif [[ "$line" == *"moved to heap"* ]]; then
            type="heap" 
            description="Переменная перемещена в кучу"
        else
            type="info"
            description="Информация о компиляции"
        fi
        
        # Очищаем строку
        clean_line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        echo "        {" >> "$JSON_LOG"
        echo "          \"line\": \"$clean_line\"," >> "$JSON_LOG"
        echo "          \"type\": \"$type\"," >> "$JSON_LOG"
        echo "          \"description\": \"$description\"" >> "$JSON_LOG"
        echo "        }" >> "$JSON_LOG"
    fi
done

echo "      ]" >> "$JSON_LOG"
echo "    }," >> "$JSON_LOG"

# Детальный анализ с -m -m
echo "Детальный анализ..."
DETAILED_OUTPUT=$(go build -gcflags="-m -m" -o "$BUILD_DIR/main_detailed" "$SRC_DIR/golang/main.go" 2>&1)

echo "    \"detailed_analysis\": {" >> "$JSON_LOG"
echo "      \"summary\": \"Детальный анализ причин escape\"," >> "$JSON_LOG"
echo "      \"results\": [" >> "$JSON_LOG"

first_line=true
# Ищем уникаольные строки с объяснениями, убираем дубликаты по номеру строки
echo "$DETAILED_OUTPUT" | grep -E "(escapes to heap|moved to heap)" | grep -v "^#" | awk -F: '{print $1":"$2":"$3}' | sort -u | while IFS= read -r line; do
    if [[ -n "$line" ]]; then
        if [[ "$first_line" != true ]]; then
            echo "," >> "$JSON_LOG"
        fi
        first_line=false
        
        # Анализируем причину escape на основе полного вывода
        full_line=$(echo "$DETAILED_OUTPUT" | grep "$line" | head -1)
        
        reason=""
        if [[ "$full_line" == *"returning &"* ]]; then
            reason="Возврат адреса локальной переменной"
        elif [[ "$full_line" == *"returning value"* ]]; then
            reason="Возврат значения (без указателя)" 
        elif [[ "$full_line" == *"new("* ]]; then
            reason="Создание через new() с возвратом указателя"
        elif [[ "$full_line" == *"parameter"* ]]; then
            reason="Утечка параметра"
        else
            reason="Требуется размещение в куче"
        fi
        
        # Очищаем строку
        clean_line=$(echo "$full_line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        echo "        {" >> "$JSON_LOG"
        echo "          \"line\": \"$clean_line\"," >> "$JSON_LOG"
        echo "          \"reason\": \"$reason\"" >> "$JSON_LOG"
        echo "        }" >> "$JSON_LOG"
    fi
done

echo "      ]" >> "$JSON_LOG"
echo "    }" >> "$JSON_LOG"

echo "  }," >> "$JSON_LOG"

# Объяснение результатов
echo '  "explanations": {' >> "$JSON_LOG"
echo '    "note": "Go компилятор показывает только переменные, которые убегают в кучу. Переменные в стеке не отображаются.",' >> "$JSON_LOG"
echo '    "heap": "Переменная размещается в куче - требует сборки мусора",' >> "$JSON_LOG"
echo '    "escape": "Переменная убегает из функции и должна быть в куче"' >> "$JSON_LOG"
echo "  }" >> "$JSON_LOG"
echo "}" >> "$JSON_LOG"

echo ""
echo "Результаты анализа:"
echo "==================="

if command -v jq >/dev/null; then
    echo "Escape Analysis результаты:"
    jq -r '.analysis.escape_analysis.results[] | "\(.line) - \(.description)"' "$JSON_LOG"
    
    echo ""
    echo "Причины размещения:"
    jq -r '.analysis.detailed_analysis.results[] | "\(.line) | Причина: \(.reason)"' "$JSON_LOG" 2>/dev/null || echo "Детальные причины не найдены"
    
    echo ""
    echo "Статистика:"
    heap_count=$(jq '[.analysis.escape_analysis.results[] | select(.type == "heap" or .type == "escape")] | length' "$JSON_LOG")
    echo "Переменных в куче: $heap_count"
    echo "Переменных в стеке: не отображаются компилятором"
else
    echo "Escape Analysis результаты:"
    grep -A 1 '"line"' "$JSON_LOG" | grep -v '"line"' | sed 's/.*"line": "//' | sed 's/",//'
fi

echo ""
echo "Лог сохранен:"
echo "$JSON_LOG"
