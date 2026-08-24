"""Serialización y escritura de los artefactos reproducibles."""

from __future__ import annotations

import hashlib
import json
from datetime import date, datetime
from pathlib import Path
from typing import Iterable

from . import construccion as datos


def sha256_texto(texto: str) -> str:
    return hashlib.sha256(texto.encode("utf-8")).hexdigest()


def sql_texto(valor: object) -> str:
    """Convierte un valor en un literal SQL."""
    if valor is None:
        return "NULL"
    if isinstance(valor, bool):
        return "TRUE" if valor else "FALSE"
    if isinstance(valor, (int, float)):
        return str(valor)
    if isinstance(valor, (date, datetime)):
        texto = datos.ts(valor) if isinstance(valor, datetime) else valor.isoformat()
        return f"'{texto}'"
    return "'" + str(valor).replace("'", "''") + "'"


def sql_insert(tabla: str, columnas: list[str], filas: Iterable[tuple]) -> str:
    """Construye un INSERT de varias filas en orden estable."""
    filas = list(filas)
    if not filas:
        return ""
    columnas_sql = ", ".join(columnas)
    valores = ",\n    ".join(
        "(" + ", ".join(sql_texto(valor) for valor in fila) + ")"
        for fila in filas
    )
    return f"INSERT INTO {tabla} ({columnas_sql}) VALUES\n    {valores};\n"


def sql_vector(vector: list[float]) -> str:
    return "'[" + ",".join(f"{valor:.8f}" for valor in vector) + "]'"


