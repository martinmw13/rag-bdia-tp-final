-- =============================================================================
-- 07_validaciones.sql - Aserciones de integridad, seguridad y ciclo documental
-- =============================================================================
--
-- Este archivo se ejecuta sólo sobre la base dedicada que crea
-- scripts/validar_base.sh. Cada prueba de escritura usa una subtransacción o un
-- ROLLBACK para no alterar el conjunto de referencia.
-- =============================================================================

SET TIME ZONE 'UTC';

-- --- Restricciones locales y temporales -------------------------------------

DO $$
BEGIN
    BEGIN
        INSERT INTO producto (codigo, nombre, categoria_id)
        VALUES ('PRD-001', 'Duplicado', 1);
        RAISE EXCEPTION 'se aceptó un código de producto duplicado';
    EXCEPTION WHEN unique_violation THEN
        NULL;
    END;

    BEGIN
        INSERT INTO pedido (codigo, cliente_id, fecha, estado)
        VALUES ('PED-FK', 999999, DATE '2026-07-01', 'pendiente');
        RAISE EXCEPTION 'se aceptó una clave foránea inexistente';
    EXCEPTION WHEN foreign_key_violation THEN
        NULL;
    END;

    BEGIN
        INSERT INTO condicion_comercial (
            cliente_id, producto_id, precio_unitario, descuento_porcentaje,
            vigente_desde
        ) VALUES (1, 2, 100, 101, DATE '2026-07-01');
        RAISE EXCEPTION 'se aceptó un descuento mayor que 100';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;

    BEGIN
        INSERT INTO condicion_comercial (
            cliente_id, producto_id, precio_unitario, descuento_porcentaje,
            vigente_desde, vigente_hasta
        ) VALUES (1, 1, 100, 0, DATE '2026-04-01', DATE '2026-05-01');
        RAISE EXCEPTION 'se aceptó un solapamiento comercial';
    EXCEPTION WHEN exclusion_violation THEN
        NULL;
    END;

    BEGIN
        INSERT INTO version_documental (
            documento_id, numero_version, estado, vigente_desde, vigente_hasta,
            publicada_en, ruta_relativa, nombre_archivo, tipo_mime,
            tamano_bytes, sha256
        ) VALUES (
            1, 99, 'publicada', TIMESTAMPTZ '2026-01-01 00:00:00+00', NULL,
            TIMESTAMPTZ '2026-01-01 00:00:00+00',
            'data/ejemplos/documentos/prueba.md', 'prueba.md', 'text/markdown',
            1, repeat('a', 64)
        );
        RAISE EXCEPTION 'se aceptó un solapamiento documental';
    EXCEPTION WHEN exclusion_violation THEN
        NULL;
    END;
END;
$$;

-- --- Invariantes diferidos --------------------------------------------------

DO $$
DECLARE
    v_id BIGINT;
BEGIN
    BEGIN
        INSERT INTO pedido (codigo, cliente_id, fecha, estado)
        VALUES ('PED-VACIO', 1, DATE '2026-07-01', 'pendiente');
        SET CONSTRAINTS ALL IMMEDIATE;
        RAISE EXCEPTION 'se aceptó un pedido sin líneas';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;

    BEGIN
        INSERT INTO consulta (actor_id, perfil_efectivo_id, pregunta, instante)
        VALUES (1, 1, 'Prueba sin evidencia', clock_timestamp())
        RETURNING id INTO v_id;

        INSERT INTO respuesta (consulta_id, tipo_resultado, contenido, instante)
        VALUES (v_id, 'exito', 'Respuesta inválida', clock_timestamp());
        SET CONSTRAINTS ALL IMMEDIATE;
        RAISE EXCEPTION 'se aceptó una respuesta exitosa sin evidencia';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;

    BEGIN
        INSERT INTO consulta (actor_id, perfil_efectivo_id, pregunta, instante)
        VALUES (1, 1, 'Prueba negativa con evidencia', clock_timestamp())
        RETURNING id INTO v_id;

        INSERT INTO respuesta (consulta_id, tipo_resultado, contenido, instante)
        VALUES (v_id, 'sin_resultados', 'Sin resultados', clock_timestamp())
        RETURNING id INTO v_id;

        INSERT INTO evidencia_documental (
            respuesta_id, embedding_id, ranking, score
        ) VALUES (v_id, 10, 1, 0.1);
        SET CONSTRAINTS ALL IMMEDIATE;
        RAISE EXCEPTION 'se aceptó evidencia para una respuesta negativa';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;

    BEGIN
        DELETE FROM linea_pedido WHERE pedido_id = 12;
        SET CONSTRAINTS ALL IMMEDIATE;
        RAISE EXCEPTION 'se permitió eliminar la última línea de un pedido';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;
