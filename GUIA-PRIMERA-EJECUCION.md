# Primera ejecución, paso a paso

Guía para levantar el laboratorio por primera vez en el Mac y comprobar que
funciona, **usted solo**, sin participantes.

Cada paso trae tres cosas: **el comando**, **qué hace** y **qué debe salir**.
Si lo que sale no se parece a lo que dice aquí, pare y mire la última sección.

Son tres fases. Hágalas en orden y no salte a la siguiente hasta que la
anterior esté verde: si algo falla, así sabrá exactamente dónde.

| Fase | Qué comprueba | Tiempo |
|---|---|---|
| **A** | GitLab arranca y los 10 usuarios existen | ~20 min |
| **B** | Un developer NO puede promover; un aprobador sí | ~15 min |
| **C** | El pipeline despliega y se ven las promociones | ~30 min |

---

# FASE A · GitLab y los usuarios

## Paso 1 · Situarse en el repositorio

```bash
cd ~/gitlab-capacitacion
```

**Qué hace:** entra en la carpeta que clonó. Todos los comandos de esta guía
se ejecutan desde aquí, no desde dentro de `scripts/` ni de `infra/`.

**Compruebe que está bien:**

```bash
ls
```

Debe listar `app`, `infra`, `k8s`, `scripts`, `README.md` y `.gitlab-ci.yml`.
Si no los ve, no está en la carpeta correcta.

---

## Paso 2 · Comprobar que el Mac puede con esto

```bash
./scripts/mac-verificar.sh
```

**Qué hace:** no toca nada, sólo mira. Comprueba el chip, la RAM, el disco, si
Docker responde, **cuánta memoria le asignó a Docker**, si existe el socket,
si los puertos 8929 y 2224 están libres, si tiene `python3`, y le dice la IP
del Mac en la red.

**Qué debe salir:** una lista con `[ ok ]` en verde y al final
`TODO LISTO` o `LISTO CON N AVISO(S)`.

**Lo que NO puede estar en rojo:**

- `memoria asignada a Docker` → si dice menos de 8 GB, abra Docker Desktop →
  Settings → Resources → suba **Memory a 8 GB** → Apply & Restart.
  GitLab CE necesita 6 GB sólo para él; con menos no arranca.
- `/var/run/docker.sock NO existe` → Docker Desktop → Settings → Advanced →
  marque **«Allow the default Docker socket to be used»** → reinicie Docker.
  Sin esto, más adelante el pipeline no podrá construir imágenes.
- `puerto 8929 ocupado` → hay otra cosa usándolo. Ciérrela o cambie el puerto
  en `infra/docker-compose.taller.yml`.

**Apunte la IP** que sale al final, en la sección «Red e hibernación». La va a
necesitar en el paso siguiente. Tendrá la forma `192.168.x.x` o `10.x.x.x`.

---

## Paso 3 · Decirle a GitLab cuál es su dirección

```bash
sed -i '' 's/IP_DEL_SERVIDOR/192.168.1.50/' infra/docker-compose.taller.yml
```

**Cambie `192.168.1.50` por la IP que le dio el paso 2.**

**Qué hace:** sustituye el marcador `IP_DEL_SERVIDOR` por la dirección real.
GitLab necesita saber por qué dirección lo van a alcanzar, porque con ella
construye los enlaces de clonado y las redirecciones. Si no coincide con lo
que teclea el usuario, la interfaz funciona pero clonar no.

**El `-i ''` no es un error de tecleo.** El `sed` de macOS exige un argumento
ahí; el de Linux no. Sin esas dos comillas da `invalid command code`.

**Compruebe que quedó bien:**

```bash
grep external_url infra/docker-compose.taller.yml
```

Debe salir su IP, no `IP_DEL_SERVIDOR`:

```
        external_url 'http://192.168.1.50:8929'
```

> Para esta primera prueba también valdría `localhost`. Se usa la IP porque
> así no hay que volver a cambiarlo cuando lleguen los participantes — y
> cambiarla después obliga a un `gitlab-ctl reconfigure` de cinco minutos.

---

## Paso 4 · Arrancar GitLab y el runner

```bash
docker compose -f infra/docker-compose.taller.yml up -d
```

**Qué hace:** descarga las dos imágenes si no las tiene y levanta dos
contenedores: `taller-gitlab` y `taller-runner`. El `-d` los deja corriendo en
segundo plano y le devuelve la terminal.

La primera vez descarga unos 3 GB de GitLab. Con buena red, 5 minutos.

**Qué debe salir:**

```
 ✔ Container taller-gitlab  Started
 ✔ Container taller-runner  Started
```

> El runner arranca **sin registrar** y se queda dando vueltas sin trabajo.
> Es correcto: lo registra el paso 6.

---

## Paso 5 · Esperar a que GitLab esté listo

```bash
docker compose -f infra/docker-compose.taller.yml ps
```

**Qué hace:** muestra el estado de los contenedores.

**Qué debe salir, al principio:**

```
NAME            STATUS
taller-gitlab   Up 2 minutes (health: starting)
taller-runner   Up 2 minutes
```