def construir_seed() -> str:
    """Devuelve el seed SQL completo sin escribirlo en disco."""
    partes: list[str] = [
        "-- =============================================================================\n"
        "-- 02_seed.sql - Carga reproducible del conjunto sintético\n"
        "-- =============================================================================\n"
        "--\n"
        "-- ARCHIVO GENERADO. No editar a mano: se produce con\n"
        "--     python scripts/generar_datos.py\n"
        "--\n"
        f"-- Versión del generador : {datos.VERSION_GENERADOR}\n"
        f"-- Semilla               : {datos.SEMILLA}\n"
        f"-- Instante de referencia: {datos.ts(datos.INSTANTE_REFERENCIA)}\n"
        "--\n"
        "-- La carga es idempotente: vacía las tablas y vuelve a insertar el mismo\n"
        "-- conjunto, de modo que dos ejecuciones limpias son equivalentes.\n"
        "-- =============================================================================\n\n"
        "SET TIME ZONE 'UTC';\n\n"
        "BEGIN;\n\n"
        "TRUNCATE\n"
        "    evento_auditoria, evidencia_estructurada, evidencia_documental,\n"
        "    resultado_estructurado, respuesta, consulta, permiso_documental, actor,\n"
        "    documento_proveedor, documento_producto, embedding, fragmento,\n"
        "    version_documental, documento, incidencia_operativa, entrega,\n"
        "    linea_pedido, pedido, condicion_comercial, producto_proveedor,\n"
        "    proveedor, cliente, producto, modelo_embedding, nivel_sensibilidad,\n"
        "    clase_documental, perfil_autorizado, segmento_cliente, categoria_producto\n"
        "    RESTART IDENTITY CASCADE;\n\n"
    ]

    partes.append("-- --- Catálogos ---------------------------------------------------------\n")
    partes.append(sql_insert("categoria_producto", ["id", "codigo", "nombre"], datos.CATEGORIAS))
    partes.append(sql_insert("segmento_cliente", ["id", "codigo", "nombre"], datos.SEGMENTOS))
    partes.append(sql_insert("perfil_autorizado", ["id", "codigo", "nombre"], datos.PERFILES))
    partes.append(sql_insert("clase_documental", ["id", "codigo", "nombre", "descripcion"], datos.CLASES))
    partes.append(sql_insert("nivel_sensibilidad", ["id", "codigo", "nombre", "requiere_auditoria"], datos.SENSIBILIDADES))
    partes.append(sql_insert("modelo_embedding", ["id", "nombre", "version", "dimension", "metrica", "activo"], datos.MODELOS))

    partes.append("\n-- --- Núcleo operativo -------------------------------------------------\n")
    partes.append(sql_insert("producto", ["id", "codigo", "nombre", "categoria_id", "activo"], datos.productos))
    partes.append(sql_insert("cliente", ["id", "codigo", "razon_social", "segmento_id", "activo"], datos.clientes))
    partes.append(sql_insert("proveedor", ["id", "codigo", "razon_social", "activo"], datos.proveedores))
    partes.append(sql_insert("producto_proveedor", ["producto_id", "proveedor_id"], datos.producto_proveedor))
    partes.append(sql_insert(
        "condicion_comercial",
        ["id", "cliente_id", "producto_id", "precio_unitario", "descuento_porcentaje",
         "vigente_desde", "vigente_hasta"],
        datos.condiciones,
    ))
    partes.append(sql_insert("pedido", ["id", "codigo", "cliente_id", "fecha", "estado"], datos.pedidos))
    partes.append(sql_insert(
        "linea_pedido",
        ["id", "pedido_id", "numero_linea", "producto_id", "cantidad",
         "precio_unitario", "descuento_porcentaje"],
        datos.lineas,
    ))
    partes.append(sql_insert(
        "entrega",
        ["id", "codigo", "pedido_id", "fecha_programada", "fecha_efectiva", "estado"],
        datos.entregas,
    ))
    partes.append(sql_insert(
        "incidencia_operativa",
        ["id", "codigo", "entrega_id", "fecha", "tipo", "descripcion", "estado"],
        datos.incidencias,
    ))

    partes.append("\n-- --- Núcleo documental ------------------------------------------------\n")
    partes.append(sql_insert(
        "documento",
        ["id", "codigo", "titulo", "clase_id", "sensibilidad_id", "procedencia", "activo"],
        datos.CONJUNTO.documentos,
    ))
    partes.append(sql_insert(
        "version_documental",
        ["id", "documento_id", "numero_version", "estado", "vigente_desde", "vigente_hasta",
         "publicada_en", "revocada_en", "ruta_relativa", "nombre_archivo", "tipo_mime",
         "tamano_bytes", "sha256"],
        datos.CONJUNTO.versiones,
    ))
    partes.append(sql_insert(
        "fragmento",
        ["id", "version_id", "posicion", "titulo", "contenido", "pagina"],
        [fragmento[:6] for fragmento in datos.CONJUNTO.fragmentos],
    ))

    partes.append("\n-- --- Embeddings -------------------------------------------------------\n")
    filas_embedding = ",\n    ".join(
        f"({e.id}, {e.fragmento_id}, {e.modelo_id}, {sql_vector(e.vector)}, {sql_texto(e.generado_en)})"
        for e in datos.CONJUNTO.embeddings
    )
    partes.append(
        "INSERT INTO embedding (id, fragmento_id, modelo_id, vector, generado_en) VALUES\n    "
        + filas_embedding
        + ";\n"
    )

    partes.append("\n-- --- Vínculos documentales opcionales ---------------------------------\n")
    partes.append(sql_insert("documento_producto", ["documento_id", "producto_id"],
                             [(1, 1), (2, 5), (10, 9)]))
    partes.append(sql_insert("documento_proveedor", ["documento_id", "proveedor_id"],
                             [(7, 1), (7, 3), (9, 4)]))

    partes.append("\n-- --- Acceso -----------------------------------------------------------\n")
    partes.append(sql_insert("actor", ["id", "codigo", "nombre", "perfil_autorizado_id", "activo"], datos.actores))
    partes.append(sql_insert("permiso_documental", ["perfil_id", "clase_id"], datos.PERMISOS))

    partes.append("\n-- --- Interacción, evidencia y auditoría --------------------------------\n")
    partes.append(sql_insert(
        "consulta", ["id", "actor_id", "perfil_efectivo_id", "pregunta", "instante"], datos.consultas))
    partes.append(sql_insert(
        "respuesta", ["id", "consulta_id", "tipo_resultado", "contenido", "instante"], datos.respuestas))
    partes.append(sql_insert(
        "resultado_estructurado",
        ["id", "tipo_consulta", "parametros", "contenido", "generado_en", "hash"],
        datos.resultados_estructurados,
    ))
    partes.append(sql_insert(
        "evidencia_documental",
        ["id", "respuesta_id", "embedding_id", "ranking", "score"],
        datos.evidencias_documentales,
    ))
    partes.append(sql_insert(
        "evidencia_estructurada",
        ["id", "respuesta_id", "resultado_estructurado_id"],
        datos.evidencias_estructuradas,
    ))
    partes.append(sql_insert(
        "evento_auditoria",
        ["id", "actor_id", "perfil_efectivo_id", "instante", "accion", "resultado",
         "recurso_tipo", "recurso_id", "consulta_id", "respuesta_id", "ranking", "score", "detalles"],
        datos.CONJUNTO.eventos,
    ))

    partes.append("\n-- --- Sincronización de secuencias --------------------------------------\n")
    tablas_con_identidad = [
        "categoria_producto", "segmento_cliente", "perfil_autorizado", "clase_documental",
        "nivel_sensibilidad", "modelo_embedding", "producto", "cliente", "proveedor",
        "condicion_comercial", "pedido", "linea_pedido", "entrega", "incidencia_operativa",
        "documento", "version_documental", "fragmento", "embedding", "actor", "consulta",
        "respuesta", "resultado_estructurado", "evidencia_documental",
        "evidencia_estructurada", "evento_auditoria",
    ]
    for tabla in tablas_con_identidad:
        partes.append(
            f"SELECT setval(pg_get_serial_sequence('{tabla}', 'id'), "
            f"(SELECT COALESCE(max(id), 1) FROM {tabla}));\n"
        )

    partes.append("\nCOMMIT;\n")
    return "".join(partes)


