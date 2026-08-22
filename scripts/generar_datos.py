#!/usr/bin/env python3
"""Generador del conjunto sintético reproducible.

Produce, a partir de una semilla fija y un instante de referencia fijo:

  - data/ejemplos/documentos/*.md   14 archivos, uno por versión documental
  - data/ejemplos/manifiesto.json   procedencia, conteos, checksums y oráculos
  - db/datos/02_seed.sql            carga reproducible de la base

Restricciones de diseño (ver docs/specs/.../impl-datos-sinteticos.md):

  - Sólo biblioteca estándar de Python: sin Faker, sin modelos de embedding
    reales y sin dependencias externas.
  - Nada depende de la hora de ejecución, del orden del filesystem ni del
    estado previo de la base.
  - Dos ejecuciones limpias producen exactamente los mismos artefactos.

Uso:
    python scripts/generar_datos.py
"""

from __future__ import annotations

import hashlib
import json
import math
import random
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

# =============================================================================
# Contrato de reproducibilidad
# =============================================================================

VERSION_GENERADOR = "1.0.0"
SEMILLA = 42
INSTANTE_REFERENCIA = datetime(2026, 6, 30, 15, 0, 0, tzinfo=timezone.utc)
FECHA_REFERENCIA = INSTANTE_REFERENCIA.date()

DIMENSION_VECTOR = 32
METRICA_VECTOR = "coseno"

RAIZ = Path(__file__).resolve().parent.parent
DIR_EJEMPLOS = RAIZ / "data" / "ejemplos"
DIR_DOCUMENTOS = DIR_EJEMPLOS / "documentos"
RUTA_MANIFIESTO = DIR_EJEMPLOS / "manifiesto.json"
RUTA_SEED = RAIZ / "db" / "datos" / "02_seed.sql"

rng = random.Random(SEMILLA)


# =============================================================================
# Utilidades
# =============================================================================

def ts(momento: datetime) -> str:
    """Instante en ISO 8601 UTC, estable e independiente de la zona local."""
    return momento.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def sql_texto(valor) -> str:
    """Literal SQL: escapa comillas simples y resuelve NULL."""
    if valor is None:
        return "NULL"
    if isinstance(valor, bool):
        return "TRUE" if valor else "FALSE"
    if isinstance(valor, (int, float)):
        return str(valor)
    if isinstance(valor, (date, datetime)):
        return "'" + (ts(valor) if isinstance(valor, datetime) else valor.isoformat()) + "'"
    return "'" + str(valor).replace("'", "''") + "'"


def sql_insert(tabla: str, columnas: list[str], filas: list[tuple]) -> str:
    """Un INSERT multi-fila, con las filas en orden estable."""
    if not filas:
        return ""
    cols = ", ".join(columnas)
    valores = ",\n    ".join(
        "(" + ", ".join(sql_texto(v) for v in fila) + ")" for fila in filas
    )
    return f"INSERT INTO {tabla} ({cols}) VALUES\n    {valores};\n"


def normalizar(vector: list[float]) -> list[float]:
    norma = math.sqrt(sum(x * x for x in vector))
    if norma == 0:
        raise ValueError("no se puede normalizar el vector nulo")
    return [round(x / norma, 8) for x in vector]


def vector_tematico(centroide: list[float], ruido: float) -> list[float]:
    """Vector normalizado alrededor de un centroide temático."""
    return normalizar([c + rng.uniform(-ruido, ruido) for c in centroide])


def sql_vector(vector: list[float]) -> str:
    return "'[" + ",".join(f"{x:.8f}" for x in vector) + "]'"


def sha256_texto(texto: str) -> str:
    return hashlib.sha256(texto.encode("utf-8")).hexdigest()


# =============================================================================
# 1. Catálogos
# =============================================================================

CATEGORIAS = [
    (1, "CAT-FERR", "Ferretería industrial"),
    (2, "CAT-ELEC", "Material eléctrico"),
    (3, "CAT-SEGU", "Seguridad industrial"),
    (4, "CAT-EMBA", "Embalaje y logística"),
]

SEGMENTOS = [
    (1, "SEG-MAY", "Mayorista"),
    (2, "SEG-MIN", "Minorista"),
    (3, "SEG-CORP", "Corporativo"),
]

PERFILES = [
    (1, "OPS", "Operaciones/Logística"),
    (2, "COM", "Comercial/Compras"),
    (3, "ADM", "Administración/Calidad"),
]

CLASES = [
    (1, "FICHA", "Ficha de producto", "Especificación técnica de un producto del catálogo."),
    (2, "PROC", "Procedimiento logístico", "Instructivo operativo de depósito y distribución."),
    (3, "POL", "Política comercial", "Condiciones, descuentos y plazos acordados."),
    (4, "CUMP", "Cumplimiento de proveedor", "Certificaciones y auditorías de proveedores."),
    (5, "LEGAL", "Documentación legal", "Contratos y documentación legal reservada."),
]

SENSIBILIDADES = [
    (1, "PUB", "Pública", False),
    (2, "INT", "Interna", False),
    (3, "RES", "Restringida", True),
]

# Dos versiones ficticias del mismo modelo. Sólo la activa participa en las
# búsquedas vigentes; la histórica existe para demostrar trazabilidad.
MODELOS = [
    (1, "distribuidora-emb", "v2", DIMENSION_VECTOR, METRICA_VECTOR, True),
    (2, "distribuidora-emb", "v1", DIMENSION_VECTOR, METRICA_VECTOR, False),
]
MODELO_ACTIVO = 1
MODELO_HISTORICO = 2

