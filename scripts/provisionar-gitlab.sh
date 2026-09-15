#!/usr/bin/env bash
# Deja el GitLab del taller listo: grupo, proyecto, los 10 usuarios con su rol,
# las ramas protegidas y el runner registrado.
#
#   ./provisionar-gitlab.sh                      usa http://localhost:8929
#   ./provisionar-gitlab.sh http://IP-DEL-SERVIDOR:8929
#
# Se puede volver a correr las veces que haga falta: lo que ya existe se
# respeta y sólo se crea lo que falta.
#
# Cómo funciona por dentro: se acuña UN token de administrador con
# `gitlab-rails` dentro del contenedor —que no necesita credenciales— y a
# partir de ahí todo va por la API REST, que es estable entre versiones.

set -euo pipefail

URL="${1:-http://localhost:8929}"
CONTENEDOR="${CONTENEDOR:-taller-gitlab}"
GRUPO="${GRUPO:-taller}"
PROYECTO="${PROYECTO:-demo-fttg}"
CLAVE_USUARIOS="${CLAVE_USUARIOS:-Taller2026!}"
USUARIOS="$(dirname "$0")/../infra/usuarios.tsv"

verde(){ printf '\033[32m  ok\033[0m %s\n' "$*"; }
info(){  printf '\033[36m%s\033[0m\n' "$*"; }
gris(){  printf '\033[90m  -- %s\033[0m\n' "$*"; }
rojo(){  printf '\033[31m  !! %s\033[0m\n' "$*"; }

# macOS no trae el ejecutable `python`, sólo `python3` —y ni ese si no están
# las herramientas de línea de comandos de Xcode—. Se busca cuál hay antes de
# usarlo, en vez de descubrirlo a mitad del provisionamiento.
PY="$(command -v python3 || command -v python || true)"
if [[ -z "$PY" ]]; then
  echo "Falta Python, que este script usa para leer las respuestas de la API."
  echo "  macOS  : xcode-select --install"
  echo "  Ubuntu : sudo apt-get install -y python3"
  exit 1
fi

api() { # api <METODO> <ruta> [campo=valor ...]
  local metodo="$1" ruta="$2"; shift 2
  local args=(-sS -X "$metodo" -H "PRIVATE-TOKEN: $TOKEN")
  local p; for p in "$@"; do args+=(--data-urlencode "$p"); done
  curl "${args[@]}" "$URL/api/v4$ruta"
}
campo() { PYTHONIOENCODING=utf-8 "$PY" -c "
import sys,json
try: d=json.load(sys.stdin)
except Exception: sys.exit(1)
v=d.get('$1') if isinstance(d,dict) else None
print(v if v is not None else '')"; }

# ─────────────────────────────────────────── 0 · esperar a que GitLab responda
info "Esperando a que GitLab responda en $URL …"
for i in $(seq 1 60); do
  if curl -sf -o /dev/null "$URL/-/health" 2>/dev/null; then verde "GitLab en pie"; break; fi
  [[ $i -eq 60 ]] && { rojo "GitLab no respondió en 10 minutos. docker logs $CONTENEDOR"; exit 1; }
  printf '.'; sleep 10
done

# ─────────────────────────────────────────── 1 · token de administrador
info "Acuñando el token de administración…"
TOKEN="glpat-taller$(date +%s | tail -c 9)"
docker exec "$CONTENEDOR" gitlab-rails runner "
  u = User.find_by_username('root')
  u.personal_access_tokens.where(name: 'provisionamiento-taller').delete_all
  t = u.personal_access_tokens.create!(
        name: 'provisionamiento-taller',
        scopes: ['api','sudo'],
        expires_at: 60.days.from_now)
  t.set_token('$TOKEN'); t.save!
" >/dev/null 2>&1 || { rojo "No se pudo acuñar el token"; exit 1; }
verde "token listo"

# ─────────────────────────────────────────── 2 · grupo
info "Grupo /$GRUPO"
ID_GRUPO="$(api GET "/groups/$GRUPO" | campo id || true)"
if [[ -z "$ID_GRUPO" ]]; then
  ID_GRUPO="$(api POST /groups "name=$GRUPO" "path=$GRUPO" "visibility=internal" \
    "description=Capacitación DevOps FTTG" | campo id)"
  verde "creado (id $ID_GRUPO)"
else gris "ya existía (id $ID_GRUPO)"; fi

# ─────────────────────────────────────────── 3 · proyecto
info "Proyecto /$GRUPO/$PROYECTO"
ID_PROY="$(api GET "/projects/$GRUPO%2F$PROYECTO" | campo id || true)"
if [[ -z "$ID_PROY" ]]; then
  ID_PROY="$(api POST /projects "name=$PROYECTO" "path=$PROYECTO" \
    "namespace_id=$ID_GRUPO" "visibility=internal" "initialize_with_readme=true" \
    "description=Laboratorio de la capacitación" | campo id)"
  verde "creado (id $ID_PROY)"
else gris "ya existía (id $ID_PROY)"; fi

# ─────────────────────────────────────────── 4 · usuarios
info "Usuarios"
# Sin `declare -a` con valor: bash 3.2 (el de macOS) trata distinto los
# arrays vacios bajo `set -u`. Se inicializan sueltos y se expanden con :-
DEVS=(); APRS=()
while IFS=$'\t' read -r usuario nombre rol; do
  [[ -z "${usuario:-}" || "$usuario" == \#* ]] && continue
  case "$rol" in
    developer) NIVEL=30 ;;
    aprobador) NIVEL=40 ;;
    *) rojo "rol desconocido '$rol' para $usuario, se omite"; continue ;;
  esac

  ID_U="$(api GET "/users?username=$usuario" | PYTHONIOENCODING=utf-8 "$PY" -c "