**Repita el comando cada minuto** hasta que diga `(healthy)`:

```
taller-gitlab   Up 8 minutes (healthy)
```

**Esto tarda entre 4 y 8 minutos.** GitLab arranca PostgreSQL, Redis, Gitaly,
Puma y Sidekiq, y hasta que todos responden no se da por sano. Es normal y no
hay forma de acelerarlo.

Si quiere ver qué está haciendo mientras tanto:

```bash
docker compose -f infra/docker-compose.taller.yml logs -f gitlab
```

Salga con `Ctrl+C` — eso corta el seguimiento del registro, no el contenedor.

---

## Paso 6 · Crear el grupo, el proyecto y los 10 usuarios

**Sólo cuando el paso 5 diga `(healthy)`.**

```bash
./scripts/provisionar-gitlab.sh http://192.168.1.50:8929
```

Con su IP, la misma del paso 3.

**Qué hace, en orden:**

1. Espera a que `/-/health` responda.
2. Entra al contenedor y acuña un token de administrador con `gitlab-rails`
   (no necesita credenciales porque se ejecuta por dentro).
3. Crea el grupo `taller`.
4. Crea el proyecto `taller/demo-fttg` con un README inicial.
5. Crea los 10 usuarios de `infra/usuarios.tsv` y los mete al proyecto con su
   rol: los `dev*` como **Developer**, los `apr*` como **Maintainer**.
6. Crea las ramas `dev` y `test`.
7. **Protege las ramas** — aquí está lo importante del taller.
8. Registra el runner contra el proyecto.

**Qué debe salir:** una lista de `ok` en verde y al final un recuadro:

```
 GitLab del taller listo
 ...
  Developers (6)   dev1 dev2 dev3 dev4 dev5 dev6
  Aprobadores (4)  apr1 apr2 apr3 apr4

  Ramas protegidas
     dev      push Developer   merge Developer
     test     push nadie       merge aprobadores
     master   push nadie       merge aprobadores
```

**Se puede volver a ejecutar** las veces que haga falta. Lo que ya existe lo
respeta y sólo crea lo que falte.

---

## Paso 7 · Mirarlo con sus ojos

Abra en el navegador: **`http://192.168.1.50:8929`**

Entre como **`root`** con la contraseña **`TallerFTTG2026!`**

Compruebe tres cosas:

| Dónde | Qué debe ver |
|---|---|
| Arriba a la izquierda → **Admin** → **Users** | **11** usuarios: root y los 10 del taller |
| Proyecto `taller/demo-fttg` → **Manage** → **Members** | 6 con rol *Developer*, 4 con *Maintainer* |
| Proyecto → **Settings** → **Repository** → **Protected branches** | `dev`, `test`, `main` y `master` en la lista |

Si las tres están, **la fase A terminó**.

---

# FASE B · Comprobar que la protección funciona

Esto es lo que de verdad hay que probar: que un developer **no pueda**
promover a test ni a producción. Se hace haciéndose pasar por dos personas.

## Paso 8 · Trabajar como developer

Cierre la sesión de `root` (arriba a la derecha → Sign out).

```bash
cd /tmp
git clone http://192.168.1.50:8929/taller/demo-fttg.git
cd demo-fttg
```

**Qué hace:** descarga el proyecto a una carpeta temporal. Le pedirá usuario y
contraseña: **`dev1`** / **`Taller2026!`**

Se usa `/tmp` a propósito, para no mezclarlo con el repositorio del
laboratorio.

```bash
git switch dev
```

**Qué hace:** se pasa a la rama `dev`, que es donde los developers pueden
trabajar libremente.

```bash
echo "Cambio de prueba de dev1" >> README.md
git commit -am "Prueba de dev1"
git push
```

**Qué hace:** modifica un archivo, lo registra y lo sube.

**Qué debe salir:** el push **funciona**. `dev` es la rama de los developers y
tienen permiso de empuje.

---

## Paso 9 · Intentar promover (esto debe FALLAR)

En el navegador, entre como **`dev1`** / `Taller2026!`

Vaya al proyecto → **Merge requests** → **New merge request**

- Source branch: **`dev`**
- Target branch: **`test`**
- **Create merge request**

**Qué debe ver en el Merge Request:**

- El botón **«Approve»** — sí existe, y dev1 puede pulsarlo
- El botón de fusionar **deshabilitado**, o un aviso de que no tiene permiso
  para fusionar en esta rama

> **Por qué es así.** En GitLab CE el botón «Approve» existe pero es
> **opcional**: no bloquea nada. Las reglas de aprobación obligatorias son de
> GitLab Premium. Quien impide de verdad que un developer promueva es la
> **protección de rama**: `test` tiene `merge` restringido a Maintainer.
>
> Si dev1 SÍ puede fusionar, la protección no quedó bien. Vuelva al paso 6.

---

## Paso 10 · Promover como aprobador

Cierre sesión. Entre como **`apr1`** / `Taller2026!`

Abra el mismo Merge Request.

