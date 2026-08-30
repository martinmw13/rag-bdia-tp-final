# Matriz de cobertura

Vincula cada requisito de la
[especificación del producto](specs/capa-datos-rag-distribuidora/PRD.md) con
el artefacto que lo implementa y la evidencia que lo demuestra. Funciona como
índice y evita repetir explicaciones de la especificación, las specs de
implementación o el informe. La columna "Sección del informe" señala dónde se
desarrolla cada punto en el borrador LaTeX actual.

> El proyecto fuente y su PDF de revisión están en [`docs/informe_latex/`](informe_latex/).
> Cuando concluya la revisión académica, el PDF definitivo se publicará como
> `docs/informe.pdf`.

## Alcance funcional

| Requisito | Artefacto | Evidencia | Sección del informe (propuesta) |
| --- | --- | --- | --- |
| Consultas sobre productos, condiciones comerciales, pedidos, entregas, incidencias, procedimientos y documentación de proveedores/cumplimiento | [`db/consultas/04_consultas.sql`](../db/consultas/04_consultas.sql) (1–6), [`06_consultas_seguridad.sql`](../db/consultas/06_consultas_seguridad.sql) (7) | [`evidencias/planes_ejecucion.md`](../evidencias/planes_ejecucion.md) | Alcance funcional y consultas representativas |
| Cada respuesta exitosa conserva evidencia documental o estructurada identificable | Constraint triggers diferidos sobre `respuesta` y sus evidencias en [`01_schema.sql`](../db/estructura/01_schema.sql) | [`07_validaciones.sql`](../db/consultas/07_validaciones.sql) | Modelo de interacción y evidencia |
| Resultado negativo explícito sin evidencia inventada | Constraint triggers diferidos sobre `respuesta` y sus evidencias | [`07_validaciones.sql`](../db/consultas/07_validaciones.sql) | Resultados negativos y evidencia |
| Historial suficiente para explicar respuestas anteriores | `version_documental` (estados `sustituida`/`revocada` no se borran) | [`docs/diagramas/fisico_notas.md`](diagramas/fisico_notas.md) | Vigencia e historial documental |

## Información y procedencia

| Requisito | Artefacto | Evidencia | Sección del informe (propuesta) |
| --- | --- | --- | --- |
| Datos sintéticos, reproducibles, sin datos reales ni licencias externas | [`scripts/generar_datos.py`](../scripts/generar_datos.py), [`data/ejemplos/manifiesto.json`](../data/ejemplos/manifiesto.json) | README §"Reproducibilidad" | Datos sintéticos y reproducibilidad |
| Clasificación estructurada / semiestructurada / no estructurada / operacional / analítica / sensible / auditoría | [`nosql/modelo_nosql.md`](../nosql/modelo_nosql.md), [`vectorial/modelo_vectorial.md`](../vectorial/modelo_vectorial.md) | — (análisis, no ejecutable) | Clasificación de los datos |
| Sólo se vectorizan fragmentos documentales; hechos operativos como datos estructurados | [`vectorial/modelo_vectorial.md`](../vectorial/modelo_vectorial.md) §"Qué se vectoriza" | Consultas 1–5 vs. 6–7 en `db/consultas/` | Clasificación de los datos |
| Documentos con procedencia, versión, vigencia, sensibilidad e integridad verificable | `documento`, `version_documental` en [`01_schema.sql`](../db/estructura/01_schema.sql) | [`docs/diagramas/fisico_recuperacion.mmd`](diagramas/fisico_recuperacion.mmd) | Modelo documental |

## Vigencia y autorización

| Requisito | Artefacto | Evidencia | Sección del informe (propuesta) |
| --- | --- | --- | --- |
| Sólo una versión publicada, no revocada y vigente es recuperable por documento | `version_documental_sin_solape_ex` (EXCLUDE parcial), vista `fragmento_recuperable` | [`docs/diagramas/fisico_notas.md`](diagramas/fisico_notas.md) | Vigencia documental |
| Publicar sustituye a la anterior sin ventana de inconsistencia | `publicar_version_documental()` en [`05_seguridad.sql`](../db/indices_vistas/05_seguridad.sql) | [`07_validaciones.sql`](../db/consultas/07_validaciones.sql) | Publicación y sustitución atómica |
| Permisos por perfil y clase documental, denegación por defecto, sin excepciones individuales | `permiso_documental`, políticas RLS en [`05_seguridad.sql`](../db/indices_vistas/05_seguridad.sql) | [`evidencias/seguridad/matriz_autorizacion.md`](../evidencias/seguridad/matriz_autorizacion.md) | Matriz de autorización |
| Vigencia y autorización limitan el universo antes del ranking vectorial | `fragmento_recuperable` + RLS sobre tablas base (no sobre la vista) | Consulta 7 en [`06_consultas_seguridad.sql`](../db/consultas/06_consultas_seguridad.sql) | Recuperación híbrida autorizada |
| Control de acceso independiente del texto de la consulta o instrucciones al modelo | Funciones `app_actor_id()`, `app_perfil_id()`, `app_clase_autorizada()` en [`05_seguridad.sql`](../db/indices_vistas/05_seguridad.sql) | [`evidencias/seguridad/matriz_autorizacion.md`](../evidencias/seguridad/matriz_autorizacion.md) §"Contextos inválidos" | Contexto efectivo y RLS |