# Matriz de autorización: perfil -> clases permitidas. Toda combinación ausente
# queda denegada por defecto (8 permisos sobre 15 combinaciones posibles).
PERMISOS = [
    (1, 1), (1, 2),                  # Operaciones/Logística: ficha, procedimiento
    (2, 1), (2, 3),                  # Comercial/Compras: ficha, política
    (3, 1), (3, 2), (3, 4), (3, 5),  # Administración/Calidad: ficha, proc., cumpl., legal
]


# =============================================================================
# 2. Núcleo operativo
# =============================================================================

NOMBRES_PRODUCTO = [
    ("Taladro percutor industrial", 1),
    ("Juego de llaves combinadas", 1),
    ("Amoladora angular", 1),
    ("Cable unipolar 2.5 mm", 2),
    ("Tablero seccional modular", 2),
    ("Luminaria LED de galpón", 2),
    ("Casco de seguridad dieléctrico", 3),
    ("Guantes anticorte nivel 5", 3),
    ("Arnés de seguridad completo", 3),
    ("Film stretch para pallets", 4),
    ("Caja de cartón corrugado", 4),
    ("Zuncho de polipropileno", 4),
]

# PRD-012 queda inactivo: escenario obligatorio de producto dado de baja.
PRODUCTO_INACTIVO = 12

productos = [
    (i, f"PRD-{i:03d}", nombre, categoria, i != PRODUCTO_INACTIVO)
    for i, (nombre, categoria) in enumerate(NOMBRES_PRODUCTO, start=1)
]

RAZONES_CLIENTE = [
    ("Corralón del Norte", 1),
    ("Distribuidora Pampa", 1),
    ("Ferretería El Roble", 2),
    ("Insumos del Litoral", 2),
    ("Constructora Andina", 3),
    ("Servicios Integrales Sur", 3),
]

# CLI-006 no tiene pedidos: escenario obligatorio de cliente sin antecedentes.
CLIENTE_SIN_PEDIDOS = 6

clientes = [
    (i, f"CLI-{i:03d}", razon, segmento, True)
    for i, (razon, segmento) in enumerate(RAZONES_CLIENTE, start=1)
]

RAZONES_PROVEEDOR = [
    "Herramientas del Plata",
    "Electro Insumos Cuyo",
    "Protección Laboral SA",
    "Embalajes Rioplatenses",
]

proveedores = [
    (i, f"PROV-{i:03d}", razon, True)
    for i, razon in enumerate(RAZONES_PROVEEDOR, start=1)
]

# 18 asociaciones producto-proveedor, deterministas: cada producto se abastece
# del proveedor de su rubro y algunos suman un segundo proveedor alternativo.
producto_proveedor = []
for producto_id, _, _, categoria_id, _ in productos:
    producto_proveedor.append((producto_id, categoria_id))
for producto_id in (1, 3, 5, 7, 9, 11):
    alternativo = (productos[producto_id - 1][3] % 4) + 1
    producto_proveedor.append((producto_id, alternativo))
producto_proveedor.sort()

DESCUENTOS = [0, 5, 10, 15, 20]


def precio_sintetico() -> float:
    """Precio en ARS dentro del rango acordado, con dos decimales."""
    return round(rng.uniform(1_000, 250_000), 2)


# 12 condiciones comerciales. El primer par cliente-producto concentra los tres
# estados temporales exigidos: vencida, vigente y futura.
condiciones = []
_id_condicion = 1


def agregar_condicion(cliente_id, producto_id, desde, hasta):
    global _id_condicion
    condiciones.append(
        (
            _id_condicion,
            cliente_id,
            producto_id,
            precio_sintetico(),
            rng.choice(DESCUENTOS),
            desde,
            hasta,
        )
    )
    _id_condicion += 1


# Escenario temporal completo sobre CLI-001 / PRD-001.
agregar_condicion(1, 1, FECHA_REFERENCIA - timedelta(days=330), FECHA_REFERENCIA - timedelta(days=120))
agregar_condicion(1, 1, FECHA_REFERENCIA - timedelta(days=120), FECHA_REFERENCIA + timedelta(days=30))
agregar_condicion(1, 1, FECHA_REFERENCIA + timedelta(days=30), None)

# Nueve condiciones vigentes adicionales sobre pares distintos.
for cliente_id, producto_id in [
    (1, 2), (2, 1), (2, 4), (3, 5), (3, 7),
    (4, 8), (4, 10), (5, 3), (5, 11),
]:
    agregar_condicion(
        cliente_id,
        producto_id,
        FECHA_REFERENCIA - timedelta(days=200),
        None,
    )

# --- Pedidos, líneas, entregas e incidencias -------------------------------

ESTADOS_PEDIDO_ACTIVOS = ["pendiente", "en_preparacion", "entregado"]

pedidos = []
lineas = []
entregas = []
incidencias = []

# PED-012 se cancela y no tiene entregas; PED-003 se entrega en dos partes;
# PED-005 tiene una entrega demorada con incidencia asociada.
PEDIDO_CANCELADO = 12
PEDIDO_PARCIAL = 3
PEDIDO_DEMORADO = 5

# Reparto fijo de 28 líneas entre 12 pedidos (mínimo una por pedido).
LINEAS_POR_PEDIDO = [3, 2, 4, 2, 3, 2, 2, 3, 2, 2, 2, 1]
assert sum(LINEAS_POR_PEDIDO) == 28

