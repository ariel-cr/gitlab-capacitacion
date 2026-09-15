# Un "servidor" del laboratorio: Ubuntu con SSH y nginx.
#
# Cada ambiente —dev, test y prod— es un contenedor de estos. No son
# contenedores de aplicación: son SERVIDORES. Se entra por SSH, se mira el
# sistema de archivos, se reinicia el servicio. Exactamente lo que describe el
# Tema 9, pero cabiendo en un Mac.
#
# El despliegue se hace copiando por SSH, que es como se despliega en un
# servidor de verdad. No con `docker cp`, que sería el atajo y no enseñaría
# nada.

FROM ubuntu:24.04

ARG AMBIENTE=dev

ENV DEBIAN_FRONTEND=noninteractive
ENV AMBIENTE=${AMBIENTE}

RUN apt-get update && apt-get install -y --no-install-recommends \
        openssh-server \
        nginx \
        ca-certificates \
        curl \
        vim-tiny \
        less \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/sshd /var/www/html

# Usuario de despliegue. El pipeline entra como él; los participantes también,
# para mirar. Sin contraseña: sólo con la llave que inyecta preparar-ambientes.
RUN useradd -m -s /bin/bash despliegue \
    && mkdir -p /home/despliegue/.ssh \
    && chmod 700 /home/despliegue/.ssh \
    && chown -R despliegue:despliegue /home/despliegue/.ssh \
    && chown -R despliegue:www-data /var/www/html \
    && chmod 775 /var/www/html

# La llave pública del runner. La genera preparar-ambientes.sh y se copia al
# contexto de build; así el pipeline puede entrar sin contraseña.
COPY --chown=despliegue:despliegue llave.pub /home/despliegue/.ssh/authorized_keys
RUN chmod 600 /home/despliegue/.ssh/authorized_keys

# Sin contraseñas por SSH: sólo llave. Es lo correcto y además evita que
# alguien entre por fuerza bruta en una red de aula.
RUN sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

# Página inicial, para que el ambiente responda algo antes del primer
# despliegue. Así se distingue "vacío" de "caído".
RUN printf '<!doctype html><meta charset="utf-8">\
<title>%s · sin desplegar</title>\
<body style="font-family:system-ui;display:grid;place-items:center;height:100vh;margin:0;background:#2b2b2b;color:#ddd">\
<div style="text-align:center">\
<p style="font-size:14vw;font-weight:800;margin:0;text-transform:uppercase">%s</p>\
<p style="font-size:2vw;opacity:.7">servidor en pie · todavia sin desplegar</p>\
</div>' "$AMBIENTE" "$AMBIENTE" > /var/www/html/index.html

# Arranca los dos servicios. Sin systemd: en un contenedor es más lío que
# ayuda, y lo que se quiere enseñar es el despliegue, no init.
COPY arrancar.sh /usr/local/bin/arrancar.sh
RUN chmod +x /usr/local/bin/arrancar.sh

EXPOSE 22 80
CMD ["/usr/local/bin/arrancar.sh"]
