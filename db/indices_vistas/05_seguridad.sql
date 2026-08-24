-- =============================================================================
-- 05_seguridad.sql - Roles, contexto efectivo, RLS y auditoría append-only
-- =============================================================================
--
-- Modelo de acceso:
--
--   Los perfiles funcionales (Operaciones/Logística, Comercial/Compras,
--   Administración/Calidad) NO son roles de base de datos. Son datos, en
--   `perfil_autorizado`, y el permiso surge de `permiso_documental`.
--
--   Los roles de base separan responsabilidades técnicas. El runtime de
--   consulta es un único rol que asume la identidad del actor en cada
--   transacción, que es como funciona una aplicación con pool de conexiones:
--   la conexión es compartida, la identidad no.
--
--   El contexto es local a la transacción. No persiste entre transacciones, no
--   se deduce del texto de la pregunta y no puede ser elevado por el propio
--   runtime.
--
-- La autenticación y el almacenamiento de credenciales están fuera de alcance:
-- los roles se crean NOLOGIN y las pruebas usan SET ROLE.
-- =============================================================================

SET TIME ZONE 'UTC';

BEGIN;

-- =============================================================================
-- 1. Roles técnicos
-- =============================================================================

DO $$
BEGIN
    -- Servicio de ingesta: incorpora borradores y datos de la muestra.
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rag_ingesta') THEN
        CREATE ROLE rag_ingesta NOLOGIN;
    END IF;

    -- Responsable documental: publica, sustituye y revoca versiones.
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rag_documental') THEN
        CREATE ROLE rag_documental NOLOGIN;
    END IF;

    -- Runtime de consulta: no propietario, no superusuario, sin BYPASSRLS.
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rag_runtime') THEN
        CREATE ROLE rag_runtime NOLOGIN;
    END IF;

    -- Revisor de auditoría: sólo lectura sobre los eventos.
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rag_auditor') THEN
        CREATE ROLE rag_auditor NOLOGIN;
    END IF;
END
$$;

-- El propietario del esquema puede asumir estos roles para las pruebas. En un
-- despliegue real cada uno tendría su propia credencial.
DO $$
BEGIN
    EXECUTE format('GRANT rag_ingesta, rag_documental, rag_runtime, rag_auditor TO %I',
                   current_user);
END
$$;

GRANT USAGE ON SCHEMA public TO rag_ingesta, rag_documental, rag_runtime, rag_auditor;


-- =============================================================================
-- 2. Contexto efectivo de la transacción
-- =============================================================================
--
-- `rag.actor` se fija con set_config(..., is_local => true) al inicio de cada
-- transacción de consulta. Al terminar la transacción, el valor desaparece.
-- =============================================================================

CREATE OR REPLACE FUNCTION app_actor_id()
RETURNS BIGINT
LANGUAGE sql
STABLE
AS $$
    SELECT a.id
    FROM actor a
    WHERE a.codigo = NULLIF(current_setting('rag.actor', true), '')
      AND a.activo;
$$;

COMMENT ON FUNCTION app_actor_id() IS
    'Actor de la transacción actual. Devuelve NULL si el contexto está ausente, '
    'vacío o corresponde a un actor inactivo: la ausencia de contexto es una '
    'denegación, no un permiso implícito.';

CREATE OR REPLACE FUNCTION app_perfil_id()
RETURNS BIGINT
LANGUAGE sql
STABLE
AS $$
    SELECT a.perfil_autorizado_id
    FROM actor a
    JOIN perfil_autorizado p ON p.id = a.perfil_autorizado_id
    WHERE a.id = app_actor_id()
      AND p.activo;
$$;

COMMENT ON FUNCTION app_perfil_id() IS
    'Perfil efectivo del actor de la transacción. Es el único perfil que el '
    'actor tiene: no se admiten delegaciones ni excepciones individuales.';