_id_linea = 1
for indice, cantidad_lineas in enumerate(LINEAS_POR_PEDIDO, start=1):
    cliente_id = ((indice - 1) % (CLIENTE_SIN_PEDIDOS - 1)) + 1
    fecha_pedido = FECHA_REFERENCIA - timedelta(days=300 - indice * 20)
    estado = (
        "cancelado"
        if indice == PEDIDO_CANCELADO
        else ESTADOS_PEDIDO_ACTIVOS[indice % len(ESTADOS_PEDIDO_ACTIVOS)]
    )
    pedidos.append((indice, f"PED-{indice:03d}", cliente_id, fecha_pedido, estado))

    productos_del_pedido = sorted(
        rng.sample([p[0] for p in productos if p[4]], cantidad_lineas)
    )
    for numero_linea, producto_id in enumerate(productos_del_pedido, start=1):
        lineas.append(
            (
                _id_linea,
                indice,
                numero_linea,
                producto_id,
                rng.randint(1, 50),
                precio_sintetico(),
                rng.choice(DESCUENTOS),
            )
        )
        _id_linea += 1

# 14 entregas: una por pedido no cancelado (11), dos extra por parcialidad y
# una adicional para el pedido demorado.
_id_entrega = 1


def agregar_entrega(pedido_id, dias_offset, estado):
    global _id_entrega
    pedido = pedidos[pedido_id - 1]
    programada = pedido[3] + timedelta(days=dias_offset)
    efectiva = programada if estado == "entregada" else None
    entregas.append(
        (_id_entrega, f"ENT-{_id_entrega:03d}", pedido_id, programada, efectiva, estado)
    )
    _id_entrega += 1


for pedido_id, _, _, _, estado_pedido in pedidos:
    if estado_pedido == "cancelado":
        continue  # escenario obligatorio: pedido cancelado sin entrega
    if pedido_id == PEDIDO_DEMORADO:
        agregar_entrega(pedido_id, 5, "demorada")
    else:
        agregar_entrega(pedido_id, 5, "entregada")

# Entregas parciales: PED-003 suma dos remitos más.
agregar_entrega(PEDIDO_PARCIAL, 12, "entregada")
agregar_entrega(PEDIDO_PARCIAL, 20, "en_transito")
# El pedido demorado completa con un segundo envío en tránsito.
agregar_entrega(PEDIDO_DEMORADO, 15, "en_transito")

assert len(entregas) == 14, len(entregas)

TIPOS_INCIDENCIA = ["demora", "faltante", "dano", "direccion_erronea"]
DESCRIPCIONES_INCIDENCIA = [
    "La unidad de reparto acumuló demora por corte de ruta.",
    "Se detectó faltante de bultos contra el remito emitido.",
    "Un pallet presentó daño de film y embalaje al arribar.",
    "El domicilio declarado no coincidió con el de entrega.",
]

# Cuatro incidencias sobre entregas existentes; la primera corresponde a la
# entrega demorada del escenario obligatorio.
entrega_demorada_id = next(e[0] for e in entregas if e[5] == "demorada")
entregas_con_incidencia = [entrega_demorada_id, 2, 6, 9]
for indice, entrega_id in enumerate(entregas_con_incidencia, start=1):
    entrega = entregas[entrega_id - 1]
    incidencias.append(
        (
            indice,
            f"INC-{indice:03d}",
            entrega_id,
            entrega[3] + timedelta(days=1),
            TIPOS_INCIDENCIA[indice - 1],
            DESCRIPCIONES_INCIDENCIA[indice - 1],
            "abierta" if indice == 1 else "cerrada",
        )
    )


# =============================================================================
# 3. Núcleo documental
# =============================================================================

# (codigo, titulo, clase_id, sensibilidad_id, procedencia, [(numero, estado, secciones)])
PLAN_DOCUMENTAL = [
    ("DOC-001", "Ficha técnica del taladro percutor industrial", 1, 1, "Compras",
     [(1, "publicada", 2)]),
    ("DOC-002", "Ficha técnica del tablero seccional modular", 1, 1, "Compras",
     [(1, "sustituida", 2), (2, "publicada", 3)]),
    ("DOC-003", "Procedimiento de gestión de entregas demoradas", 2, 2, "Operaciones",
     [(1, "sustituida", 2), (2, "publicada", 4)]),
    ("DOC-004", "Procedimiento de devoluciones y logística inversa", 2, 2, "Operaciones",
     [(1, "publicada", 2)]),
    ("DOC-005", "Política comercial de descuentos por volumen", 3, 2, "Comercial",
     [(1, "sustituida", 2), (2, "publicada", 3)]),
    ("DOC-006", "Política comercial de plazos de pago", 3, 2, "Comercial",
     [(1, "revocada", 2)]),
    ("DOC-007", "Certificaciones vigentes de proveedores homologados", 4, 2, "Calidad",
     [(1, "publicada", 2)]),
    ("DOC-008", "Programa anual de auditorías a proveedores", 4, 2, "Calidad",
     [(1, "borrador", 2)]),
    ("DOC-009", "Contrato marco de distribución mayorista", 5, 3, "Legales",
     [(1, "sustituida", 2), (2, "publicada", 2)]),
    ("DOC-010", "Ficha técnica del arnés de seguridad completo", 1, 1, "Compras",
     [(1, "publicada", 2)]),
]

