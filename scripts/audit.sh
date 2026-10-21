#!/usr/bin/env bash
set -uo pipefail

PASS=0; FAIL=0

check() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        echo " [OK]  $desc"
        ((PASS++))
    else
        echo " [FAIL] $desc (ожидалось: '$expected', получено: '$actual')"
        ((FAIL++))
    fi
}

echo "Аудит конфигурации: $(hostname -f), $(date '+%Y-%m-%d %H:%M')"

# ==========================================
# РАЗДЕЛ 1: Служба SSH (из ПР №5)
# ==========================================
echo "[1] Служба SSH"
check "Вход от имени root запрещён" "no" "$(sudo sshd -T | awk '/^permitrootlogin/{print $2}')"
check "Парольная аутентификация отключена" "no" "$(sudo sshd -T | awk '/^passwordauthentication/{print $2}')"

# TODO 1: проверьте, что значение параметра port отлично от 22
# Мы проверяем, что порт НЕ равен 22. Для этого передаем в check "no"
IS_PORT_22=$(sudo sshd -T | awk '/^port/{print $2}' | grep -q "^22$" && echo "yes" || echo "no")
check "Порт SSH не равен 22" "no" "$IS_PORT_22"

# TODO 2: проверьте, что значение параметра maxauthtries равно 3
check "MaxAuthTries равен 3" "3" "$(sudo sshd -T | awk '/^maxauthtries/{print $2}')"


# ==========================================
# РАЗДЕЛ 2: Межсетевой экран (из ПР №5)
# ==========================================
echo "[2] Межсетевой экран"
check "Межсетевой экран активен" "active" "$(sudo ufw status | awk '/^Status:/{print $2}')"

# TODO 3: проверьте, что политика по умолчанию для входящего трафика равна deny
UFW_INCOMING=$(sudo ufw status verbose | awk '/^Default:/{print $3}')
check "Политика по умолчанию для входящего трафика: deny" "deny" "$UFW_INCOMING"


# ==========================================
# РАЗДЕЛ 3: Учётные записи (из ПР №5)
# ==========================================
echo "[3] Учётные записи"
awk -F: ' $3>=1000 && $3<65534 {printf " %s (uid=%s)\n",$1,$3}' /etc/passwd


# ==========================================
# РАЗДЕЛ 4: Веб-сервер (из ПР №6)
# ==========================================
echo "[4] Веб-сервер"

# а) конфигурация nginx синтаксически корректна
sudo nginx -t >/dev/null 2>&1
check "Конфигурация Nginx корректна" "0" "$?"

# б) сертификат истекает не ранее чем через 30 дней (2592000 секунд)
openssl x509 -checkend 2592000 -noout -in /etc/ssl/certs/devops.crt >/dev/null 2>&1
check "Сертификат действителен более 30 дней" "0" "$?"

# в) в каталоге ресурса нет файлов с правом записи для всех (o+w)
# find возвращает список файлов. Если список пуст, команда wc -l выдаст 0.
NO_WW_FILES=$(sudo find /var/www/devops-site -perm -o+w 2>/dev/null | wc -l | tr -d ' ')
check "Нет файлов с правом записи для всех (o+w)" "0" "$NO_WW_FILES"

# г) права ключа равны 600
KEY_PERMS=$(sudo stat -c '%a' /etc/ssl/private/devops.key)
check "Права закрытого ключа TLS (600)" "600" "$KEY_PERMS"


# ==========================================
# ИТОГИ
# ==========================================
echo "----------------------------------------"
echo "Пройдено: $PASS, не пройдено: $FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1