#!/usr/bin/env bash
# Genera el kubeconfig que el pipeline necesita para desplegar en el clúster.
#
# Es el paso que más se atasca, y conviene entender por qué existe:
#
#   El kubeconfig que k3d deja en su máquina apunta a 127.0.0.1:<puerto>.
#   Eso vale para USTED, desde el escritorio. Pero el job del pipeline no corre
#   en su escritorio: corre dentro de un contenedor, en la red de Docker. Desde
#   ahí, 127.0.0.1 es el propio contenedor, no el clúster.
#
#   Por eso hay que reescribir la dirección del servidor para que apunte al
#   nombre que el clúster tiene DENTRO de la red: k3d-taller-server-0:6443.
#
#   ./kubeconfig-para-gitlab.sh
#
# Copie el bloque que imprime y péguelo en GitLab:
#   Settings → CI/CD → Variables → Add variable
#     Key   : KUBECONFIG
#     Type  : File          ← importante, tipo Archivo, no Variable
#     Value : (el bloque)
#     Flags : Protect = NO  ← si lo protege, las ramas dev y test no lo verán

set -euo pipefail

CLUSTER="taller"
SALIDA="${1:-}"

command -v k3d >/dev/null || { echo "Falta k3d."; exit 1; }
k3d cluster list | grep -q "^$CLUSTER " || { echo "No existe el clúster $CLUSTER."; exit 1; }

# Dirección interna del servidor del clúster, la que sí resuelve desde la red
# de Docker donde corren los jobs.
INTERNO="https://k3d-${CLUSTER}-server-0:6443"

CONFIG="$(k3d kubeconfig get "$CLUSTER" \
  | sed -E "s#server: https?://[^[:space:]]+#server: ${INTERNO}#")"

# Comprobación: si la sustitución no ocurrió, mejor avisar ahora que descubrirlo
# con un pipeline en rojo delante de doce personas.
if ! grep -q "$INTERNO" <<<"$CONFIG"; then
  echo "No se pudo reescribir la dirección del servidor. Revise la salida de:"
  echo "  k3d kubeconfig get $CLUSTER"
  exit 1
fi

if [[ -n "$SALIDA" ]]; then
  printf '%s\n' "$CONFIG" > "$SALIDA"
  echo "Escrito en $SALIDA"
else
  echo "════════ COPIE DESDE AQUÍ ════════"
  printf '%s\n' "$CONFIG"
  echo "════════ HASTA AQUÍ ══════════════"
fi

echo
echo "Comprobación rápida, desde un contenedor en la misma red que el runner:"
echo "  docker run --rm --network k3d-${CLUSTER} \\"
echo "    -v \$PWD/kubeconfig:/kc bitnami/kubectl:1.31 --kubeconfig=/kc get nodes"