SECCIONES_POR_CLASE = {
    1: [
        ("Alcance y aplicación", "La ficha describe el uso previsto del artículo dentro del catálogo mayorista y las condiciones en que la distribuidora lo comercializa."),
        ("Especificaciones técnicas", "Se detallan medidas, materiales, tolerancias y requisitos de conservación declarados por el proveedor homologado."),
        ("Condiciones de almacenamiento", "El artículo debe estibarse en estanterías señalizadas, protegido de humedad y a distancia de fuentes de calor."),
        ("Reposición y equivalencias", "Ante faltante de stock, el reemplazo debe elegirse entre las equivalencias homologadas por Compras."),
    ],
    2: [
        ("Objetivo del procedimiento", "Fijar los pasos que Operaciones debe seguir para encauzar el desvío y dejar registro trazable de cada decisión."),
        ("Responsables intervinientes", "El responsable de depósito inicia el circuito y coordina con distribución y atención al cliente según la criticidad."),
        ("Registro de la incidencia", "Toda desviación se asienta con tipo, fecha y descripción, quedando asociada a la entrega afectada."),
        ("Comunicación al cliente", "El aviso se cursa dentro de las veinticuatro horas, informando la nueva fecha comprometida y su motivo."),
    ],
    3: [
        ("Criterio general", "La política fija los límites dentro de los cuales Comercial puede pactar condiciones sin autorización adicional."),
        ("Escalas aplicables", "Las escalas se calculan sobre el volumen acumulado del período y no son acumulables con acuerdos particulares."),
        ("Excepciones y autorizaciones", "Cualquier condición fuera de escala requiere autorización expresa y queda registrada con su fundamento."),
    ],
    4: [
        ("Alcance del control", "El control abarca a los proveedores homologados que abastecen artículos críticos del catálogo."),
        ("Evidencia requerida", "Cada proveedor aporta certificados vigentes, informes de ensayo y constancias de las acciones correctivas."),
        ("Frecuencia de revisión", "La documentación se revisa al menos una vez por año y ante cualquier cambio en el proceso productivo."),
    ],
    5: [
        ("Objeto del contrato", "El instrumento regula la relación de distribución, su territorio y las obligaciones recíprocas de las partes."),
        ("Confidencialidad", "La información intercambiada se considera reservada y no puede difundirse fuera del ámbito autorizado."),
        ("Vigencia y rescisión", "El plazo se renueva por períodos anuales salvo notificación fehaciente en contrario."),
    ],
}

documentos = []
versiones = []
fragmentos = []
archivos = []

_id_version = 1
_id_fragmento = 1

for documento_id, (codigo, titulo, clase_id, sensibilidad_id, procedencia, plan) in enumerate(
    PLAN_DOCUMENTAL, start=1
):
    documentos.append((documento_id, codigo, titulo, clase_id, sensibilidad_id, procedencia, True))

    for numero_version, estado, cantidad_secciones in plan:
        # Vigencias escalonadas hacia atrás desde el instante de referencia.
        publicada_en = None
        vigente_desde = None
        vigente_hasta = None
        revocada_en = None

        if estado != "borrador":
            base = INSTANTE_REFERENCIA - timedelta(days=400 - numero_version * 60)
            publicada_en = base
            vigente_desde = base
            if estado == "sustituida":
                vigente_hasta = base + timedelta(days=60)
            elif estado == "revocada":
                revocada_en = base + timedelta(days=90)
                vigente_hasta = revocada_en

        nombre_archivo = f"{codigo}-v{numero_version}.md"
        ruta_relativa = f"data/ejemplos/documentos/{nombre_archivo}"

        secciones = SECCIONES_POR_CLASE[clase_id][:cantidad_secciones]
        cuerpo = [f"# {titulo}", "", f"Versión {numero_version} — {procedencia}", ""]
        for encabezado, texto in secciones:
            cuerpo += [f"## {encabezado}", "", texto, ""]
        contenido_archivo = "\n".join(cuerpo)

        archivos.append((ruta_relativa, contenido_archivo))

        versiones.append(
            (
                _id_version,
                documento_id,
                numero_version,
                estado,
                vigente_desde,
                vigente_hasta,
                publicada_en,
                revocada_en,
                ruta_relativa,
                nombre_archivo,
                "text/markdown",
                len(contenido_archivo.encode("utf-8")),
                sha256_texto(contenido_archivo),
            )
        )

        for posicion, (encabezado, texto) in enumerate(secciones, start=1):
            fragmentos.append(
                (_id_fragmento, _id_version, posicion, encabezado, texto, None, clase_id, titulo)
            )
            _id_fragmento += 1

        _id_version += 1

assert len(documentos) == 10, len(documentos)
assert len(versiones) == 14, len(versiones)
assert len(fragmentos) == 32, len(fragmentos)


# =============================================================================
# 4. Embeddings sintéticos
# =============================================================================

# Un centroide por clase documental: los fragmentos de la misma clase quedan
# cerca entre sí, de modo que el vecindario temático es conocido de antemano.
centroides = {}
for clase_id, _, _, _ in CLASES:
    base = [0.0] * DIMENSION_VECTOR
    for posicion in range(DIMENSION_VECTOR):
        base[posicion] = 1.0 if posicion % len(CLASES) == (clase_id - 1) else 0.05
    centroides[clase_id] = normalizar(base)

embeddings = []
_id_embedding = 1
vectores_por_fragmento = {}

for fragmento_id, version_id, posicion, encabezado, texto, _, clase_id, _ in fragmentos:
    vector = vector_tematico(centroides[clase_id], ruido=0.12)
    vectores_por_fragmento[fragmento_id] = vector
    embeddings.append(
        (_id_embedding, fragmento_id, MODELO_ACTIVO, vector, INSTANTE_REFERENCIA - timedelta(days=30))
    )
    _id_embedding += 1