## Trazabilidad

| Requisito | Artefacto | Evidencia | Sección del informe (propuesta) |
| --- | --- | --- | --- |
| Registro inmutable de acciones sobre documentos, consultas, accesos, recuperación y evidencia | Operaciones y triggers de auditoría en [`05_seguridad.sql`](../db/indices_vistas/05_seguridad.sql) | Consulta 9 y [`07_validaciones.sql`](../db/consultas/07_validaciones.sql) | Auditoría append-only |
| Cada evento identifica actor, perfil efectivo, instante, acción, resultado, recurso y correlación | Columnas de `evento_auditoria` en [`01_schema.sql`](../db/estructura/01_schema.sql) | [`evidencias/seguridad/matriz_autorizacion.md`](../evidencias/seguridad/matriz_autorizacion.md) | Auditoría append-only |
| La auditoría no duplica contenido sensible de los documentos | `COMMENT ON TABLE evento_auditoria` en [`01_schema.sql`](../db/estructura/01_schema.sql) | — (verificable por inspección del esquema: sin columna de texto de documento) | Auditoría append-only |

## Prueba funcional

| Requisito | Artefacto | Evidencia | Sección del informe (propuesta) |
| --- | --- | --- | --- |
| Modelos conceptual, lógico y físico con relaciones, cardinalidades y restricciones | Vistas índice y temáticas en [`docs/diagramas/`](diagramas/), más [`fisico_notas.md`](diagramas/fisico_notas.md) | Correspondencia con [`01_schema.sql`](../db/estructura/01_schema.sql) y los scripts de índices y seguridad | Modelo de datos |
| Implementación mínima: estructuras, datos, índices, controles de acceso, consultas | `db/estructura/`, `db/datos/`, `db/indices_vistas/`, `db/consultas/` | [`scripts/cargar_base.sh`](../scripts/cargar_base.sh) ejecuta las cinco fases en orden | Implementación |
| Al menos cinco consultas de negocio y recuperación; conjunto acordado de nueve | [`04_consultas.sql`](../db/consultas/04_consultas.sql) (1–6), [`06_consultas_seguridad.sql`](../db/consultas/06_consultas_seguridad.sql) (7–9) | [`evidencias/planes_ejecucion.md`](../evidencias/planes_ejecucion.md) | Consultas representativas |
| Resultados repetibles tras dos cargas limpias equivalentes | Semilla `42`, instante `2026-06-30T15:00:00Z` en [`generar_datos.py`](../scripts/generar_datos.py) | [`validar_base.sh`](../scripts/validar_base.sh) compara snapshots ordenados | Reproducibilidad |

## Requisitos recomendados

| Requisito | Artefacto | Evidencia | Sección del informe (propuesta) |
| --- | --- | --- | --- |
| Diagramas regenerables desde fuentes textuales versionadas | [`docs/diagramas/*.mmd`](diagramas/) | [`docs/diagramas/README.md`](diagramas/README.md) (instrucciones de render) | Modelo de datos |
| Evidencias revisables sin repetir explicaciones del informe | [`evidencias/`](../evidencias/) | — | Evidencias (anexo) |
| Recuperación con desempate estable | Orden `distancia, fragmento_id` en consultas 6–7 | [`db/consultas/04_consultas.sql`](../db/consultas/04_consultas.sql) §resultados esperados | Recuperación vectorial |
| Decisiones de rendimiento basadas en planes observados, no en optimizaciones anticipadas | Comentarios de justificación en [`03_indices.sql`](../db/indices_vistas/03_indices.sql) | [`evidencias/planes_ejecucion.md`](../evidencias/planes_ejecucion.md) | Rendimiento y escalabilidad |

## Requisitos opcionales

| Requisito | Artefacto | Evidencia | Sección del informe (propuesta) |
| --- | --- | --- | --- |
| Separación futura de almacenamiento de archivos e ingesta | README §"Limitaciones y posibles mejoras" | — (análisis, no implementado) | Evolución y trabajo futuro |
| Réplicas de lectura y particionamiento temporal para tablas de crecimiento continuo | README §"Limitaciones y posibles mejoras"; [`nosql/modelo_nosql.md`](../nosql/modelo_nosql.md) §"Base columnar" | — (análisis, no implementado) | Evolución y trabajo futuro |
| Métricas operativas adicionales, sin ampliar el dataset ni volverlo benchmark | No ejercido | — | Evolución y trabajo futuro (mención de alcance) |

