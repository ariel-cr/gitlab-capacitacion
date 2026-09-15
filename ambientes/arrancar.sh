#!/bin/sh
# Arranca sshd y nginx en primer plano.
#
# Un contenedor muere cuando muere su proceso principal, asi que uno de los
# dos tiene que quedarse en primer plano. sshd va al fondo y nginx manda.
set -e
/usr/sbin/sshd
echo "[$AMBIENTE] sshd escuchando en el 22"
echo "[$AMBIENTE] nginx escuchando en el 80"
exec nginx -g 'daemon off;'
