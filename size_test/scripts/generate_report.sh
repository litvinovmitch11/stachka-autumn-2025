#!/bin/bash

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$PROJECT_ROOT/logs"

latest_report=$(ls -t "$LOG_DIR"/size_analysis_*.json 2>/dev/null | head -1)

if [[ -z "$latest_report" ]]; then
    echo "Нет отчетов для анализа. Сначала запустите scripts/analyze_size.sh"
    exit 1
fi

echo "Отчет анализа размера бинарников"
echo "===================================="
echo "Файл: $(basename "$latest_report")"
echo ""

# Сводная таблица
echo "Сводная таблица размеров (KB):"
echo ""

jq -r '
["Бинарник", "Компилятор", "Оптимизация", "Размер.KB", "Динамич.библиотеки"],
(.[] | [
    .name,
    .compiler,
    .optimization,
    (.size_kb | tostring),
    (.dynamic_libs_count | tostring)
]) 
| @tsv' "$latest_report" | column -t

echo ""
echo "Сравнение компиляторов:"
echo ""

# Сравнение по компиляторам
jq -r '
group_by(.compiler)[] | 
"Компилятор: \(.[0].compiler)
  Средний размер: \(map(.size_kb) | add / length | round) KB
  Минимальный: \(map(.size_kb) | min) KB
  Максимальный: \(map(.size_kb) | max) KB
  Количество бинарников: \(length)
"' "$latest_report"

echo ""
echo "Детальный анализ Go бинарников:"
echo ""

jq -r '
.[] | select(.language == "Go") |
"\(.name) (\(.compiler), \(.optimization)):
  Размер: \(.size_kb) KB (\(.size_mb) MB)
  Секции: text=\(.sections.text) data=\(.sections.data) bss=\(.sections.bss)
  Символов: \(.symbol_count)
  Динамических библиотек: \(.dynamic_libs_count)
"' "$latest_report"
