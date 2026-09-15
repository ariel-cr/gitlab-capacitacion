#!/usr/bin/env bash
# Registra el GitLab Runner del alumno y lo deja corriendo.
#
# Cada alumno registra el SUYO, contra el GitLab compartido del aula. Es el
# ejercicio del Tema 10, componente 1 de 4: "GitLab Runner y configuración".
#
#   ./registrar-runner.sh http://192.168.1.50:8929 glrt-xxxxxxxxxxxx
#                         └─ URL del GitLab        └─ token del proyecto
#
# El token se saca en el proyecto de GitLab:
#   Settings → CI/CD → Runners → New project runner
#   (marcar "Run untagged jobs" NO hace falta: usamos la etiqueta `taller`)

set -euo pipefail

GITLAB_URL="${1:-}"
TOKEN="${2:-}"
CLUSTER="taller"
NOMBRE="runner-$(whoami 2>/dev/null || echo alumno)"
RED="k3d-${CLUSTER}"

if [[ -z "$GITLAB_URL" || -z "$TOKEN" ]]; then
  echo "Uso: $0 <url-de-gitlab> <token-del-runner>"
  echo "Ej.: $0 http://192.168.1.50:8929 glrt-ABC123..."
  exit 1
fi

if ! docker network inspect "$RED" >/dev/null 2>&1; then
  echo "No existe la red $RED. Cree primero el clúster: ./crear-cluster.sh"
  exit 1
fi

echo "Limpiando un runner anterior, si lo hubiera…"
docker rm -f taller-runner >/dev/null 2>&1 || true

echo "Creando el runner…"
docker volume create taller-runner-config >/dev/null

# El registro es NO INTERACTIVO a propósito: en un aula, doce personas
# respondiendo siete preguntas cada una es donde se pierde media hora.
docker run --rm \
  -v taller-runner-config:/etc/gitlab-runner \
  gitlab/gitlab-runner:v17.5.3 register \
    --non-interactive \
    --url "$GITLAB_URL" \
    --token "$TOKEN" \
    --executor docker \
    --docker-image alpine:3.20 \
    --description "$NOMBRE" \
    --docker-privileged=false \
    --docker-volumes "/var/run/docker.sock:/var/run/docker.sock" \
    --docker-network-mode "$RED" \
    --docker-pull-policy if-not-present

echo "Arrancando el runner…"
docker run -d --name taller-runner --restart unless-stopped \
  -v taller-runner-config:/etc/gitlab-runner \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --network "$RED" \
  gitlab/gitlab-runner:v17.5.3

echo
echo "Runner arriba. Compruébelo en GitLab: Settings → CI/CD → Runners"
echo "Debe aparecer «$NOMBRE» con un punto verde."
echo
echo "Tres cosas que se le configuraron, y por qué:"
echo "  · executor docker        → cada job corre en un contenedor limpio"
echo "  · monta docker.sock      → para que el job pueda construir imágenes"
echo "  · red $RED   → para que alcance el clúster y el registro"
echo
docker logs --tail 12 taller-runner