END;
$$;

-- --- Matriz perfil/clase y contextos ---------------------------------------

BEGIN;
SET LOCAL ROLE rag_runtime;
SELECT set_config('rag.actor', 'ACT-001', true);
DO $$
DECLARE
    v_obtenido JSONB;
BEGIN
    SELECT jsonb_object_agg(cd.codigo, cantidad ORDER BY cd.codigo)
      INTO v_obtenido
      FROM clase_documental cd
      CROSS JOIN LATERAL (
          SELECT count(f.id) AS cantidad
          FROM documento d
          JOIN version_documental v ON v.documento_id = d.id
          JOIN fragmento f ON f.version_id = v.id
          WHERE d.clase_id = cd.id
      ) conteo;
    IF v_obtenido <> '{"CUMP": 0, "FICHA": 7, "LEGAL": 0, "POL": 0, "PROC": 6}'::jsonb THEN
        RAISE EXCEPTION 'matriz OPS inesperada: %', v_obtenido;
    END IF;
END;
$$;
ROLLBACK;

BEGIN;
SET LOCAL ROLE rag_runtime;
SELECT set_config('rag.actor', 'ACT-003', true);
DO $$
DECLARE
    v_obtenido JSONB;
BEGIN
    SELECT jsonb_object_agg(cd.codigo, cantidad ORDER BY cd.codigo)
      INTO v_obtenido
      FROM clase_documental cd
      CROSS JOIN LATERAL (
          SELECT count(f.id) AS cantidad
          FROM documento d
          JOIN version_documental v ON v.documento_id = d.id
          JOIN fragmento f ON f.version_id = v.id
          WHERE d.clase_id = cd.id
      ) conteo;
    IF v_obtenido <> '{"CUMP": 0, "FICHA": 7, "LEGAL": 0, "POL": 3, "PROC": 0}'::jsonb THEN
        RAISE EXCEPTION 'matriz COM inesperada: %', v_obtenido;
    END IF;
END;
$$;
ROLLBACK;

BEGIN;
SET LOCAL ROLE rag_runtime;
SELECT set_config('rag.actor', 'ACT-005', true);
DO $$
DECLARE
    v_obtenido JSONB;
BEGIN
    SELECT jsonb_object_agg(cd.codigo, cantidad ORDER BY cd.codigo)
      INTO v_obtenido
      FROM clase_documental cd
      CROSS JOIN LATERAL (
          SELECT count(f.id) AS cantidad
          FROM documento d
          JOIN version_documental v ON v.documento_id = d.id
          JOIN fragmento f ON f.version_id = v.id
          WHERE d.clase_id = cd.id
      ) conteo;
    IF v_obtenido <> '{"CUMP": 2, "FICHA": 7, "LEGAL": 2, "POL": 0, "PROC": 6}'::jsonb THEN
        RAISE EXCEPTION 'matriz ADM inesperada: %', v_obtenido;
    END IF;
END;
$$;
ROLLBACK;

BEGIN;
SET LOCAL ROLE rag_runtime;
DO $$
DECLARE
    v_contexto TEXT;
    v_cantidad BIGINT;
BEGIN
    FOREACH v_contexto IN ARRAY ARRAY['', 'ACT-999', 'ACT-006']
    LOOP
        PERFORM set_config('rag.actor', v_contexto, true);
        SELECT count(*) INTO v_cantidad FROM fragmento_recuperable;
        IF v_cantidad <> 0 THEN
            RAISE EXCEPTION 'el contexto inválido % expuso % fragmentos',
                v_contexto, v_cantidad;
        END IF;
    END LOOP;
END;
$$;

SELECT set_config('rag.actor', '', true);
DO $$
BEGIN
    IF (SELECT count(*) FROM fragmento_recuperable) <> 0 THEN
        RAISE EXCEPTION 'el contexto ausente expuso fragmentos';
    END IF;
END;
$$;
ROLLBACK;

-- --- Aislamiento de datos operativos ---------------------------------------

