# Modelo de datos vectorial

> **Estado: pendiente.** Este documento es responsabilidad del track de tecnología y arquitectura.

La consigna exige presentar el modelo vectorial indicando qué se vectoriza, qué metadatos se almacenan junto a cada vector, cómo se vinculan los vectores con los datos originales, qué consultas por similitud se esperan resolver y qué restricciones de acceso aplican sobre esos datos.

Debe cubrir:

- **Qué se vectoriza**: únicamente los fragmentos documentales. Los hechos operativos (productos, pedidos, entregas) se consultan como datos estructurados.
- **Estructura del elemento vectorizado**: texto que compone el vector y su relación con el contenido almacenado.
- **Metadatos asociados**: versión, documento, clase documental, sensibilidad, modelo de embedding, posición del fragmento.
- **Vínculo con el dato original**: fragmento → versión → documento → archivo en `data/ejemplos/`.
- **Consultas por similitud esperadas**: búsqueda top-k y búsqueda híbrida (similitud combinada con filtros relacionales de vigencia y autorización).
- **Criterios de filtrado y control de acceso**: la autorización y la vigencia se aplican **antes** del ranking, nunca como post-filtro.
- **Configuración**: dimensión, métrica de distancia (coseno) y tipo de índice vectorial (HNSW).
- **Justificación de `pgvector` frente a una base vectorial dedicada** — ver `nosql/modelo_nosql.md`.
- **Riesgos** si se recupera información incorrecta, desactualizada o no autorizada.
