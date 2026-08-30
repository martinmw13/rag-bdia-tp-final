# Simplificación de los diagramas del informe

Estado: en diseño.

## Objetivo

Reorganizar los diagramas para que cada figura explique una parte concreta del
diseño y pueda leerse dentro del informe sin ampliarla. Se conservará la
cobertura exigida para los modelos conceptual, lógico y físico, pero se evitará
repetir el esquema completo en varias imágenes.

## Organización propuesta

- Un mapa conceptual general y tres vistas: operación; documentos y
  recuperación; acceso, interacción y evidencia.
- Tres vistas del modelo lógico con claves, relaciones y atributos relevantes.
- Vistas físicas separadas, acompañadas por una tabla de tipos, restricciones,
  índices y estructuras de acceso propias de PostgreSQL.
- Un diagrama de arquitectura concentrado en el recorrido de los datos.

El esquema SQL seguirá siendo la descripción exhaustiva de la implementación.
Los diagramas físicos mostrarán las decisiones que necesitan explicación, sin
reproducir en una sola lámina todas las columnas del esquema.

## Correcciones que acompañan el rediseño

- Alinear las cardinalidades documentales con el ciclo de carga de borradores.
- Representar la unicidad conjunta del nombre y la versión del modelo de
  embedding.
- Mostrar que la auditoría se genera mediante funciones y triggers controlados.
- Incluir las condiciones comerciales y las incidencias entre los datos
  protegidos por RLS.
- Mostrar los tres resultados del generador: datos SQL, documentos y
  manifiesto.
- Reservar el estado de borrador para la versión documental.

## Decisión pendiente

Definir si `fecha_efectiva` debe ser nula para todos los estados de una entrega
excepto `entregada`. Si se adopta esa regla, habrá que ajustar el esquema y sus
pruebas además de los diagramas.
