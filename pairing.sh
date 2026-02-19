#!/usr/bin/env bash
set -euo pipefail

CONTAINER="${CONTAINER:-openclaw}"
URL="${URL:-ws://127.0.0.1:8080}"

# Récupère le token depuis env ou depuis .env
if [[ -z "${OPENCLAW_GATEWAY_TOKEN:-}" ]]; then
  if [[ -f .env ]]; then
    OPENCLAW_GATEWAY_TOKEN="$(grep -E '^OPENCLAW_GATEWAY_TOKEN=' .env | tail -n1 | cut -d= -f2- | tr -d '\r')"
  fi
fi

if [[ -z "${OPENCLAW_GATEWAY_TOKEN:-}" ]]; then
  echo "ERROR: OPENCLAW_GATEWAY_TOKEN manquant (exporte-le ou mets-le dans .env)." >&2
  exit 1
fi

echo "[pair] Gateway URL: ${URL}"
echo "[pair] Token: (ok, non affiché)"
echo "[pair] Ouvre l'UI et laisse-la afficher 'pairing required', car les pending expirent vite."  # pending.json est short-lived [web:205]

# --url => exige des credentials explicites, donc on passe --token explicitement [web:180]
JSON="$(docker exec -i "$CONTAINER" openclaw devices list --url "$URL" --token "$OPENCLAW_GATEWAY_TOKEN" --json)"

if command -v jq >/dev/null 2>&1; then
  mapfile -t REQ_IDS < <(printf '%s' "$JSON" | jq -r '.. | objects | .requestId? // empty' | sort -u)
else
  # fallback sans jq
  mapfile -t REQ_IDS < <(printf '%s' "$JSON" | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | sort -u)
fi

if [[ "${#REQ_IDS[@]}" -eq 0 ]]; then
  echo "[pair] Aucun pending trouvé."
  echo "[pair] Astuce: recharge http://localhost:8080/... puis relance ce script (les pending expirent)."  # pending expire [web:205]
  exit 0
fi

echo "[pair] Pending requestId:"
printf ' - %s\n' "${REQ_IDS[@]}"
echo

for rid in "${REQ_IDS[@]}"; do
  read -r -p "[pair] Approuver ${rid} ? [y/N] " ans
  if [[ "${ans}" == "y" || "${ans}" == "Y" ]]; then
    docker exec -it "$CONTAINER" openclaw devices approve "$rid" --url "$URL" --token "$OPENCLAW_GATEWAY_TOKEN"
  fi
done

echo "[pair] Terminé. Vérifie sur le host: ./openclaw-state/devices/paired.json"
