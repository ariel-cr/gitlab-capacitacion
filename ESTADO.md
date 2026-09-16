# Estado del laboratorio · traspaso

Documento para retomar el trabajo sin perder contexto. Última
actualización: 16 de septiembre de 2026.

---

## 1 · Qué es esto

Kit práctico para una **capacitación DevOps de 6 horas** (3 h + 3 h en dos
días) en la Fundación Terminal Terrestre de Guayaquil, impartida por Ariel
Cedeño (Iguana Digital).

**Repositorio:** https://github.com/ariel-cr/gitlab-capacitacion
**Carpeta de trabajo:** `C:\Ariel\facturacion\capacitacion\lab` (Windows)
y `~/gitlab-capacitacion` (Mac, donde se ejecuta).

### El material de origen

En `C:\Ariel\facturacion\capacitacion\` hay **5 presentaciones** (142
diapositivas) que ya existen y son **sólo teoría**:

| Tema | Diapositivas | Contenido |
|---|---|---|
| 8 · CI/CD | 37 | Tres ambientes, ramas, Merge Request, pipeline, los servidores reales de DEV/TEST/PROD, el flujo con sus dos promociones |
| 9 · Aprovisionamiento | 25 | Roles control/ejecución, seis componentes, prerrequisitos por servidor |
| 10 · DevOps CI/CD | 25 | Instalar ≠ configurar, cuatro componentes (Runner, ENV, pipeline, K8s), diagrama de ramas |
| 11 · Kubernetes | 20 | Control-plane, worker, pod, Ingress, Traefik |
| 12 · Código | 35 | Objetos de BD, capa MS/ES/US, portal-web, carpetas |

**El laboratorio existe para convertir esa teoría en práctica.** Principio
rector: cada ejercicio apunta a una diapositiva concreta. El pipeline usa
literalmente las cuatro etapas de la diapositiva 23 del Tema 8.

**Plan completo:** `../PLAN-CAPACITACION.md`

---

## 2 · La arquitectura, y cómo se llegó a ella

El diseño cambió varias veces según se aclaraban los requisitos. **El
diseño final es el 4.** Los anteriores se documentan para no volver a
proponerlos.

| # | Diseño | Por qué se descartó |
|---|---|---|
| 1 | Todo en el portátil de cada participante | GitLab CE pide 6 GB; las máquinas de oficina son de 8 GB |
| 2 | GitLab compartido + k3d por participante | Seguía exigiendo Docker Desktop en cada portátil |
| 3 | Mac como servidor + una VM Ubuntu por alumno | 6 VMs × 2 GB no caben en un Air de 16 GB |
| **4** | **Mac con todo dockerizado; los alumnos entran por navegador y git** | **Es el actual** |

### Diseño actual

```
  MAC (servidor)                         WINDOWS de los alumnos
  ┌──────────────────────────┐           ┌──────────────┐
  │ Docker Desktop           │           │  navegador   │
  │  ├── taller-gitlab :8929 │◄──────────┤  + git       │
  │  ├── taller-runner       │    red    │              │
  │  ├── registro      :5000 │  10.35.40 │  nada más    │
  │  ├── amb-dev       :8081 │◄──────────┤  instalado   │
  │  ├── amb-test      :8082 │◄──────────┤              │
  │  └── amb-prod      :8083 │◄──────────┤              │
  └──────────────────────────┘           └──────────────┘