CREATE OR REPLACE FUNCTION app_clase_autorizada(p_clase_id BIGINT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM permiso_documental pd
        WHERE pd.perfil_id = app_perfil_id()
          AND pd.clase_id  = p_clase_id
    );
$$;

COMMENT ON FUNCTION app_clase_autorizada(BIGINT) IS
    'Verdadero sólo si existe un permiso explícito entre el perfil efectivo y '
    'la clase documental. La ausencia de fila implica denegación.';

CREATE OR REPLACE FUNCTION app_perfil_codigo()
RETURNS TEXT
LANGUAGE sql
STABLE
AS $$
    SELECT p.codigo
    FROM perfil_autorizado p
    WHERE p.id = app_perfil_id();
$$;

CREATE OR REPLACE FUNCTION app_version_recuperable(p_version_id BIGINT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.version_documental v
        JOIN public.documento d ON d.id = v.documento_id
        WHERE v.id = p_version_id
          AND d.activo
          AND public.app_clase_autorizada(d.clase_id)
          AND v.estado = 'publicada'
          AND v.vigente_desde <= now()
          AND (v.vigente_hasta IS NULL OR v.vigente_hasta > now())
          AND EXISTS (
              SELECT 1
              FROM public.fragmento f
              JOIN public.embedding e ON e.fragmento_id = f.id
              JOIN public.modelo_embedding me ON me.id = e.modelo_id
              WHERE f.version_id = v.id
                AND me.activo
          )
    );
$$;

CREATE OR REPLACE FUNCTION app_version_historica_autorizada(p_version_id BIGINT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.version_documental v
        JOIN public.documento d ON d.id = v.documento_id
        WHERE v.id = p_version_id
          AND public.app_clase_autorizada(d.clase_id)
    );
$$;

REVOKE ALL ON FUNCTION app_version_recuperable(BIGINT) FROM PUBLIC;
REVOKE ALL ON FUNCTION app_version_historica_autorizada(BIGINT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION app_version_recuperable(BIGINT) TO rag_runtime;
GRANT EXECUTE ON FUNCTION app_version_historica_autorizada(BIGINT) TO rag_auditor;


-- =============================================================================
-- 3. Políticas RLS sobre el corpus documental
-- =============================================================================

ALTER TABLE documento          ENABLE ROW LEVEL SECURITY;
ALTER TABLE version_documental ENABLE ROW LEVEL SECURITY;
ALTER TABLE fragmento          ENABLE ROW LEVEL SECURITY;
ALTER TABLE embedding          ENABLE ROW LEVEL SECURITY;

-- El propietario también queda sujeto a las políticas: de lo contrario, correr
-- una consulta como propietario daría una falsa sensación de aislamiento.
ALTER TABLE documento          FORCE ROW LEVEL SECURITY;
ALTER TABLE version_documental FORCE ROW LEVEL SECURITY;
ALTER TABLE fragmento          FORCE ROW LEVEL SECURITY;
ALTER TABLE embedding          FORCE ROW LEVEL SECURITY;

-- Las funciones SECURITY DEFINER y las tareas de administración conservan un
-- acceso explícito para el propietario aun con FORCE ROW LEVEL SECURITY.
DO $owner_policies$
DECLARE
    v_owner NAME := current_user;
    v_table NAME;
BEGIN
    FOREACH v_table IN ARRAY ARRAY[
        'documento', 'version_documental', 'fragmento', 'embedding'
    ]::NAME[]
    LOOP
        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON %I',
            v_table || '_administracion_propietario', v_table
        );
        EXECUTE format(
            'CREATE POLICY %I ON %I FOR ALL TO %I USING (true) WITH CHECK (true)',
            v_table || '_administracion_propietario', v_table, v_owner
        );
    END LOOP;
END
$owner_policies$;

-- --- documento --------------------------------------------------------------

