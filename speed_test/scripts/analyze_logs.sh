#!/bin/bash

# analyze_logs.sh - Анализ результатов бенчмарков

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$PROJECT_ROOT/logs"

echo "Анализ результатов бенчмарков"
echo "============================="

for json_file in "$LOG_DIR"/*.json; do
    if [ -f "$json_file" ]; then
        echo ""
        echo "JSON лог: $(basename "$json_file")"
        jq -r '.benchmarks[] | "\(.name): \(.execution_time), Память: \(.max_rss_kb) KB"' "$json_file"
    fi
done
