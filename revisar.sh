#!/usr/bin/env bash
set -u

BASE_URL="https://gnuino.com.ar"
TIMEOUT=15

command -v curl >/dev/null || { echo "Falta instalar curl"; exit 1; }
command -v openssl >/dev/null || { echo "Falta instalar openssl"; exit 1; }

# Devuelve el código HTTP; 000 suele indicar un error de conexión o timeout.
check_url() {
  local url="$1" code
  code=$(curl -L -sS -o /dev/null \
    --connect-timeout 8 --max-time "$TIMEOUT" \
    -w '%{http_code}' "$url" 2>/dev/null) || code="000"

  if [[ "$code" =~ ^2|^3 ]]; then
    printf 'ACTIVO  [%s] %s\n' "$code" "$url"
  else
    printf 'ERROR   [%s] %s\n' "$code" "$url"
  fi
}

echo "== Homepage =="
check_url "$BASE_URL"

echo
echo "== Certificado SSL/TLS =="

host=$(printf '%s\n' "$BASE_URL" | sed -E 's#^https?://([^/:]+).*#\1#')
if cert_info=$(openssl s_client -connect "${host}:443" -servername "$host" \
    -verify_return_error </dev/null 2>&1); then
  if grep -q 'Verify return code: 0 (ok)' <<<"$cert_info"; then
    echo "VÁLIDO: la cadena del certificado fue verificada."
  else
    echo "NO VÁLIDO o no verificable:"
    grep -E 'Verify return code:|verify error' <<<"$cert_info" | tail -n 3
  fi

  expiry=$(openssl s_client -connect "${host}:443" -servername "$host" \
    </dev/null 2>/dev/null |
    openssl x509 -noout -enddate 2>/dev/null)
  [[ -n "$expiry" ]] && echo "$expiry"
else
  echo "ERROR: no se pudo establecer la conexión TLS con $host."
fi

echo
echo "== Enlaces encontrados en la homepage =="

html=$(curl -L -sS --connect-timeout 8 --max-time "$TIMEOUT" "$BASE_URL" 2>/dev/null)
if [[ -z "$html" ]]; then
  echo "No se pudo descargar la homepage."
  exit 1
fi

# Python estándar para extraer y normalizar hrefs, incluidos enlaces relativos.
mapfile -t links < <(python3 - "$BASE_URL" <<'PY'
import sys
from html.parser import HTMLParser
from urllib.parse import urljoin, urldefrag

base = sys.argv[1]

class Links(HTMLParser):
    def handle_starttag(self, tag, attrs):
        if tag.lower() == "a":
            href = dict(attrs).get("href")
            if href:
                url, _ = urldefrag(urljoin(base, href.strip()))
                if url.startswith(("http://", "https://")):
                    print(url)

Links().feed(sys.stdin.read())
PY
<<<"$html")



echo
echo "== Proyectos =="

for item in \
  "Apryx|https://gnuino.com.ar/Apryx/" \
  "AUTONEX|https://gnuino.com.ar/AUTONEX/" \
  "OceanOS|https://gnuino.com.ar/OceanOS/" \
  "Guia Rapida|https://gnuino.com.ar/guia-rapida/" \
  "Turnos Medicos|https://gnuino.com.ar/turnos/" \
  "BatchAlert|https://gnuino.com.ar/batchalert/"
  
do
  nombre=${item%%|*}
  url=${item#*|}

  codigo=$(curl -L -s -o /dev/null -w '%{http_code}' "$url")
  echo "$nombre: HTTP $codigo — $url"
done