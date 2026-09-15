# Imagen de la aplicación de demostración.
#
# Es deliberadamente mínima: nginx sirviendo un HTML. No hay lenguaje que
# compilar ni dependencias que descargar, así que el `build` del pipeline tarda
# segundos y la clase no se queda mirando una barra de progreso.
#
# Lo único que hace es enseñar, muy grande, EN QUÉ AMBIENTE está corriendo y
# QUÉ VERSIÓN. Eso es todo lo que hace falta para ver una promoción en vivo.

FROM nginx:1.27-alpine

# Datos que inyecta el pipeline en tiempo de build. Los valores por defecto
# permiten construir la imagen a mano, fuera de GitLab, para probar.
ARG AMBIENTE=local
ARG VERSION=0.0.0
ARG COMMIT=sin-commit
ARG RAMA=sin-rama
ARG PIPELINE=0

COPY index.template.html /tmp/index.template.html

# El color se deriva del ambiente: verde para dev, ámbar para test, azul para
# prod. Que cada ambiente tenga su color es lo que hace que la promoción se
# entienda de un vistazo, sin leer.
RUN set -eu; \
    case "$AMBIENTE" in \
      dev)  COLOR="#0f5f3d"; TEXTO="#eafff5" ;; \
      test) COLOR="#8a5412"; TEXTO="#fff4e2" ;; \
      prod) COLOR="#123a63"; TEXTO="#e6f1ff" ;; \
      *)    COLOR="#2b2b2b"; TEXTO="#f0f0f0" ;; \
    esac; \
    FECHA="$(date -u '+%Y-%m-%d %H:%M UTC')"; \
    sed -e "s|__AMBIENTE__|${AMBIENTE}|g" \
        -e "s|__VERSION__|${VERSION}|g" \
        -e "s|__COMMIT__|${COMMIT}|g" \
        -e "s|__RAMA__|${RAMA}|g" \
        -e "s|__PIPELINE__|${PIPELINE}|g" \
        -e "s|__FECHA__|${FECHA}|g" \
        -e "s|__COLOR__|${COLOR}|g" \
        -e "s|__TEXTO__|${TEXTO}|g" \
        /tmp/index.template.html > /usr/share/nginx/html/index.html; \
    rm /tmp/index.template.html

# Sonda de salud: la usa Kubernetes para saber si el pod está listo.
HEALTHCHECK --interval=10s --timeout=3s CMD wget -qO- http://localhost/ >/dev/null || exit 1

EXPOSE 80
