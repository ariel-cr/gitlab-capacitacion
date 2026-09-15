#!/usr/bin/env bash
# Crea una máquina Ubuntu por participante en el Mac que hace de servidor.
#
# Se ejecuta EN EL MAC, una vez, antes del día 1.
#
#   ./mac-crear-vms.sh 6              crea alumno1 … alumno6
#   ./mac-crear-vms.sh 6 --borrar     las elimina
#
# Las máquinas se crean VACÍAS, con Ubuntu recién instalado y nada más. Eso es
# deliberado: aprovisionarlas es el ejercicio del Tema 9, y si vinieran con
# Docker puesto no habría nada que enseñar.
#
# Requisitos en el Mac:
#   brew install --cask multipass
#
# Red: las máquinas se crean en modo puente para que cada una tenga una IP de
# la red del aula y los participantes lleguen por SSH directamente, sin saltar
# por el Mac. Si el puente no está disponible, vea el final del script.

set -euo pipefail

CANTIDAD="${1:-6}"
INTERFAZ="${INTERFAZ:-en0}"      # en0 suele ser Wi-Fi; en Ethernet, suele ser en1
CPUS="${CPUS:-2}"
MEMORIA="${MEMORIA:-2G}"
DISCO="${DISCO:-12G}"

command -v multipass >/dev/null || { echo "Falta multipass: brew install --cask multipass"; exit 1; }

if [[ "${2:-}" == "--borrar" ]]; then
  for i in $(seq 1 "$CANTIDAD"); do multipass delete "alumno$i" 2>/dev/null || true; done
  multipass purge
  echo "Máquinas eliminadas."
  exit 0
fi

# Clave pública del capacitador, para poder entrar a todas sin contraseña.
LLAVE="$HOME/.ssh/id_ed25519.pub"
[[ -f "$LLAVE" ]] || ssh-keygen -t ed25519 -N "" -f "${LLAVE%.pub}"

echo "Creando $CANTIDAD máquinas de $MEMORIA y $CPUS CPU…"
echo

for i in $(seq 1 "$CANTIDAD"); do
  NOMBRE="alumno$i"
  if multipass list | grep -q "^$NOMBRE "; then
    echo "  $NOMBRE ya existe, se omite"
    continue
  fi

  # cloud-init mínimo: sólo crea el usuario y mete la llave. NADA más:
  # ni Docker, ni nada. Eso lo instalan ellos, que es la clase.
  cat > "/tmp/init-$NOMBRE.yaml" <<EOF
#cloud-config
users:
  - name: alumno
    groups: [sudo]
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    lock_passwd: false
    # contraseña: taller2026  (para quien prefiera entrar sin llave)
    passwd: \$6\$rounds=4096\$saltsalt\$0GRQPzIuNPQcT9R1cLcNzIPqOPFHfBfQZvJvZ8IqLKvJQmYQEq9oVGPTfPqLMnGEoLzZ.NqQ5jX0Zf5hZ8rXo1
    ssh_authorized_keys:
      - $(cat "$LLAVE")
ssh_pwauth: true
EOF

  echo "  creando $NOMBRE…"
  multipass launch 24.04 \
    --name "$NOMBRE" \
    --cpus "$CPUS" \
    --memory "$MEMORIA" \
    --disk "$DISCO" \
    --cloud-init "/tmp/init-$NOMBRE.yaml" \
    ${PUENTE:+--network "$INTERFAZ"} \
    >/dev/null
  rm -f "/tmp/init-$NOMBRE.yaml"
done

echo
echo "════════════════════════════════════════════════════════════"
echo " Máquinas listas"
echo "════════════════════════════════════════════════════════════"
multipass list
echo
echo "Reparto para los participantes:"
for i in $(seq 1 "$CANTIDAD"); do
  IP="$(multipass info "alumno$i" --format csv 2>/dev/null | tail -1 | cut -d, -f3)"
  printf "  alumno%-3s  ssh alumno@%s   (contraseña: taller2026)\n" "$i" "${IP:-?}"
done
echo
echo "Si las IP son 192.168.64.x, están en la red interna del Mac y los"
echo "participantes NO llegan desde sus equipos. Dos salidas:"
echo
echo "  a) Rehacerlas en modo puente, para que tomen IP del aula:"
echo "       multipass set local.bridged-network=$INTERFAZ"
echo "       PUENTE=1 $0 $CANTIDAD"
echo
echo "  b) Dejarlas como están y que salten por el Mac:"
echo "       ssh -J usuario@<ip-del-mac> alumno@192.168.64.x"