```

**Los alumnos NO necesitan SSH, ni Docker, ni Kubernetes.** Sólo navegador
y Git para Windows. Git funciona sobre HTTP contra el GitLab del Mac.

### Cada ambiente es un servidor, no un contenedor de aplicación

`amb-dev`, `amb-test` y `amb-prod` son **Ubuntu 24.04 con sshd y su propio
dockerd dentro** (`--privileged`). El pipeline:

1. construye una imagen
2. la sube al `registro`
3. entra por SSH al servidor del ambiente
4. **ese servidor baja la imagen y levanta el contenedor en su propio Docker**

Es fiel al Tema 8: cada ambiente tiene sus propias máquinas.

**Kubernetes dentro de cada servidor es opcional:** `CON_KUBERNETES=si`.
Son 369 MB por ambiente frente a 23 MB del Docker solo.

---

## 3 · Datos concretos

| | |
|---|---|
| **Mac** | MacBook Air 15", Apple Silicon (`aarch64` confirmado en los logs), **16 GB** |
| **IP del Mac** | **10.35.40.177** — interfaz `en0` (Wi-Fi), `/24` |
| **Windows de desarrollo** | 10.35.40.129 (misma subred) |
| **Docker Desktop** | tenía 7,7 GB asignados. **Hace falta ≥ 8, recomendado 10** |
| **GitLab** | `root` / `TallerFTTG2026!` |
| **Los 10 usuarios** | `Taller2026!` |
| **Developers** | `dev1` … `dev6` — rol Developer (30) |
| **Aprobadores** | `apr1` … `apr4` — rol Maintainer (40) |
| **Puertos** | 8929 GitLab · 2224 git-ssh · 5000 registro · 8081/8082/8083 ambientes · 2201/2202/2203 ssh de ambientes |
| **Red de Docker** | `taller_default` — el runner y los ambientes tienen que compartirla |

### Consumo de memoria, MEDIDO (no estimado)

| Pieza | En reposo |
|---|---|
| App de demostración (`nginx:alpine`) | 4,3 MB |
| PostgreSQL `16-alpine` | 32,7 MB |
| RabbitMQ `3.13-management-alpine` | 136,8 MB |
| **GitLab Runner** | **23,9 MB** |
| Docker dentro de un contenedor | 23 MB |
| k3s dentro de un contenedor | 369 MB |
| Servidor de ambiente (Ubuntu+sshd+dockerd) | 39 MB · 531 MB en disco |
| **GitLab CE** | **~6 GB** ← el único pesado |

Total del diseño actual: **~10 GB de los 16**. Cabe.

---

## 4 · Fallos ya encontrados y corregidos

**No volver a introducirlos.** Cada uno costó una ronda de depuración.

| # | Fallo | Causa | Arreglo |
|---|---|---|---|
| 1 | Los scripts no arrancaban en macOS | 3 archivos con **CRLF** (editados desde Windows) | Normalizados a LF + `.gitattributes` con `eol=lf` |
| 2 | `provisionar-gitlab.sh` fallaba | usaba `python`, que **no existe en macOS** | Detecta `python3` o `python` en `$PY` |
| 3 | El script abortaba al final | **bash 3.2** de macOS + `set -u` + array vacío | `${DEVS[*]:-ninguno}` |
| 4 | `permission denied` al clonar en Mac | Windows no tiene bit de ejecución | `git update-index --chmod=+x` |
| 5 | El pipeline no resolvía `registro` ni `amb-dev` | Al runner le faltaba `--docker-network-mode` | Añadido `taller_default` |
| 6 | **GitLab en bucle de reinicio** | `grafana['enable']` — **GitLab 19 retiró Grafana**; `Mixlib::Config::UnknownConfigOptionError` | Línea eliminada |
| 7 | GitLab no correría en Apple Silicon | `17.5.2-ce.0` es **sólo amd64** | Fijada **`19.3.2-ce.0`** (amd64 + arm64) |

### Hechos verificados que conviene no volver a investigar

- **GitLab CE publica arm64 desde la 18.11.** Todas las 19.x lo tienen.
- **Las aprobaciones de Merge Request SÍ existen en GitLab CE**, pero son
  **opcionales**: el botón «Approve» aparece y cualquier Developer puede
  pulsarlo, pero **no bloquea la fusión**. Las reglas obligatorias
  («requiere N aprobaciones») son de **Premium**.
  → Por eso la barrera real son las **ramas protegidas**:
  `test` y `master` con `push = nadie`, `merge = Maintainer`.
- **Docker Desktop en Mac es de un solo usuario.** Otro usuario entrando
  por SSH no puede usar `docker`. Por eso se descartó el SSH a macOS.
- El Air es **sin ventilador**: bajo carga sostenida throttlea. Mantenerlo
  enchufado, elevado, con la tapa abierta y `caffeinate -dims`.

---

## 5 · Estado: qué funciona y qué no

### Probado y funcionando

- Construcción de la app de demostración en los 3 ambientes; HTML sin
  marcadores sin sustituir; sirve HTTP 200
- Los 3 ambientes en Docker Compose, perfil mínimo: 13,2 MB, tres HTTP 200
- Imagen del servidor de ambiente: arranca con **dockerd 29.1.3 dentro**,
  sshd activo, 39 MB
- Sintaxis: los 8 scripts, los 4 compose, el `.gitlab-ci.yml`
- Lectura de `usuarios.tsv`: 6 developers + 4 aprobadores

### NO probado todavía

- **`provisionar-gitlab.sh` contra un GitLab real.** Es lo más importante
  que falta. Puntos donde puede fallar:
  - la rama por defecto del proyecto (se protegen `main` y `master` por si acaso)
  - el endpoint `POST /api/v4/user/runners`, que cambió entre GitLab 15 y 16
- `preparar-ambientes.sh` de principio a fin
- El pipeline completo contra los tres servidores
- Las promociones dev → test → prod

---

## 6 · BLOQUEO ACTUAL · la red

**Desde 10.35.40.129 (Windows) no se alcanza 10.35.40.177 (Mac).** Ni
ICMP ni ningún puerto TCP, estando ambos en la misma subred `/24`.

Tres causas posibles, sin discriminar todavía:

1. **No había nada escuchando** — se acababa de hacer `down -v`
2. **Cortafuegos de macOS** (modo *stealth* bloquea ICMP)
3. **Aislamiento de clientes en la Wi-Fi corporativa** ← el grave

### La prueba pendiente

En el Mac:

```bash
python3 -m http.server 8929
```

Y desde otro equipo de la red, intentar `http://10.35.40.177:8929`.

