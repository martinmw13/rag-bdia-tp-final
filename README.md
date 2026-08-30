# Capa de datos para un copiloto RAG interno de una distribuidora mayorista

## Uso de IA

Hola profe! En este trabajo usamos IA como apoyo para explorar alternativas y definir el diseño del proyecto.
Las decisiones de dominio, alcance, modelado y validación fueron discutidas y aprobadas por los
tres integrantes.

Como referencia metodológica tomamos el flujo de
[Matt Pocock](https://github.com/mattpocock/skills), esta buenisimo. Antes de implementar, organizamos las preguntas
abiertas en un mapa compartido, resolvimos cada decisión,
consolidamos el resultado en un PRD y contrastamos la implementación con ese
documento.

La trazabilidad del proceso se puede ver en:

- [Mapa de decisiones: issue #1](https://github.com/martinmw13/rag-bdia-tp-final/issues/1), con enlaces a las diez decisiones resueltas como subissues.
- [PRD final](docs/specs/capa-datos-rag-distribuidora/PRD.md)

**Trabajo Práctico Integrador — Bases de Datos para Inteligencia Artificial**
Carrera de Especialización en Inteligencia Artificial
Docente: Martín Lacheski — Año: 2026

## Integrantes del grupo

- Martin, Madrid
- Orellana, César Andrés
- Ciarrapico, Nicolás Valentin

## Caso de uso elegido

**Caso 1 de la cátedra: Sistema RAG para consulta de documentación técnica.**

El caso se adapta a una **distribuidora mayorista** y combina documentos con
datos operativos. El diseño se concentra en tres problemas: la **vigencia** de
la documentación, la **autorización** antes de recuperar y la **evidencia** que
sostuvo cada respuesta.

## Descripción breve de la solución

La información está repartida entre catálogos, pedidos, entregas, incidencias,
procedimientos y documentos de proveedores. Encontrar una respuesta puede
llevar tiempo, terminar en una versión vencida o depender de alguien que conozca
el proceso. Además, no todos los perfiles pueden ver lo mismo.

Se diseña la **capa de datos** de ese copiloto: modelos conceptual, lógico y
físico, más una prueba funcional de almacenamiento, integridad, recuperación
autorizada y trazabilidad.

El alcance se limita a la capa de datos. No incluye frontend, backend, API ni
integración con un modelo de lenguaje. La IA funciona como contexto del
problema.

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

Se usa **PostgreSQL** con **`pgvector`** (búsqueda por similitud) y
**`btree_gist`** (exclusión de solapamientos temporales). Una sola instancia
concentra datos operativos, metadatos documentales, embeddings, permisos,
interacciones y auditoría.

Los archivos quedan fuera de la base y se vinculan por ruta relativa, tipo MIME,
tamaño y SHA-256.

## Estructura del repositorio

```text
├── README.md
├── compose.yaml                         # PostgreSQL 17 con pgvector (opcional)
├── docs/
│   ├── informe_latex/                  # Fuentes y PDF de revisión del informe
│   ├── specs/
│   │   └── capa-datos-rag-distribuidora/
│   │       └── PRD.md                 # Especificación del producto
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
│       ├── 04_consultas.sql           # Consultas funcionales 1 a 6
│       ├── 06_consultas_seguridad.sql # Consulta 7 y pruebas 8 y 9
│       └── 07_validaciones.sql        # Aserciones automáticas
├── vectorial/modelo_vectorial.md      # Modelo de datos vectorial
├── evidencias/
│   ├── planes_ejecucion.md            # Planes reales y su interpretación
│   └── seguridad/                     # Matriz de autorización y pruebas negativas
├── scripts/
│   ├── generar_datos.py               # Generador del conjunto sintético
│   ├── cargar_base.sh                 # Recorrido simple de la muestra
│   ├── cargar_base_docker.sh          # Mismo recorrido mediante Docker Compose
│   └── validar_base.sh                # Validación exhaustiva en dos cargas
```

Los archivos SQL están numerados por orden de ejecución: `01` y `02` crean y
cargan la base; `03` agrega estructuras de acceso; `04` consulta; `05` aplica la
seguridad; `06` la prueba; y `07` contiene las validaciones completas.

## Instrucciones para ejecutar la implementación mínima

### Opción con Docker Compose

Este camino requiere Docker con Compose y Python 3, pero no necesita una
instalación local de PostgreSQL, `psql` ni pgvector:

```bash
scripts/cargar_base_docker.sh
```

El script inicia un único servicio PostgreSQL 17 con pgvector, regenera los
datos, recrea `rag_distribuidora` y ejecuta los nueve casos. El primer argumento
permite usar otro nombre de base. Para detener el servicio sin borrar sus datos:

```bash
docker compose down
```

El puerto se publica sólo en `127.0.0.1:5432`. Si ese puerto está ocupado, se
puede elegir otro antes de ejecutar el script, por ejemplo:

```bash
RAG_POSTGRES_PORT=55432 scripts/cargar_base_docker.sh
```

> La base indicada **se elimina y se vuelve a crear** dentro del volumen de
> Docker Compose. No usar el nombre de una base con datos que interesen.

### Opción con PostgreSQL local

### Requisitos previos

- PostgreSQL 15 o superior, [`pgvector`](https://github.com/pgvector/pgvector) y
  `psql` en el `PATH`.
- Python 3. El generador usa sólo la biblioteca estándar, sin dependencias ni
  entorno virtual.

La implementación se desarrolló y verificó sobre PostgreSQL 17.11 con pgvector
0.8.6.

### Ejecución completa

```bash
scripts/cargar_base.sh
```

El script regenera los datos, recrea `rag_distribuidora`, aplica el esquema,
carga los datos, agrega índices y seguridad, y ejecuta los nueve casos. El
primer argumento permite usar otro nombre de base.

> La base indicada **se elimina y se vuelve a crear**. No apuntar a una base con
> datos que interesen.

### Validación exhaustiva

```bash
scripts/validar_base.sh rag_distribuidora_validacion
```

Este comando comprueba restricciones, permisos, ciclo documental, auditoría,
conteos, checksums y oráculos vectoriales. Recrea la base dos veces y compara
instantáneas ordenadas. Sólo acepta nombres terminados en `_validacion`.

### Paso a paso

```bash
python3 scripts/generar_datos.py          # documentos, manifiesto y 02_seed.sql
createdb rag_distribuidora
psql -d rag_distribuidora -f db/estructura/01_schema.sql
psql -d rag_distribuidora -f db/datos/02_seed.sql
psql -d rag_distribuidora -f db/indices_vistas/03_indices.sql
psql -d rag_distribuidora -f db/indices_vistas/05_seguridad.sql
```

Las consultas 6 y 7 reciben un vector como parámetro. El script lo toma de
`oraculos_vectoriales` en `data/ejemplos/manifiesto.json`.

### Reproducibilidad

El generador usa la semilla `42` y el instante
`2026-06-30T15:00:00Z`. `02_seed.sql` vacía las tablas antes de insertar.
`validar_base.sh` compara los conteos, el contenido y los checksums de dos
cargas limpias.

## Principales decisiones de diseño

- **Un único motor** para datos operativos, documentales y vectoriales. Así la
  similitud y los filtros relacionales se resuelven en una consulta, sin
  sincronizar dos sistemas.
- **Sólo se vectorizan los fragmentos documentales.** Los hechos operativos se consultan como datos estructurados.
- **La autorización y la vigencia se aplican antes del ranking.** Un resultado
  prohibido nunca ocupa un lugar en el top-k.
- **Permisos por perfil y clase documental**, con denegación por defecto. El
  control de acceso no depende del texto consultado.
- **Los perfiles funcionales se guardan como datos.** Los roles de PostgreSQL
  separan ingesta, gestión documental, consulta y auditoría. En cada transacción,
  `rag_runtime` fija la identidad del actor. Así una conexión compartida puede
  representar distintos actores sin mezclar sus permisos.
- **El aislamiento se apoya en RLS (seguridad a nivel de fila).** Las políticas
  protegen las tablas incluso ante una consulta directa. La vista usa
  `security_invoker` para respetar esos permisos.
- **Historial completo.** Las versiones sustituidas o revocadas dejan de
  recuperarse, pero se conservan para explicar respuestas anteriores.
- **Evidencia obligatoria.** Cada respuesta exitosa guarda su fuente exacta. Un
  resultado negativo declara la causa y no inventa evidencia.
- **Auditoría append-only para los roles operativos.** Registra la actividad sin
  copiar contenido sensible. El propietario conserva las tareas administrativas
  necesarias para recrear la muestra.
- **Uso acotado de JSONB.** Se reserva para datos de forma variable. Todo lo que
  se filtra, relaciona o autoriza permanece tipado y normalizado.
- **Datos sintéticos reproducibles**, generados con semilla fija y sin dependencias externas.

## Casos verificables incluidos

El conjunto contiene siete consultas funcionales y dos pruebas de seguridad y
auditoría. Cada caso declara su propósito, parámetros y resultado esperado. Los
resultados usan códigos de negocio para mantenerse estables entre cargas.

| # | Caso | Patrón que demuestra |
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

C1 a C6 están en `db/consultas/04_consultas.sql`. C7 a C9 están en
`db/consultas/06_consultas_seguridad.sql` y se ejecutan con `rag_runtime`, un rol
sin propiedad ni `BYPASSRLS`.

El caso C7 muestra el control de acceso. Con el mismo vector y corpus,
Comercial/Compras recibe primero la política buscada. Operaciones/Logística no
recibe **ningún** fragmento de esa clase: la autorización lo excluye antes de
calcular el top-5. Las salidas están en
[`evidencias/seguridad/matriz_autorizacion.md`](evidencias/seguridad/matriz_autorizacion.md).

## Limitaciones y posibles mejoras

La prueba valida el diseño, pero no representa un sistema en producción:

- **Los embeddings son sintéticos.** Son vectores de 32 dimensiones construidos
  con centroides y ruido determinista, no la salida de un modelo real. Permiten
  probar almacenamiento, índice, métrica y permisos, pero no la calidad
  semántica.
- **La escala es mínima.** Ninguna tabla supera las 56 filas, así que el
  planificador usa `Seq Scan` aunque existan índices. Los tiempos no se pueden
  extrapolar: ver
  [`evidencias/planes_ejecucion.md`](evidencias/planes_ejecucion.md).
- **No hay autenticación.** Los actores no guardan credenciales y los roles se
  crean `NOLOGIN`; las pruebas usan `SET ROLE`. La autenticación y la propagación
  de identidad quedan fuera del alcance.
- **No hay integración con un modelo de lenguaje.** El copiloto es el contexto
  del problema; sólo se diseña su capa de datos.
- **La arquitectura es un núcleo único.** Separación del almacenamiento de
  archivos, réplicas y particionamiento se analizan, pero no se implementan.

Los próximos pasos serían reemplazar los vectores sintéticos, revisar HNSW,
mover los archivos a almacenamiento de objetos y particionar
`evento_auditoria`, la tabla con el crecimiento continuo más claro.

## Documentación

- [Borrador del informe técnico en LaTeX](docs/informe_latex/README.md)
- [Especificación del producto](docs/specs/capa-datos-rag-distribuidora/PRD.md)
- Diagramas: [conceptual](docs/modelo_conceptual.png), [lógico](docs/modelo_logico_o_equivalente.png), [físico](docs/modelo_fisico_o_equivalente.png) y [arquitectura](docs/arquitectura.png); [fuentes Mermaid](docs/diagramas/)
- [Matriz de cobertura](docs/matriz_cobertura.md)
- [Modelo de datos vectorial](vectorial/modelo_vectorial.md)
