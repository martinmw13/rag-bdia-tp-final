#!/usr/bin/env bash
#
# Recrea la base de datos completa desde cero y ejecuta las consultas
# representativas.
#
# Uso:
#   scripts/cargar_base.sh [nombre_base]
#
# Requiere PostgreSQL 15 o superior con la extensión pgvector disponible, y
# `psql` en el PATH. La base se elimina y se vuelve a crear: no debe apuntarse
# a una base con datos que interesen.
#
set -euo pipefail

BASE="${1:-rag_distribuidora}"
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

echo "==> Regenerando el conjunto sintético"
python3 scripts/generar_datos.py

echo "==> Recreando la base '$BASE'"
dropdb --if-exists "$BASE"
createdb "$BASE"

for archivo in \
    db/estructura/01_schema.sql \
    db/datos/02_seed.sql \
    db/indices_vistas/03_indices.sql \
    db/indices_vistas/05_seguridad.sql
do
    echo "==> $archivo"
    psql -q -d "$BASE" -v ON_ERROR_STOP=1 -f "$archivo"
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
psql -d "$BASE" -v ON_ERROR_STOP=1 \
     -v vector_consulta="$VECTOR_CONSULTA" \
     -f db/consultas/04_consultas.sql

echo "==> db/consultas/06_consultas_seguridad.sql"
psql -d "$BASE" -v ON_ERROR_STOP=1 \
     -v vector_hibrida="$VECTOR_HIBRIDA" \
     -f db/consultas/06_consultas_seguridad.sql

echo
echo "==> Listo. Base '$BASE' cargada y consultas ejecutadas."
