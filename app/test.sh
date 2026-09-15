#!/bin/sh
# Pruebas unitarias de la aplicación de demostración.
#
# Son de verdad, aunque la aplicación sea mínima: comprueban que la plantilla
# tiene todos los marcadores que el Dockerfile va a sustituir. Si alguien
# renombra un marcador y se olvida del otro lado, esta prueba falla ANTES de
# construir la imagen — que es exactamente lo que el tema 8 explica sobre por
# qué el orden del pipeline no es arbitrario.

set -eu
PLANTILLA="${1:-index.template.html}"
fallos=0

comprobar() {
  if grep -q "$1" "$PLANTILLA"; then
    echo "  ok    marcador $1"
  else
    echo "  FALLA marcador $1 no está en $PLANTILLA"
    fallos=$((fallos + 1))
  fi
}

echo "Pruebas unitarias · plantilla de la aplicación"
for m in __AMBIENTE__ __VERSION__ __COMMIT__ __RAMA__ __PIPELINE__ __FECHA__ __COLOR__ __TEXTO__; do
  comprobar "$m"
done

# La plantilla no debe llevar un ambiente escrito a mano: eso significaría que
# alguien fijó el valor en vez de dejar que lo ponga el pipeline.
for literal in ">dev<" ">test<" ">prod<"; do
  if grep -q "$literal" "$PLANTILLA"; then
    echo "  FALLA la plantilla trae el ambiente escrito a mano: $literal"
    fallos=$((fallos + 1))
  fi
done

echo ""
if [ "$fallos" -eq 0 ]; then
  echo "TODAS LAS PRUEBAS PASAN"
  exit 0
fi
echo "$fallos PRUEBA(S) FALLIDA(S)"
exit 1
