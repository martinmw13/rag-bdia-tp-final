-- =============================================================================
-- 06_consultas_seguridad.sql - Casos 7, 8 y 9
-- =============================================================================
--
-- Recuperación híbrida autorizada, matriz de autorización y trazabilidad e
-- inmutabilidad. Requiere db/indices_vistas/05_seguridad.sql aplicado.
--
-- Todas las consultas se ejecutan con el rol `rag_runtime`, que no es
-- propietario, no es superusuario y no tiene BYPASSRLS. El contexto de actor
-- se fija con set_config(..., is_local => true), de modo que muere al terminar
-- la transacción.
--
-- Ejecución:
--   VECTOR=$(python3 -c "import json; \
--       v=json.load(open('data/ejemplos/manifiesto.json')) \
--       ['oraculos_vectoriales']['consulta_hibrida']['vector']; \
--       print('['+','.join(f'{x:.8f}' for x in v)+']')")
--   psql -d rag_distribuidora -v vector_hibrida=\"\$VECTOR\" -f db/consultas/06_consultas_seguridad.sql
-- =============================================================================

SET TIME ZONE 'UTC';


-- =============================================================================
-- C7. Recuperación híbrida autorizada
-- =============================================================================
-- Pregunta   : ¿Qué descuentos por volumen puedo ofrecer a un cliente
--              mayorista? La respuesta vive en una política comercial.
-- Parámetros : vector de consulta del modelo activo (oraculos_vectoriales
--              .consulta_hibrida en el manifiesto), k = 5.
-- Espera     : para ACT-003 (Comercial/Compras), primer puesto del fragmento
--              18 de DOC-005 con distancia 0.004778. Para ACT-001
--              (Operaciones/Logística), la misma consulta devuelve fragmentos
--              de otras clases y NINGUNO de clase POL: la política comercial
--              no está en su universo.
-- Patrón     : similitud vectorial combinada con filtros relacionales de
--              actividad, publicación, vigencia, modelo y permiso.
-- Utilidad   : es la consulta que realmente ejecuta el copiloto. Lo relevante
--              no es sólo que ordene bien, sino DÓNDE se aplica la
--              autorización: las políticas de RLS limitan el universo antes de
--              que se calcule el orden, así que un fragmento prohibido no
--              ocupa un lugar en el top-k para ser descartado después.
-- =============================================================================

-- --- C7.a Perfil autorizado: Comercial/Compras ------------------------------
BEGIN;
SET LOCAL ROLE rag_runtime;
SELECT set_config('rag.actor', 'ACT-003', true);

SELECT
    fr.fragmento_id,
    fr.documento_codigo,
    fr.clase_codigo,
    fr.fragmento_titulo,
    round((fr.vector <=> :'vector_hibrida'::vector)::numeric, 6) AS distancia
FROM fragmento_recuperable fr
ORDER BY fr.vector <=> :'vector_hibrida'::vector, fr.fragmento_id
LIMIT 5;

COMMIT;

-- --- C7.b Mismo vector, perfil no autorizado: Operaciones/Logística ---------
-- No aparece ningún fragmento de clase POL.
BEGIN;
SET LOCAL ROLE rag_runtime;
SELECT set_config('rag.actor', 'ACT-001', true);

SELECT
    fr.fragmento_id,
    fr.documento_codigo,
    fr.clase_codigo,
    round((fr.vector <=> :'vector_hibrida'::vector)::numeric, 6) AS distancia
FROM fragmento_recuperable fr
ORDER BY fr.vector <=> :'vector_hibrida'::vector, fr.fragmento_id
LIMIT 5;

COMMIT;

-- --- C7.c Universo vacío: contexto ausente ----------------------------------
-- Sin contexto no hay perfil efectivo, y sin perfil efectivo no hay permiso.
-- Devuelve cero filas: la denegación es el comportamiento por defecto, no una
-- excepción que haya que programar.
BEGIN;
SET LOCAL ROLE rag_runtime;

SELECT count(*) AS fragmentos_visibles_sin_contexto
FROM fragmento_recuperable;

COMMIT;


-- =============================================================================
-- C8. Matriz de autorización
-- =============================================================================
-- Pregunta   : ¿Cada perfil ve exactamente las clases documentales que tiene
--              autorizadas, y ninguna más?
-- Parámetros : un actor por perfil — ACT-001 (OPS), ACT-003 (COM),
--              ACT-005 (ADM).
-- Espera     : 15 filas, una por combinación perfil-clase. OPS ve 7 fragmentos
--              FICHA y 6 PROC; COM ve 7 FICHA y 3 POL; ADM ve 7 FICHA, 6 PROC,
--              2 CUMP y 2 LEGAL. Las otras siete combinaciones devuelven 0.
-- Patrón     : verificación exhaustiva del control de acceso desde un rol no
--              propietario.
-- Utilidad   : demuestra que la matriz declarada en `permiso_documental` es la
--              que efectivamente rige, y que no hay filtrado accidental por
--              otra vía. Cuenta fragmentos, no documentos, porque el fragmento
--              es la unidad que el copiloto llega a exponer.
-- =============================================================================

BEGIN;
SET LOCAL ROLE rag_runtime;

SELECT set_config('rag.actor', 'ACT-001', true);
SELECT 'OPS' AS perfil, cd.codigo AS clase, count(f.id) AS fragmentos_visibles
FROM clase_documental cd
LEFT JOIN documento d          ON d.clase_id = cd.id
LEFT JOIN version_documental v ON v.documento_id = d.id
LEFT JOIN fragmento f          ON f.version_id = v.id
GROUP BY cd.codigo ORDER BY cd.codigo;