## Reglas de negocio

| Regla | Artefacto | Evidencia |
| --- | --- | --- |
| Un actor pertenece a un único perfil; la consulta conserva el perfil efectivo | FK compuesta `consulta (actor_id, perfil_efectivo_id) → actor (id, perfil_autorizado_id)` | [`fisico_notas.md`](diagramas/fisico_notas.md) §"Claves foráneas compuestas" |
| Ausencia de permiso perfil-clase implica denegación | `permiso_documental` sin fila = sin acceso; RLS lo aplica | [`evidencias/seguridad/matriz_autorizacion.md`](../evidencias/seguridad/matriz_autorizacion.md) |
| Estados documentales: borrador, publicada, sustituida, revocada | `version_documental.estado CHECK` | [`01_schema.sql`](../db/estructura/01_schema.sql) |
| Versiones sustituidas o revocadas se conservan pero no son recuperables | Exclusión parcial `WHERE estado = 'publicada'` + vista `fragmento_recuperable` | [`docs/diagramas/fisico_notas.md`](diagramas/fisico_notas.md) |
| Pedido con cliente y al menos una línea; producto no repetido en el pedido | `linea_pedido_producto_uk` y constraint trigger diferido en [`01_schema.sql`](../db/estructura/01_schema.sql) | [`07_validaciones.sql`](../db/consultas/07_validaciones.sql) |
| Entrega pertenece a un pedido; entregas parciales admitidas | `entrega.pedido_id`, sin restricción de cardinalidad máxima | [`01_schema.sql`](../db/estructura/01_schema.sql) |
| Incidencia pertenece a una entrega, nunca directamente a un pedido | `incidencia_operativa.entrega_id NOT NULL` | [`01_schema.sql`](../db/estructura/01_schema.sql) |
| Condiciones comerciales con historia, sin solape por cliente-producto | `condicion_comercial_sin_solape_ex` (EXCLUDE gist) | Consulta 1 en [`04_consultas.sql`](../db/consultas/04_consultas.sql) |
| La línea de pedido conserva precio y descuento aplicados (snapshot) | `linea_pedido.precio_unitario/descuento_porcentaje` | [`01_schema.sql`](../db/estructura/01_schema.sql), comentario de columna |
| Respuesta exitosa requiere evidencia; los resultados negativos no admiten evidencia | Constraint triggers `DEFERRABLE INITIALLY DEFERRED` en [`01_schema.sql`](../db/estructura/01_schema.sql) | [`07_validaciones.sql`](../db/consultas/07_validaciones.sql) |
| Una misma evidencia no se repite dentro de una respuesta | `evidencia_documental_unica_uk`, `evidencia_estructurada_unica_uk` | [`01_schema.sql`](../db/estructura/01_schema.sql) |

## Riesgos y mitigaciones

| Riesgo | Mitigación exigida | Artefacto que la implementa |
| --- | --- | --- |
| Recuperar información no autorizada | Filtrar por perfil y clase antes del ranking; probar las 15 combinaciones | RLS en [`05_seguridad.sql`](../db/indices_vistas/05_seguridad.sql); [`evidencias/seguridad/matriz_autorizacion.md`](../evidencias/seguridad/matriz_autorizacion.md) |
| Usar contenido obsoleto o revocado | Aplicar estado y vigencia antes de recuperar; conservar historial separado | Vista `fragmento_recuperable`; exclusión parcial en `version_documental` |
| Presentar una respuesta sin fundamento | Asociar cada éxito a evidencia exacta; reservar sin-evidencia para negativos | `evidencia_documental`/`evidencia_estructurada`; `respuesta.tipo_resultado` |
| Perder reproducibilidad | Fijar reglas, semilla, instante, conteos y checksums | [`generar_datos.py`](../scripts/generar_datos.py), [`manifiesto.json`](../data/ejemplos/manifiesto.json) |
| Confundir demostración pequeña con rendimiento productivo | Interpretar planes sobre su escala real | [`evidencias/planes_ejecucion.md`](../evidencias/planes_ejecucion.md) |
| Sobredimensionar la arquitectura | Núcleo único; componentes distribuidos como evolución justificada | [`docs/diagramas/arquitectura.mmd`](diagramas/arquitectura.mmd); README §"Limitaciones" |
| Duplicar decisiones entre entregables | Fuente de autoridad única por artefacto | Esta matriz; tabla "Autoridad de los entregables" en [`impl-validacion-entregables.md`](specs/capa-datos-rag-distribuidora/impl-validacion-entregables.md) |

