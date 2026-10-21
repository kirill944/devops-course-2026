#!/usr/bin/env bash

# Доставка статического ресурса на devops-vm
# Использование: scripts/deploy.sh [--dry-run]

set -euo pipefail

REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"
# Определяем корень репозитория и путь к site/
LOCAL_DIR="$(git rev-parse --show-toplevel)/site/"

# 1. Разбор аргумента --dry-run
DRY_RUN=""
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN="--dry-run"
    echo "Режим пробного запуска (--dry-run)"
fi

# 2. Проверка наличия index.html (Требование 4)
if [[ ! -f "${LOCAL_DIR}/index.html" ]]; then
    echo "Ошибка: файл ${LOCAL_DIR}/index.html не найден!" >&2
    exit 1
fi

# 3. Проверка незафиксированных изменений в Git (Требование 5)
if [[ -n "$(git status --porcelain)" ]]; then
    echo "Ошибка: в репозитории есть незафиксированные изменения!" >&2
    exit 1
fi

# 4. Синхронизация каталога (Требование 3 и 8)
echo "Синхронизация ${LOCAL_DIR} на ${REMOTE}:${REMOTE_DIR}..."
# Используем -e для настройки SSH, чтобы избежать интерактивного ввода пароля (Требование 9)
rsync -avz --delete --chmod=D755,F644 ${DRY_RUN} -e "ssh -o BatchMode=yes -o ConnectTimeout=5" "${LOCAL_DIR}" "${REMOTE}:${REMOTE_DIR}"

# 5. При --dry-run — завершение с кодом 0 (Требование 1)
if [[ -n "${DRY_RUN}" ]]; then
    echo "Пробный запуск завершен. Изменения на сервере не применялись."
    exit 0
fi

# 6. Проверка доступности ресурса (Требование 6)
echo "Проверка доступности ${SITE_URL}..."
if ! curl -f --cacert "${CA_CERT}" -s -o /dev/null "${SITE_URL}"; then
    echo "Ошибка: ресурс ${SITE_URL} недоступен!" >&2
    exit 1
fi

# 7. Успешное завершение (Требование 7)
COMMIT_HASH=$(git rev-parse --short HEAD)
echo "Деплой успешно завершен. Доставлен коммит: ${COMMIT_HASH}"
exit 0