SELECT set_config('rag.actor', 'ACT-003', true);
SELECT 'COM' AS perfil, cd.codigo AS clase, count(f.id) AS fragmentos_visibles
FROM clase_documental cd
LEFT JOIN documento d          ON d.clase_id = cd.id
LEFT JOIN version_documental v ON v.documento_id = d.id
LEFT JOIN fragmento f          ON f.version_id = v.id
GROUP BY cd.codigo ORDER BY cd.codigo;

SELECT set_config('rag.actor', 'ACT-005', true);
SELECT 'ADM' AS perfil, cd.codigo AS clase, count(f.id) AS fragmentos_visibles
FROM clase_documental cd
LEFT JOIN documento d          ON d.clase_id = cd.id
LEFT JOIN version_documental v ON v.documento_id = d.id
LEFT JOIN fragmento f          ON f.version_id = v.id
GROUP BY cd.codigo ORDER BY cd.codigo;

COMMIT;


-- =============================================================================
-- C9. Trazabilidad e inmutabilidad
-- =============================================================================
-- Pregunta   : ¿Puede reconstruirse qué evidencia sostuvo una respuesta, y qué
--              ocurrió en un acceso denegado?
-- Parámetros : ESC-06 (respuesta exitosa con evidencia documental) y ESC-07
--              (resultado negativo por falta de fuente autorizada).
-- Espera     : para ESC-06, la traza en orden — consulta_iniciada, tres
--              fragmento_recuperado con su ranking, evidencia_utilizada y
--              respuesta_generada — y la evidencia resuelta hasta el
--              embedding, el fragmento, la versión y el documento exactos.
--              Para ESC-07, un acceso_denegado correlacionado, sin evidencia
--              asociada y sin exponer contenido.
-- Patrón     : consulta de auditoría con correlación histórica.
-- Utilidad   : es lo que permite explicar una respuesta meses después, incluso
--              si la versión que la sostuvo ya fue sustituida: la evidencia
--              apunta al embedding exacto, no al documento vigente.
-- =============================================================================

-- El revisor de auditoría es un rol de sólo lectura, y queda igualmente sujeto
-- a RLS: reconstruye con un contexto de Administración/Calidad y no alcanza
-- nada que ese perfil no pueda ver.
BEGIN;
SET LOCAL ROLE rag_auditor;
SELECT set_config('rag.actor', 'ACT-005', true);

-- --- C9.a Traza ordenada de una respuesta exitosa ---------------------------
SELECT
    ea.instante,
    a.codigo    AS actor,
    p.codigo    AS perfil,
    ea.accion,
    ea.resultado,
    ea.recurso_tipo,
    ea.ranking
FROM evento_auditoria ea
JOIN actor a             ON a.id = ea.actor_id
JOIN perfil_autorizado p ON p.id = ea.perfil_efectivo_id
WHERE ea.consulta_id = 6
ORDER BY ea.instante, ea.id;

-- --- C9.b Evidencia resuelta hasta la fuente exacta -------------------------
SELECT
    r.tipo_resultado,
    ed.ranking,
    ed.score,
    d.codigo  AS documento,
    v.numero_version,
    v.estado  AS estado_version,
    f.posicion,
    f.titulo  AS fragmento,
    me.nombre || ' ' || me.version AS modelo
FROM respuesta r
JOIN evidencia_documental ed ON ed.respuesta_id = r.id
JOIN embedding e             ON e.id = ed.embedding_id
JOIN fragmento f             ON f.id = e.fragmento_id
JOIN version_documental v    ON v.id = f.version_id
JOIN documento d             ON d.id = v.documento_id
JOIN modelo_embedding me     ON me.id = e.modelo_id
WHERE r.consulta_id = 6
ORDER BY ed.ranking;

-- --- C9.c Acceso denegado correlacionado ------------------------------------
-- El evento identifica actor, perfil, recurso y correlación, pero no copia el
-- contenido del documento al que no se accedió.
SELECT
    ea.instante,
    a.codigo AS actor,
    p.codigo AS perfil,
    ea.accion,
    ea.resultado,
    ea.recurso_tipo,
    ea.detalles,
    r.tipo_resultado,
    (SELECT count(*) FROM evidencia_documental ed WHERE ed.respuesta_id = r.id)
        AS evidencias_asociadas
FROM evento_auditoria ea
JOIN actor a             ON a.id = ea.actor_id
JOIN perfil_autorizado p ON p.id = ea.perfil_efectivo_id
JOIN respuesta r         ON r.id = ea.respuesta_id
WHERE ea.accion = 'acceso_denegado'
ORDER BY ea.instante;

COMMIT;

-- --- C9.d La auditoría no se modifica ni se elimina -------------------------
-- Ambas sentencias deben fallar. Se dejan comentadas para que el archivo corra
-- de principio a fin; las salidas de error están en evidencias/seguridad/.
--
--   BEGIN; SET LOCAL ROLE rag_runtime;
--   UPDATE evento_auditoria SET resultado = 'permitido' WHERE id = 1;
--   -- ERROR: permission denied for table evento_auditoria
--   ROLLBACK;
--
--   DELETE FROM evento_auditoria WHERE id = 1;
--   -- ERROR: evento_auditoria es append-only: DELETE rechazado