def construir_documentos() -> dict[str, str]:
    """Devuelve los documentos Markdown indexados por su ruta relativa."""
    return dict(datos.archivos)


def construir_inventario(documentos: dict[str, str]) -> list[dict[str, object]]:
    return [
        {
            "ruta": ruta,
            "tamano_bytes": len(contenido.encode("utf-8")),
            "sha256": sha256_texto(contenido),
        }
        for ruta, contenido in documentos.items()
    ]


def construir_manifiesto(inventario: list[dict[str, object]]) -> dict[str, object]:
    """Devuelve el manifiesto sin escribirlo en disco."""
    return {
        "version_generador": datos.VERSION_GENERADOR,
        "semilla": datos.SEMILLA,
        "instante_referencia": datos.ts(datos.INSTANTE_REFERENCIA),
        "modelo_vectorial": {
            "dimension": datos.DIMENSION_VECTOR,
            "metrica": datos.METRICA_VECTOR,
            "modelo_activo": "distribuidora-emb v2",
            "modelo_historico": "distribuidora-emb v1",
        },
        "conteos": {
            "categoria_producto": len(datos.CATEGORIAS),
            "segmento_cliente": len(datos.SEGMENTOS),
            "perfil_autorizado": len(datos.PERFILES),
            "clase_documental": len(datos.CLASES),
            "nivel_sensibilidad": len(datos.SENSIBILIDADES),
            "modelo_embedding": len(datos.MODELOS),
            "producto": len(datos.productos),
            "cliente": len(datos.clientes),
            "proveedor": len(datos.proveedores),
            "producto_proveedor": len(datos.producto_proveedor),
            "condicion_comercial": len(datos.condiciones),
            "pedido": len(datos.pedidos),
            "linea_pedido": len(datos.lineas),
            "entrega": len(datos.entregas),
            "incidencia_operativa": len(datos.incidencias),
            "documento": len(datos.CONJUNTO.documentos),
            "version_documental": len(datos.CONJUNTO.versiones),
            "fragmento": len(datos.CONJUNTO.fragmentos),
            "embedding": len(datos.CONJUNTO.embeddings),
            "actor": len(datos.actores),
            "permiso_documental": len(datos.PERMISOS),
            "consulta": len(datos.consultas),
            "respuesta": len(datos.respuestas),
            "resultado_estructurado": len(datos.resultados_estructurados),
            "evidencia_documental": len(datos.evidencias_documentales),
            "evidencia_estructurada": len(datos.evidencias_estructuradas),
            "evento_auditoria": len(datos.CONJUNTO.eventos),
        },
        "escenarios": [
            {
                "id": escenario.codigo,
                "actor": datos.actores[escenario.actor_id - 1][1],
                "perfil": datos.PERFILES[datos.actores[escenario.actor_id - 1][3] - 1][1],
                "pregunta": escenario.pregunta,
                "tipo_resultado": escenario.tipo_resultado,
                "con_evidencia": escenario.naturaleza != "negativa",
            }
            for escenario in datos.CONJUNTO.escenarios
        ],
        "oraculos_vectoriales": {
            "consulta_vectorial": {
                "vector": datos.vector_consulta_vectorial,
                "fragmento_esperado": datos.esperado_vectorial,
                "documento_esperado": datos.CONJUNTO.documentos[
                    datos.CONJUNTO.versiones[datos.CONJUNTO.fragmentos[datos.esperado_vectorial - 1].version_id - 1].documento_id - 1
                ].codigo,
            },
            "consulta_hibrida": {
                "vector": datos.vector_consulta_hibrida,
                "fragmento_esperado_comercial": datos.esperado_hibrida_com,
                "documento_esperado_comercial": datos.CONJUNTO.documentos[
                    datos.CONJUNTO.versiones[datos.CONJUNTO.fragmentos[datos.esperado_hibrida_com - 1].version_id - 1].documento_id - 1
                ].codigo,
            },
        },
        "matriz_permisos": {
            datos.PERFILES[perfil - 1][1]: sorted(
                datos.CLASES[clase - 1][1]
                for perfil_permiso, clase in datos.PERMISOS
                if perfil_permiso == perfil
            )
            for perfil, _ in datos.PERMISOS
        },
        "archivos": inventario,
    }


