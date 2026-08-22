-- =============================================================================
-- 03_indices.sql - Índices, vistas y estructuras de acceso
-- =============================================================================
--
-- Criterio: sólo se crean índices que respaldan un patrón de consulta real de
-- db/consultas/04_consultas.sql. No se agregan índices "por si acaso" ni se
-- duplican los que PostgreSQL ya crea para claves primarias, restricciones de
-- unicidad y restricciones de exclusión.
--
-- Un índice de unicidad sobre (a, b) ya sirve para buscar por `a`, así que las
-- claves foráneas cubiertas por el prefijo de una unicidad existente no
-- reciben un índice propio. Es el caso de:
--   - version_documental.documento_id  -> cubierto por (documento_id, numero_version)
--   - embedding.fragmento_id           -> cubierto por (fragmento_id, modelo_id)
--   - linea_pedido.pedido_id           -> cubierto por (pedido_id, numero_linea)
--   - fragmento.version_id             -> cubierto por (version_id, posicion)
--   - evidencia_documental.respuesta_id-> cubierto por (respuesta_id, ranking)
--
-- Sobre la escala: el conjunto de prueba tiene entre 12 y 56 filas por tabla.
-- A ese tamaño el planificador elige `Seq Scan` incluso habiendo índice, porque
-- recorrer la tabla entera es más barato que pasar por el índice. Eso no
-- invalida la decisión: los índices están justificados por el patrón de acceso
-- y por cómo crecerían las tablas en un escenario real. Ver la sección de
-- rendimiento del informe.
-- =============================================================================

SET TIME ZONE 'UTC';

BEGIN;

-- --- Núcleo operativo -------------------------------------------------------

-- Consulta 3: importe neto por categoría (join linea_pedido -> producto -> categoría).
CREATE INDEX IF NOT EXISTS producto_categoria_ix ON producto (categoria_id);

-- Consulta 4: acumulación por segmento (join cliente -> segmento).
CREATE INDEX IF NOT EXISTS cliente_segmento_ix ON cliente (segmento_id);

-- Consultas 2 y 5: recorrido pedido -> cliente y búsqueda de clientes sin pedidos.
CREATE INDEX IF NOT EXISTS pedido_cliente_ix ON pedido (cliente_id);

-- Consultas 3 y 4: join linea_pedido -> producto.
CREATE INDEX IF NOT EXISTS linea_pedido_producto_ix ON linea_pedido (producto_id);

-- Consulta 2: recorrido pedido -> entrega -> incidencia.
CREATE INDEX IF NOT EXISTS entrega_pedido_ix ON entrega (pedido_id);
CREATE INDEX IF NOT EXISTS incidencia_entrega_ix ON incidencia_operativa (entrega_id);

-- Consulta 1: condición vigente para un cliente, un producto y un instante.
-- El índice de exclusión es GiST y sirve para detectar solapamientos, no para
-- resolver eficientemente esta búsqueda por igualdad más rango.
CREATE INDEX IF NOT EXISTS condicion_comercial_busqueda_ix
    ON condicion_comercial (cliente_id, producto_id, vigente_desde DESC);

-- --- Núcleo documental y vectorial ------------------------------------------

-- Autorización: el filtro por clase documental es el que limita el universo
-- recuperable antes del ranking.
CREATE INDEX IF NOT EXISTS documento_clase_ix ON documento (clase_id);

-- Recuperación vigente: filtra por estado y ventana de vigencia.
CREATE INDEX IF NOT EXISTS version_documental_vigencia_ix
    ON version_documental (estado, vigente_desde, vigente_hasta);

-- Búsqueda vectorial: restringe al modelo activo antes de ordenar por distancia.
CREATE INDEX IF NOT EXISTS embedding_modelo_ix ON embedding (modelo_id);

