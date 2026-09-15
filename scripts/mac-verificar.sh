#!/usr/bin/env bash
# Comprobación previa EN EL MAC que va a hacer de servidor del taller.
#
#   ./mac-verificar.sh
#
# Se corre ANTES de levantar nada. Comprueba lo que de verdad rompe en Docker
# Desktop para Mac, que no es lo mismo que rompe en Linux.

set -uo pipefail
fallos=0; avisos=0
ok(){    printf '  \033[32m[ ok ]\033[0m %s\n' "$*"; }
falla(){ printf '  \033[31m[FALLA]\033[0m %s\n' "$*"; fallos=$((fallos+1)); }
aviso(){ printf '  \033[33m[aviso]\033[0m %s\n' "$*"; avisos=$((avisos+1)); }
tit(){   printf '\n\033[36m%s\033[0m\n' "$*"; }

tit "1 · Equipo"
CHIP="$(uname -m)"
case "$CHIP" in
  arm64) ok "Apple Silicon ($CHIP). GitLab 18.11+ trae arm64 nativo: correcto" ;;
  x86_64) ok "Intel ($CHIP)" ;;
  *) aviso "arquitectura inesperada: $CHIP" ;;
esac
RAM=$(( $(sysctl -n hw.memsize) / 1073741824 ))
if   [[ $RAM -ge 32 ]]; then ok "RAM ${RAM} GB — holgado"
elif [[ $RAM -ge 16 ]]; then aviso "RAM ${RAM} GB — alcanza para GitLab, pero deja poco para VMs de alumnos"
else falla "RAM ${RAM} GB — GitLab CE pide 6 GB sólo para él"; fi

LIBRE=$(df -g / | awk 'NR==2{print $4}')
[[ ${LIBRE:-0} -ge 40 ]] && ok "Disco libre ${LIBRE} GB" || falla "Disco libre ${LIBRE} GB — se necesitan 40"

tit "2 · Docker Desktop"
if ! command -v docker >/dev/null; then
  falla "Docker no instalado — brew install --cask docker"
else
  if docker info >/dev/null 2>&1; then
    ok "el demonio responde"
    # LA comprobación que más falla en Mac: Docker Desktop reparte al motor
    # sólo la memoria que se le asigne en Settings → Resources, y por omisión
    # suele quedarse corto para GitLab.
    MEM=$(docker info --format '{{.MemTotal}}' 2>/dev/null)
    MEMGB=$(( ${MEM:-0} / 1073741824 ))
    if   [[ $MEMGB -ge 8 ]]; then ok "memoria asignada a Docker: ${MEMGB} GB"
    elif [[ $MEMGB -ge 6 ]]; then aviso "memoria asignada a Docker: ${MEMGB} GB — justo. Suba a 8 en Settings → Resources"
    else falla "memoria asignada a Docker: ${MEMGB} GB — GitLab no arranca. Settings → Resources → Memory ≥ 8 GB"; fi
    CPUS=$(docker info --format '{{.NCPU}}' 2>/dev/null)
    [[ ${CPUS:-0} -ge 4 ]] && ok "CPU asignadas: $CPUS" || aviso "CPU asignadas: ${CPUS:-?} — suba a 4"
  else
    falla "Docker instalado pero el demonio no responde — abra Docker Desktop"
  fi
fi

tit "3 · El socket de Docker"
# El runner monta /var/run/docker.sock para poder construir imágenes. En las
# versiones recientes de Docker Desktop ese enlace NO se crea salvo que se
# marque "Allow the default Docker socket to be used" en Settings → Advanced.
if [[ -S /var/run/docker.sock ]]; then
  ok "/var/run/docker.sock existe"
else
  falla "/var/run/docker.sock NO existe.
           Docker Desktop → Settings → Advanced →
           marque «Allow the default Docker socket to be used» y reinicie.
           Sin esto, la etapa build del pipeline no puede construir imágenes."
fi

tit "4 · Herramientas del script"
if command -v python3 >/dev/null; then ok "$(python3 --version)"
else falla "falta python3 — xcode-select --install"; fi
command -v curl >/dev/null && ok "curl" || falla "falta curl"
command -v git  >/dev/null && ok "$(git --version)" || aviso "falta git — xcode-select --install"

tit "5 · Puertos"
for p in 8929 2224; do
  if lsof -nP -iTCP:$p -sTCP:LISTEN >/dev/null 2>&1; then
    falla "el puerto $p está ocupado — $(lsof -nP -iTCP:$p -sTCP:LISTEN | awk 'NR==2{print $1}')"
  else ok "puerto $p libre"; fi
done

tit "6 · Red e hibernación"
IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"
if [[ -n "$IP" ]]; then
  ok "IP en la red: $IP"
  echo "         → ponga esta IP en external_url de docker-compose.taller.yml"
else aviso "no se detectó IP de red — conecte el Mac a la red del aula"; fi

if pmset -g | grep -qE 'sleep[[:space:]]+0'; then
  ok "la suspensión está desactivada"
else
  aviso "el Mac se va a dormir y con él GitLab y las VMs.
           Durante el taller:  caffeinate -dims
           o Ajustes → Batería → Evitar que el Mac se duerma"
fi

echo
printf '════════════════════════════════════════════════════════════\n'
if   [[ $fallos -eq 0 && $avisos -eq 0 ]]; then printf ' \033[32mTODO LISTO\033[0m\n'
elif [[ $fallos -eq 0 ]]; then printf ' \033[33mLISTO CON %s AVISO(S)\033[0m\n' "$avisos"
else printf ' \033[31m%s PROBLEMA(S) QUE RESOLVER ANTES DE LEVANTAR GITLAB\033[0m\n' "$fallos"; fi
printf '════════════════════════════════════════════════════════════\n'
exit $(( fallos > 0 ? 1 : 0 ))
