# Especificación de implementación: consultas, validación y entregables

## Propósito

Definir qué debe comprobar la prueba funcional y cómo se reparte la autoridad entre documentación, implementación y evidencias.

## Áreas y archivos a investigar

- `db/consultas/`, para consultas ejecutables y sus parámetros.
- `db/indices_vistas/`, para las estructuras justificadas por consultas reales.
- `evidencias/`, para resultados esperados, seguridad y planes.
- `docs/diagramas/`, para fuentes Mermaid y sus renders.
- `docs/informe_latex/`, para la narrativa académica.
- `docs/matriz_cobertura.md`, para vincular la consigna con artefactos y evidencia.
- `README.md`, para la entrada y reproducción de la entrega.

## Conjunto de casos verificables

### 1. Condición comercial vigente

Para cliente, producto e instante de referencia, devuelve como máximo una condición. Debe incluir la fila prevista y excluir períodos vencidos o futuros.

### 2. Pedidos y entregas que requieren atención

Relaciona pedido, cliente, entrega e incidencia. Incluye entregas parciales o demoradas de pedidos no cancelados, conserva la incidencia cuando existe y excluye el pedido cancelado.

### 3. Importe neto por categoría

Agrupa el importe `cantidad × precio_unitario × (1 − descuento_porcentaje / 100)` y excluye pedidos cancelados. Debe producir categorías, conteos y totales exactos.

### 4. Productos principales por segmento

Acumula importe neto por segmento y producto y usa `DENSE_RANK` dentro de cada segmento. El rango depende sólo del importe; el código del producto estabiliza la presentación en empates.

### 5. Clientes sin pedidos históricos

Localiza clientes que nunca tuvieron pedidos. Debe devolver exactamente el escenario reservado; un pedido cancelado cuenta como antecedente histórico.

### 6. Búsqueda vectorial top-k

Usa vector de consulta sintético, modelo activo y distancia coseno. El fragmento temático esperado debe ocupar la primera posición; ranking, distancia y trazabilidad deben ser estables.

### 7. Búsqueda híbrida autorizada

Combina similitud con filtros relacionales de actividad, publicación, vigencia, modelo y permiso. Mantiene primero el fragmento esperado para el perfil autorizado y devuelve cero filas fuera de su universo permitido.

### 8. Matriz de autorización

Comprueba las quince combinaciones perfil-clase con un rol runtime no propietario y sin bypass. La visibilidad esperada es de dos clases para Operaciones/Logística, dos para Comercial/Compras y cuatro para Administración/Calidad.

### 9. Trazabilidad e inmutabilidad

Reconstruye el flujo exitoso en orden y un acceso denegado correlacionado. Los intentos de actualizar o eliminar eventos deben ser rechazados.

## Contrato común de las consultas

Cada consulta debe incluir:

- identificador y propósito;
- pregunta del dominio que responde;
- parámetros y sus valores de prueba;
- sentencia ejecutable;
- resultado esperado expresado con códigos de negocio;
- conteos, valores y orden exactos cuando correspondan;
- explicación breve de su utilidad y del patrón SQL que demuestra.

Las siete primeras consultas generan exactamente siete pares `consulta`–`respuesta`. Los casos de autorización y auditoría reutilizan esas interacciones como pruebas transversales.

## Cobertura SQL mínima

El conjunto debe demostrar:

- selección y filtrado;
- relaciones mediante `JOIN`;
- agregación y `GROUP BY`;
- subconsulta o `NOT EXISTS`;
- función de ventana;
- recuperación vectorial;
- combinación de similitud y filtros relacionales;
- consulta de auditoría y correlación histórica.

## Evidencia de rendimiento

- Aplicar `EXPLAIN (ANALYZE, BUFFERS)` a las consultas críticas.
- Conservar planes antes y después del índice HNSW para la búsqueda vectorial.
- Registrar nodo de acceso, filas estimadas y reales, costos, tiempos y buffers.
- Relacionar índices B-tree con joins y filtros efectivamente usados.
- Aceptar e interpretar `Seq Scan` sobre la muestra pequeña.
- No inflar los datos, forzar el optimizador ni extrapolar tiempos a producción.

## Validación de integridad

Debe existir una validación automatizable que compruebe:

- conteos del manifiesto;
- ausencia de huérfanos;
- unicidades y cardinalidades materializadas;
- dimensión y normalización vectorial;
- vigencias no superpuestas;
- una única versión recuperable por documento;
- respuestas exitosas con evidencia y negativas sin evidencia;
- checksums de los archivos.

Las operaciones inválidas deben ejecutarse de forma aislada y reversible para demostrar su rechazo sin dejar residuos.

## Autoridad de los entregables

| Artefacto | Autoridad |
| --- | --- |
| PRD y specs | Problema, alcance, requisitos, contratos y aceptación. |
| Informe LaTeX | Narrativa académica, justificación, interpretación y conclusiones. |
| Mermaid | Fuente canónica de diagramas conceptual, lógico, físico y de arquitectura. |
| SQL, datos y controles | Comportamiento efectivamente implementado. |
| Evidencias | Resultados reproducibles, checksums, autorizaciones y planes. |
| README | Orientación, estructura y pasos de reproducción mediante enlaces. |
| Plan de implementación | Secuencia de construcción y verificación, sin reemplazar documentación final. |
| Matriz de cobertura | Índice liviano entre consigna, informe, implementación y evidencia. |

## Cobertura académica requerida

La documentación final debe cubrir:

- caso de uso, usuarios, riesgos y relevamiento de datos;
- clasificación estructurada, semiestructurada, no estructurada, operacional, analítica, sensible y auditable;
- modelos conceptual, lógico y físico;
- normalización, uso acotado de JSONB y vínculos a archivos;
- selección y justificación de PostgreSQL y pgvector frente a alternativas;
- datos sintéticos, implementación mínima y consultas representativas;
- búsqueda vectorial y recuperación autorizada;
- arquitectura general y recorrido de los datos;
- roles, permisos, aislamiento y auditoría;
- rendimiento, escalabilidad y conclusiones.

## Límites de documentación

- El informe explica e interpreta; no copia scripts ni salidas extensas.
- El README orienta; no repite la especificación ni el informe.
- La matriz de cobertura enlaza; no crea una segunda narrativa.
- Los diagramas renderizados derivan de sus fuentes Mermaid.
- No deben aparecer rutas locales, herramientas internas, atribuciones de asistentes ni datos reales.

## Casos límite de revisión

- Una consulta funcionalmente correcta pero sin oráculo estable no cumple el contrato.
- Un índice existente pero no vinculado a un patrón de consulta no cuenta como justificación.
- Un plan con `Seq Scan` no constituye por sí solo una falla.
- Una respuesta histórica debe seguir siendo explicable después de sustituir el documento vigente.
- Un artefacto que contradiga la spec debe resolverse en su fuente de autoridad, no mediante texto duplicado.

## Criterios de aceptación

- Los nueve casos producen los resultados y rechazos esperados tras dos cargas limpias.
- Cada requisito obligatorio de la consigna apunta a una sección del informe, un artefacto y una evidencia cuando corresponde.
- Todos los entregables usan terminología canónica en español y resultan navegables desde el README.
- La prueba funcional se reproduce sin frontend, API, LLM ni infraestructura avanzada.