DROP POLICY IF EXISTS documento_lectura_runtime ON documento;
CREATE POLICY documento_lectura_runtime ON documento
    FOR SELECT TO rag_runtime
    USING (activo AND app_clase_autorizada(clase_id));

DROP POLICY IF EXISTS documento_lectura_auditoria ON documento;
CREATE POLICY documento_lectura_auditoria ON documento
    FOR SELECT TO rag_auditor
    USING (app_clase_autorizada(clase_id));

DROP POLICY IF EXISTS documento_alta_ingesta ON documento;
CREATE POLICY documento_alta_ingesta ON documento
    FOR INSERT TO rag_ingesta
    WITH CHECK (true);

-- --- version_documental -----------------------------------------------------

DROP POLICY IF EXISTS version_lectura_runtime ON version_documental;
CREATE POLICY version_lectura_runtime ON version_documental
    FOR SELECT TO rag_runtime
    USING (app_version_recuperable(id));

DROP POLICY IF EXISTS version_lectura_auditoria ON version_documental;
CREATE POLICY version_lectura_auditoria ON version_documental
    FOR SELECT TO rag_auditor
    USING (app_version_historica_autorizada(id));

DROP POLICY IF EXISTS version_alta_ingesta ON version_documental;
CREATE POLICY version_alta_ingesta ON version_documental
    FOR INSERT TO rag_ingesta
    WITH CHECK (estado = 'borrador');

DROP POLICY IF EXISTS version_lectura_documental ON version_documental;
CREATE POLICY version_lectura_documental ON version_documental
    FOR SELECT TO rag_documental, rag_ingesta
    USING (true);

DROP POLICY IF EXISTS documento_lectura_documental ON documento;
CREATE POLICY documento_lectura_documental ON documento
    FOR SELECT TO rag_documental, rag_ingesta
    USING (true);

-- --- fragmento --------------------------------------------------------------

DROP POLICY IF EXISTS fragmento_lectura_runtime ON fragmento;
CREATE POLICY fragmento_lectura_runtime ON fragmento
    FOR SELECT TO rag_runtime
    USING (app_version_recuperable(version_id));

DROP POLICY IF EXISTS fragmento_lectura_auditoria ON fragmento;
CREATE POLICY fragmento_lectura_auditoria ON fragmento
    FOR SELECT TO rag_auditor
    USING (app_version_historica_autorizada(version_id));

DROP POLICY IF EXISTS fragmento_alta_ingesta ON fragmento;
CREATE POLICY fragmento_alta_ingesta ON fragmento
    FOR INSERT TO rag_ingesta
    WITH CHECK (true);

DROP POLICY IF EXISTS fragmento_lectura_ingesta ON fragmento;
CREATE POLICY fragmento_lectura_ingesta ON fragmento
    FOR SELECT TO rag_ingesta, rag_documental
    USING (true);

-- --- embedding --------------------------------------------------------------

DROP POLICY IF EXISTS embedding_lectura_runtime ON embedding;
CREATE POLICY embedding_lectura_runtime ON embedding
    FOR SELECT TO rag_runtime
    USING (
        EXISTS (
            SELECT 1
            FROM fragmento f
            WHERE f.id = embedding.fragmento_id
              AND app_version_recuperable(f.version_id)
        )
        AND EXISTS (
            SELECT 1 FROM modelo_embedding me
            WHERE me.id = embedding.modelo_id AND me.activo
        )
    );

DROP POLICY IF EXISTS embedding_lectura_auditoria ON embedding;
CREATE POLICY embedding_lectura_auditoria ON embedding
    FOR SELECT TO rag_auditor
    USING (EXISTS (
        SELECT 1
        FROM fragmento f
        WHERE f.id = embedding.fragmento_id
          AND app_version_historica_autorizada(f.version_id)
    ));

DROP POLICY IF EXISTS embedding_alta_ingesta ON embedding;
CREATE POLICY embedding_alta_ingesta ON embedding
    FOR INSERT TO rag_ingesta
    WITH CHECK (true);

