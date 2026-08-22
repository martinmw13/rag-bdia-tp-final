# Especificación de implementación: conjunto sintético reproducible

## Propósito

Fijar el contrato de procedencia, volumen y reproducibilidad de los datos usados para demostrar el diseño. El conjunto no representa producción ni constituye un benchmark.

## Áreas y archivos a investigar

- `data/ejemplos/`, destino de datos generados, documentos y manifiesto.
- `db/datos/`, destino de la carga reproducible.
- `evidencias/`, destino de checksums, conteos y validaciones reproducibles.
- `practica/scripts/`, referencia para generación y carga, sin reutilizar datos reales, modelos externos ni vectores de 384 dimensiones.

## Contrato de generación

- Generador basado únicamente en Python estándar.
- Semilla global fija: `42`.
- Instante de referencia: `2026-06-30T15:00:00Z`.
- Identificadores, códigos de negocio y orden de salida estables.
- Ningún valor depende de la hora de ejecución, el orden del filesystem o el estado previo de la base.
- Una carga limpia debe ser idempotente y producir los mismos artefactos.
- Los nombres, organizaciones y contenidos deben ser ficticios y construidos con vocabulario del dominio, sin Faker ni fuentes externas.

## Manifiesto canónico

El manifiesto JSON debe registrar:

- versión del generador;
- semilla global;
- instante de referencia;
- conteos esperados por tipo de registro;
- inventario de archivos generados;
- checksums de los artefactos;
- identificador de los siete escenarios de consulta que producen interacción y evidencia.

## Conteos exactos

| Grupo | Conteos |
| --- | --- |
| Catálogos | 4 categorías, 3 segmentos, 3 perfiles, 5 clases documentales, 3 sensibilidades, 2 modelos de embedding. |
| Operación | 12 productos, 6 clientes, 4 proveedores, 18 asociaciones producto-proveedor, 12 condiciones comerciales. |
| Actividad | 12 pedidos, 28 líneas, 14 entregas, 4 incidencias. |
| Documentación | 10 documentos, 14 versiones, 32 fragmentos. |
| Vectores | 32 embeddings del modelo activo y 4 embeddings históricos. |
| Acceso | 6 actores, dos por perfil, y 8 permisos documentales. |
| Interacción | 7 consultas y 7 respuestas; evidencias y eventos derivados de esos escenarios. |

Los casos de autorización y auditoría son pruebas transversales y no agregan dos pares adicionales de consulta/respuesta.

## Rangos y distribuciones

- Cantidades enteras entre 1 y 50.
- Precios en ARS entre 1.000 y 250.000.
- Descuentos pertenecientes a `0`, `5`, `10`, `15` o `20` por ciento.
- Fechas operativas dentro de los doce meses anteriores al instante de referencia.
- Estados y relaciones definidos primero por escenarios; la semilla sólo varía valores dentro de rangos controlados.

## Escenarios obligatorios

- Un producto inactivo y un actor inactivo.
- Un cliente sin pedidos históricos.
- Un pedido cancelado sin entrega.
- Un pedido con entregas parciales.
- Una entrega demorada con incidencia.
- Condiciones comerciales vencida, vigente y futura.
- Documentos vigentes, sustituidos, revocados y en borrador.
- Accesos permitidos y denegados para los tres perfiles.
- Respuestas exitosas con evidencia y resultados negativos explícitos sin evidencia.

## Documentos y fragmentación

- Deben generarse 14 archivos Markdown, uno por versión documental.
- Cada encabezado de segundo nivel y su cuerpo forman un fragmento.
- Cada versión contiene entre dos y cuatro secciones hasta completar 32 fragmentos.
- El texto usado para construir el vector combina título, encabezado y contenido.
- `fragmento.contenido` conserva sólo el cuerpo propio de la sección.
- Cada versión registra ruta relativa, nombre, MIME type, tamaño y SHA-256 del archivo.

## Embeddings sintéticos

- Dos versiones ficticias del mismo modelo, ambas con dimensión 32 y métrica coseno.
- Un vector normalizado del modelo activo por cada fragmento.
- Cuatro fragmentos conservan además un vector histórico.
- Los vecindarios temáticos se forman mediante centroides y ruido determinista.
- Las consultas usan vectores construidos con la versión activa.
- La generación debe permitir conocer de antemano el fragmento temático esperado para cada caso vectorial.

## Matriz de permisos de la muestra

| Perfil | Clases permitidas |
| --- | --- |
| Operaciones/Logística | Ficha de producto; procedimiento logístico. |
| Comercial/Compras | Ficha de producto; política comercial. |
| Administración/Calidad | Ficha de producto; procedimiento logístico; cumplimiento de proveedor; documentación legal. |

Toda combinación ausente se considera denegada y debe participar en los casos negativos previstos.

## Validaciones mínimas

- Conteos exactos y ausencia de registros huérfanos.
- Dimensión 32 y normalización de los vectores dentro de una tolerancia documentada.
- Checksum, tamaño y existencia de cada archivo.
- Rechazo aislado y reversible de código duplicado, FK inexistente, descuento fuera de rango, condición comercial superpuesta y versión vigente superpuesta.
- Coincidencia de resultados tras dos generaciones y cargas limpias.
- Oráculos expresados mediante códigos de negocio, no claves internas.

## Casos límite

- El modelo histórico no cubre todos los fragmentos y nunca participa en búsquedas vigentes.
- Un cambio de orden de lectura del filesystem no altera el resultado.
- Una ejecución sobre una base con residuos no se acepta como carga limpia.
- Un checksum distinto invalida la versión aun si el nombre del archivo coincide.
- La pequeña cardinalidad puede producir `Seq Scan`; esto no invalida el conjunto.

## Criterios de aceptación

- El manifiesto describe de manera suficiente la procedencia y permite verificar cada artefacto.
- Dos ejecuciones limpias generan los mismos códigos, conteos, archivos y checksums.
- Todos los escenarios positivos y negativos requeridos están presentes sin usar datos reales.
- Los vectores forman los vecindarios previstos y mantienen trazabilidad completa.
- No se genera volumen adicional para forzar planes o tiempos de rendimiento.
