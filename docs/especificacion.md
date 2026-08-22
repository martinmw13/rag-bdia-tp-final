# Especificación del producto: capa de datos para un RAG interno

## Resumen

El trabajo propone la capa de datos de un copiloto interno para una empresa distribuidora mayorista. El copiloto recuperará información documental y operativa para responder preguntas de personal autorizado, mostrando la evidencia utilizada y respetando la vigencia y los permisos de cada fuente.

El producto académico no es una aplicación completa. Su resultado será un diseño de datos coherente y una prueba funcional pequeña que demuestre almacenamiento, integridad, recuperación, autorización, trazabilidad y criterios de evolución.

## Problema

La información de una distribuidora se reparte entre catálogos, condiciones comerciales, pedidos, entregas, incidencias, fichas, procedimientos y documentación de proveedores o cumplimiento. Buscarla manualmente dificulta localizar la versión vigente, distinguir hechos operativos de conocimiento documental y explicar qué fuente fundamentó una respuesta.

Además, no toda la información puede exponerse a todos los perfiles. Una recuperación útil pero no autorizada, desactualizada o imposible de rastrear constituye una falla del sistema.

## Objetivos

- Organizar en un modelo coherente los datos operativos, documentales, vectoriales, de acceso y de auditoría.
- Permitir consultas estructuradas y recuperación semántica sobre fuentes vigentes y autorizadas.
- Conservar la evidencia exacta utilizada por cada respuesta.
- Demostrar las decisiones principales mediante datos sintéticos reproducibles y consultas verificables.
- Justificar una arquitectura simple y una evolución posible sin sobredimensionar la implementación académica.

## Usuarios y responsabilidades

### Operaciones/Logística

Consulta información interna general, fichas de producto, procedimientos logísticos e incidencias autorizadas. No accede a condiciones comerciales ni a documentación legal.

### Comercial/Compras

Consulta información interna general, fichas de producto, políticas y condiciones comerciales e información autorizada de proveedores. No accede a incidencias operativas ni a documentación legal reservada.

### Administración/Calidad

Consulta las clases documentales necesarias para control, calidad y cumplimiento. Un responsable documental perteneciente a este ámbito puede publicar, sustituir o revocar versiones.

### Servicios internos

La ingesta incorpora borradores y datos sintéticos; la consulta opera en modo de sólo lectura; la administración documental controla el ciclo de publicación. Estos servicios no representan usuarios finales ni amplían sus permisos.

## Historias de usuario

- Como integrante de Operaciones/Logística, quiero consultar el procedimiento vigente para una entrega demorada y ver la fuente utilizada.
- Como integrante de Comercial/Compras, quiero conocer la condición comercial aplicable a un cliente y producto en una fecha determinada.
- Como integrante de Administración/Calidad, quiero consultar documentación vigente de cumplimiento y reconstruir qué evidencia sostuvo una respuesta.
- Como responsable documental, quiero sustituir una versión de manera atómica para que la anterior deje de recuperarse sin perder el historial.
- Como responsable de seguridad, quiero que una fuente no autorizada quede fuera de la recuperación antes de calcular los resultados finales.
- Como docente o revisor, quiero reproducir la carga y las consultas para comprobar las decisiones de diseño.

## Requisitos imprescindibles

### Alcance funcional

- El copiloto debe admitir consultas sobre productos, condiciones comerciales, pedidos, entregas, incidencias, procedimientos y documentación de proveedores o cumplimiento.
- Cada respuesta exitosa debe conservar al menos una evidencia documental o estructurada identificable.
- Cuando no existan resultados, una fuente autorizada o acceso, el resultado debe declararlo de forma explícita y no presentar evidencia inexistente.
- La solución debe conservar el historial necesario para explicar respuestas anteriores aunque cambie la fuente vigente.

### Información y procedencia

- La prueba debe usar exclusivamente información sintética y reproducible, sin datos personales o comerciales reales ni dependencias de licencias externas.
- La información debe clasificarse como estructurada, semiestructurada, no estructurada, operacional, analítica, sensible o de auditoría, según corresponda.
- Sólo los fragmentos documentales deben vectorizarse. Los hechos operativos deben consultarse como datos estructurados.
- Los documentos deben conservar procedencia, versión, vigencia, sensibilidad e integridad verificable.

### Vigencia y autorización

- Sólo una versión publicada, no revocada y vigente puede recuperarse para un documento en un instante dado.
- Publicar una nueva versión debe sustituir a la anterior sin una ventana de inconsistencia.
- Los permisos deben definirse por perfil y clase documental, sin excepciones individuales y con denegación por defecto.
- La vigencia y la autorización deben limitar el universo de información antes de la recuperación vectorial o de la exposición de contenido.
- El control de acceso no puede depender del texto de la consulta ni de instrucciones dirigidas al modelo.

### Trazabilidad

- Deben registrarse de forma inmutable las acciones relevantes sobre documentos, consultas, accesos, recuperación y evidencia.
- Cada evento debe identificar actor, perfil efectivo, instante, acción, resultado, recurso y correlación cuando corresponda.
- La auditoría no debe duplicar el contenido sensible de los documentos.