- **Llega** → la red está bien, era que GitLab estaba apagado
- **No llega** → cortafuegos o aislamiento

Comprobar también:

```bash
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode off
```

**Si es aislamiento de la Wi-Fi, el diseño entero no funciona** y hay que:
pedir a redes que habiliten el tráfico entre esos equipos, usar cable, o
montar GitLab en un servidor de la FTTG en vez del Air.

---

## 7 · Los archivos

```
lab/
├── .gitlab-ci.yml                Pipeline · 4 etapas = Tema 8 dp. 23
├── .gitattributes                Fuerza LF (fallo #1)
├── ESTADO.md                     Este documento
├── GUIA-PRIMERA-EJECUCION.md     Paso a paso  ⚠ fase C DESACTUALIZADA
├── README.md                     Guía rápida  ⚠ menciona k3d, desactualizado
├── app/
│   ├── Dockerfile                nginx + sustitución de marcadores
│   ├── index.template.html       Tarjeta de color por ambiente
│   └── test.sh                   Pruebas unitarias (etapa 1)
├── ambientes/
│   ├── Dockerfile                Ubuntu + sshd + dockerd [+ k3s opcional]
│   └── arrancar.sh               Arranca sshd, dockerd y k3s
├── k8s/
│   └── aplicacion.yaml           Deployment+Service+Ingress  ⚠ del diseño 2
├── infra/
│   ├── docker-compose.taller.yml       GitLab + Runner   ← EL QUE SE USA
│   ├── docker-compose.servidores.yml   Los 3 ambientes + registro
│   ├── docker-compose.gitlab.yml       Versión antigua, redundante
│   ├── docker-compose.ambientes.yml         3 ambientes con BD/broker (~595 MB)
│   ├── docker-compose.ambientes-minimo.yml  3 ambientes sólo app (~13 MB)
│   └── usuarios.tsv              Los 10 usuarios, editable
└── scripts/
    ├── 00-verificar.ps1          Requisitos en Windows (para alumnos)
    ├── mac-verificar.sh          Requisitos en el Mac ← EMPEZAR AQUÍ
    ├── provisionar-gitlab.sh     Grupo, proyecto, 10 usuarios, ramas, runner
    ├── preparar-ambientes.sh     Llaves SSH, construye y levanta los 3
    ├── registrar-runner.sh       Registro manual del runner (respaldo)
    ├── crear-cluster.sh          k3d          ⚠ del diseño 2
    ├── kubeconfig-para-gitlab.sh kubeconfig   ⚠ del diseño 2
    ├── aprovisionar.sh           Guion del Tema 9 (no se ejecuta en clase)
    └── mac-crear-vms.sh          VMs Multipass ⚠ del diseño 3
```

