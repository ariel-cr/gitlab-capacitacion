#!/usr/bin/env bash
# Aprovisionamiento de la máquina del participante.
#
# ESTE SCRIPT NO SE EJECUTA EN CLASE. Existe para dos cosas:
#   · que el capacitador pueda dejar una máquina lista en dos minutos si
#     alguien se queda atrás
#   · que quede por escrito, en orden, lo que se hace a mano durante la sesión
#
# En clase se teclea comando por comando, explicando cada uno. El Tema 9 trata
# precisamente de esto, y ejecutar un script no enseña a aprovisionar nada.
#
#   ./aprovisionar.sh            todo
#   ./aprovisionar.sh docker     sólo hasta Docker (final del día 1)

set -euo pipefail
HASTA="${1:-todo}"

titulo() { printf '\n\033[36m── %s\033[0m\n' "$*"; }
ok()     { printf '  \033[32mok\033[0m %s\n' "$*"; }

# ─────────────────────────────────────────────────── 1 · Lo básico
titulo "1 · Actualizar el índice de paquetes"
# Un servidor recién instalado no sabe qué versiones hay disponibles.
sudo apt-get update -qq
ok "índice actualizado"

titulo "2 · Git"
sudo apt-get install -y -qq git
ok "$(git --version)"

# ─────────────────────────────────────────────────── 3 · Docker
titulo "3 · Docker"
# Tema 9, diapositiva 19: el servidor de réplica lleva sólo Docker, y se
# instala así. Del repositorio de Ubuntu, no del de Docker: es lo que dice el
# documento del proyecto y alcanza de sobra.
sudo apt-get install -y -qq docker.io
sudo systemctl enable --now docker

# Sin esto hay que poner sudo en cada comando de docker. La sesión tiene que
# reabrirse para que el grupo tome efecto.
sudo usermod -aG docker "$USER"
ok "$(sudo docker --version)"
echo "     (cierre la sesión y vuelva a entrar para usar docker sin sudo)"

titulo "4 · Docker Compose"
# Tema 9: sólo DOS de los tres servidores lo necesitan. El de réplica corre un
# único contenedor, así que Docker solo le alcanza. Aquí se instala porque
# esta máquina hace de las tres cosas.
sudo apt-get install -y -qq docker-compose-v2 2>/dev/null \
  || sudo apt-get install -y -qq docker-compose
ok "compose instalado"

if [[ "$HASTA" == "docker" ]]; then
  echo
  ok "Hasta aquí el día 1."
  exit 0
fi

# ─────────────────────────────────────────────────── 5 · Kubernetes
titulo "5 · kubectl"
# El cliente. Por sí solo no hace nada: hace falta un clúster al que hablarle.
ARQ="$(dpkg --print-architecture)"
VER="$(curl -sL https://dl.k8s.io/release/stable.txt)"
curl -sLO "https://dl.k8s.io/release/${VER}/bin/linux/${ARQ}/kubectl"
sudo install -m 0755 kubectl /usr/local/bin/kubectl && rm -f kubectl
ok "$(kubectl version --client --output=yaml | grep gitVersion | head -1 | tr -s ' ')"

titulo "6 · k3d"
# Levanta un k3s real dentro de contenedores de Docker. Por eso el paso 3
# tenía que ir antes: sin Docker, k3d no tiene dónde crear nada.
curl -sL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | sudo bash >/dev/null
ok "$(k3d version | head -1)"

echo
titulo "Resumen de lo instalado"
printf '  %-16s %s\n' "git"     "$(git --version | cut -d' ' -f3)"
printf '  %-16s %s\n' "docker"  "$(sudo docker --version | cut -d' ' -f3 | tr -d ,)"
printf '  %-16s %s\n' "kubectl" "$(kubectl version --client 2>/dev/null | head -1 | awk '{print $3}')"
printf '  %-16s %s\n' "k3d"     "$(k3d version | head -1 | awk '{print $3}')"
echo
echo "El orden no fue casual:"
echo "  · Docker antes que k3d, porque k3d crea sus nodos como contenedores"
echo "  · kubectl antes que el clúster, porque es el cliente y se configura solo"
echo "    cuando el clúster existe"
echo
echo "Siguiente paso:  MINIMO=1 ./crear-cluster.sh"
