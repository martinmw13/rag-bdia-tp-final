# Especificación de implementación: seguridad, recuperación y trazabilidad

## Propósito

Definir el contrato técnico que impide recuperar información no vigente o no autorizada y que conserva la evidencia exacta de cada interacción.

## Áreas y archivos a investigar

- `db/estructura/`, para identidades, permisos, interacción y auditoría.
- `db/indices_vistas/`, para políticas RLS, privilegios y vista de recuperación.
- `db/consultas/`, para búsquedas vectoriales e híbridas y consultas de trazabilidad.
- `evidencias/seguridad/`, para la matriz de autorización y pruebas negativas.
- Material de las prácticas de seguridad y pgvector vistas en clase, como referencia de mínimo privilegio, RLS y filtrado híbrido.

## Identidades funcionales y roles técnicos

Los perfiles funcionales son Operaciones/Logística, Comercial/Compras y Administración/Calidad. Cada actor tiene un único perfil y no se admiten excepciones ni delegaciones individuales.

La implementación debe separar al menos estas responsabilidades técnicas:

- propietario del esquema, usado sólo para administración y nunca para probar acceso de aplicación;
- servicio de ingesta, habilitado para cargar borradores y datos de la muestra;
- responsable documental, habilitado para publicar, sustituir y revocar;
- runtime de consulta, no propietario, no superusuario y sin `BYPASSRLS`;
- revisor de auditoría, de sólo lectura, reservado a Administración/Calidad para la prueba.

Los perfiles funcionales no deben convertirse directamente en propietarios de tablas. La autenticación y las credenciales quedan fuera de alcance.

## Contexto efectivo

- Cada transacción de consulta debe fijar actor y perfil mediante contexto local a la transacción.
- El perfil efectivo debe coincidir con el único perfil activo del actor.
- Un contexto ausente, incompleto, inactivo o inconsistente debe producir denegación por defecto.
- El contexto no debe persistir entre transacciones ni depender del texto de la pregunta.

## Matriz de autorización

| Clase | Operaciones/Logística | Comercial/Compras | Administración/Calidad |
| --- | :---: | :---: | :---: |
| Ficha de producto | Sí | Sí | Sí |
| Procedimiento logístico | Sí | No | Sí |
| Política comercial | No | Sí | No |
| Cumplimiento de proveedor | No | No | Sí |
| Documentación legal | No | No | Sí |

La matriz física se representa mediante permisos explícitos entre perfil y clase. La ausencia de fila implica denegación. El nivel de sensibilidad no reemplaza ni duplica esta relación.

## Vigencia documental

Una versión es recuperable únicamente cuando:

- el documento está activo;
- su estado es `publicada`;
- no está revocada;
- su intervalo de vigencia contiene el instante efectivo;
- el modelo de embedding está activo;
- la clase documental está permitida para el perfil efectivo.

La publicación de una nueva versión debe sustituir la anterior en una sola transacción. La recuperación histórica sólo ocurre al reconstruir evidencia ya utilizada, no en la búsqueda vigente normal.

## RLS, privilegios y vista segura

- Las tablas documentales deben aplicar políticas RLS basadas en perfil, clase y permiso normalizado.
- Las políticas deben contemplar tanto visibilidad como inserción/modificación mediante reglas equivalentes a `USING` y `WITH CHECK` donde corresponda.
- El runtime debe consultar el corpus por medio de una vista normal con semántica de invocador y privilegios mínimos.
- La vista debe reunir sólo filas recuperables y no debe ejecutar con autoridad del propietario.
- El runtime no puede actualizar hechos operativos, versiones publicadas ni permisos.
- El runtime puede registrar los eventos necesarios, pero no actualizar o eliminar auditoría.
- El revisor de auditoría puede leer eventos para los escenarios de Administración/Calidad y no puede modificarlos.

## Recuperación vectorial

- Métrica: distancia coseno mediante el operador compatible con `vector_cosine_ops`.
- Modelo: únicamente el modelo activo para búsquedas vigentes.
- Orden: distancia ascendente y clave estable del fragmento como desempate.
- Trazabilidad: cada resultado identifica embedding, fragmento, versión, documento y modelo.
- La búsqueda top-k no debe mezclar embeddings de modelos distintos.

## Recuperación híbrida autorizada

“Híbrida” significa similitud vectorial combinada con joins y filtros relacionales; no implica combinar ranking lexical y vectorial.

La autorización, actividad, publicación, vigencia y modelo activo deben aplicarse antes del ordenamiento y del límite top-k. Un resultado prohibido no puede ocupar un lugar y ser descartado después, ni provocar que se exponga contenido parcial.

## Evidencia y resultados

- Una evidencia documental referencia el embedding exacto recuperado y conserva ranking y score.
- Una evidencia estructurada referencia un snapshot inmutable de una consulta predefinida.
- Una respuesta `exito` requiere al menos una evidencia al finalizar la transacción.
- `sin_resultados`, `sin_fuente_autorizada` y `acceso_denegado` no deben asociar evidencia.
- Una misma evidencia no puede aparecer dos veces en una respuesta.
- El resultado estructurado no puede almacenar ni habilitar SQL arbitrario.

## Eventos de auditoría

Acciones mínimas:

- carga de borrador;
- publicación;
- sustitución;
- revocación;
- consulta iniciada;
- acceso denegado;
- fragmento recuperado;
- evidencia utilizada;
- respuesta generada.

Cada evento conserva actor, perfil efectivo, instante, acción, resultado, tipo e identificador de recurso y correlación con consulta o respuesta cuando corresponda. Ranking y score se registran sólo cuando son pertinentes. No deben copiarse el documento completo, el vector ni secretos.

## Casos de prueba obligatorios

- Las quince combinaciones entre tres perfiles y cinco clases.
- Contexto sin actor, sin perfil, con actor inactivo y con perfil que no corresponde al actor.
- Borrador, versión sustituida, revocada, vencida y futura invisibles en recuperación normal.
- Fuente existente pero no autorizada devuelve cero filas y el resultado negativo correcto.
- El fragmento temático esperado queda primero para el perfil autorizado y fuera del universo para el no autorizado.
- Intentos de `UPDATE` y `DELETE` sobre auditoría rechazados.
- Reconstrucción ordenada de consulta iniciada, fragmentos recuperados, evidencia utilizada y respuesta generada.
- Evento de acceso denegado correlacionado sin exposición de contenido.

## Criterios de aceptación

- El runtime no puede omitir RLS ni usar autoridad del propietario.
- Todas las combinaciones ausentes de la matriz devuelven cero filas.
- Ningún contenido no vigente o no autorizado participa en el top-k.
- Cada respuesta exitosa se reconstruye hasta la fuente exacta que utilizó.
- La auditoría es append-only para roles operativos y no duplica contenido sensible.