**Los marcados ⚠ son de diseños anteriores.** No se han borrado por si se
retoma Kubernetes para el Tema 11, pero **no forman parte del flujo actual**.

---

## 8 · Secuencia de ejecución actual

```bash
cd ~/gitlab-capacitacion && git pull

# 1 · comprobar el Mac (memoria de Docker ≥ 8 GB, socket presente)
./scripts/mac-verificar.sh

# 2 · poner la IP  (¡comillas simples, y -i '' porque es el sed de macOS!)
sed -i '' 's/IP_DEL_SERVIDOR/10.35.40.177/' infra/docker-compose.taller.yml
grep external_url infra/docker-compose.taller.yml      # VERIFICAR

# 3 · GitLab + runner  (4-8 min hasta (healthy))
docker compose -f infra/docker-compose.taller.yml up -d
docker compose -f infra/docker-compose.taller.yml ps

# 4 · usuarios, proyecto, ramas protegidas, runner
./scripts/provisionar-gitlab.sh http://10.35.40.177:8929

# 5 · los tres servidores (~10 min la primera vez)
./scripts/preparar-ambientes.sh
#    → imprime la llave privada; pegarla en GitLab como variable
#      SSH_PRIVADA, tipo File, SIN marcar Protect

# 6 · subir la aplicación al proyecto
cd /tmp && git clone http://10.35.40.177:8929/taller/demo-fttg.git
cd demo-fttg
cp -r ~/gitlab-capacitacion/{app,ambientes,.gitlab-ci.yml} .
git add -A && git commit -m "Aplicacion y pipeline"
git switch dev && git push          # dev1 / Taller2026!
```

### Empezar de cero

```bash
docker compose -f infra/docker-compose.taller.yml down -v
docker compose -f infra/docker-compose.servidores.yml down -v
```

---

## 9 · Lo que falta

1. **Resolver el bloqueo de red** (sección 6). Es lo primero.
2. Ejecutar `provisionar-gitlab.sh` contra el GitLab real y corregir lo
   que salga.
3. Probar el pipeline completo y las dos promociones.
4. **Reescribir la fase C de `GUIA-PRIMERA-EJECUCION.md`**, que todavía
   describe k3d en vez de los tres servidores.
5. Actualizar `README.md`, que también menciona k3d.
6. Decidir si se activa `CON_KUBERNETES=si` para el bloque del Tema 11.
7. Ajustar `PLAN-CAPACITACION.md` al diseño 4 (describe el 2 y el 3).

### Decisiones pendientes del cliente

- ¿Cuántos participantes exactamente? (se habló de 6, y de 6+4 perfiles)
- ¿Se activa Kubernetes dentro de los ambientes, o el Tema 11 queda como
  demostración?
- ¿La política de la FTTG permite `gitlab.com` como plan B, o tiene que
  ser autoalojado sí o sí?
