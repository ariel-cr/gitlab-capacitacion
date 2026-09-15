#!/usr/bin/env bash
# Deja los tres servidores del laboratorio en pie: dev, test y prod.
#
#   ./preparar-ambientes.sh
#
# Qué hace, en orden:
#   1. Genera una pareja de llaves SSH para el despliegue (si no existe).
#   2. Construye la imagen de servidor con la llave pública dentro.
#   3. Levanta los tres contenedores.
#   4. Comprueba que los tres responden.
#   5. Imprime la llave PRIVADA para pegarla en GitLab.
#
# Por qué llaves y no contraseñas: porque así se despliega en un servidor de
# verdad, y porque el pipeline no puede teclear una contraseña.

set -euo pipefail

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
LLAVES="$RAIZ/.llaves"
PRIVADA="$LLAVES/despliegue"
RED="taller_default"

verde(){ printf '\033[32m  ok\033[0m %s\n' "$*"; }
info(){  printf '\n\033[36m%s\033[0m\n' "$*"; }
rojo(){  printf '\033[31m  !! \033[0m%s\n' "$*"; }

# ── 1 · llaves ───────────────────────────────────────────────────────────
info "1 · Llave de despliegue"
mkdir -p "$LLAVES"
if [[ -f "$PRIVADA" ]]; then
  verde "ya existía ($PRIVADA)"
else
  ssh-keygen -t ed25519 -N "" -C "despliegue@taller" -f "$PRIVADA" >/dev/null
  verde "generada"
fi
cp "$PRIVADA.pub" "$RAIZ/ambientes/llave.pub"
verde "llave pública copiada al contexto de construcción"

# ── 2 · red compartida ───────────────────────────────────────────────────
info "2 · Red"
# Los servidores tienen que estar en la misma red que el runner, o el
# despliegue no los alcanza por nombre.
if docker network inspect "$RED" >/dev/null 2>&1; then
  verde "la red $RED ya existe"
else
  docker network create "$RED" >/dev/null
  verde "red $RED creada"
fi

# ── 3 · construir y levantar ─────────────────────────────────────────────
info "3 · Construyendo y levantando los tres servidores"
docker compose -f "$RAIZ/infra/docker-compose.servidores.yml" up -d --build
verde "levantados"

# ── 4 · comprobar ────────────────────────────────────────────────────────
info "4 · Comprobación"
sleep 6
fallo=0
for par in "dev:8081" "test:8082" "prod:8083"; do
  amb="${par%%:*}"; puerto="${par##*:}"
  codigo="$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "http://localhost:$puerto/" || echo 000)"
  if [[ "$codigo" == "200" ]]; then verde "$(printf '%-5s http://localhost:%s  responde' "$amb" "$puerto")"
  else rojo "$(printf '%-5s puerto %s devolvió %s' "$amb" "$puerto" "$codigo")"; fallo=1; fi
done

# Que el despliegue por SSH vaya a funcionar, comprobado ahora y no cuando
# falle el pipeline delante de la clase.
info "5 · Acceso por SSH desde el runner"
if docker ps --format '{{.Names}}' | grep -q '^taller-runner$'; then
  for amb in dev test prod; do
    if docker run --rm --network "$RED" -v "$PRIVADA:/k:ro" alpine:3.20 \
         sh -c 'apk add -q openssh-client && chmod 600 /k &&
                ssh -i /k -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
                    despliegue@amb-'"$amb"' "echo vale"' 2>/dev/null | grep -q vale; then
      verde "amb-$amb acepta la llave"
    else rojo "amb-$amb NO acepta la llave"; fallo=1; fi
  done
else
  printf '  \033[33m--\033[0m el runner no está arriba; se omite la prueba de SSH\n'
fi

# ── 6 · la llave privada, para GitLab ────────────────────────────────────
cat <<FIN

════════════════════════════════════════════════════════════════
 Los tres servidores
════════════════════════════════════════════════════════════════

  DEV    http://<IP-DEL-MAC>:8081     ssh -p 2201 despliegue@<IP-DEL-MAC>
  TEST   http://<IP-DEL-MAC>:8082     ssh -p 2202 despliegue@<IP-DEL-MAC>
  PROD   http://<IP-DEL-MAC>:8083     ssh -p 2203 despliegue@<IP-DEL-MAC>

  Los participantes abren esas tres direcciones en tres pestañas y ven
  cambiar el color cuando alguien promueve.

── Falta un paso: darle la llave al pipeline ───────────────────

  En GitLab, como root:
     Settings → CI/CD → Variables → Add variable

     Key    : SSH_PRIVADA
     Type   : File            <- tipo Archivo, NO Variable
     Protect: desmarcado      <- si lo marca, dev y test no la verán
     Value  : todo el bloque de abajo, incluidas las líneas BEGIN y END

FIN
cat "$PRIVADA"
echo
[[ $fallo -eq 0 ]] || { rojo "Hubo comprobaciones fallidas, revise arriba"; exit 1; }