def renderizar_artefactos() -> dict[str, str]:
    """Construye todos los artefactos como texto antes de escribirlos."""
    documentos = construir_documentos()
    seed = construir_seed()
    manifiesto = construir_manifiesto(construir_inventario(documentos))
    manifiesto["checksums"] = {"db/datos/02_seed.sql": sha256_texto(seed)}
    return {
        **documentos,
        "db/datos/02_seed.sql": seed,
        "data/ejemplos/manifiesto.json": (
            json.dumps(manifiesto, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
        ),
    }


def escribir_artefactos(raiz: Path) -> dict[str, str]:
    """Escribe una generación completa bajo la raíz indicada."""
    artefactos = renderizar_artefactos()
    directorio_documentos = raiz / "data" / "ejemplos" / "documentos"
    directorio_documentos.mkdir(parents=True, exist_ok=True)
    for archivo in sorted(directorio_documentos.glob("*.md")):
        archivo.unlink()
    for ruta_relativa, contenido in artefactos.items():
        destino = raiz / ruta_relativa
        destino.parent.mkdir(parents=True, exist_ok=True)
        destino.write_text(contenido, encoding="utf-8")
    return artefactos


def generar_artefactos(raiz: Path | None = None) -> None:
    """Genera los artefactos y muestra sus rutas principales."""
    raiz = raiz or Path(__file__).resolve().parents[2]
    artefactos = escribir_artefactos(raiz)
    print(f"Documentos generados : {len(datos.archivos)}")
    print("Seed                 : db/datos/02_seed.sql")
    print("Manifiesto           : data/ejemplos/manifiesto.json")
    print(f"Fragmento esperado (vectorial) : {datos.esperado_vectorial}")
    print(f"Fragmento esperado (híbrida/COM): {datos.esperado_hibrida_com}")