DROP POLICY IF EXISTS embedding_lectura_ingesta ON embedding;
CREATE POLICY embedding_lectura_ingesta ON embedding
    FOR SELECT TO rag_ingesta, rag_documental
    USING (true);

-- --- datos operativos sensibles ---------------------------------------------

ALTER TABLE condicion_comercial ENABLE ROW LEVEL SECURITY;
ALTER TABLE incidencia_operativa ENABLE ROW LEVEL SECURITY;
ALTER TABLE condicion_comercial FORCE ROW LEVEL SECURITY;
ALTER TABLE incidencia_operativa FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS condicion_comercial_runtime ON condicion_comercial;
CREATE POLICY condicion_comercial_runtime ON condicion_comercial
    FOR SELECT TO rag_runtime
    USING (app_perfil_codigo() IN ('COM', 'ADM'));

DROP POLICY IF EXISTS incidencia_operativa_runtime ON incidencia_operativa;
CREATE POLICY incidencia_operativa_runtime ON incidencia_operativa
    FOR SELECT TO rag_runtime
    USING (app_perfil_codigo() IN ('OPS', 'ADM'));

DO $owner_operativo$
DECLARE
    v_owner NAME := current_user;
BEGIN
    DROP POLICY IF EXISTS condicion_comercial_administracion_propietario
        ON condicion_comercial;
    EXECUTE format(
        'CREATE POLICY condicion_comercial_administracion_propietario '
        'ON condicion_comercial FOR ALL TO %I USING (true) WITH CHECK (true)',
        v_owner
    );
    DROP POLICY IF EXISTS incidencia_operativa_administracion_propietario
        ON incidencia_operativa;
    EXECUTE format(
        'CREATE POLICY incidencia_operativa_administracion_propietario '
        'ON incidencia_operativa FOR ALL TO %I USING (true) WITH CHECK (true)',
        v_owner
    );
END
$owner_operativo$;


-- =============================================================================
-- 4. Privilegios mínimos
-- =============================================================================

-- Runtime: lee el corpus y los datos operativos, y registra su actividad.
-- No puede modificar hechos operativos, versiones publicadas ni permisos.
GRANT SELECT ON
    categoria_producto, segmento_cliente, perfil_autorizado, clase_documental,
    nivel_sensibilidad, modelo_embedding, producto, cliente, proveedor,
    producto_proveedor, condicion_comercial, pedido, linea_pedido, entrega,
    incidencia_operativa, documento, version_documental, fragmento, embedding,
    documento_producto, documento_proveedor, actor, permiso_documental,
    consulta, respuesta, resultado_estructurado, evidencia_documental,
    evidencia_estructurada, fragmento_recuperable
TO rag_runtime;

GRANT INSERT ON
    consulta, respuesta, resultado_estructurado, evidencia_documental,
    evidencia_estructurada
TO rag_runtime;

GRANT USAGE ON SEQUENCE
    consulta_id_seq, respuesta_id_seq, resultado_estructurado_id_seq,
    evidencia_documental_id_seq, evidencia_estructurada_id_seq
TO rag_runtime;

-- Ingesta: incorpora borradores y sus fragmentos y vectores.
GRANT SELECT ON
    modelo_embedding, documento, version_documental, fragmento, embedding,
    documento_producto, documento_proveedor, producto, proveedor, actor,
    perfil_autorizado
TO rag_ingesta;
GRANT INSERT ON documento, version_documental, fragmento, embedding,
                documento_producto, documento_proveedor
TO rag_ingesta;
GRANT USAGE ON SEQUENCE
    documento_id_seq, version_documental_id_seq, fragmento_id_seq,
    embedding_id_seq
TO rag_ingesta;

-- Responsable documental: controla el ciclo de publicación.
GRANT SELECT ON
    documento, version_documental, fragmento, embedding, modelo_embedding,
    actor, perfil_autorizado, evento_auditoria
