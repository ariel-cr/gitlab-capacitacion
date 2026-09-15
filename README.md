# Laboratorio · Capacitación DevOps FTTG

Guía rápida para el participante. El plan completo, con tiempos y con el
porqué de cada decisión, está en [`../PLAN-CAPACITACION.md`](../PLAN-CAPACITACION.md).

---

## Antes de venir

```powershell
powershell -ExecutionPolicy Bypass -File scripts\00-verificar.ps1
```

Si algo sale en rojo, vuelva a correrlo con `-Instalar` y mande el resultado al
capacitador. **No espere al día de la clase para hacerlo.**

---

## Día 1 · Del código al pipeline

```bash
# 1. Su repositorio
git config --global user.name "Nombre Apellido"
git config --global user.email "nombre@ttg.ec"
git init && git add . && git commit -m "Primer commit"

# 2. Las ramas del proyecto
git switch -c dev
git switch -c test
git switch -c feature/mi-cambio
git log --oneline --graph --all

# 3. Subirlo a GitLab
git remote add origin http://<IP-DEL-AULA>:8929/taller/demo-<su-nombre>.git
git push -u origin master
git push origin dev test

# 4. Los tres ambientes con Docker Compose
#    PERFIL MINIMO (maquinas de 8 GB) - 3 contenedores, ~13 MB
docker compose -f infra/docker-compose.ambientes-minimo.yml up -d --build
#    PERFIL COMPLETO (16 GB) - anade bases de datos y brokers, ~595 MB
# docker compose -f infra/docker-compose.ambientes.yml up -d
#   DEV  → http://localhost:8081   (verde)
#   TEST → http://localhost:8082   (ámbar)
#   PROD → http://localhost:8083   (azul)

# 5. Su GitLab Runner
#    Token: GitLab → Settings → CI/CD → Runners → New project runner
#    Etiqueta: taller
./scripts/registrar-runner.sh http://<IP-DEL-AULA>:8929 glrt-XXXXXXXX
```

Al terminar el día 1, apague los ambientes para dejarle sitio al clúster:

```bash
docker compose -f infra/docker-compose.ambientes-minimo.yml down
```

---

## Día 2 · Del pipeline a Kubernetes

```bash
# 1. El clúster y los tres ambientes
MINIMO=1 ./scripts/crear-cluster.sh    # 1 nodo, para maquinas de 8 GB
# ./scripts/crear-cluster.sh           # 2 nodos, para 16 GB
kubectl get nodes -o wide
kubectl get namespaces -l ambiente

# 2. El kubeconfig que verá el pipeline
./scripts/kubeconfig-para-gitlab.sh
#    Péguelo en GitLab → Settings → CI/CD → Variables
#      Key    : KUBECONFIG
#      Type   : File        ← tipo Archivo, no Variable
#      Protect: NO          ← si lo protege, dev y test no lo verán

# 3. Un cambio que recorre los tres ambientes
git switch dev
#    …editar app/index.template.html…
git commit -am "Mi cambio" && git push
```

Deje estas tres pestañas abiertas y mírelas mientras promueve:

| Ambiente | Dirección |
|---|---|
| DEV | http://dev.demo.localhost:8080 |
| TEST | http://test.demo.localhost:8080 |
| PROD | http://prod.demo.localhost:8080 |

Las promociones son dos Merge Requests: `dev` → `test`, y `test` → `master`.
El despliegue a producción **no es automático**: hay que pulsar el botón.

---

## Comandos que va a necesitar

```bash
# Ver qué hay en cada ambiente
kubectl get pods,svc,ingress -n dev
kubectl get deploy -A -l app=demo-fttg \
  -o custom-columns=AMBIENTE:.metadata.namespace,IMAGEN:.spec.template.spec.containers[0].image

# Cuando un pod no arranca
kubectl describe pod -n dev <nombre>
kubectl logs -n dev <nombre>

# El runner
docker logs taller-runner --tail 20

# Empezar de cero
./scripts/crear-cluster.sh --borrar && ./scripts/crear-cluster.sh
```

---

## Si algo falla

| Síntoma | Qué hacer |
|---|---|
| El runner sale en gris en GitLab | `docker logs taller-runner` — casi siempre no alcanza la URL del GitLab |
| `deploy` dice «connection refused» | Rehacer el kubeconfig con `kubeconfig-para-gitlab.sh` |
| «variable KUBECONFIG no encontrada» en `dev` | Está marcada como **Protect**. Quítelo |
| `ImagePullBackOff` | La imagen no llegó al registro. `docker push localhost:5111/...` |
| `dev.demo.localhost` no abre | Use Chrome o Edge |
| En Git Bash, rutas de contenedor que fallan | `export MSYS_NO_PATHCONV=1` |
| Todo lentísimo | Docker Desktop → Settings → Resources → 8 GB |

---

## Qué es cada archivo

| | |
|---|---|
| `.gitlab-ci.yml` | El pipeline. Cuatro etapas: `unit-test`, `analisis`, `build`, `deploy` |
| `app/Dockerfile` | La imagen. Recibe el ambiente y la versión como argumentos de build |
| `app/index.template.html` | La tarjeta de color que cambia según el ambiente |
| `app/test.sh` | Las pruebas unitarias que corre la primera etapa |
| `k8s/aplicacion.yaml` | Deployment, Service e Ingress. **Un solo archivo para los tres ambientes** |
| `infra/docker-compose.ambientes-minimo.yml` | Los tres ambientes, perfil mínimo (~13 MB) |
| `infra/docker-compose.ambientes.yml` | Los tres ambientes con BD y broker (~595 MB) |
| `infra/docker-compose.gitlab.yml` | El GitLab del aula. Lo levanta el capacitador |
| `scripts/` | Verificación, clúster, runner y kubeconfig |