### Prueba funcional

- Deben demostrarse los modelos conceptual, lógico y físico con sus relaciones, cardinalidades y restricciones.
- La implementación mínima debe incluir estructuras, datos de ejemplo, índices pertinentes, controles de acceso y consultas representativas.
- Deben existir al menos cinco consultas de negocio y recuperación; el conjunto acordado contiene nueve casos verificables, incluidos seguridad y auditoría.
- Los resultados deben repetirse después de dos cargas limpias equivalentes.

## Requisitos recomendados

- Los diagramas deben poder regenerarse desde fuentes textuales versionadas.
- Las evidencias deben permitir revisar conteos, restricciones rechazadas, resultados esperados, permisos y planes de ejecución sin repetir explicaciones del informe.
- La recuperación debe ordenar de manera estable los empates para que los resultados sean comparables.
- Las decisiones de rendimiento deben basarse en patrones de consulta y planes observados, no en optimizaciones anticipadas.

## Requisitos opcionales

- Analizar una futura separación del almacenamiento de archivos y del proceso de ingesta.
- Analizar réplicas de lectura y particionamiento temporal para tablas de crecimiento continuo.
- Considerar métricas operativas adicionales si no amplían el conjunto de datos ni convierten la prueba en un benchmark.

## Reglas de negocio

- Un actor pertenece a un único perfil autorizado y cada consulta conserva el perfil efectivo utilizado.
- La ausencia de permiso entre perfil y clase documental implica acceso denegado.
- Los estados documentales son borrador, publicada, sustituida y revocada.
- Las versiones sustituidas o revocadas se conservan, pero no son recuperables.
- Un pedido pertenece a un cliente y contiene al menos una línea; un producto no puede repetirse dentro del mismo pedido.
- Una entrega pertenece a un pedido; un pedido puede carecer de entregas o tener entregas parciales.
- Una incidencia pertenece a una entrega.
- Las condiciones comerciales conservan historia y no se superponen para el mismo cliente y producto.
- La línea de pedido conserva el precio y descuento aplicados, aun si luego cambia la condición comercial.
- Una respuesta exitosa requiere evidencia; los resultados negativos explícitos no la requieren.
- Una misma evidencia no puede repetirse dentro de una respuesta.

## Riesgos y mitigaciones

| Riesgo | Mitigación exigida |
| --- | --- |
| Recuperar información no autorizada | Filtrar por perfil y clase antes del ranking y probar todas las combinaciones de permisos. |
| Usar contenido obsoleto o revocado | Aplicar estado y vigencia antes de recuperar y conservar el historial separado. |
| Presentar una respuesta sin fundamento | Asociar cada éxito con evidencia exacta y reservar resultados sin evidencia para casos negativos explícitos. |
| Perder reproducibilidad | Fijar reglas, semilla, instante de referencia, conteos y checksums. |
| Confundir una demostración pequeña con rendimiento productivo | Interpretar los planes sobre su escala real y no extrapolar tiempos. |
| Sobredimensionar la arquitectura | Implementar un núcleo único y dejar componentes distribuidos como evolución justificada. |
| Duplicar decisiones entre entregables | Asignar una fuente de autoridad a especificación, informe, diagramas, implementación, evidencias y README. |

## Métricas de éxito

- El 100 % de los escenarios de carga y validación produce los conteos y checksums esperados.
- Las siete consultas representativas devuelven códigos, valores, conteos y orden deterministas.
- Las quince combinaciones entre perfiles y clases documentales respetan la matriz acordada.
- Ninguna búsqueda devuelve contenido fuera del universo autorizado o vigente.
- Toda respuesta exitosa puede reconstruirse hasta su fuente; todo resultado negativo usa el tipo esperado y carece de evidencia ficticia.
- Los intentos previstos de violar integridad, modificar auditoría o acceder sin permiso son rechazados.
- Los planes de ejecución relevantes quedan registrados e interpretados sin exigir un tipo de acceso artificial.
- La documentación cubre todos los puntos obligatorios de la consigna y permite reproducir la prueba funcional.

## Fuera de alcance

- Frontend, interfaz gráfica, backend o API de producción.
- Integración efectiva con un LLM o generación automática de respuestas.
- Entrenamiento de modelos de machine learning o embeddings de calidad real.
- Acciones automáticas sobre inventario, pedidos, precios o decisiones de negocio.
- Autenticación, almacenamiento de credenciales o contratos completos.
- Datos personales o comerciales reales.
- Despliegue de particionamiento, réplicas, almacenamiento de objetos o infraestructura distribuida.
- Benchmark de rendimiento o simulación de volumen productivo.

## Criterios de aceptación del producto

El producto se considera especificado cuando sus contratos funcionales y técnicos no presentan contradicciones, y se considera implementado cuando una ejecución limpia demuestra integridad, reproducibilidad, recuperación autorizada, evidencia histórica, auditoría inmutable y las consultas representativas acordadas. El informe deberá justificar estas decisiones y la evidencia del repositorio deberá demostrarlas.
