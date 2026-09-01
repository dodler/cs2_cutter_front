#!/usr/bin/env bash
# Запуск ТОЛЬКО веб-интерфейса, без бэкенда и без CS2.
#
# Здесь крутится только статика; задачи выполняет бэкенд на машине с CS2 —
# он лежит в отдельном репозитории (cs2_cutter, скрипт run_service.sh).
#
#   CS2_API_BASE=http://192.168.0.4:8000 ./serve_ui.sh
#   CS2_API_BASE=http://192.168.0.4:8000 UI_HOST=0.0.0.0 UI_PORT=8080 ./serve_ui.sh
#
# CS2_API_BASE пустой = UI ждёт API на своём же origin. Для отдельного UI это
# почти наверняка ошибка, поэтому предупреждаем.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

WEB_DIR="$SCRIPT_DIR/web"
UI_HOST="${UI_HOST:-0.0.0.0}"
UI_PORT="${UI_PORT:-8080}"
CS2_API_BASE="${CS2_API_BASE:-}"
# Сервис авторизации и библиотеки фрагментов. Пусто = там же, где CS2_API_BASE.
CS2_LIBRARY_BASE="${CS2_LIBRARY_BASE:-}"

# Убираем хвостовые слэши: в UI адрес склеивается с путями вида "/api/...".
CS2_API_BASE="${CS2_API_BASE%/}"
CS2_LIBRARY_BASE="${CS2_LIBRARY_BASE%/}"

if [[ -z "$CS2_API_BASE" ]]; then
    echo "[!] CS2_API_BASE не задан — UI будет искать API на http://<этот хост>:$UI_PORT," >&2
    echo "    где никакого API нет. Укажите адрес бэкенда:" >&2
    echo "    CS2_API_BASE=http://192.168.0.4:8000 $0" >&2
fi

# config.js генерируем при каждом запуске: адрес бэкенда — параметр развёртывания,
# а не то, что стоит держать закоммиченным.
python3 - "$WEB_DIR/config.js" "$CS2_API_BASE" "$CS2_LIBRARY_BASE" <<'PY'
import json, sys
path, api_base, lib_base = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, "w", encoding="utf-8") as f:
    f.write("// Сгенерировано serve_ui.sh — правки будут перезаписаны.\n"
            "// Адреса задаются переменными CS2_API_BASE и CS2_LIBRARY_BASE.\n"
            f"window.CS2_API_BASE = {json.dumps(api_base)};\n"
            f"window.CS2_LIBRARY_BASE = {json.dumps(lib_base)};\n")
PY

echo "[*] UI:     http://$UI_HOST:$UI_PORT"
echo "[*] Бэкенд:    ${CS2_API_BASE:-<тот же origin>}"
echo "[*] Библиотека: ${CS2_LIBRARY_BASE:-<там же, где бэкенд>}"

# Статика — стандартным http.server: зависимостей не нужно, а раздать
# один html с двумя скриптами больше ничего и не требует.
exec python3 -m http.server "$UI_PORT" --bind "$UI_HOST" --directory "$WEB_DIR"
