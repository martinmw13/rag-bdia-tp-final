# Modelo de datos vectorial

Este documento describe el modelo vectorial efectivamente implementado en
[`db/estructura/01_schema.sql`](../db/estructura/01_schema.sql),
[`db/indices_vistas/03_indices.sql`](../db/indices_vistas/03_indices.sql) y
[`db/indices_vistas/05_seguridad.sql`](../db/indices_vistas/05_seguridad.sql),
y justifica `pgvector` frente a una base vectorial dedicada. No introduce
estructuras nuevas: documenta las ya construidas y probadas (ver
[`evidencias/planes_ejecucion.md`](../evidencias/planes_ejecucion.md) y
[`evidencias/seguridad/matriz_autorizacion.md`](../evidencias/seguridad/matriz_autorizacion.md)).

## Qué se vectoriza

Únicamente `fragmento`: la sección de una versión documental publicada. Los
hechos operativos — productos, pedidos, entregas, condiciones comerciales —
nunca se vectorizan y se consultan siempre como datos estructurados (ver
consultas 1 a 5 en `db/consultas/04_consultas.sql`). Esta separación evita el
error más común de un diseño RAG mal planteado: tratar hechos que tienen una
respuesta exacta y verificable como si fueran texto libre a recuperar por
similitud.

## Estructura del elemento vectorizado

El texto que compone el vector combina **título del documento + encabezado de
la sección + contenido del cuerpo** (contrato fijado en
`docs/specs/capa-datos-rag-distribuidora/impl-datos-sinteticos.md`, sección
"Documentos y fragmentación"). `fragmento.contenido` almacena sólo el cuerpo
propio de la sección — no el texto combinado — porque el contenido debe
poder mostrarse como evidencia sin repetir el título en cada fragmento
recuperado; el texto combinado es un artefacto de construcción del vector,
no un dato persistente adicional.

## Metadatos asociados

`embedding` no lleva metadatos propios más allá de `generado_en`: el modelo
delega los metadatos de recuperación a las tablas relacionadas, evitando
duplicarlos dentro del vector o en un campo JSON paralelo. La vista
`fragmento_recuperable` (`03_indices.sql`) es el punto único que reúne, para
cada embedding recuperable:

| Metadato | Origen | Uso |
| --- | --- | --- |
| `version_id`, `numero_version`, `vigente_desde/hasta` | `version_documental` | Vigencia: filtra antes del ranking |
| `documento_id`, `documento_codigo`, `documento_titulo` | `documento` | Identificación y evidencia legible |
| `clase_id`, `clase_codigo` | `clase_documental` (vía `documento`) | Autorización: entrada a `permiso_documental` |
| `sensibilidad_id`, `sensibilidad_codigo` | `nivel_sensibilidad` (vía `documento`) | Contexto para auditoría; **no** reemplaza la autorización por clase |
| `modelo_id`, `modelo_nombre`, `modelo_version` | `modelo_embedding` | Evita mezclar vectores de modelos distintos en un mismo ranking |
| `posicion`, `fragmento_titulo`, `pagina` | `fragmento` | Desempate estable y trazabilidad de la posición exacta |

## Vínculo con el dato original

`fragmento` → `version_documental` → `documento` → archivo en
`data/ejemplos/documentos/`. El archivo Markdown vive **fuera** de la base;
`version_documental` conserva `ruta_relativa`, `nombre_archivo`, `tipo_mime`,
`tamano_bytes` y `sha256` como contrato de integridad verificable sin
almacenar el binario. La evidencia documental (`evidencia_documental`) no
apunta al fragmento en general sino al `embedding_id` exacto que participó
en la respuesta, lo que permite reconstruir hasta el modelo de embedding
usado, no sólo el texto recuperado.

## Consultas por similitud esperadas

Dos, con contratos distintos y complementarios (`db/consultas/04_consultas.sql`
y `06_consultas_seguridad.sql`):

1. **Búsqueda vectorial top-k (consulta 6).** Distancia coseno contra el
   modelo activo únicamente, sin filtro de autorización, para validar el
   comportamiento puro del índice: el fragmento temático esperado debe
   ocupar la primera posición, con desempate estable por `fragmento_id`.
2. **Recuperación híbrida autorizada (consulta 7).** "Híbrida" significa acá
   *similitud vectorial combinada con `JOIN` y filtros relacionales* —no
   ranking lexical + vectorial—: actividad de documento y modelo,
   publicación, vigencia y permiso del perfil efectivo se aplican en el
   mismo plan de ejecución que calcula la distancia coseno, antes del
   `LIMIT`.

## Criterios de filtrado y control de acceso

La autorización y la vigencia limitan el universo **antes** del ranking, no
como post-filtro: un fragmento prohibido nunca ocupa un lugar en el top-k
para luego descartarse. Esto se logra en dos capas independientes:

- La vista `fragmento_recuperable` aplica `d.activo`, `me.activo`,
  `v.estado = 'publicada'` y el rango de vigencia — condiciones
  independientes de quién consulta.
