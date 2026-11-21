#!/usr/bin/env bash
# UniPet sunucusunu boş bir Ubuntu 22.04/24.04 VPS'e kurar (ROADMAP 6.1).
# Alan adı gerekmez: HTTPS sertifikası <ip>.sslip.io adına Caddy ile otomatik alınır.
#
# Kullanım (VPS'te, root ya da sudo ile):
#   curl -fsSL https://raw.githubusercontent.com/talha24052050/unipet/main/server/deploy/setup-vps.sh | sudo bash
# Sonra: /opt/unipet/server/.env içindeki SUPABASE_* değerlerini doldurup `sudo /opt/unipet/server/deploy/restart.sh`
set -euo pipefail

REPO="https://github.com/talha24052050/unipet.git"
DIR="/opt/unipet"

if [ "$(id -u)" -ne 0 ]; then echo "root/sudo ile çalıştır"; exit 1; fi

echo "== Docker"
if ! command -v docker >/dev/null; then
  curl -fsSL https://get.docker.com | sh
fi

echo "== Kod"
if [ -d "$DIR/.git" ]; then git -C "$DIR" pull --ff-only; else git clone --depth 1 "$REPO" "$DIR"; fi

echo "== Ayarlar (.env)"
ENV="$DIR/server/.env"
if [ ! -f "$ENV" ]; then
  cp "$DIR/server/.env.example" "$ENV"
  rand() { head -c 32 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 32; }
  sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$(rand)/" "$ENV"
  sed -i "s/^NAKAMA_SERVER_KEY=.*/NAKAMA_SERVER_KEY=$(rand)/" "$ENV"
  sed -i "s/^NAKAMA_CONSOLE_PASS=.*/NAKAMA_CONSOLE_PASS=$(rand)/" "$ENV"
  # Yayında sahte giriş KAPALI: sadece Supabase oturumu kabul edilir.
  sed -i "s/^UNIPET_DEV_AUTH=.*/UNIPET_DEV_AUTH=false/" "$ENV"
  chmod 600 "$ENV"
fi

IP="$(curl -fsSL https://api.ipify.org)"
HOST="$(echo "$IP" | tr '.' '-').sslip.io"
echo "UNIPET_PUBLIC_HOST=$HOST" > "$DIR/server/deploy/.host"

echo "== Güvenlik duvarı (22, 80, 443)"
if command -v ufw >/dev/null; then
  ufw allow 22/tcp >/dev/null; ufw allow 80/tcp >/dev/null; ufw allow 443/tcp >/dev/null
  ufw --force enable >/dev/null
fi

"$DIR/server/deploy/restart.sh"

KEY="$(grep '^NAKAMA_SERVER_KEY=' "$ENV" | cut -d= -f2)"
echo
echo "Hazır. Oyundaki sunucu adresi: https://$HOST"
echo "Oyun ayarı (game/secrets.cfg ya da GitHub secret):"
echo "  [nakama] host=\"$HOST\" port=443 ssl=true server_key=\"$KEY\""
echo "Konsol (sadece SSH tüneliyle): ssh -L 7351:127.0.0.1:7351 <kullanıcı>@$IP  →  http://127.0.0.1:7351"