# Cuatro fragmentos conservan además un vector del modelo histórico, que nunca
# participa de las búsquedas vigentes.
FRAGMENTOS_HISTORICOS = [1, 8, 17, 26]
for fragmento_id in FRAGMENTOS_HISTORICOS:
    clase_id = fragmentos[fragmento_id - 1][6]
    embeddings.append(
        (
            _id_embedding,
            fragmento_id,
            MODELO_HISTORICO,
            vector_tematico(centroides[clase_id], ruido=0.30),
            INSTANTE_REFERENCIA - timedelta(days=200),
        )
    )
    _id_embedding += 1

assert len(embeddings) == 36, len(embeddings)


def distancia_coseno(a: list[float], b: list[float]) -> float:
    return 1.0 - sum(x * y for x, y in zip(a, b))


def fragmento_esperado(vector_consulta: list[float], recuperables: list[int]) -> int:
    """Fragmento más cercano dentro del universo indicado."""
    return min(
        recuperables,
        key=lambda fid: (distancia_coseno(vector_consulta, vectores_por_fragmento[fid]), fid),
    )


# =============================================================================
# 5. Acceso
# =============================================================================

NOMBRES_ACTOR = [
    ("ACT-001", "Lucía Bengochea", 1, True),
    ("ACT-002", "Rodrigo Paz", 1, True),
    ("ACT-003", "Marina Duarte", 2, True),
    ("ACT-004", "Esteban Correa", 2, True),
    ("ACT-005", "Valeria Ibarra", 3, True),
    ("ACT-006", "Hernán Vidal", 3, False),  # actor inactivo: escenario obligatorio
]

actores = [
    (i, codigo, nombre, perfil, activo)
    for i, (codigo, nombre, perfil, activo) in enumerate(NOMBRES_ACTOR, start=1)
]


# =============================================================================
# 6. Interacción, evidencia y auditoría
# =============================================================================

# Fragmentos recuperables: pertenecen a una versión publicada y vigente.
versiones_vigentes = {
    v[0] for v in versiones
    if v[3] == "publicada"
    and v[4] is not None
    and v[4] <= INSTANTE_REFERENCIA
    and (v[5] is None or v[5] > INSTANTE_REFERENCIA)
}
fragmentos_recuperables = [f[0] for f in fragmentos if f[1] in versiones_vigentes]

clase_de_fragmento = {f[0]: f[6] for f in fragmentos}


def recuperables_para(perfil_id: int) -> list[int]:
    permitidas = {clase for perfil, clase in PERMISOS if perfil == perfil_id}
    return [f for f in fragmentos_recuperables if clase_de_fragmento[f] in permitidas]


def fragmento_de(codigo_documento: str, numero_version: int, posicion: int) -> int:
    """Ubica un fragmento por coordenadas de negocio, no por clave interna."""
    documento_id = next(d[0] for d in documentos if d[1] == codigo_documento)
    version_id = next(
        v[0] for v in versiones if v[1] == documento_id and v[2] == numero_version
    )
    return next(f[0] for f in fragmentos if f[1] == version_id and f[2] == posicion)


def vector_de_consulta(fragmento_objetivo: int, ruido: float = 0.03) -> list[float]:
    """Vector de consulta anclado al fragmento que debe recuperarse.

    Se construye perturbando levemente el vector del fragmento objetivo. Así el
    resultado esperado no depende del azar del ruido entre fragmentos de la
    misma clase: el fragmento correcto queda primero con margen holgado y el
    caso de prueba tiene un oráculo defendible.
    """
    return normalizar(
        [x + rng.uniform(-ruido, ruido) for x in vectores_por_fragmento[fragmento_objetivo]]
    )


# Caso 6: pregunta operativa sobre entregas demoradas. El objetivo es la
# sección "Objetivo del procedimiento" de la versión vigente de DOC-003.
objetivo_vectorial = fragmento_de("DOC-003", 2, 1)
vector_consulta_vectorial = vector_de_consulta(objetivo_vectorial)

# Caso 7: pregunta comercial sobre descuentos por volumen, cuyo universo
# autorizado depende del perfil. El objetivo es la versión vigente de DOC-005.
objetivo_hibrida = fragmento_de("DOC-005", 2, 1)
vector_consulta_hibrida = vector_de_consulta(objetivo_hibrida)

esperado_vectorial = fragmento_esperado(vector_consulta_vectorial, fragmentos_recuperables)
esperado_hibrida_com = fragmento_esperado(vector_consulta_hibrida, recuperables_para(2))

# El oráculo debe cumplirse por construcción: si no, el conjunto no sirve como
# caso de prueba y es preferible fallar en la generación.
assert esperado_vectorial == objetivo_vectorial, (esperado_vectorial, objetivo_vectorial)
assert esperado_hibrida_com == objetivo_hibrida, (esperado_hibrida_com, objetivo_hibrida)

# Siete escenarios: seis producen respuesta exitosa con evidencia y el séptimo
# es un resultado negativo explícito, sin evidencia.
ESCENARIOS = [
    ("ESC-01", 3, "¿Qué condición comercial se aplica hoy al taladro percutor para el Corralón del Norte?", "exito", "estructurada"),
    ("ESC-02", 1, "¿Qué pedidos y entregas requieren atención esta semana?", "exito", "estructurada"),
    ("ESC-03", 3, "¿Cuál es el importe neto facturado por categoría de producto?", "exito", "estructurada"),
    ("ESC-04", 3, "¿Cuáles son los productos principales de cada segmento de cliente?", "exito", "estructurada"),
    ("ESC-05", 3, "¿Qué clientes no registran pedidos históricos?", "exito", "estructurada"),
    ("ESC-06", 1, "¿Cómo debo proceder ante una entrega demorada?", "exito", "documental"),
    ("ESC-07", 1, "¿Qué descuentos por volumen puedo ofrecer a un cliente mayorista?", "sin_fuente_autorizada", "negativa"),
]

