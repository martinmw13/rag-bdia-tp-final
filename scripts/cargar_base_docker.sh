#!/usr/bin/env bash
#
# Inicia PostgreSQL con pgvector mediante Docker Compose, recrea la base y
# ejecuta las consultas representativas C1 a C9.
#
# Uso:
#   scripts/cargar_base_docker.sh [nombre_base]
#
# Sólo requiere Docker con Compose y Python 3 en el host. La base indicada se
# elimina y se vuelve a crear dentro del volumen administrado por Compose.
#
set -euo pipefail

BASE="${1:-rag_distribuidora}"
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! "$BASE" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
    echo "Error: el nombre de la base sólo puede contener letras, números y guiones bajos." >&2
    exit 2
fi

case "$BASE" in
    postgres|template0|template1)
        echo "Error: '$BASE' es una base reservada y no se puede recrear." >&2
        exit 2
        ;;
esac

for comando in docker python3; do
    if ! command -v "$comando" >/dev/null 2>&1; then
        echo "Error: falta el comando requerido '$comando'." >&2
        exit 127
    fi
done

if ! docker compose version >/dev/null 2>&1; then
    echo "Error: Docker Compose no está disponible." >&2
    exit 127
fi

cd "$RAIZ"

compose() {
    docker compose -f "$RAIZ/compose.yaml" "$@"
}

echo "==> Regenerando el conjunto sintético"
python3 scripts/generar_datos.py

echo "==> Iniciando PostgreSQL 17 con pgvector"
compose up -d --wait postgres

echo "==> Recreando la base '$BASE' dentro del contenedor"
compose exec -T postgres dropdb -U postgres --if-exists "$BASE"
compose exec -T postgres createdb -U postgres "$BASE"

for archivo in \
    db/estructura/01_schema.sql \
    db/datos/02_seed.sql \
    db/indices_vistas/03_indices.sql \
    db/indices_vistas/05_seguridad.sql
do
    echo "==> $archivo"
    compose exec -T postgres \
        psql -q -U postgres -d "$BASE" -v ON_ERROR_STOP=1 \
        -f "/workspace/$archivo"
done

# Los vectores de consulta se leen del manifiesto, que es su fuente de autoridad.
leer_vector() {
    python3 -c "
import json, sys
m = json.load(open('data/ejemplos/manifiesto.json'))
v = m['oraculos_vectoriales'][sys.argv[1]][sys.argv[2]]
print('[' + ','.join(f'{x:.8f}' for x in v) + ']')
" "$1" "$2"
}

VECTOR_CONSULTA="$(leer_vector consulta_vectorial vector)"
VECTOR_HIBRIDA="$(leer_vector consulta_hibrida vector)"

echo "==> db/consultas/04_consultas.sql"
compose exec -T postgres \
    psql -U postgres -d "$BASE" -v ON_ERROR_STOP=1 \
    -v vector_consulta="$VECTOR_CONSULTA" \
    -f /workspace/db/consultas/04_consultas.sql

echo "==> db/consultas/06_consultas_seguridad.sql"
compose exec -T postgres \
    psql -U postgres -d "$BASE" -v ON_ERROR_STOP=1 \
    -v vector_hibrida="$VECTOR_HIBRIDA" \
    -f /workspace/db/consultas/06_consultas_seguridad.sql

echo
echo "==> Listo. Base '$BASE' cargada y consultas C1 a C9 ejecutadas."
echo "==> Para detener PostgreSQL sin borrar sus datos: docker compose down"
