#!/usr/bin/env bash
# Sunucuyu (Nakama + Postgres + Caddy HTTPS) başlatır/yeniden başlatır. setup-vps.sh çağırır; güncellemeden sonra da çalıştır.
set -euo pipefail
DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$DIR/server"
source deploy/.host
export UNIPET_PUBLIC_HOST
git -C "$DIR" pull --ff-only || true
docker compose -f docker-compose.yml -f deploy/docker-compose.prod.yml --env-file .env up -d --remove-orphans
for i in $(seq 1 60); do
  if curl -fsS "https://$UNIPET_PUBLIC_HOST/healthcheck" >/dev/null 2>&1; then echo "Sağlık: OK (https://$UNIPET_PUBLIC_HOST)"; exit 0; fi
  sleep 2
done
echo "Sağlık kontrolü başarısız. Loglar: docker compose -f docker-compose.yml -f deploy/docker-compose.prod.yml logs --tail 50"
exit 1