import sys,json
l=json.load(sys.stdin)
print(l[0]['id'] if l else '')" || true)"

  if [[ -z "$ID_U" ]]; then
    ID_U="$(api POST /users \
      "username=$usuario" "name=$nombre" "email=$usuario@taller.local" \
      "password=$CLAVE_USUARIOS" "skip_confirmation=true" \
      "force_random_password=false" | campo id)"
    [[ -z "$ID_U" ]] && { rojo "no se pudo crear $usuario"; continue; }
    verde "$(printf '%-6s %-18s %s' "$usuario" "$nombre" "$rol")"
  else
    gris "$(printf '%-6s ya existía' "$usuario")"
  fi

  api POST "/projects/$ID_PROY/members" "user_id=$ID_U" "access_level=$NIVEL" >/dev/null 2>&1 || true
  [[ "$rol" == developer ]] && DEVS+=("$usuario") || APRS+=("$usuario")
done < "$USUARIOS"

# ─────────────────────────────────────────── 5 · ramas
info "Ramas dev y test"
for rama in dev test; do
  api POST "/projects/$ID_PROY/repository/branches" "branch=$rama" "ref=main" >/dev/null 2>&1 \
    && verde "$rama creada" || gris "$rama ya existía"
done

# ─────────────────────────────────────────── 6 · protección de ramas
# Aquí está la enseñanza. En GitLab CE el botón «Approve» existe y cualquier
# Developer puede pulsarlo, PERO es opcional: no impide fusionar. Las reglas
# de aprobación obligatorias son de pago.
#
# La barrera de verdad, en CE, son las ramas protegidas. Así queda:
#
#   dev    → los Developers empujan y fusionan. Trabajan con libertad.
#   test   → NADIE empuja. Sólo los aprobadores (Maintainer) fusionan.
#   master → NADIE empuja. Sólo los aprobadores fusionan.
#
# Resultado: las dos promociones del Tema 8 sólo las puede ejecutar un
# aprobador, que es exactamente lo que se quería enseñar.
info "Protegiendo las ramas"
proteger() { # proteger <rama> <nivel_push> <nivel_merge>
  api DELETE "/projects/$ID_PROY/protected_branches/$1" >/dev/null 2>&1 || true
  api POST "/projects/$ID_PROY/protected_branches" \
    "name=$1" "push_access_level=$2" "merge_access_level=$3" >/dev/null 2>&1 \
    && verde "$(printf '%-7s push=%-9s merge=%s' "$1" "${4}" "${5}")" \
    || rojo "no se pudo proteger $1"
}
proteger dev    30 30 "Developer" "Developer"
proteger test    0 40 "nadie"     "aprobadores"
proteger main    0 40 "nadie"     "aprobadores"
proteger master  0 40 "nadie"     "aprobadores"

# ─────────────────────────────────────────── 7 · runner
info "Runner"
if docker exec taller-runner test -s /etc/gitlab-runner/config.toml 2>/dev/null \
   && docker exec taller-runner grep -q '\[\[runners\]\]' /etc/gitlab-runner/config.toml 2>/dev/null; then
  gris "ya estaba registrado"
else
  TOK_RUNNER="$(api POST /user/runners \
    "runner_type=project_type" "project_id=$ID_PROY" \
    "tag_list=taller" "description=Runner del taller" | campo token || true)"
  if [[ -z "$TOK_RUNNER" ]]; then
    rojo "no se obtuvo el token del runner; regístrelo a mano con registrar-runner.sh"
  else
    docker exec taller-runner gitlab-runner register \
      --non-interactive --url "$URL" --token "$TOK_RUNNER" \
      --executor docker --docker-image alpine:3.20 \
      --docker-volumes /var/run/docker.sock:/var/run/docker.sock \
      --docker-network-mode "${RED_TALLER:-taller_default}" \
      --docker-pull-policy if-not-present \
      --description "Runner del taller" >/dev/null 2>&1 \
      && { docker restart taller-runner >/dev/null; verde "registrado y arrancado"; } \
      || rojo "el registro falló; vea docker logs taller-runner"
  fi
fi

# ─────────────────────────────────────────── resumen
cat <<RESUMEN

════════════════════════════════════════════════════════════════
 GitLab del taller listo
════════════════════════════════════════════════════════════════

  Dirección   $URL
  Proyecto    $URL/$GRUPO/$PROYECTO

  Administrador   root / TallerFTTG2026!
  Todos los demás usan la contraseña:  $CLAVE_USUARIOS

  Developers (${#DEVS[@]})   ${DEVS[*]:-ninguno}
     · empujan a dev, abren Merge Requests, pueden aprobar
     · NO pueden fusionar en test ni en master

  Aprobadores (${#APRS[@]})  ${APRS[*]:-ninguno}
     · además, son los únicos que fusionan en test y master
     · ejecutan las dos promociones del Tema 8

  Ramas protegidas
     dev      push Developer   merge Developer
     test     push nadie       merge aprobadores
     master   push nadie       merge aprobadores

  Aviso: en GitLab CE el botón «Approve» es OPCIONAL, no bloquea la
  fusión. Quien impide de verdad que un developer promueva es la
  protección de rama. Las reglas de aprobación obligatorias
  ("requiere 2 aprobaciones") son de GitLab Premium.

RESUMEN