TO rag_documental;
REVOKE INSERT, UPDATE, DELETE ON version_documental FROM rag_documental;

-- Revisor de auditoría: sólo lectura. Además de los eventos necesita alcanzar
-- la evidencia para reconstruir qué sostuvo cada respuesta, pero lo hace bajo
-- las mismas políticas de RLS que cualquier otro rol: reconstruye con un
-- contexto de Administración/Calidad y no ve más que lo que ese perfil ve.
GRANT SELECT ON
    evento_auditoria, actor, perfil_autorizado, consulta, respuesta,
    evidencia_documental, evidencia_estructurada, resultado_estructurado,
    embedding, fragmento, version_documental, documento, clase_documental,
    nivel_sensibilidad, modelo_embedding, permiso_documental
TO rag_auditor;

-- Ningún rol operativo puede alterar la auditoría ya registrada.
REVOKE UPDATE, DELETE, TRUNCATE ON evento_auditoria
FROM rag_runtime, rag_ingesta, rag_documental, rag_auditor;

REVOKE INSERT ON evento_auditoria
FROM rag_runtime, rag_ingesta, rag_documental, rag_auditor;


-- =============================================================================
-- 5. Operaciones documentales atómicas
-- =============================================================================

CREATE OR REPLACE FUNCTION publicar_version_documental(
    p_version_id BIGINT,
    p_instante TIMESTAMPTZ
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_documento_id BIGINT;
    v_numero_version INTEGER;
    v_estado TEXT;
    v_version_anterior BIGINT;
    v_actor_id BIGINT;
    v_perfil_id BIGINT;
BEGIN
    v_actor_id := public.app_actor_id();
    v_perfil_id := public.app_perfil_id();

    IF v_actor_id IS NULL OR public.app_perfil_codigo() <> 'ADM' THEN
        RAISE EXCEPTION 'se requiere un actor activo de Administración/Calidad'
            USING ERRCODE = '42501';
    END IF;

    IF p_instante IS NULL OR p_instante > clock_timestamp() THEN
        RAISE EXCEPTION 'el instante de publicación debe ser válido y no futuro'
            USING ERRCODE = '22007';
    END IF;

    SELECT v.documento_id, v.numero_version, v.estado
      INTO v_documento_id, v_numero_version, v_estado
      FROM public.version_documental v
     WHERE v.id = p_version_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'la versión documental % no existe', p_version_id
            USING ERRCODE = 'P0002';
    END IF;

    IF v_estado <> 'borrador' THEN
        RAISE EXCEPTION 'la versión documental % no está en borrador', p_version_id
            USING ERRCODE = '23514';
    END IF;

    PERFORM 1
      FROM public.version_documental v
     WHERE v.documento_id = v_documento_id
     ORDER BY v.id
     FOR UPDATE;

    IF EXISTS (
        SELECT 1
        FROM public.version_documental v
        WHERE v.documento_id = v_documento_id
          AND v.estado = 'publicada'
          AND v.vigente_desde > p_instante
    ) THEN
        RAISE EXCEPTION 'el documento % tiene una publicación futura', v_documento_id
            USING ERRCODE = '23514';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.fragmento f
        JOIN public.embedding e ON e.fragmento_id = f.id
        JOIN public.modelo_embedding me ON me.id = e.modelo_id
        WHERE f.version_id = p_version_id
          AND me.activo
    ) THEN
        RAISE EXCEPTION 'la versión documental % no tiene embeddings activos',
            p_version_id
            USING ERRCODE = '23514';
    END IF;

    SELECT v.id
      INTO v_version_anterior
      FROM public.version_documental v
     WHERE v.documento_id = v_documento_id
       AND v.estado = 'publicada'
       AND v.vigente_desde <= p_instante
       AND (v.vigente_hasta IS NULL OR v.vigente_hasta > p_instante)
     ORDER BY v.vigente_desde DESC
     LIMIT 1;

    IF v_version_anterior IS NOT NULL THEN
        UPDATE public.version_documental
           SET estado = 'sustituida',
               vigente_hasta = p_instante
         WHERE id = v_version_anterior;

        INSERT INTO public.evento_auditoria (
            actor_id, perfil_efectivo_id, instante, accion, resultado,
            recurso_tipo, recurso_id, detalles
        ) VALUES (
            v_actor_id, v_perfil_id, p_instante, 'sustitucion', 'permitido',
            'version_documental', v_version_anterior,
            jsonb_build_object('version_nueva_id', p_version_id)
        );
    END IF;

    UPDATE public.version_documental
       SET estado = 'publicada',
           vigente_desde = p_instante,
           vigente_hasta = NULL,
           publicada_en = p_instante,
           revocada_en = NULL
     WHERE id = p_version_id;

    INSERT INTO public.evento_auditoria (
        actor_id, perfil_efectivo_id, instante, accion, resultado,
        recurso_tipo, recurso_id, detalles
    ) VALUES (
        v_actor_id, v_perfil_id, p_instante, 'publicacion', 'permitido',
        'version_documental', p_version_id,
        jsonb_build_object(
            'documento_id', v_documento_id,
            'version', v_numero_version
        )
    );