**Ahora sí** aparece el botón de fusionar. Púlselo.

**Eso es la primera promoción: DEV → TEST.**

Repita el ejercicio con un Merge Request de **`test` a `master`** para la
segunda promoción. Sólo `apr1` puede hacerla.

Con esto la fase B está comprobada y el taller ya se sostiene.

---

# FASE C · El clúster y el pipeline

Sólo cuando A y B funcionen.

## Paso 11 · Instalar las herramientas de Kubernetes

```bash
brew install k3d kubectl
```

**Qué hace:** instala `k3d`, que levanta un Kubernetes real dentro de
contenedores de Docker, y `kubectl`, que es el cliente para hablarle.

---

## Paso 12 · Crear el clúster y los tres ambientes

```bash
MINIMO=1 ./scripts/crear-cluster.sh
```

**Qué hace:** crea un clúster de un nodo, un registro de imágenes local, y los
tres namespaces `dev`, `test` y `prod`. Tarda menos de un minuto.

`MINIMO=1` deja un solo nodo, que es lo que conviene en un MacBook Air. Sin esa
variable crea dos (control-plane y worker).

**Compruebe:**

```bash
kubectl get nodes
kubectl get namespaces -l ambiente
```

---

## Paso 13 · Darle al pipeline acceso al clúster

```bash
./scripts/kubeconfig-para-gitlab.sh
```

**Qué hace:** imprime un kubeconfig con la dirección del clúster **reescrita**.

> **Por qué hace falta.** El kubeconfig normal apunta a `127.0.0.1`. Eso sirve
> para usted desde la terminal, pero el trabajo del pipeline corre dentro de
> un contenedor, donde `127.0.0.1` es el propio contenedor. Hay que apuntar al
> nombre que el clúster tiene dentro de la red de Docker.

Copie el bloque entre las líneas `COPIE DESDE AQUÍ` y `HASTA AQUÍ`, y péguelo
en GitLab, como `root`:

**Settings → CI/CD → Variables → Add variable**

| Campo | Valor |
|---|---|
| Key | `KUBECONFIG` |
| Type | **File** ← no «Variable» |
| Value | el bloque copiado |
| Protect variable | **desmarcado** ← si lo marca, `dev` y `test` no lo verán |

---

## Paso 14 · Que el pipeline despliegue

```bash
cd /tmp/demo-fttg
```

Copie el laboratorio dentro del proyecto:

```bash
cp -r ~/gitlab-capacitacion/{app,k8s,.gitlab-ci.yml} .
git add -A
git commit -m "Anade la aplicacion y el pipeline"
git push
```

Abra **Build → Pipelines** en GitLab y véalo correr: `unit-test`, `analisis`,
`build`, `deploy`.

Cuando termine, abra **http://dev.demo.localhost:8080**

---

# Apagar y empezar de cero

**Parar sin perder nada:**

```bash
docker compose -f infra/docker-compose.taller.yml stop
```

**Volver a arrancar:**

```bash
docker compose -f infra/docker-compose.taller.yml start
```

**Borrarlo TODO y empezar limpio** (se pierden usuarios y proyectos):

```bash
docker compose -f infra/docker-compose.taller.yml down -v
./scripts/crear-cluster.sh --borrar
```

El `-v` borra también los volúmenes. Sin él, GitLab conserva los datos.

---

# Si algo falla

| Síntoma | Causa y salida |
|---|---|
| `sed: invalid command code` | Le faltaron las comillas: `sed -i ''` |
| GitLab nunca llega a `healthy` | Memoria de Docker. `docker compose -f infra/docker-compose.taller.yml logs gitlab \| tail -50` |
| «GitLab no respondió en 10 minutos» | La IP del `external_url` y la que pasó al script deben ser **la misma** |
| «No se pudo acuñar el token» | Arrancó pero aún no está del todo. Espere 2 minutos y repita el paso 6 |
| «Falta Python» | `xcode-select --install` |
| `permission denied` al ejecutar un script | `chmod +x scripts/*.sh app/test.sh` |
| El clon rechaza la contraseña | Es `Taller2026!`, no un token. Y el usuario es `dev1`, no su correo |
| dev1 SÍ puede fusionar a `test` | La protección no se aplicó. Repita el paso 6 y revise Protected branches |
| El pipeline falla en `build` | El socket de Docker. Paso 2, Settings → Advanced |
| `deploy` dice «connection refused» | Rehaga el paso 13; el kubeconfig apunta a `127.0.0.1` |
| `dev.demo.localhost` no abre | Use Chrome o Edge; Safari no resuelve `*.localhost` |

---

## Contraseñas

| Quién | Usuario | Contraseña |
|---|---|---|
| Administrador | `root` | `TallerFTTG2026!` |
| Developers | `dev1` … `dev6` | `Taller2026!` |
| Aprobadores | `apr1` … `apr4` | `Taller2026!` |

Cámbielas en `infra/docker-compose.taller.yml` y en `CLAVE_USUARIOS` del
script si el aula no es de confianza.
