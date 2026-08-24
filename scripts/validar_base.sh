#!/usr/bin/env bash
#
# Recrea dos veces una base exclusiva de validación y compara sus resultados.
#
# Uso:
#   scripts/validar_base.sh [nombre_base]
#
# La base indicada se elimina en cada pasada. Por seguridad, el nombre debe
# terminar en `_validacion`.
#
set -euo pipefail

BASE_VALIDACION="${1:-rag_distribuidora_validacion}"
RAIZ_PROYECTO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIRECTORIO_TEMPORAL="$(mktemp -d)"
trap 'rm -rf -- "$DIRECTORIO_TEMPORAL"' EXIT

if [[ ! "$BASE_VALIDACION" =~ ^[a-zA-Z_][a-zA-Z0-9_]*_validacion$ ]]; then
    echo "Error: el nombre de la base debe terminar en _validacion." >&2
    exit 2
fi

cd "$RAIZ_PROYECTO"

for comando in python3 psql createdb dropdb; do
    if ! command -v "$comando" >/dev/null 2>&1; then
        echo "Error: falta el comando requerido '$comando'." >&2
        exit 127
    fi
done

echo "==> Regenerando y verificando los artefactos sintéticos"
python3 scripts/generar_datos.py
python3 - <<'PY'
import hashlib
import json
from pathlib import Path

raiz = Path.cwd()
manifiesto = json.loads((raiz / "data/ejemplos/manifiesto.json").read_text())

por_verificar = [
    (item["ruta"], item["sha256"])
    for item in manifiesto["archivos"]
]
por_verificar.append((
    "db/datos/02_seed.sql",
    manifiesto["checksums"]["db/datos/02_seed.sql"],
))

for ruta_relativa, esperado in por_verificar:
    obtenido = hashlib.sha256((raiz / ruta_relativa).read_bytes()).hexdigest()
    if obtenido != esperado:
        raise SystemExit(
            f"checksum inesperado para {ruta_relativa}: {obtenido} != {esperado}"
        )

print(f"checksums verificados: {len(por_verificar)}")
PY

leer_vector() {
    python3 -c "
import json, sys
m = json.load(open('data/ejemplos/manifiesto.json'))
v = m['oraculos_vectoriales'][sys.argv[1]]['vector']
print('[' + ','.join(f'{x:.8f}' for x in v) + ']')
" "$1"
}

VECTOR_CONSULTA="$(leer_vector consulta_vectorial)"
VECTOR_HIBRIDA="$(leer_vector consulta_hibrida)"

cargar_base() {
    dropdb --if-exists "$BASE_VALIDACION"
    createdb "$BASE_VALIDACION"

    for archivo in \
        db/estructura/01_schema.sql \
        db/datos/02_seed.sql \
        db/indices_vistas/03_indices.sql \
        db/indices_vistas/05_seguridad.sql
    do
        psql -q -d "$BASE_VALIDACION" -v ON_ERROR_STOP=1 -f "$archivo"
    done
}

validar_conteos() {
    python3 - <<'PY' | while IFS='|' read -r tabla esperado; do
import json

with open("data/ejemplos/manifiesto.json", encoding="utf-8") as archivo:
    conteos = json.load(archivo)["conteos"]

for tabla, cantidad in sorted(conteos.items()):
    print(f"{tabla}|{cantidad}")
PY
        obtenido="$(psql -X -A -t -d "$BASE_VALIDACION" \
            -v ON_ERROR_STOP=1 -c "SELECT count(*) FROM $tabla")"
        if [[ "$obtenido" != "$esperado" ]]; then
            echo "Error: $tabla tiene $obtenido filas; se esperaban $esperado." >&2
            exit 1
        fi
    done
}

validar_oraculos() {
    local fragmento_vectorial
    local fragmento_hibrido

    fragmento_vectorial="$(psql -X -q -A -t -d "$BASE_VALIDACION" \
        -v ON_ERROR_STOP=1 -v vector_consulta="$VECTOR_CONSULTA" <<'SQL'
BEGIN;
SET LOCAL ROLE rag_runtime;
SELECT set_config('rag.actor', 'ACT-001', true) \gset
SELECT fragmento_id
FROM fragmento_recuperable
ORDER BY vector <=> :'vector_consulta'::vector, fragmento_id
LIMIT 1;
ROLLBACK;
SQL
)"

    fragmento_hibrido="$(psql -X -q -A -t -d "$BASE_VALIDACION" \
        -v ON_ERROR_STOP=1 -v vector_hibrida="$VECTOR_HIBRIDA" <<'SQL'
BEGIN;
SET LOCAL ROLE rag_runtime;
SELECT set_config('rag.actor', 'ACT-003', true) \gset
SELECT fragmento_id
FROM fragmento_recuperable
ORDER BY vector <=> :'vector_hibrida'::vector, fragmento_id
LIMIT 1;
ROLLBACK;
SQL
)"

    [[ "$fragmento_vectorial" == "10" ]] || {
        echo "Error: C6 devolvió primero el fragmento $fragmento_vectorial." >&2
        exit 1
    }
    [[ "$fragmento_hibrido" == "18" ]] || {
        echo "Error: C7 devolvió primero el fragmento $fragmento_hibrido." >&2
        exit 1
    }
}

capturar_snapshot() {
    local destino="$1"

    python3 - <<'PY' | while IFS= read -r tabla; do
import json

with open("data/ejemplos/manifiesto.json", encoding="utf-8") as archivo:
    tablas = json.load(archivo)["conteos"]

for tabla in sorted(tablas):
    print(tabla)
PY
        psql -X -A -t -d "$BASE_VALIDACION" -v ON_ERROR_STOP=1 -c \
            "SELECT '$tabla|' || count(*) || '|' || md5(COALESCE(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text)::text, '[]')) FROM $tabla t" \
            >>"$destino"
    done
}

for pasada in 1 2; do
    echo "==> Carga limpia $pasada de 2"
    cargar_base
    validar_conteos
    psql -X -d "$BASE_VALIDACION" -v ON_ERROR_STOP=1 \
        -f db/consultas/07_validaciones.sql
    validar_oraculos
    capturar_snapshot "$DIRECTORIO_TEMPORAL/snapshot-$pasada.txt"
done

if ! cmp -s \
    "$DIRECTORIO_TEMPORAL/snapshot-1.txt" \
    "$DIRECTORIO_TEMPORAL/snapshot-2.txt"
then
    diff -u \
        "$DIRECTORIO_TEMPORAL/snapshot-1.txt" \
        "$DIRECTORIO_TEMPORAL/snapshot-2.txt" >&2 || true
    echo "Error: las dos cargas limpias produjeron snapshots distintos." >&2
    exit 1
fi

echo "==> Validación completa: restricciones, permisos y snapshots verificados."