consultas = []
respuestas = []
resultados_estructurados = []
evidencias_documentales = []
evidencias_estructuradas = []
eventos = []

_id_resultado = 1
_id_evidencia_doc = 1
_id_evidencia_est = 1
_id_evento = 1


def agregar_evento(actor_id, perfil_id, momento, accion, resultado, recurso_tipo,
                   recurso_id=None, consulta_id=None, respuesta_id=None,
                   ranking=None, score=None, detalles=None):
    global _id_evento
    eventos.append(
        (
            _id_evento,
            actor_id,
            perfil_id,
            momento,
            accion,
            resultado,
            recurso_tipo,
            recurso_id,
            consulta_id,
            respuesta_id,
            ranking,
            score,
            json.dumps(detalles or {}, ensure_ascii=False, sort_keys=True),
        )
    )
    _id_evento += 1


# Eventos del ciclo de vida documental, previos a cualquier consulta.
for version in versiones:
    version_id, documento_id, numero, estado = version[0], version[1], version[2], version[3]
    momento_carga = (version[6] or INSTANTE_REFERENCIA - timedelta(days=420))
    agregar_evento(5, 3, momento_carga - timedelta(days=1), "carga_borrador", "permitido",
                   "version_documental", version_id,
                   detalles={"documento": documentos[documento_id - 1][1], "version": numero})
    if estado != "borrador":
        agregar_evento(5, 3, version[6], "publicacion", "permitido",
                       "version_documental", version_id,
                       detalles={"documento": documentos[documento_id - 1][1], "version": numero})
    if estado == "sustituida":
        agregar_evento(5, 3, version[5], "sustitucion", "permitido",
                       "version_documental", version_id,
                       detalles={"documento": documentos[documento_id - 1][1], "version": numero})
    if estado == "revocada":
        agregar_evento(5, 3, version[7], "revocacion", "permitido",
                       "version_documental", version_id,
                       detalles={"documento": documentos[documento_id - 1][1], "version": numero})

# Interacciones.
for indice, (escenario, actor_id, pregunta, tipo_resultado, naturaleza) in enumerate(
    ESCENARIOS, start=1
):
    perfil_id = actores[actor_id - 1][3]
    instante_consulta = INSTANTE_REFERENCIA - timedelta(minutes=(len(ESCENARIOS) - indice) * 15)
    instante_respuesta = instante_consulta + timedelta(seconds=2)

    consultas.append((indice, actor_id, perfil_id, pregunta, instante_consulta))
    agregar_evento(actor_id, perfil_id, instante_consulta, "consulta_iniciada", "permitido",
                   "consulta", indice, consulta_id=indice, detalles={"escenario": escenario})

    if naturaleza == "negativa":
        contenido = (
            "No hay fuentes autorizadas para el perfil efectivo que respondan la consulta. "
            "No se expone contenido ni evidencia."
        )
    elif naturaleza == "documental":
        contenido = "Se recuperó el procedimiento vigente aplicable y se cita la fuente utilizada."
    else:
        contenido = "Se resolvió con datos operativos estructurados y se conserva el snapshot consultado."

    respuestas.append((indice, indice, tipo_resultado, contenido, instante_respuesta))

    if naturaleza == "estructurada":
        parametros = {"escenario": escenario, "instante_referencia": ts(INSTANTE_REFERENCIA)}
        contenido_json = {"escenario": escenario, "filas": indice + 1}
        resultados_estructurados.append(
            (
                _id_resultado,
                escenario,
                json.dumps(parametros, ensure_ascii=False, sort_keys=True),
                json.dumps(contenido_json, ensure_ascii=False, sort_keys=True),
                instante_respuesta,
                sha256_texto(json.dumps(contenido_json, ensure_ascii=False, sort_keys=True)),
            )
        )
        evidencias_estructuradas.append((_id_evidencia_est, indice, _id_resultado))
        agregar_evento(actor_id, perfil_id, instante_respuesta, "evidencia_utilizada", "permitido",
                       "resultado_estructurado", _id_resultado,
                       consulta_id=indice, respuesta_id=indice)
        _id_resultado += 1
        _id_evidencia_est += 1

    elif naturaleza == "documental":
        universo = recuperables_para(perfil_id)
        ordenados = sorted(
            universo,
            key=lambda fid: (distancia_coseno(vector_consulta_vectorial, vectores_por_fragmento[fid]), fid),
        )[:3]
        for ranking, fragmento_id in enumerate(ordenados, start=1):
            embedding_id = next(
                e[0] for e in embeddings
                if e[1] == fragmento_id and e[2] == MODELO_ACTIVO
            )
            score = round(distancia_coseno(vector_consulta_vectorial, vectores_por_fragmento[fragmento_id]), 8)
            evidencias_documentales.append((_id_evidencia_doc, indice, embedding_id, ranking, score))
            agregar_evento(actor_id, perfil_id, instante_respuesta, "fragmento_recuperado", "permitido",
                           "fragmento", fragmento_id, consulta_id=indice, respuesta_id=indice,
                           ranking=ranking, score=score)
            _id_evidencia_doc += 1
        agregar_evento(actor_id, perfil_id, instante_respuesta, "evidencia_utilizada", "permitido",
                       "embedding", None, consulta_id=indice, respuesta_id=indice)

    else:
        agregar_evento(actor_id, perfil_id, instante_respuesta, "acceso_denegado", "denegado",
                       "clase_documental", 3, consulta_id=indice, respuesta_id=indice,
                       detalles={"motivo": "perfil sin permiso sobre la clase documental"})

    agregar_evento(actor_id, perfil_id, instante_respuesta, "respuesta_generada", "permitido",
                   "respuesta", indice, consulta_id=indice, respuesta_id=indice,
                   detalles={"tipo_resultado": tipo_resultado})