## Métricas de éxito

| Métrica | Cómo se verifica | Evidencia |
| --- | --- | --- |
| 100% de escenarios de carga y validación con conteos/checksums esperados | [`validar_base.sh`](../scripts/validar_base.sh) compara contra `manifiesto.json` | [`data/ejemplos/manifiesto.json`](../data/ejemplos/manifiesto.json) |
| Los nueve casos verificables (siete consultas y dos pruebas transversales) devuelven códigos, valores, conteos y orden deterministas | Ejecutar `04_consultas.sql` y `06_consultas_seguridad.sql` | [`db/consultas/04_consultas.sql`](../db/consultas/04_consultas.sql) §resultados esperados |
| Las quince combinaciones perfil-clase respetan la matriz acordada | Consulta 8 con `rag_runtime` sin `BYPASSRLS` | [`evidencias/seguridad/matriz_autorizacion.md`](../evidencias/seguridad/matriz_autorizacion.md) |
| Ninguna búsqueda devuelve contenido fuera del universo autorizado o vigente | Consulta 7 (cero filas fuera del universo permitido) | [`evidencias/seguridad/matriz_autorizacion.md`](../evidencias/seguridad/matriz_autorizacion.md) |
| Toda respuesta exitosa reconstruible hasta su fuente; negativos sin evidencia ficticia | Consulta 9 (trazabilidad) | [`06_consultas_seguridad.sql`](../db/consultas/06_consultas_seguridad.sql) |
| Intentos de violar integridad, auditoría o acceso son rechazados | Restricciones, triggers diferidos, privilegios y RLS | [`07_validaciones.sql`](../db/consultas/07_validaciones.sql) |
| Planes de ejecución relevantes registrados e interpretados | `EXPLAIN (ANALYZE, BUFFERS)` con y sin índice HNSW | [`evidencias/planes_ejecucion.md`](../evidencias/planes_ejecucion.md) |
| La documentación cubre todos los puntos obligatorios y permite reproducir la prueba | Esta matriz + README | — |

## Cobertura académica requerida (`impl-validacion-entregables.md`)

| Tema | Sección del informe | Estado |
| --- | --- | --- |
| Caso de uso, usuarios, riesgos y relevamiento de datos | [`01_caso_uso.tex`](informe_latex/secciones/01_caso_uso.tex), [`02_relevamiento_datos.tex`](informe_latex/secciones/02_relevamiento_datos.tex) | Cubierto |
| Clasificación de datos | [`03_clasificacion_datos.tex`](informe_latex/secciones/03_clasificacion_datos.tex) | Cubierto |
| Modelos conceptual, lógico y físico | [`04_modelo_conceptual.tex`](informe_latex/secciones/04_modelo_conceptual.tex), [`05_modelo_implementacion.tex`](informe_latex/secciones/05_modelo_implementacion.tex) | Cubierto; incluye los diagramas renderizados |
| Normalización, JSONB, embebido y referencias | [`06_decisiones_diseno.tex`](informe_latex/secciones/06_decisiones_diseno.tex) | Cubierto |
| Selección y justificación tecnológica | [`07_justificacion_tecnologica.tex`](informe_latex/secciones/07_justificacion_tecnologica.tex) | Cubierto |
| Implementación mínima, datos y consultas | [`08_implementacion_minima.tex`](informe_latex/secciones/08_implementacion_minima.tex), [`09_datos_ejemplo.tex`](informe_latex/secciones/09_datos_ejemplo.tex), [`10_consultas_representativas.tex`](informe_latex/secciones/10_consultas_representativas.tex) | Cubierto |
| Datos vectoriales y recuperación autorizada | [`11_datos_vectoriales.tex`](informe_latex/secciones/11_datos_vectoriales.tex) | Cubierto |
| Arquitectura general y recorrido de datos | [`12_arquitectura_datos.tex`](informe_latex/secciones/12_arquitectura_datos.tex) | Cubierto |
| Roles, permisos, aislamiento y auditoría | [`13_seguridad_aislamiento.tex`](informe_latex/secciones/13_seguridad_aislamiento.tex) | Cubierto |
| Rendimiento, escalabilidad y conclusiones | [`14_escalabilidad_rendimiento.tex`](informe_latex/secciones/14_escalabilidad_rendimiento.tex), [`15_conclusiones.tex`](informe_latex/secciones/15_conclusiones.tex) | Cubierto |

El único paso editorial pendiente es publicar el PDF definitivo en
`docs/informe.pdf` una vez concluida la revisión académica. Las fuentes Mermaid
siguen siendo la autoridad de los diagramas y se regeneran mediante el
procedimiento de [`diagramas/README.md`](diagramas/README.md).