BEGIN;
SET LOCAL ROLE rag_runtime;
SELECT set_config('rag.actor', 'ACT-001', true);
DO $$ BEGIN
    IF (SELECT count(*) FROM condicion_comercial) <> 0
       OR (SELECT count(*) FROM incidencia_operativa) <> 4 THEN
        RAISE EXCEPTION 'aislamiento operativo incorrecto para OPS';
    END IF;
END $$;
ROLLBACK;

BEGIN;
SET LOCAL ROLE rag_runtime;
SELECT set_config('rag.actor', 'ACT-003', true);
DO $$ BEGIN
    IF (SELECT count(*) FROM condicion_comercial) <> 12
       OR (SELECT count(*) FROM incidencia_operativa) <> 0 THEN
        RAISE EXCEPTION 'aislamiento operativo incorrecto para COM';
    END IF;
END $$;
ROLLBACK;

BEGIN;
SET LOCAL ROLE rag_runtime;
SELECT set_config('rag.actor', 'ACT-005', true);
DO $$ BEGIN
    IF (SELECT count(*) FROM condicion_comercial) <> 12
       OR (SELECT count(*) FROM incidencia_operativa) <> 4 THEN
        RAISE EXCEPTION 'aislamiento operativo incorrecto para ADM';
    END IF;
END $$;
ROLLBACK;

-- --- Tablas base y universo recuperable ------------------------------------

BEGIN;
SET LOCAL ROLE rag_runtime;
SELECT set_config('rag.actor', 'ACT-005', true);
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM version_documental
        WHERE estado <> 'publicada'
           OR vigente_desde > now()
           OR (vigente_hasta IS NOT NULL AND vigente_hasta <= now())
    ) THEN
        RAISE EXCEPTION 'el runtime accedió a una versión no recuperable';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM embedding e
        JOIN modelo_embedding me ON me.id = e.modelo_id
        WHERE NOT me.activo
    ) THEN
        RAISE EXCEPTION 'el runtime accedió a un embedding histórico';
    END IF;
END;
$$;
ROLLBACK;

-- --- Auditoría automática de la interacción -------------------------------

BEGIN;
SET LOCAL ROLE rag_runtime;
SELECT set_config('rag.actor', 'ACT-001', true);
INSERT INTO consulta (actor_id, perfil_efectivo_id, pregunta, instante)
VALUES (1, 1, 'Prueba de auditoría automática', clock_timestamp())
RETURNING id AS consulta_prueba \gset

INSERT INTO respuesta (consulta_id, tipo_resultado, contenido, instante)
VALUES (:consulta_prueba, 'exito', 'Respuesta de prueba', clock_timestamp())
RETURNING id AS respuesta_prueba \gset

INSERT INTO evidencia_documental (respuesta_id, embedding_id, ranking, score)
VALUES (:respuesta_prueba, 10, 1, 0.1);
SET CONSTRAINTS ALL IMMEDIATE;
RESET ROLE;

SELECT set_config('validacion.consulta_prueba', :'consulta_prueba', false);
DO $$
DECLARE
    v_consulta_id BIGINT := current_setting('validacion.consulta_prueba')::BIGINT;
BEGIN
    IF (SELECT count(*) FROM evento_auditoria
        WHERE consulta_id = v_consulta_id
          AND accion IN (
              'consulta_iniciada', 'respuesta_generada',
              'fragmento_recuperado', 'evidencia_utilizada'
          )) <> 4 THEN
        RAISE EXCEPTION 'la interacción no generó sus cuatro eventos';
    END IF;
END;
$$;
ROLLBACK;

-- --- Publicación, sustitución, revocación y trazabilidad ----------------

BEGIN;
INSERT INTO version_documental (
    documento_id, numero_version, estado, ruta_relativa, nombre_archivo,
    tipo_mime, tamano_bytes, sha256
) VALUES (
    1, 2, 'borrador', 'data/ejemplos/documentos/prueba-v2.md',
    'prueba-v2.md', 'text/markdown', 1, repeat('b', 64)
) RETURNING id AS version_prueba \gset

SELECT set_config('validacion.version_prueba', :'version_prueba', false);

INSERT INTO fragmento (version_id, posicion, titulo, contenido)
VALUES (:version_prueba, 1, 'Prueba', 'Contenido de prueba')
RETURNING id AS fragmento_prueba \gset