-- Índice vectorial HNSW con distancia coseno y parámetros por defecto.
-- Es la estructura de acceso que justifica la elección de pgvector: sin él, la
-- búsqueda por similitud degrada a comparar la consulta contra todos los
-- vectores almacenados.
CREATE INDEX IF NOT EXISTS embedding_vector_hnsw_ix
    ON embedding USING hnsw (vector vector_cosine_ops);

-- --- Acceso, interacción y auditoría ----------------------------------------

-- Resolución del perfil efectivo de cada actor.
CREATE INDEX IF NOT EXISTS actor_perfil_ix ON actor (perfil_autorizado_id);

-- Consulta 9: reconstrucción de una interacción a partir de su actor.
CREATE INDEX IF NOT EXISTS consulta_actor_ix ON consulta (actor_id);

-- Consulta 9: correlación de los eventos de una consulta o respuesta, en orden.
CREATE INDEX IF NOT EXISTS evento_auditoria_consulta_ix
    ON evento_auditoria (consulta_id, instante);
CREATE INDEX IF NOT EXISTS evento_auditoria_respuesta_ix
    ON evento_auditoria (respuesta_id, instante);

-- Auditoría por tipo de acción y ventana temporal.
CREATE INDEX IF NOT EXISTS evento_auditoria_accion_ix
    ON evento_auditoria (accion, instante);

-- Reconstrucción de la evidencia hasta el embedding exacto utilizado.
CREATE INDEX IF NOT EXISTS evidencia_documental_embedding_ix
    ON evidencia_documental (embedding_id);


-- =============================================================================
-- Vista de fragmentos recuperables
-- =============================================================================
--
-- Reúne fragmento, versión, documento y modelo aplicando las condiciones de
-- vigencia y actividad, que son independientes de quién consulta.
--
-- `security_invoker = true` es lo esencial: la vista se ejecuta con los
-- privilegios de quien la invoca, no del propietario. Sin esa cláusula, una
-- vista sería un camino para eludir las políticas de RLS que se aplican en
-- 05_seguridad.sql, y el runtime podría leer filas que su rol tiene prohibidas.
--
-- La autorización por perfil y clase NO se resuelve acá: se aplica mediante RLS
-- sobre las tablas subyacentes, de modo que el filtro siga vigente aunque
-- alguien consulte las tablas directamente en lugar de usar esta vista.
-- =============================================================================

CREATE OR REPLACE VIEW fragmento_recuperable
WITH (security_invoker = true) AS
SELECT
    f.id            AS fragmento_id,
    f.posicion,
    f.titulo        AS fragmento_titulo,
    f.contenido,
    f.pagina,
    v.id            AS version_id,
    v.numero_version,
    v.vigente_desde,
    v.vigente_hasta,
    d.id            AS documento_id,
    d.codigo        AS documento_codigo,
    d.titulo        AS documento_titulo,
    d.clase_id,
    cd.codigo       AS clase_codigo,
    d.sensibilidad_id,
    ns.codigo       AS sensibilidad_codigo,
    e.id            AS embedding_id,
    e.vector,
    e.modelo_id,
    me.nombre       AS modelo_nombre,
    me.version      AS modelo_version
FROM fragmento f
JOIN version_documental v  ON v.id  = f.version_id
JOIN documento d           ON d.id  = v.documento_id
JOIN clase_documental cd   ON cd.id = d.clase_id
JOIN nivel_sensibilidad ns ON ns.id = d.sensibilidad_id
JOIN embedding e           ON e.fragmento_id = f.id
JOIN modelo_embedding me   ON me.id = e.modelo_id
WHERE d.activo
  AND me.activo
  AND v.estado = 'publicada'
  AND v.vigente_desde <= now()
  AND (v.vigente_hasta IS NULL OR v.vigente_hasta > now());

COMMENT ON VIEW fragmento_recuperable IS
    'Universo recuperable en el instante actual: sólo versiones publicadas y '
    'vigentes de documentos activos, vectorizadas con el modelo activo. Se '
    'ejecuta con los privilegios del invocador para no eludir RLS.';

COMMIT;
