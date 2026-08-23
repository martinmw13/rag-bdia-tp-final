# Análisis de alternativas NoSQL

La solución implementada usa **PostgreSQL** como motor único (ver
[`db/estructura/01_schema.sql`](../db/estructura/01_schema.sql) y
[`README.md`](../README.md)). Este documento no propone reemplazarlo: evalúa,
para cada gran familia NoSQL, qué resolvería bien del caso y qué perdería,
usando los criterios que pide la consigna — tipo y variabilidad de los datos,
volumen esperado, patrones de consulta, relaciones entre entidades,
consistencia requerida, seguridad y control de acceso, escalabilidad,
complejidad operativa, y ventajas/limitaciones frente a la alternativa
elegida.

## Por qué la pregunta no es trivial

El dominio combina datos muy distintos en un mismo copiloto: hechos
operativos altamente relacionales (pedidos, entregas, condiciones
comerciales), contenido documental semiestructurado con versionado y
vigencia, vectores para recuperación semántica, una matriz de permisos que
debe evaluarse en cada lectura, y un registro de auditoría de crecimiento
continuo. Cada uno de esos cinco perfiles de datos es, por separado, el caso
de uso típico de una familia NoSQL distinta. La pregunta de diseño no es "¿es
viable NoSQL?" sino "¿conviene partir el sistema en varios motores
especializados, o resolverlo en uno solo que cubra los cinco perfiles
razonablemente bien?".

## Base documental (MongoDB y similares)

**Qué resolvería bien:** el corpus documental encaja naturalmente en el
modelo de documentos. `documento` → `version_documental` → `fragmento` podría
representarse como un documento JSON con versiones embebidas, sin necesidad
de tablas de unión, y la ausencia de esquema fijo facilitaría agregar tipos
de metadatos nuevos sin migraciones.

**Qué perdería:**

- **Integridad referencial entre versionado y vigencia.** El requisito
  central del caso — "sólo una versión publicada, no revocada y vigente por
  documento en un instante dado" — se implementa en este proyecto con una
  restricción de exclusión temporal declarativa
  (`version_documental_sin_solape_ex`, `EXCLUDE USING gist`) que el motor
  rechaza automáticamente si se viola. Una base documental no tiene un
  equivalente declarativo: la regla pasaría a vivir en la aplicación, con
  ventana de inconsistencia posible entre el chequeo y la escritura salvo que
  se implementen transacciones multi-documento (disponibles en MongoDB desde
  la versión 4, pero con un costo de rendimiento que anula buena parte de la
  ventaja de "documento autocontenido").
- **Relación con el núcleo operativo.** `documento_producto` y
  `documento_proveedor` vinculan el corpus con productos y proveedores que
  viven en tablas relacionales con sus propias reglas (código único, borrado
  restringido). Mantener esa relación consistente entre dos motores exigiría
  sincronización dual, exactamente lo que el diseño actual evita
  deliberadamente (ver "Un único motor" en el README).
- **Autorización uniforme.** La solución adoptada apoya el control de acceso
  en RLS a nivel de fila, evaluado por el mismo motor que resuelve el `JOIN`
  y el `ORDER BY`. Una base documental sin RLS nativo obligaría a replicar el
  filtro de autorización en cada consulta de la aplicación, perdiendo la
  garantía de "el aislamiento se apoya en RLS, no en las consultas" que el
  proyecto declara como decisión de diseño no negociable.

**Veredicto:** resolvería bien el corpus en aislamiento, pero al costo de
partir la integridad transaccional y la autorización entre dos sistemas. No
se adopta.

## Base clave-valor (Redis y similares)

**Qué resolvería bien:** es la tecnología correcta para una **caché de
recuperación** — por ejemplo, resultados de búsquedas híbridas frecuentes
por perfil, o el contexto efectivo de un actor durante su sesión — y para
estructuras de expiración rápida que no necesitan historial.

**Qué perdería si fuera almacenamiento primario:** no tiene forma nativa de
expresar relaciones (`producto_proveedor`, `condicion_comercial`), vigencia
temporal con exclusión de solapamiento, ni consultas de agregación como las
de las consultas 3 y 4 (`GROUP BY`, `DENSE_RANK`). Tampoco resuelve
naturalmente la trazabilidad histórica, que exige poder reconstruir una
respuesta antigua después de que el dato vigente cambió.

**Veredicto:** aplicable únicamente como capa de caché *delante* de
PostgreSQL, nunca como almacenamiento primario. El TP no incorpora una capa
de caché porque el volumen de la prueba no la justifica, pero es la evolución
natural si el sistema creciera: cachear resultados de recuperación híbrida
por combinación (perfil, vector, top-k), invalidando por publicación o
revocación de versión.

## Base columnar (Cassandra, Bigtable y similares)

**Qué resolvería bien:** `evento_auditoria` es, por diseño, la única tabla
de **crecimiento continuo e ilimitado** del modelo — cada consulta, cada
recuperación y cada respuesta generan un evento y nada se borra. Ese patrón
de escritura predominantemente append-only, particionable por tiempo y con
lecturas mayormente por rango de fecha o por actor, es el caso de libro de
texto de una base columnar orientada a series de eventos.

**Qué perdería:** las columnares sacrifican consultas ad hoc y `JOIN`
eficientes a cambio de escritura y lectura secuencial masiva. Los casos 8 y 9
de este TP (matriz de autorización, trazabilidad) necesitan correlacionar
`evento_auditoria` con `consulta`, `respuesta`, `actor` y `perfil_autorizado`
en la misma consulta — exactamente lo que una columnar resuelve peor que un
motor relacional a esta escala.