END;
$$;

CREATE OR REPLACE FUNCTION revocar_version_documental(
    p_version_id BIGINT,
    p_instante TIMESTAMPTZ
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_estado TEXT;
    v_vigente_desde TIMESTAMPTZ;
    v_actor_id BIGINT;
    v_perfil_id BIGINT;
BEGIN
    v_actor_id := public.app_actor_id();
    v_perfil_id := public.app_perfil_id();

    IF v_actor_id IS NULL OR public.app_perfil_codigo() <> 'ADM' THEN
        RAISE EXCEPTION 'se requiere un actor activo de Administración/Calidad'
            USING ERRCODE = '42501';
    END IF;

    SELECT v.estado, v.vigente_desde
      INTO v_estado, v_vigente_desde
      FROM public.version_documental v
     WHERE v.id = p_version_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'la versión documental % no existe', p_version_id
            USING ERRCODE = 'P0002';
    END IF;

    IF v_estado <> 'publicada' THEN
        RAISE EXCEPTION 'la versión documental % no está publicada', p_version_id
            USING ERRCODE = '23514';
    END IF;

    IF p_instante IS NULL
       OR p_instante <= v_vigente_desde
       OR p_instante > clock_timestamp() THEN
        RAISE EXCEPTION 'el instante de revocación debe ser posterior a la publicación y no futuro'
            USING ERRCODE = '22007';
    END IF;

    UPDATE public.version_documental
       SET estado = 'revocada',
           vigente_hasta = p_instante,
           revocada_en = p_instante
     WHERE id = p_version_id;

    INSERT INTO public.evento_auditoria (
        actor_id, perfil_efectivo_id, instante, accion, resultado,
        recurso_tipo, recurso_id
    ) VALUES (
        v_actor_id, v_perfil_id, p_instante, 'revocacion', 'permitido',
        'version_documental', p_version_id
    );
END;
$$;

REVOKE ALL ON FUNCTION publicar_version_documental(BIGINT, TIMESTAMPTZ) FROM PUBLIC;
REVOKE ALL ON FUNCTION revocar_version_documental(BIGINT, TIMESTAMPTZ) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION publicar_version_documental(BIGINT, TIMESTAMPTZ)
TO rag_documental;
GRANT EXECUTE ON FUNCTION revocar_version_documental(BIGINT, TIMESTAMPTZ)
TO rag_documental;


-- =============================================================================
-- 6. Auditoría automática y append-only
-- =============================================================================
--
-- Los privilegios ya impiden que los roles operativos modifiquen la auditoría.
-- El disparador agrega una segunda barrera que alcanza también al propietario:
-- si alguien concediera UPDATE por error, la operación seguiría fallando.
--
-- No bloquea TRUNCATE, porque la recarga limpia del conjunto sintético lo
-- necesita y es una operación de administración, no de uso.
-- =============================================================================

CREATE OR REPLACE FUNCTION auditar_consulta_insertada()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
    INSERT INTO public.evento_auditoria (
        actor_id, perfil_efectivo_id, instante, accion, resultado,
        recurso_tipo, recurso_id, consulta_id
    ) VALUES (
        NEW.actor_id, NEW.perfil_efectivo_id, NEW.instante,
        'consulta_iniciada', 'permitido', 'consulta', NEW.id, NEW.id
    );
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION auditar_borrador_insertado()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
    INSERT INTO public.evento_auditoria (
        actor_id, perfil_efectivo_id, instante, accion, resultado,
        recurso_tipo, recurso_id, detalles
    ) VALUES (
        public.app_actor_id(), public.app_perfil_id(), clock_timestamp(),
        'carga_borrador', 'permitido', 'version_documental', NEW.id,
        jsonb_build_object(
            'documento_id', NEW.documento_id,
            'version', NEW.numero_version
        )
    );
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION auditar_respuesta_insertada()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_actor_id BIGINT;
    v_perfil_id BIGINT;
BEGIN
    SELECT c.actor_id, c.perfil_efectivo_id
      INTO v_actor_id, v_perfil_id
      FROM public.consulta c
     WHERE c.id = NEW.consulta_id;

    IF NEW.tipo_resultado IN ('sin_fuente_autorizada', 'acceso_denegado') THEN
        INSERT INTO public.evento_auditoria (
            actor_id, perfil_efectivo_id, instante, accion, resultado,
            recurso_tipo, recurso_id, consulta_id, respuesta_id, detalles
        ) VALUES (
            v_actor_id, v_perfil_id, NEW.instante, 'acceso_denegado', 'denegado',
            'respuesta', NEW.id, NEW.consulta_id, NEW.id,
            jsonb_build_object('tipo_resultado', NEW.tipo_resultado)
        );
    END IF;

    INSERT INTO public.evento_auditoria (
        actor_id, perfil_efectivo_id, instante, accion, resultado,
        recurso_tipo, recurso_id, consulta_id, respuesta_id, detalles
    ) VALUES (
        v_actor_id, v_perfil_id, NEW.instante, 'respuesta_generada', 'permitido',
        'respuesta', NEW.id, NEW.consulta_id, NEW.id,
        jsonb_build_object('tipo_resultado', NEW.tipo_resultado)
    );
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION auditar_evidencia_documental_insertada()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_actor_id BIGINT;
    v_perfil_id BIGINT;
    v_consulta_id BIGINT;
    v_fragmento_id BIGINT;
    v_instante TIMESTAMPTZ;
BEGIN
    SELECT c.actor_id, c.perfil_efectivo_id, c.id, r.instante, e.fragmento_id
      INTO v_actor_id, v_perfil_id, v_consulta_id, v_instante, v_fragmento_id
      FROM public.respuesta r
      JOIN public.consulta c ON c.id = r.consulta_id
      JOIN public.embedding e ON e.id = NEW.embedding_id
     WHERE r.id = NEW.respuesta_id;

    INSERT INTO public.evento_auditoria (
        actor_id, perfil_efectivo_id, instante, accion, resultado,
        recurso_tipo, recurso_id, consulta_id, respuesta_id, ranking, score
    ) VALUES (
        v_actor_id, v_perfil_id, v_instante, 'fragmento_recuperado', 'permitido',
        'fragmento', v_fragmento_id, v_consulta_id, NEW.respuesta_id,
        NEW.ranking, NEW.score
    );

    INSERT INTO public.evento_auditoria (
        actor_id, perfil_efectivo_id, instante, accion, resultado,
        recurso_tipo, recurso_id, consulta_id, respuesta_id, ranking, score
    ) VALUES (
        v_actor_id, v_perfil_id, v_instante, 'evidencia_utilizada', 'permitido',
        'embedding', NEW.embedding_id, v_consulta_id, NEW.respuesta_id,
        NEW.ranking, NEW.score
    );
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION auditar_evidencia_estructurada_insertada()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_actor_id BIGINT;
    v_perfil_id BIGINT;
    v_consulta_id BIGINT;
    v_instante TIMESTAMPTZ;
BEGIN
    SELECT c.actor_id, c.perfil_efectivo_id, c.id, r.instante
      INTO v_actor_id, v_perfil_id, v_consulta_id, v_instante
      FROM public.respuesta r
      JOIN public.consulta c ON c.id = r.consulta_id
     WHERE r.id = NEW.respuesta_id;

    INSERT INTO public.evento_auditoria (
        actor_id, perfil_efectivo_id, instante, accion, resultado,
        recurso_tipo, recurso_id, consulta_id, respuesta_id
    ) VALUES (
        v_actor_id, v_perfil_id, v_instante, 'evidencia_utilizada', 'permitido',
        'resultado_estructurado', NEW.resultado_estructurado_id,
        v_consulta_id, NEW.respuesta_id
    );
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION auditar_consulta_insertada() FROM PUBLIC;
REVOKE ALL ON FUNCTION auditar_borrador_insertado() FROM PUBLIC;
REVOKE ALL ON FUNCTION auditar_respuesta_insertada() FROM PUBLIC;
REVOKE ALL ON FUNCTION auditar_evidencia_documental_insertada() FROM PUBLIC;
REVOKE ALL ON FUNCTION auditar_evidencia_estructurada_insertada() FROM PUBLIC;

DROP TRIGGER IF EXISTS consulta_auditoria_tg ON consulta;
CREATE TRIGGER consulta_auditoria_tg
    AFTER INSERT ON consulta
    FOR EACH ROW EXECUTE FUNCTION auditar_consulta_insertada();

DROP TRIGGER IF EXISTS version_borrador_auditoria_tg ON version_documental;
CREATE TRIGGER version_borrador_auditoria_tg
    AFTER INSERT ON version_documental
    FOR EACH ROW EXECUTE FUNCTION auditar_borrador_insertado();

DROP TRIGGER IF EXISTS respuesta_auditoria_tg ON respuesta;
CREATE TRIGGER respuesta_auditoria_tg
    AFTER INSERT ON respuesta
    FOR EACH ROW EXECUTE FUNCTION auditar_respuesta_insertada();

DROP TRIGGER IF EXISTS evidencia_documental_auditoria_tg ON evidencia_documental;
CREATE TRIGGER evidencia_documental_auditoria_tg
    AFTER INSERT ON evidencia_documental
    FOR EACH ROW EXECUTE FUNCTION auditar_evidencia_documental_insertada();

DROP TRIGGER IF EXISTS evidencia_estructurada_auditoria_tg ON evidencia_estructurada;
CREATE TRIGGER evidencia_estructurada_auditoria_tg
    AFTER INSERT ON evidencia_estructurada
    FOR EACH ROW EXECUTE FUNCTION auditar_evidencia_estructurada_insertada();

CREATE OR REPLACE FUNCTION auditoria_inmutable()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION
        'evento_auditoria es append-only: % rechazado', TG_OP
        USING HINT = 'Los eventos registrados no se modifican ni se eliminan.';
END;
$$;

DROP TRIGGER IF EXISTS evento_auditoria_inmutable_tg ON evento_auditoria;
CREATE TRIGGER evento_auditoria_inmutable_tg
    BEFORE UPDATE OR DELETE ON evento_auditoria
    FOR EACH ROW
    EXECUTE FUNCTION auditoria_inmutable();

COMMIT;