INSERT INTO embedding (fragmento_id, modelo_id, vector, generado_en)
SELECT :fragmento_prueba, 1, vector, TIMESTAMPTZ '2026-07-01 00:00:00+00'
FROM embedding WHERE id = 1;

SET LOCAL ROLE rag_documental;
SELECT set_config('rag.actor', 'ACT-005', true);
SELECT publicar_version_documental(
    :version_prueba, TIMESTAMPTZ '2026-07-01 00:00:00+00'
);
RESET ROLE;

DO $$
DECLARE
    v_version_prueba BIGINT := current_setting('validacion.version_prueba')::BIGINT;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM version_documental
        WHERE id = 1 AND estado = 'sustituida'
          AND vigente_hasta = TIMESTAMPTZ '2026-07-01 00:00:00+00'
    ) OR NOT EXISTS (
        SELECT 1 FROM version_documental
        WHERE id = v_version_prueba AND estado = 'publicada'
          AND vigente_desde = TIMESTAMPTZ '2026-07-01 00:00:00+00'
    ) THEN
        RAISE EXCEPTION 'la sustitución no actualizó ambas versiones';
    END IF;

    IF (SELECT count(*) FROM evento_auditoria
        WHERE recurso_id IN (1, v_version_prueba)
          AND accion IN ('sustitucion', 'publicacion')
          AND instante = TIMESTAMPTZ '2026-07-01 00:00:00+00') <> 2 THEN
        RAISE EXCEPTION 'la sustitución no registró sus dos eventos';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM evidencia_documental ed
        JOIN embedding e ON e.id = ed.embedding_id
        JOIN fragmento f ON f.id = e.fragmento_id
        JOIN version_documental v ON v.id = f.version_id
        WHERE ed.respuesta_id = 6 AND v.id = 5
    ) THEN
        RAISE EXCEPTION 'la evidencia histórica perdió su versión exacta';
    END IF;
END;
$$;

SET LOCAL ROLE rag_documental;
SELECT set_config('rag.actor', 'ACT-005', true);
SELECT revocar_version_documental(
    :version_prueba, TIMESTAMPTZ '2026-07-02 00:00:00+00'
);
RESET ROLE;

DO $$
DECLARE
    v_version_prueba BIGINT := current_setting('validacion.version_prueba')::BIGINT;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM version_documental
        WHERE id = v_version_prueba AND estado = 'revocada'
          AND vigente_hasta = TIMESTAMPTZ '2026-07-02 00:00:00+00'
          AND revocada_en = TIMESTAMPTZ '2026-07-02 00:00:00+00'
    ) OR NOT EXISTS (
        SELECT 1 FROM evento_auditoria
        WHERE recurso_id = v_version_prueba AND accion = 'revocacion'
    ) THEN
        RAISE EXCEPTION 'la revocación no actualizó estado y auditoría';
    END IF;
END;
$$;
ROLLBACK;

BEGIN;
SET LOCAL ROLE rag_documental;
DO $$
BEGIN
    BEGIN
        UPDATE version_documental SET estado = 'revocada' WHERE id = 1;
        RAISE EXCEPTION 'rag_documental modificó una versión directamente';
    EXCEPTION WHEN insufficient_privilege THEN
        NULL;
    END;
END;
$$;
ROLLBACK;

-- --- Auditoría inmutable y sin inserción directa --------------------------

DO $$
BEGIN
    BEGIN
        UPDATE evento_auditoria SET resultado = 'rechazado' WHERE id = 1;
        RAISE EXCEPTION 'se permitió modificar la auditoría';
    EXCEPTION WHEN raise_exception THEN
        IF SQLERRM NOT LIKE 'evento_auditoria es append-only:%' THEN
            RAISE;
        END IF;
    END;
END;
$$;

BEGIN;
SET LOCAL ROLE rag_runtime;
DO $$
BEGIN
    BEGIN
        INSERT INTO evento_auditoria (
            instante, accion, resultado, recurso_tipo
        ) VALUES (clock_timestamp(), 'consulta_iniciada', 'permitido', 'prueba');
        RAISE EXCEPTION 'el runtime insertó un evento arbitrario';
    EXCEPTION WHEN insufficient_privilege THEN
        NULL;
    END;
END;
$$;
ROLLBACK;

SELECT 'validaciones SQL completadas' AS resultado;
