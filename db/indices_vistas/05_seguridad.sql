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

-- --- documento --------------------------------------------------------------

DROP POLICY IF EXISTS documento_lectura_autorizada ON documento;
CREATE POLICY documento_lectura_autorizada ON documento
    FOR SELECT
    USING (app_clase_autorizada(clase_id));

DROP POLICY IF EXISTS documento_alta_ingesta ON documento;
CREATE POLICY documento_alta_ingesta ON documento
    FOR INSERT TO rag_ingesta
    WITH CHECK (true);

-- --- version_documental -----------------------------------------------------

DROP POLICY IF EXISTS version_lectura_autorizada ON version_documental;
CREATE POLICY version_lectura_autorizada ON version_documental
    FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM documento d
        WHERE d.id = version_documental.documento_id
          AND app_clase_autorizada(d.clase_id)
    ));

DROP POLICY IF EXISTS version_alta_ingesta ON version_documental;
CREATE POLICY version_alta_ingesta ON version_documental
    FOR INSERT TO rag_ingesta
    WITH CHECK (estado = 'borrador');

-- El responsable documental publica, sustituye y revoca. USING delimita qué
-- filas puede tocar; WITH CHECK delimita en qué estado pueden quedar.
DROP POLICY IF EXISTS version_ciclo_documental ON version_documental;
CREATE POLICY version_ciclo_documental ON version_documental
    FOR UPDATE TO rag_documental
    USING (true)
    WITH CHECK (estado IN ('borrador', 'publicada', 'sustituida', 'revocada'));

DROP POLICY IF EXISTS version_lectura_documental ON version_documental;
CREATE POLICY version_lectura_documental ON version_documental
    FOR SELECT TO rag_documental, rag_ingesta
    USING (true);

DROP POLICY IF EXISTS documento_lectura_documental ON documento;
CREATE POLICY documento_lectura_documental ON documento
    FOR SELECT TO rag_documental, rag_ingesta
    USING (true);

-- --- fragmento --------------------------------------------------------------

DROP POLICY IF EXISTS fragmento_lectura_autorizada ON fragmento;
CREATE POLICY fragmento_lectura_autorizada ON fragmento
    FOR SELECT
    USING (EXISTS (
        SELECT 1
        FROM version_documental v
        JOIN documento d ON d.id = v.documento_id
        WHERE v.id = fragmento.version_id
          AND app_clase_autorizada(d.clase_id)
    ));

DROP POLICY IF EXISTS fragmento_alta_ingesta ON fragmento;
CREATE POLICY fragmento_alta_ingesta ON fragmento
    FOR INSERT TO rag_ingesta
    WITH CHECK (true);

DROP POLICY IF EXISTS fragmento_lectura_ingesta ON fragmento;
CREATE POLICY fragmento_lectura_ingesta ON fragmento
    FOR SELECT TO rag_ingesta, rag_documental
    USING (true);

-- --- embedding --------------------------------------------------------------

DROP POLICY IF EXISTS embedding_lectura_autorizada ON embedding;
CREATE POLICY embedding_lectura_autorizada ON embedding
    FOR SELECT
    USING (EXISTS (
        SELECT 1
        FROM fragmento f
        JOIN version_documental v ON v.id = f.version_id
        JOIN documento d          ON d.id = v.documento_id
        WHERE f.id = embedding.fragmento_id
          AND app_clase_autorizada(d.clase_id)
    ));

DROP POLICY IF EXISTS embedding_alta_ingesta ON embedding;
CREATE POLICY embedding_alta_ingesta ON embedding
    FOR INSERT TO rag_ingesta
    WITH CHECK (true);

DROP POLICY IF EXISTS embedding_lectura_ingesta ON embedding;
CREATE POLICY embedding_lectura_ingesta ON embedding
    FOR SELECT TO rag_ingesta, rag_documental
    USING (true);


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
    evidencia_estructurada, evento_auditoria
TO rag_runtime;

GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO rag_runtime;

-- Ingesta: incorpora borradores y sus fragmentos y vectores.
GRANT SELECT ON ALL TABLES IN SCHEMA public TO rag_ingesta;
GRANT INSERT ON documento, version_documental, fragmento, embedding,
                documento_producto, documento_proveedor, evento_auditoria
TO rag_ingesta;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO rag_ingesta;

-- Responsable documental: controla el ciclo de publicación.
GRANT SELECT ON ALL TABLES IN SCHEMA public TO rag_documental;
GRANT UPDATE ON version_documental TO rag_documental;
GRANT INSERT ON version_documental, evento_auditoria TO rag_documental;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO rag_documental;

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


-- =============================================================================
-- 5. Auditoría append-only
-- =============================================================================
--
-- Los privilegios ya impiden que los roles operativos modifiquen la auditoría.
-- El disparador agrega una segunda barrera que alcanza también al propietario:
-- si alguien concediera UPDATE por error, la operación seguiría fallando.
--
-- No bloquea TRUNCATE, porque la recarga limpia del conjunto sintético lo
-- necesita y es una operación de administración, no de uso.
-- =============================================================================

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
