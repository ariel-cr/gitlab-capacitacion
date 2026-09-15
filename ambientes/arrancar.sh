#!/bin/bash
# Arranca los servicios del servidor: sshd, dockerd y, si toca, k3s.
#
# Sin systemd. En un contenedor systemd es más lío que ayuda, y lo que se
# quiere enseñar aquí es el despliegue, no el arranque del sistema.

set -e

echo "════════════════════════════════════════════"
echo " Servidor $AMBIENTE"
echo "════════════════════════════════════════════"

# ── SSH ─────────────────────────────────────────────────────────────────
/usr/sbin/sshd
echo "  [ok] sshd        puerto 22"

# ── Docker ──────────────────────────────────────────────────────────────
# Este es el Docker DEL SERVIDOR, distinto del Docker del Mac. Aquí es donde
# el pipeline va a levantar los contenedores de la aplicación.
dockerd >/var/log/dockerd.log 2>&1 &
for i in $(seq 1 30); do
  if docker info >/dev/null 2>&1; then
    echo "  [ok] dockerd     $(docker version --format '{{.Server.Version}}')"
    break
  fi
  [ "$i" = 30 ] && echo "  [!!] dockerd no arrancó — vea /var/log/dockerd.log"
  sleep 1
done

# ── Kubernetes, si se pidió al construir ────────────────────────────────
if [ "$CON_KUBERNETES" = "si" ] && command -v k3s >/dev/null 2>&1; then
  k3s server --disable=traefik --disable=metrics-server \
             --write-kubeconfig-mode=644 >/var/log/k3s.log 2>&1 &
  echo "  [..] k3s         arrancando (tarda ~40 s)"
  ( for i in $(seq 1 60); do
      if k3s kubectl get nodes >/dev/null 2>&1; then
        echo "  [ok] k3s         $(k3s kubectl get nodes --no-headers | awk '{print $1" "$2}')"
        break
      fi
      sleep 1
    done ) &
fi

# ── nginx no: lo sirve el contenedor que despliegue el pipeline ─────────
# El servidor arranca VACÍO. Que no haya nada en el puerto 80 hasta el primer
# despliegue es correcto y es parte de la lección: un servidor aprovisionado
# no es un servidor con la aplicación puesta.
echo "  [--] puerto 80   libre, esperando el primer despliegue"
echo

# Mantener el contenedor vivo mostrando el registro de dockerd.
exec tail -f /var/log/dockerd.log
