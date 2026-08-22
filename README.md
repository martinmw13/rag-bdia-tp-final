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

No es una aplicación: no incluye frontend, backend, API ni integración efectiva con un modelo de lenguaje. La aplicación de IA funciona como contexto del problema.

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
│   ├── especificacion.md          # Especificación del producto
│   ├── specs/                     # Especificaciones de implementación
│   └── diagramas/                 # Fuentes Mermaid y diagramas renderizados
├── data/
│   └── ejemplos/                  # Datos sintéticos y documentos generados
├── db/
│   ├── estructura/                # DDL: tablas, claves y restricciones
│   ├── datos/                     # Carga de datos de ejemplo
│   ├── indices_vistas/            # Índices, vistas y controles de acceso
│   └── consultas/                 # Consultas representativas
├── nosql/
│   └── modelo_nosql.md            # Análisis de alternativas NoSQL
├── vectorial/
│   └── modelo_vectorial.md        # Modelo de datos vectorial
├── evidencias/                    # Resultados reproducibles y planes de ejecución
├── scripts/                       # Generación de datos sintéticos
└── anexos/
    └── material_complementario.md
```

## Instrucciones para ejecutar la implementación mínima

> **Pendiente.** Se completa cuando exista la implementación.

## Principales decisiones de diseño

- **Un único motor** para datos operativos, documentales y vectoriales, evitando sincronizar dos sistemas y permitiendo resolver la similitud y los filtros relacionales en una sola consulta.
- **Sólo se vectorizan los fragmentos documentales.** Los hechos operativos se consultan como datos estructurados.
- **La autorización y la vigencia limitan el universo antes del ranking**, no después: un resultado prohibido nunca ocupa un lugar en el top-k.
- **Permisos por perfil y clase documental**, con denegación por defecto y sin excepciones individuales. El control de acceso no depende del texto de la consulta.
- **Historial completo**: las versiones sustituidas o revocadas se conservan pero dejan de recuperarse, de modo que una respuesta anterior siga siendo explicable.
- **Evidencia obligatoria**: toda respuesta exitosa conserva la fuente exacta que utilizó; los resultados negativos se declaran explícitamente y no inventan evidencia.
- **Auditoría append-only**, que registra la actividad sin duplicar contenido sensible.
- **Uso acotado de JSONB**, limitado a metadatos y detalles variables; todo lo que se filtra, relaciona o autoriza permanece tipado y normalizado.
- **Datos sintéticos reproducibles**, generados con semilla fija y sin dependencias externas.

## Consultas incluidas

> **Pendiente.** Se completa cuando existan las consultas.

## Limitaciones y posibles mejoras

> **Pendiente.** Se completa al cierre del trabajo.

## Documentación

- [Especificación del producto](docs/especificacion.md)
- [Especificaciones de implementación](docs/specs/capa-datos-rag-distribuidora/)
