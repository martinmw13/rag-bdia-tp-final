-- =============================================================================
-- 04_consultas.sql - Consultas representativas de negocio y recuperación
-- =============================================================================
--
-- Casos 1 a 6. Los casos 7 (recuperación híbrida autorizada), 8 (matriz de
-- autorización) y 9 (trazabilidad e inmutabilidad) viven en
-- db/consultas/06_consultas_seguridad.sql, porque sólo tienen sentido con los
-- roles y las políticas de RLS ya aplicados.
--
-- Cada consulta declara identificador, propósito, pregunta del dominio,
-- parámetros con sus valores de prueba, resultado esperado en códigos de
-- negocio y el patrón SQL que demuestra.
--
-- Los resultados esperados corresponden al conjunto sintético generado con
-- semilla 42 e instante de referencia 2026-06-30T15:00:00Z. Se verificaron
-- ejecutando estas mismas sentencias sobre una carga limpia.
--
-- Ejecución. La consulta C6 recibe el vector de consulta como parámetro, que
-- está publicado en data/ejemplos/manifiesto.json:
--
--   VECTOR=$(python3 -c "import json; \
--       v=json.load(open('data/ejemplos/manifiesto.json')) \
--       ['oraculos_vectoriales']['consulta_vectorial']['vector']; \
--       print('['+','.join(f'{x:.8f}' for x in v)+']')")
--   psql -d rag_distribuidora -v vector_consulta=\"\$VECTOR\" -f db/consultas/04_consultas.sql
-- =============================================================================

SET TIME ZONE 'UTC';


-- =============================================================================
-- C1. Condición comercial vigente
-- =============================================================================
-- Pregunta   : ¿Qué precio y descuento se aplican hoy a un producto para un
--              cliente determinado?
-- Parámetros : cliente = 'CLI-001', producto = 'PRD-001',
--              instante = DATE '2026-06-30'
-- Espera     : exactamente 1 fila — precio 185646.07, descuento 5.00,
--              vigencia [2026-03-02, 2026-07-30). Quedan excluidas la
--              condición vencida y la futura del mismo par cliente-producto.
-- Patrón     : selección y filtrado sobre un intervalo semiabierto.
-- Utilidad   : es la consulta que responde "cuánto le cobro a este cliente",
--              y demuestra que la historia de precios no contamina el valor
--              vigente.
-- =============================================================================

BEGIN;
SET LOCAL ROLE rag_runtime;
SELECT set_config('rag.actor', 'ACT-003', true);

SELECT
    c.codigo  AS cliente,
    p.codigo  AS producto,
    cc.precio_unitario,
    cc.descuento_porcentaje,
    cc.vigente_desde,
    cc.vigente_hasta
FROM condicion_comercial cc
JOIN cliente  c ON c.id = cc.cliente_id
JOIN producto p ON p.id = cc.producto_id
WHERE c.codigo = 'CLI-001'
  AND p.codigo = 'PRD-001'
  AND cc.vigente_desde <= DATE '2026-06-30'
  AND (cc.vigente_hasta IS NULL OR cc.vigente_hasta > DATE '2026-06-30');

COMMIT;


-- =============================================================================
-- C2. Pedidos y entregas que requieren atención
-- =============================================================================
-- Pregunta   : ¿Qué entregas están demoradas o todavía en tránsito, y cuáles
--              tienen una incidencia registrada?
-- Parámetros : ninguno.
-- Espera     : 3 filas — PED-003/ENT-013 en tránsito sin incidencia (entrega
--              parcial), y PED-005 con ENT-005 demorada e INC-001 de tipo
--              'demora' más ENT-014 en tránsito. El pedido cancelado PED-012
--              no aparece porque no tiene entregas.
-- Patrón     : JOIN entre cuatro entidades y LEFT JOIN para conservar la
--              entrega aunque no haya incidencia.
-- Utilidad   : es el tablero operativo de seguimiento; el LEFT JOIN evita
--              perder entregas problemáticas que todavía no fueron
--              formalizadas como incidencia.
-- =============================================================================

BEGIN;
SET LOCAL ROLE rag_runtime;
SELECT set_config('rag.actor', 'ACT-001', true);

SELECT
    p.codigo  AS pedido,
    c.codigo  AS cliente,
    p.estado  AS estado_pedido,
    e.codigo  AS entrega,
    e.estado  AS estado_entrega,
    e.fecha_programada,
    i.codigo  AS incidencia,
    i.tipo    AS tipo_incidencia
FROM pedido p
JOIN cliente c ON c.id = p.cliente_id
JOIN entrega e ON e.pedido_id = p.id
LEFT JOIN incidencia_operativa i ON i.entrega_id = e.id
WHERE p.estado <> 'cancelado'
  AND e.estado IN ('demorada', 'en_transito')
ORDER BY p.codigo, e.codigo;

COMMIT;


-- =============================================================================
-- C3. Importe neto por categoría
-- =============================================================================
-- Pregunta   : ¿Cuánto se facturó por categoría de producto, ya descontados
--              los descuentos aplicados?
-- Parámetros : ninguno.
-- Espera     : 4 filas — CAT-ELEC 29413118.87 (10 líneas), CAT-EMBA
--              12002449.50 (6), CAT-FERR 13098769.04 (6), CAT-SEGU
--              12220765.35 (5). Excluye el pedido cancelado.
-- Patrón     : agregación con GROUP BY sobre una expresión de cálculo.
-- Utilidad   : responde la pregunta comercial de mezcla de ventas, y usa los
--              snapshots de precio y descuento de la línea en lugar de la
--              condición comercial vigente, que pudo haber cambiado después.
-- =============================================================================

