#!/usr/bin/env bash
# Crea el clúster de Kubernetes del laboratorio y sus tres ambientes.
#
# Se usa k3d, que levanta un k3s real dentro de contenedores Docker. Es
# Kubernetes de verdad —mismos objetos, mismo kubectl, mismo Traefik— pero
# arranca en menos de un minuto y cabe en un portátil. Un kubeadm de verdad
# sobre tres máquinas se lleva la mañana entera, y no es lo que se quiere
# enseñar en tres horas.
#
#   ./crear-cluster.sh            crea el clúster (2 nodos)
#   MINIMO=1 ./crear-cluster.sh   perfil mínimo: 1 solo nodo, ~250 MB menos
#   ./crear-cluster.sh --borrar   lo destruye
#
# El perfil mínimo es para máquinas de oficina de 8 GB. Lo único que se pierde
# es poder señalar dos líneas distintas en `kubectl get nodes` y decir «este
# es el control-plane y este el worker»: con un nodo, ese nodo hace los dos
# papeles. Namespaces, Ingress, Traefik, despliegues y promociones son
# idénticos.

set -euo pipefail

CLUSTER="taller"
REGISTRO="taller-registry"
PUERTO_REGISTRO="5111"
PUERTO_HTTP="8080"

rojo()  { printf '\033[31m%s\033[0m\n' "$*"; }
verde() { printf '\033[32m%s\033[0m\n' "$*"; }
info()  { printf '\033[36m%s\033[0m\n' "$*"; }

if [[ "${1:-}" == "--borrar" ]]; then
  info "Borrando el clúster $CLUSTER…"
  k3d cluster delete "$CLUSTER" 2>/dev/null || true
  k3d registry delete "$REGISTRO" 2>/dev/null || true
  verde "Listo. No queda nada."
  exit 0
fi

command -v k3d >/dev/null || { rojo "Falta k3d. Instálelo con scripts/00-verificar."; exit 1; }
docker info >/dev/null 2>&1 || { rojo "Docker no responde. Arranque Docker Desktop."; exit 1; }

if k3d cluster list | grep -q "^$CLUSTER "; then
  info "El clúster $CLUSTER ya existe. Si quiere rehacerlo: $0 --borrar"
else
  # 1 servidor (control-plane) + 1 agente (worker): los dos roles del Tema 9,
  # uno manda y otro trabaja. En perfil mínimo se deja sólo el servidor, que
  # entonces hace ambos papeles.
  if [[ -n "${MINIMO:-}" ]]; then
    AGENTES=0
    info "Creando el clúster «$CLUSTER» en PERFIL MÍNIMO (1 nodo)…"
  else
    AGENTES=1
    info "Creando el clúster «$CLUSTER» (2 nodos)…"
  fi
  k3d cluster create "$CLUSTER" \
    --servers 1 \
    --agents "$AGENTES" \
    --registry-create "$REGISTRO:0.0.0.0:$PUERTO_REGISTRO" \
    --port "$PUERTO_HTTP:80@loadbalancer" \
    --k3s-arg "--disable=metrics-server@server:0" \
    --wait
  verde "Clúster creado."
fi

info "Creando los tres ambientes como namespaces…"
for ambiente in dev test prod; do
  kubectl create namespace "$ambiente" --dry-run=client -o yaml | kubectl apply -f -
  kubectl label namespace "$ambiente" ambiente="$ambiente" --overwrite >/dev/null
done

echo
verde "════════════════════════════════════════════════════════════"
verde " Clúster listo"
verde "════════════════════════════════════════════════════════════"
kubectl get nodes -o wide
echo
kubectl get namespaces -l ambiente
echo
info "Registro de imágenes : localhost:$PUERTO_REGISTRO  (desde el clúster: $REGISTRO:5000)"
info "Entrada HTTP         : http://localhost:$PUERTO_HTTP"
info "Ambientes            : http://dev.demo.localhost:$PUERTO_HTTP"
info "                       http://test.demo.localhost:$PUERTO_HTTP"
info "                       http://prod.demo.localhost:$PUERTO_HTTP"
echo
info "Red de Docker del clúster: k3d-$CLUSTER"
info "  (el runner tiene que estar en esa red para poder desplegar)"
