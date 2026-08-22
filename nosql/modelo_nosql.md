# Análisis de alternativas NoSQL

> **Estado: pendiente.** Este documento es responsabilidad del track de tecnología y arquitectura.

La consigna exige analizar qué tecnologías aplican al caso y cuáles no, justificando la decisión. Como la solución se implementa sobre PostgreSQL, este documento debe explicar por qué **no** se adoptó un motor NoSQL como núcleo, sin evitar el modelado.

Debe cubrir:

- **Base documental** (colecciones, documentos embebidos vs. referencias, índices): qué resolvería bien del corpus documental y qué perdería en integridad referencial y vigencia.
- **Base clave-valor**: aplicabilidad como caché de recuperación, no como almacenamiento primario.
- **Base columnar**: aplicabilidad al crecimiento continuo de auditoría e interacción.
- **Base de grafos**: relaciones entre documentos, versiones y entidades del dominio.
- **Base vectorial dedicada** (Pinecone, Qdrant, Milvus, Chroma): comparación con `pgvector` — ver `vectorial/modelo_vectorial.md`.

Criterios de comparación que pide la consigna: tipo y variabilidad de los datos, volumen esperado, patrones de consulta, relaciones entre entidades, consistencia requerida, seguridad y control de acceso, escalabilidad, complejidad operativa, y ventajas y limitaciones frente a otras alternativas.
