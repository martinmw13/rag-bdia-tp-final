# Capa de datos para un copiloto RAG interno de una distribuidora mayorista

**Trabajo Práctico Integrador — Bases de Datos para Inteligencia Artificial**
Carrera de Especialización en Inteligencia Artificial
Docente: Martín Lacheski — Año: 2026

## Integrantes del grupo

- Martin, Madrid
- Orellana, César Andrés
- Ciarrapico, Nicolás Valentin

## Caso de uso elegido

**Caso 1 de la cátedra: Sistema RAG para consulta de documentación técnica.**

La impronta propia del grupo es ambientarlo en una **distribuidora mayorista**, donde el copiloto interno no consulta únicamente un corpus documental sino que convive con datos operativos del negocio. El eje diferencial del trabajo son tres problemas que el caso general enuncia pero no resuelve: la **vigencia** de la documentación, la **autorización** aplicada antes de recuperar y la **evidencia exacta** que sostuvo cada respuesta.

## Descripción breve de la solución

La información de una distribuidora se reparte entre catálogos, condiciones comerciales, pedidos, entregas, incidencias, fichas de producto, procedimientos y documentación de proveedores o cumplimiento. Buscarla manualmente dificulta localizar la versión vigente, distinguir hechos operativos de conocimiento documental y explicar qué fuente fundamentó una respuesta. Además, no toda la información puede exponerse a todos los perfiles.

Este trabajo diseña la **capa de datos** que soportaría ese copiloto: modelo conceptual, lógico y físico, más una prueba funcional que demuestra almacenamiento, integridad, recuperación semántica autorizada, trazabilidad y criterios de evolución.

El alcance se limita a la capa de datos. No incluye frontend, backend, API ni integración efectiva con un modelo de lenguaje; la aplicación de IA funciona como contexto del problema.

## Datos principales identificados

| Ámbito | Datos |
| --- | --- |
| Operativo | Productos, categorías, clientes, segmentos, proveedores, condiciones comerciales, pedidos, líneas de pedido, entregas, incidencias |
| Documental | Documentos, versiones, estados y vigencia, fragmentos, clases documentales, niveles de sensibilidad, procedencia e integridad del archivo original |
| Vectorial | Embeddings de fragmentos y modelos de embedding |
| Acceso | Actores, perfiles autorizados y permisos por perfil y clase documental |
| Interacción y evidencia | Consultas, respuestas, evidencia documental y evidencia estructurada |
| Auditoría | Eventos inmutables de carga, publicación, sustitución, revocación, consulta, acceso denegado y recuperación |

## Tecnologías propuestas

**PostgreSQL** con las extensiones **`pgvector`** (búsqueda por similitud) y **`btree_gist`** (exclusión de solapamientos temporales), en una única instancia que concentra datos operativos, metadatos documentales, embeddings, permisos, interacción y auditoría.

Los archivos originales de los documentos permanecen fuera de la base, vinculados por ruta relativa, tipo MIME, tamaño y SHA-256.

La justificación frente a alternativas NoSQL y a bases vectoriales dedicadas se desarrolla en [`nosql/modelo_nosql.md`](nosql/modelo_nosql.md) y [`vectorial/modelo_vectorial.md`](vectorial/modelo_vectorial.md).

## Estructura del repositorio

```text
├── README.md
├── docs/
│   ├── specs/
│   │   └── capa-datos-rag-distribuidora/
│   │       ├── PRD.md                 # Especificación del producto
│   │       └── impl-*.md              # Especificaciones de implementación
│   ├── matriz_cobertura.md            # Requisito → artefacto → evidencia
│   ├── modelo_conceptual.png          # Diagramas renderizados
│   ├── modelo_logico_o_equivalente.png
│   ├── modelo_fisico_o_equivalente.png
│   ├── arquitectura.png
│   └── diagramas/                     # Fuentes Mermaid (autoridad de los diagramas)
├── data/
│   └── ejemplos/
│       ├── documentos/                # 14 archivos Markdown, uno por versión
│       └── manifiesto.json            # Procedencia, conteos, checksums y oráculos
├── db/
│   ├── estructura/01_schema.sql       # Tablas, claves y restricciones
│   ├── datos/02_seed.sql              # Carga de datos de ejemplo (generado)
│   ├── indices_vistas/
│   │   ├── 03_indices.sql             # Índices y vista de recuperación
│   │   └── 05_seguridad.sql           # Roles, RLS y auditoría append-only
│   └── consultas/
│       ├── 04_consultas.sql           # Consultas 1 a 6
│       ├── 06_consultas_seguridad.sql # Consultas 7 a 9
│       └── 07_validaciones.sql        # Aserciones automáticas
├── nosql/modelo_nosql.md              # Análisis de alternativas NoSQL
├── vectorial/modelo_vectorial.md      # Modelo de datos vectorial
├── evidencias/
│   ├── planes_ejecucion.md            # Planes reales y su interpretación
│   └── seguridad/                     # Matriz de autorización y pruebas negativas
├── scripts/
│   ├── generar_datos.py               # Generador del conjunto sintético
│   ├── cargar_base.sh                 # Recorrido simple de la muestra
│   └── validar_base.sh                # Validación exhaustiva en dos cargas
└── anexos/material_complementario.md
```