SELECT
    cat.codigo AS categoria,
    cat.nombre AS categoria_nombre,
    count(DISTINCT lp.pedido_id) AS pedidos,
    count(*)                     AS lineas,
    round(sum(lp.cantidad * lp.precio_unitario
              * (1 - lp.descuento_porcentaje / 100)), 2) AS importe_neto
FROM linea_pedido lp
JOIN pedido p              ON p.id   = lp.pedido_id
JOIN producto pr           ON pr.id  = lp.producto_id
JOIN categoria_producto cat ON cat.id = pr.categoria_id
WHERE p.estado <> 'cancelado'
GROUP BY cat.codigo, cat.nombre
ORDER BY cat.codigo;


-- =============================================================================
-- C4. Productos principales por segmento
-- =============================================================================
-- Pregunta   : Dentro de cada segmento de cliente, ¿qué productos concentran
--              el mayor importe neto?
-- Parámetros : ninguno.
-- Espera     : el primer puesto de cada segmento es PRD-010 en SEG-CORP
--              (2742424.82), PRD-001 en SEG-MAY (7542340.23) y PRD-006 en
--              SEG-MIN (14193094.55).
-- Patrón     : función de ventana DENSE_RANK sobre una partición.
-- Utilidad   : permite comparar el peso relativo de cada producto dentro de
--              su segmento sin mezclar segmentos de tamaños distintos. La
--              posición depende sólo del importe; el código de producto
--              interviene únicamente para estabilizar la presentación de
--              empates, de modo que dos ejecuciones devuelvan el mismo orden.
-- =============================================================================

WITH importe_por_segmento_producto AS (
    SELECT
        s.codigo  AS segmento,
        pr.codigo AS producto,
        pr.nombre AS producto_nombre,
        sum(lp.cantidad * lp.precio_unitario
            * (1 - lp.descuento_porcentaje / 100)) AS importe_neto
    FROM linea_pedido lp
    JOIN pedido p            ON p.id  = lp.pedido_id AND p.estado <> 'cancelado'
    JOIN cliente c           ON c.id  = p.cliente_id
    JOIN segmento_cliente s  ON s.id  = c.segmento_id
    JOIN producto pr         ON pr.id = lp.producto_id
    GROUP BY s.codigo, pr.codigo, pr.nombre
)
SELECT
    segmento,
    producto,
    producto_nombre,
    round(importe_neto, 2) AS importe_neto,
    DENSE_RANK() OVER (PARTITION BY segmento ORDER BY importe_neto DESC) AS posicion
FROM importe_por_segmento_producto
ORDER BY segmento, posicion, producto;


-- =============================================================================
-- C5. Clientes sin pedidos históricos
-- =============================================================================
-- Pregunta   : ¿Qué clientes registrados nunca hicieron un pedido?
-- Parámetros : ninguno.
-- Espera     : exactamente 1 fila — CLI-006, "Servicios Integrales Sur",
--              segmento SEG-CORP. Un pedido cancelado cuenta como antecedente
--              histórico, así que sus clientes no aparecen acá.
-- Patrón     : subconsulta correlacionada con NOT EXISTS.
-- Utilidad   : alimenta la acción comercial sobre cuentas inactivas.
--              NOT EXISTS se prefiere a un LEFT JOIN con IS NULL porque
--              expresa la intención directamente y corta en la primera
--              coincidencia.
-- =============================================================================

SELECT
    c.codigo AS cliente,
    c.razon_social,
    s.codigo AS segmento
FROM cliente c
JOIN segmento_cliente s ON s.id = c.segmento_id
WHERE NOT EXISTS (
    SELECT 1 FROM pedido p WHERE p.cliente_id = c.id
)
ORDER BY c.codigo;


-- =============================================================================
-- C6. Búsqueda vectorial top-k
-- =============================================================================
-- Pregunta   : ¿Qué fragmento del corpus responde mejor a "cómo proceder ante
--              una entrega demorada"?
-- Parámetros : vector de consulta sintético del modelo activo
--              (distribuidora-emb v2), k = 5. El vector está registrado en
--              data/ejemplos/manifiesto.json, en oraculos_vectoriales.
-- Espera     : primer puesto para el fragmento 10, "Objetivo del
--              procedimiento" de DOC-003, con distancia 0.004763. El segundo
--              queda a 0.090607, así que el orden no depende de un empate.
--              Todos los resultados pertenecen a versiones publicadas y
--              vigentes: los fragmentos de versiones sustituidas, revocadas o
--              en borrador no participan.
-- Patrón     : recuperación vectorial por distancia coseno con orden estable.
-- Utilidad   : es el corazón del copiloto. El desempate por fragmento_id
--              garantiza que dos ejecuciones devuelvan la misma lista aunque
--              dos vectores queden a igual distancia.
-- =============================================================================

BEGIN;
SET LOCAL ROLE rag_runtime;
SELECT set_config('rag.actor', 'ACT-001', true);

SELECT
    fr.fragmento_id,
    fr.documento_codigo,
    fr.clase_codigo,
    fr.fragmento_titulo,
    fr.numero_version,
    round((fr.vector <=> :'vector_consulta'::vector)::numeric, 6) AS distancia
FROM fragmento_recuperable fr
ORDER BY fr.vector <=> :'vector_consulta'::vector, fr.fragmento_id
LIMIT 5;

COMMIT;
