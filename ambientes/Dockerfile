# Un SERVIDOR del laboratorio: Ubuntu con SSH, Docker y, opcionalmente, k3s.
#
# Cada ambiente —dev, test y prod— es una de estas máquinas. No es un
# contenedor de aplicación: es un servidor completo. Se entra por SSH, tiene
# su propio Docker, y el pipeline despliega ahí dentro contenedores, igual que
# haría contra un servidor de verdad.
#
# Es lo que describen los temas 8 y 9: DEV tiene sus servidores, TEST los
# suyos, PROD los suyos. Cada ambiente con su propio Docker.
#
# Coste medido en reposo:
#   Ubuntu + sshd + nginx ............   5 MB
#   + dockerd interno ................  23 MB
#   + k3s (si se activa) ............. 369 MB
#
# Requiere arrancarse con --privileged para que el Docker interno funcione.

FROM ubuntu:24.04

ARG AMBIENTE=dev
ARG CON_KUBERNETES=no

ENV DEBIAN_FRONTEND=noninteractive
ENV AMBIENTE=${AMBIENTE}
ENV CON_KUBERNETES=${CON_KUBERNETES}

RUN apt-get update && apt-get install -y --no-install-recommends \
        openssh-server ca-certificates curl vim-tiny less iproute2 \
        docker.io \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/sshd

# k3s sólo si se pide: son 369 MB por ambiente y no siempre hacen falta.
RUN if [ "$CON_KUBERNETES" = "si" ]; then \
      curl -sfL https://get.k3s.io -o /tmp/k3s.sh && \
      INSTALL_K3S_SKIP_START=true INSTALL_K3S_SKIP_ENABLE=true sh /tmp/k3s.sh && \
      rm -f /tmp/k3s.sh ; \
    fi

# Usuario de despliegue: por él entra el pipeline, y también los participantes
# a mirar. Va en el grupo docker para poder manejar el Docker del servidor.
RUN useradd -m -s /bin/bash despliegue \
    && usermod -aG docker despliegue \
    && mkdir -p /home/despliegue/.ssh \
    && chmod 700 /home/despliegue/.ssh \
    && chown -R despliegue:despliegue /home/despliegue/.ssh

COPY --chown=despliegue:despliegue llave.pub /home/despliegue/.ssh/authorized_keys
RUN chmod 600 /home/despliegue/.ssh/authorized_keys

# Sólo llave, sin contraseñas. Es lo correcto y evita sorpresas en el aula.
RUN sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

# El registro del taller es local y sin TLS. Hay que declararlo como inseguro
# o el Docker del servidor se niega a descargar de él.
RUN mkdir -p /etc/docker \
    && printf '{ "insecure-registries": ["registro:5000"] }\n' > /etc/docker/daemon.json

COPY arrancar.sh /usr/local/bin/arrancar.sh
RUN chmod +x /usr/local/bin/arrancar.sh

# 22 SSH · 80 la aplicación desplegada · 6443 la API de Kubernetes
EXPOSE 22 80 6443
CMD ["/usr/local/bin/arrancar.sh"]