- Las políticas RLS sobre `documento`, `version_documental`, `fragmento` y
  `embedding` (`05_seguridad.sql`) aplican `app_clase_autorizada(clase_id)`,
  evaluada contra el perfil efectivo de la transacción — condición que sí
  depende de quién consulta, y que se aplica sobre las **tablas**, no sobre
  la vista, para que el filtro siga vigente aunque alguien consulte
  `fragmento` o `embedding` directamente en lugar de pasar por la vista.

El resultado medido en
[`evidencias/seguridad/matriz_autorizacion.md`](../evidencias/seguridad/matriz_autorizacion.md)
es literal: para una clase no autorizada, el conteo de fragmentos visibles es
cero, no "visible pero descartado".

## Configuración

| Parámetro | Valor | Justificación |
| --- | --- | --- |
| Dimensión | 32 (`VECTOR(32)`) | Suficiente para demostrar centroides y vecindarios temáticos con datos sintéticos; evita el costo de manejar 384+ dimensiones sin un modelo real detrás. |
| Métrica | Distancia coseno (`vector_cosine_ops`) | Es la métrica estándar para embeddings de texto normalizados; coherente con `modelo_embedding.metrica = 'coseno'`. |
| Índice | HNSW, parámetros por defecto (`m`, `ef_construction` de `pgvector`) | Aproximado pero de alta recuperación (`recall`) a este volumen; ver el plan real con y sin índice en `evidencias/planes_ejecucion.md`. No se ajustaron parámetros porque el volumen de prueba (36 filas) no lo justifica — ver "Casos límite de revisión" en la spec de validación. |
| Un vector por fragmento y modelo | `UNIQUE (fragmento_id, modelo_id)` | Permite conservar un embedding histórico junto al activo sin ambigüedad sobre cuál participó en cada respuesta. |

## Justificación de `pgvector` frente a una base vectorial dedicada

| Dimensión | `pgvector` (elegido) | Base vectorial dedicada (Pinecone, Qdrant, Milvus, Chroma) |
| --- | --- | --- |
| Filtrado autorizado | En la misma consulta y transacción que el ranking, con RLS evaluado por el motor. | Requiere replicar perfil/clase/vigencia como metadatos filtrables en el motor vectorial, y mantenerlos sincronizados con la fuente de verdad relacional. |
| Consistencia | Publicar, sustituir o vectorizar son parte de la misma transacción ACID que el resto del modelo. | Consistencia eventual entre el store relacional y el índice vectorial; una sustitución de versión puede dejar una ventana donde el vector viejo sigue siendo top-k. |
| Trazabilidad | La evidencia referencia una fila (`embedding_id`) con las mismas garantías de integridad que cualquier otra tabla. | Requiere correlacionar IDs entre dos sistemas para reconstruir una respuesta. |
| Escala de esta prueba | 36 embeddings de 32 dimensiones: HNSW en PostgreSQL es más que suficiente (ver planes de ejecución). | Sin ventaja de rendimiento medible a este volumen; la complejidad operativa no tiene contrapartida. |
| Escala productiva (evolución) | Escala vertical primero; búsqueda vectorial a millones de vectores con múltiples réplicas es el punto donde una base dedicada empieza a tener ventaja real. | Gana en throughput de búsqueda pura y en operar el índice de forma aislada del tráfico transaccional. |
| Complejidad operativa | Un único motor que ya se administra. | Un segundo sistema a desplegar, versionar y sincronizar. |

**Conclusión:** para el volumen y las garantías que pide este TP —
autorización aplicada antes del ranking, vigencia transaccional y evidencia
exacta reconstruible — `pgvector` sobre PostgreSQL domina en todas las
dimensiones relevantes salvo el throughput de búsqueda vectorial pura a gran
escala, que no es el problema que este caso plantea. Una base vectorial
dedicada queda como evolución posible, condicionada a que el volumen de
embeddings crezca varios órdenes de magnitud y a resolver antes cómo
replicar el filtrado autorizado sin reabrir la ventana de inconsistencia que
el diseño actual evita.

## Riesgos si se recupera información incorrecta, desactualizada o no autorizada

| Riesgo | Cómo lo evita este modelo |
| --- | --- |
| Recuperar una versión sustituida o revocada | La vista filtra por `estado = 'publicada'` y vigencia; el historial se conserva pero queda fuera de la recuperación normal (`evidencias/planes_ejecucion.md` documenta la exclusión temporal que lo garantiza a nivel de restricción). |
| Recuperar contenido de una clase no autorizada | RLS sobre las tablas base, no sobre la vista; probado exhaustivamente para las 15 combinaciones perfil × clase. |
| Mezclar vectores de modelos distintos en un mismo ranking | `embedding_modelo_ix` y el filtro `me.activo` en la vista restringen la búsqueda al modelo activo; sólo un modelo puede estar activo a la vez según el contrato de datos sintéticos. |
| Presentar una respuesta sin evidencia reconstruible | `evidencia_documental` referencia el `embedding_id` exacto, no el documento en general; una respuesta `exito` debe cerrar su transacción con al menos una evidencia, invariante que garantiza la transacción de carga y que el esquema documenta en el comentario de `respuesta`. |
| Empates no deterministas en el top-k | Orden por distancia ascendente con `fragmento_id` como desempate estable, verificado en las consultas 6 y 7. |