Los archivos SQL están numerados por orden de ejecución, que atraviesa las
carpetas: `01` y `02` construyen y pueblan, `03` agrega estructuras de acceso,
`04` consulta, `05` aplica el control de acceso, `06` lo verifica y `07`
contiene las aserciones exhaustivas.

## Instrucciones para ejecutar la implementación mínima

### Requisitos previos

- PostgreSQL 15 o superior con la extensión [`pgvector`](https://github.com/pgvector/pgvector) disponible, y `psql` en el `PATH`.
- Python 3 para el generador de datos, que usa **sólo biblioteca estándar**: no hay que instalar dependencias ni crear un entorno virtual.

La implementación se desarrolló y verificó sobre PostgreSQL 17.11 con pgvector
0.8.6.

### Ejecución completa

```bash
scripts/cargar_base.sh
```

El script regenera el conjunto sintético, recrea la base `rag_distribuidora`
desde cero, aplica el esquema, los datos, los índices y la seguridad, y luego
ejecuta las nueve consultas. Acepta otro nombre de base como primer argumento.

> La base indicada **se elimina y se vuelve a crear**. No apuntar a una base con
> datos que interesen.

### Validación exhaustiva

```bash
scripts/validar_base.sh rag_distribuidora_validacion
```

Este comando comprueba restricciones, permisos, ciclo documental, auditoría,
conteos, checksums y oráculos vectoriales. Recrea dos veces la base indicada y
compara snapshots ordenados. Como medida de seguridad, sólo acepta nombres que
terminen en `_validacion`.

### Paso a paso

```bash
python3 scripts/generar_datos.py          # documentos, manifiesto y 02_seed.sql
createdb rag_distribuidora
psql -d rag_distribuidora -f db/estructura/01_schema.sql
psql -d rag_distribuidora -f db/datos/02_seed.sql
psql -d rag_distribuidora -f db/indices_vistas/03_indices.sql
psql -d rag_distribuidora -f db/indices_vistas/05_seguridad.sql
```

Las consultas 6 y 7 reciben el vector de consulta como parámetro. Su fuente de
autoridad es `data/ejemplos/manifiesto.json`, en `oraculos_vectoriales`; el
script de carga lo lee de ahí automáticamente.

### Reproducibilidad

El generador usa semilla `42` y el instante de referencia
`2026-06-30T15:00:00Z`. La carga es idempotente: `02_seed.sql` vacía las tablas
antes de insertar. `validar_base.sh` demuestra la reproducibilidad al comparar
conteos, contenido y checksums de dos recreaciones limpias.

## Principales decisiones de diseño

- **Un único motor** para datos operativos, documentales y vectoriales, evitando sincronizar dos sistemas y permitiendo resolver la similitud y los filtros relacionales en una sola consulta.
- **Sólo se vectorizan los fragmentos documentales.** Los hechos operativos se consultan como datos estructurados.
- **La autorización y la vigencia limitan el universo antes del ranking**, no después: un resultado prohibido nunca ocupa un lugar en el top-k.
- **Permisos por perfil y clase documental**, con denegación por defecto y sin excepciones individuales. El control de acceso no depende del texto de la consulta.
- **Los perfiles funcionales se modelan como datos** y el permiso surge de una tabla. Los roles de base separan las responsabilidades técnicas de ingesta, gestión documental, consulta y revisión de auditoría. El runtime asume la identidad del actor por transacción, como una aplicación con pool de conexiones: la conexión es compartida, la identidad es propia de cada transacción.
- **El aislamiento se apoya en RLS, no en las consultas.** Las políticas se aplican sobre las tablas, no sobre una vista, de modo que el filtro siga vigente aunque alguien consulte las tablas directamente. La vista de recuperación usa `security_invoker` para no convertirse en un camino que las eluda.
- **Historial completo**: las versiones sustituidas o revocadas se conservan pero dejan de recuperarse, de modo que una respuesta anterior siga siendo explicable.
- **Evidencia obligatoria**: toda respuesta exitosa conserva la fuente exacta que utilizó; los resultados negativos se declaran explícitamente y no inventan evidencia.
- **Auditoría append-only**, que registra la actividad sin duplicar contenido sensible.
- **Uso acotado de JSONB**, limitado a metadatos y detalles variables; todo lo que se filtra, relaciona o autoriza permanece tipado y normalizado.
- **Datos sintéticos reproducibles**, generados con semilla fija y sin dependencias externas.

## Consultas incluidas

Nueve consultas, con su propósito, parámetros y resultado esperado declarados
en el propio archivo SQL. Los resultados se expresan en códigos de negocio, no
en claves internas, para que sobrevivan a una recarga.

| # | Consulta | Patrón que demuestra |
| --- | --- | --- |
| 1 | Condición comercial vigente | Selección y filtrado sobre un intervalo semiabierto |
| 2 | Pedidos y entregas que requieren atención | `JOIN` entre cuatro entidades y `LEFT JOIN` |
| 3 | Importe neto por categoría | Agregación con `GROUP BY` |
| 4 | Productos principales por segmento | Función de ventana `DENSE_RANK` |
| 5 | Clientes sin pedidos históricos | Subconsulta correlacionada con `NOT EXISTS` |
| 6 | Búsqueda vectorial top-k | Distancia coseno con orden estable |
| 7 | Recuperación híbrida autorizada | Similitud combinada con filtros relacionales |
| 8 | Matriz de autorización | Verificación exhaustiva del control de acceso |
| 9 | Trazabilidad e inmutabilidad | Auditoría y correlación histórica |

Las consultas 1 a 6 están en `db/consultas/04_consultas.sql`. Las 7, 8 y 9
están en `db/consultas/06_consultas_seguridad.sql` porque sólo tienen sentido
con los roles y las políticas de RLS aplicados: se ejecutan con el rol
`rag_runtime`, que no es propietario ni tiene `BYPASSRLS`.

La consulta 7 muestra el efecto del control de acceso. Con el mismo vector y el
mismo corpus, Comercial/Compras recibe primero la política comercial buscada,
mientras que Operaciones/Logística no recibe **ningún** fragmento de esa clase,
ni siquiera en la última posición del top-5: la autorización limita el universo
antes de calcular el orden, así que un fragmento prohibido nunca llega a ocupar
un lugar. Las salidas están en
[`evidencias/seguridad/matriz_autorizacion.md`](evidencias/seguridad/matriz_autorizacion.md).

## Limitaciones y posibles mejoras

Límites asumidos de forma deliberada, por tratarse de una prueba funcional de
diseño y no de un sistema en producción:

- **Los embeddings son sintéticos.** Son vectores de 32 dimensiones construidos
  con centroides y ruido determinista, no la salida de un modelo real. Permiten
  demostrar el almacenamiento, el índice, la métrica y el filtrado autorizado,
  pero no la calidad semántica de la recuperación.
- **La escala es mínima.** Ninguna tabla supera las 56 filas, así que el
  planificador resuelve casi todo con `Seq Scan` incluso habiendo índices. Los
  tiempos medidos no deben extrapolarse: ver
  [`evidencias/planes_ejecucion.md`](evidencias/planes_ejecucion.md).
- **No hay autenticación.** Los actores no guardan credenciales y los roles se
  crean `NOLOGIN`; las pruebas usan `SET ROLE`. Cómo se autentica un usuario y
  cómo se propaga su identidad hasta el contexto de la transacción queda fuera
  de alcance.
- **No hay integración con un modelo de lenguaje.** El copiloto es el contexto
  del problema; lo que se diseña es la capa de datos que lo sostendría.
- **La arquitectura es un núcleo único.** Separación del almacenamiento de
  archivos, réplicas de lectura y particionamiento temporal se analizan como
  evolución, pero no se implementan.

Si el trabajo continuara, las mejoras serían reemplazar los vectores sintéticos
por un modelo real y revisar la dimensión y los parámetros del índice HNSW;
mover los archivos originales a almacenamiento de objetos conservando el
contrato de checksum; y particionar `evento_auditoria` por tiempo, que es la
tabla de crecimiento continuo más claro.

## Documentación

- [Especificación del producto](docs/specs/capa-datos-rag-distribuidora/PRD.md)
- [Especificaciones de implementación](docs/specs/capa-datos-rag-distribuidora/)
- Diagramas: [conceptual](docs/modelo_conceptual.png), [lógico](docs/modelo_logico_o_equivalente.png), [físico](docs/modelo_fisico_o_equivalente.png) y [arquitectura](docs/arquitectura.png); [fuentes Mermaid](docs/diagramas/)
- [Matriz de cobertura](docs/matriz_cobertura.md)
- [Análisis de alternativas NoSQL](nosql/modelo_nosql.md)
- [Modelo de datos vectorial](vectorial/modelo_vectorial.md)