# =============================================================================
# 7. Emisión de artefactos
# =============================================================================

def escribir_documentos() -> list[dict]:
    DIR_DOCUMENTOS.mkdir(parents=True, exist_ok=True)
    for archivo in sorted(DIR_DOCUMENTOS.glob("*.md")):
        archivo.unlink()

    inventario = []
    for ruta_relativa, contenido in archivos:
        destino = RAIZ / ruta_relativa
        destino.write_text(contenido, encoding="utf-8")
        inventario.append(
            {
                "ruta": ruta_relativa,
                "tamano_bytes": len(contenido.encode("utf-8")),
                "sha256": sha256_texto(contenido),
            }
        )
    return inventario


def construir_seed() -> str:
    partes: list[str] = []
    partes.append(
        "-- =============================================================================\n"
        "-- 02_seed.sql - Carga reproducible del conjunto sintético\n"
        "-- =============================================================================\n"
        "--\n"
        "-- ARCHIVO GENERADO. No editar a mano: se produce con\n"
        "--     python scripts/generar_datos.py\n"
        "--\n"
        f"-- Versión del generador : {VERSION_GENERADOR}\n"
        f"-- Semilla               : {SEMILLA}\n"
        f"-- Instante de referencia: {ts(INSTANTE_REFERENCIA)}\n"
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
    )

    partes.append("-- --- Catálogos ---------------------------------------------------------\n")
    partes.append(sql_insert("categoria_producto", ["id", "codigo", "nombre"], CATEGORIAS))
    partes.append(sql_insert("segmento_cliente", ["id", "codigo", "nombre"], SEGMENTOS))
    partes.append(sql_insert("perfil_autorizado", ["id", "codigo", "nombre"], PERFILES))
    partes.append(sql_insert("clase_documental", ["id", "codigo", "nombre", "descripcion"], CLASES))
    partes.append(sql_insert("nivel_sensibilidad", ["id", "codigo", "nombre", "requiere_auditoria"], SENSIBILIDADES))
    partes.append(sql_insert("modelo_embedding", ["id", "nombre", "version", "dimension", "metrica", "activo"], MODELOS))

    partes.append("\n-- --- Núcleo operativo -------------------------------------------------\n")
    partes.append(sql_insert("producto", ["id", "codigo", "nombre", "categoria_id", "activo"], productos))
    partes.append(sql_insert("cliente", ["id", "codigo", "razon_social", "segmento_id", "activo"], clientes))
    partes.append(sql_insert("proveedor", ["id", "codigo", "razon_social", "activo"], proveedores))
    partes.append(sql_insert("producto_proveedor", ["producto_id", "proveedor_id"], producto_proveedor))
    partes.append(sql_insert(
        "condicion_comercial",
        ["id", "cliente_id", "producto_id", "precio_unitario", "descuento_porcentaje",
         "vigente_desde", "vigente_hasta"],
        condiciones,
    ))
    partes.append(sql_insert("pedido", ["id", "codigo", "cliente_id", "fecha", "estado"], pedidos))
    partes.append(sql_insert(
        "linea_pedido",
        ["id", "pedido_id", "numero_linea", "producto_id", "cantidad",
         "precio_unitario", "descuento_porcentaje"],
        lineas,
    ))
    partes.append(sql_insert(
        "entrega",
        ["id", "codigo", "pedido_id", "fecha_programada", "fecha_efectiva", "estado"],
        entregas,
    ))
    partes.append(sql_insert(
        "incidencia_operativa",
        ["id", "codigo", "entrega_id", "fecha", "tipo", "descripcion", "estado"],
        incidencias,
    ))

    partes.append("\n-- --- Núcleo documental ------------------------------------------------\n")
    partes.append(sql_insert(
        "documento",
        ["id", "codigo", "titulo", "clase_id", "sensibilidad_id", "procedencia", "activo"],
        documentos,
    ))
    partes.append(sql_insert(
        "version_documental",
        ["id", "documento_id", "numero_version", "estado", "vigente_desde", "vigente_hasta",
         "publicada_en", "revocada_en", "ruta_relativa", "nombre_archivo", "tipo_mime",
         "tamano_bytes", "sha256"],
        versiones,
    ))
    partes.append(sql_insert(
        "fragmento",
        ["id", "version_id", "posicion", "titulo", "contenido", "pagina"],
        [(f[0], f[1], f[2], f[3], f[4], f[5]) for f in fragmentos],
    ))

    partes.append("\n-- --- Embeddings -------------------------------------------------------\n")
    filas_embedding = ",\n    ".join(
        f"({e[0]}, {e[1]}, {e[2]}, {sql_vector(e[3])}, {sql_texto(e[4])})"
        for e in embeddings
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
    partes.append(sql_insert("actor", ["id", "codigo", "nombre", "perfil_autorizado_id", "activo"], actores))
    partes.append(sql_insert("permiso_documental", ["perfil_id", "clase_id"], PERMISOS))

    partes.append("\n-- --- Interacción, evidencia y auditoría --------------------------------\n")
    partes.append(sql_insert(
        "consulta", ["id", "actor_id", "perfil_efectivo_id", "pregunta", "instante"], consultas))
    partes.append(sql_insert(
        "respuesta", ["id", "consulta_id", "tipo_resultado", "contenido", "instante"], respuestas))
    partes.append(sql_insert(
        "resultado_estructurado",
        ["id", "tipo_consulta", "parametros", "contenido", "generado_en", "hash"],
        resultados_estructurados,
    ))
    partes.append(sql_insert(
        "evidencia_documental",
        ["id", "respuesta_id", "embedding_id", "ranking", "score"],
        evidencias_documentales,
    ))
    partes.append(sql_insert(
        "evidencia_estructurada",
        ["id", "respuesta_id", "resultado_estructurado_id"],
        evidencias_estructuradas,
    ))
    partes.append(sql_insert(
        "evento_auditoria",
        ["id", "actor_id", "perfil_efectivo_id", "instante", "accion", "resultado",
         "recurso_tipo", "recurso_id", "consulta_id", "respuesta_id", "ranking", "score", "detalles"],
        eventos,
    ))

    # Las secuencias quedan por encima del máximo id insertado: de lo contrario
    # el primer INSERT sin id explícito chocaría contra la clave primaria.
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


def construir_manifiesto(inventario: list[dict]) -> dict:
    return {
        "version_generador": VERSION_GENERADOR,
        "semilla": SEMILLA,
        "instante_referencia": ts(INSTANTE_REFERENCIA),
        "modelo_vectorial": {
            "dimension": DIMENSION_VECTOR,
            "metrica": METRICA_VECTOR,
            "modelo_activo": "distribuidora-emb v2",
            "modelo_historico": "distribuidora-emb v1",
        },
        "conteos": {
            "categoria_producto": len(CATEGORIAS),
            "segmento_cliente": len(SEGMENTOS),
            "perfil_autorizado": len(PERFILES),
            "clase_documental": len(CLASES),
            "nivel_sensibilidad": len(SENSIBILIDADES),
            "modelo_embedding": len(MODELOS),
            "producto": len(productos),
            "cliente": len(clientes),
            "proveedor": len(proveedores),
            "producto_proveedor": len(producto_proveedor),
            "condicion_comercial": len(condiciones),
            "pedido": len(pedidos),
            "linea_pedido": len(lineas),
            "entrega": len(entregas),
            "incidencia_operativa": len(incidencias),
            "documento": len(documentos),
            "version_documental": len(versiones),
            "fragmento": len(fragmentos),
            "embedding": len(embeddings),
            "actor": len(actores),
            "permiso_documental": len(PERMISOS),
            "consulta": len(consultas),
            "respuesta": len(respuestas),
            "resultado_estructurado": len(resultados_estructurados),
            "evidencia_documental": len(evidencias_documentales),
            "evidencia_estructurada": len(evidencias_estructuradas),
            "evento_auditoria": len(eventos),
        },
        "escenarios": [
            {
                "id": escenario,
                "actor": actores[actor_id - 1][1],
                "perfil": PERFILES[actores[actor_id - 1][3] - 1][1],
                "pregunta": pregunta,
                "tipo_resultado": tipo_resultado,
                "con_evidencia": naturaleza != "negativa",
            }
            for escenario, actor_id, pregunta, tipo_resultado, naturaleza in ESCENARIOS
        ],
        "oraculos_vectoriales": {
            "consulta_vectorial": {
                "vector": vector_consulta_vectorial,
                "fragmento_esperado": esperado_vectorial,
                "documento_esperado": documentos[
                    versiones[fragmentos[esperado_vectorial - 1][1] - 1][1] - 1
                ][1],
            },
            "consulta_hibrida": {
                "vector": vector_consulta_hibrida,
                "fragmento_esperado_comercial": esperado_hibrida_com,
                "documento_esperado_comercial": documentos[
                    versiones[fragmentos[esperado_hibrida_com - 1][1] - 1][1] - 1
                ][1],
            },
        },
        "matriz_permisos": {
            PERFILES[perfil - 1][1]: sorted(
                CLASES[clase - 1][1] for p, clase in PERMISOS if p == perfil
            )
            for perfil, _ in PERMISOS
        },
        "archivos": inventario,
    }


def main() -> None:
    inventario = escribir_documentos()

    seed = construir_seed()
    RUTA_SEED.parent.mkdir(parents=True, exist_ok=True)
    RUTA_SEED.write_text(seed, encoding="utf-8")

    manifiesto = construir_manifiesto(inventario)
    manifiesto["checksums"] = {
        "db/datos/02_seed.sql": sha256_texto(seed),
    }
    RUTA_MANIFIESTO.write_text(
        json.dumps(manifiesto, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    print(f"Documentos generados : {len(inventario)}")
    print(f"Seed                 : {RUTA_SEED.relative_to(RAIZ)}")
    print(f"Manifiesto           : {RUTA_MANIFIESTO.relative_to(RAIZ)}")
    print(f"Fragmento esperado (vectorial) : {esperado_vectorial}")
    print(f"Fragmento esperado (híbrida/COM): {esperado_hibrida_com}")


if __name__ == "__main__":
    main()