**Veredicto:** es la evolución más justificada de las cuatro si el volumen de
auditoría creciera varios órdenes de magnitud. El README ya la señala como
mejora natural bajo la forma más simple y menos disruptiva: particionar
`evento_auditoria` por tiempo dentro de PostgreSQL (partición declarativa por
rango de `instante`), que da la mayoría del beneficio de escritura secuencial
sin salir del motor único. Migrar a una base columnar dedicada recién se
justificaría si esa partición dejara de alcanzar.

## Base de grafos (Neo4j y similares)

**Qué resolvería bien:** relaciones como "qué versiones sucedieron a cuál",
"qué documentos comparten proveedor" o "qué cadena de eventos llevó a una
respuesta" son navegaciones de grafo por naturaleza, y una base de grafos las
resuelve con recorridos nativos en lugar de `JOIN` recursivos.

**Qué perdería:** en este dominio esas relaciones tienen **profundidad fija y
conocida** (una versión sustituye a lo sumo a una anterior del mismo
documento; una evidencia referencia exactamente un embedding), no cadenas de
longitud variable que requieran recorrido general de grafo. Un `JOIN` de
profundidad 2-3 sobre claves foráneas indexadas resuelve lo mismo sin pagar
el costo operativo de un segundo motor, y conserva las restricciones
declarativas (unicidad, exclusión temporal) que una base de grafos no ofrece
con la misma madurez que PostgreSQL.

**Veredicto:** no se justifica. El caso de uso que la haría atractiva —
recorridos de profundidad variable y desconocida a priori — no está presente
en los requisitos ni en las consultas acordadas.

## Base vectorial dedicada (Pinecone, Qdrant, Milvus, Chroma)

Desarrollado en detalle en [`vectorial/modelo_vectorial.md`](../vectorial/modelo_vectorial.md).
En síntesis: una base vectorial dedicada optimiza mejor la búsqueda por
similitud a gran escala, pero exigiría sincronizar dos fuentes de verdad
(embeddings allá, autorización y vigencia acá) y resolver el filtrado
autorizado **antes** del ranking mediante metadatos replicados en el motor
vectorial — replicando exactamente el problema de consistencia dual que el
diseño de un único motor evita. A la escala de esta prueba (36 embeddings de
32 dimensiones) esa complejidad adicional no tiene contrapartida de
rendimiento: `pgvector` con índice HNSW resuelve la búsqueda, el filtro
relacional y la autorización en la misma consulta y la misma transacción.

## Criterios de comparación, resumidos

| Criterio | Documental | Clave-valor | Columnar | Grafos | Vectorial dedicada | PostgreSQL (elegido) |
| --- | --- | --- | --- | --- | --- | --- |
| Tipo y variabilidad de datos | Alta (semiestructurado) | Baja | Media (series) | Alta (relaciones) | Baja (vectores + metadatos) | Mixta, es el punto fuerte del caso |
| Volumen esperado en el TP | Bajo | Bajo | Bajo | Bajo | Bajo | Bajo, y sin cambio de motor si crece |
| Patrones de consulta | Documento completo | Punto (get/set) | Rango temporal | Recorrido | Top-k por similitud | `JOIN` + agregación + top-k + RLS, todo en la misma consulta |
| Relaciones entre entidades | Débiles (embebidas) | Ninguna | Débiles | Fuertes, nativas | Ninguna | Fuertes, con integridad declarativa |
| Consistencia requerida | Eventual aceptable en muchos usos | Eventual | Eventual | Fuerte en el recorrido | No aplica al filtrado autorizado | Fuerte, transaccional (ACID) |
| Seguridad y control de acceso | Depende de la aplicación | Depende de la aplicación | Depende de la aplicación | Variable por producto | Depende de metadatos replicados | RLS nativo, evaluado por el motor |
| Escalabilidad horizontal | Alta | Muy alta | Muy alta | Media | Alta | Vertical primero; particionamiento y réplicas como evolución |
| Complejidad operativa agregada | Un motor más que sincronizar | Un motor más | Un motor más | Un motor más | Un motor más + replicación de metadatos | Ninguna: un solo motor |
| Ventaja principal | Esquema flexible | Latencia mínima | Escritura masiva sostenida | Recorridos complejos | Búsqueda vectorial a gran escala | Un solo lugar para vigencia + autorización + similitud + auditoría |
| Limitación principal aquí | Sin integridad temporal declarativa | Sin relaciones ni agregación | Sin `JOIN` eficiente | Recorridos de profundidad fija no lo necesitan | Filtrado autorizado requiere sincronización | Escala vertical tiene techo (fuera de alcance de este TP) |

## Conclusión

Ninguna alternativa NoSQL resuelve *mejor* el conjunto de requisitos que un
único PostgreSQL con `pgvector` y `btree_gist`, porque el eje diferencial del
trabajo — vigencia, autorización aplicada antes del ranking y evidencia
exacta — depende de que el motor que vectoriza sea el mismo que aplica RLS,
resuelve la exclusión temporal y mantiene la integridad referencial entre
documento, versión, fragmento y embedding. Partir el sistema en varios
motores especializados movería esas garantías desde restricciones
declarativas verificadas por el motor hacia lógica de aplicación
sincronizada a mano, que es precisamente el riesgo que la consigna pide
mitigar. Las familias NoSQL analizadas quedan como evolución posible y
acotada — caché clave-valor delante de la vista de recuperación,
particionamiento (inicialmente nativo de PostgreSQL, no necesariamente un
motor columnar aparte) para `evento_auditoria` — nunca como reemplazo del
núcleo.
