# Notas del modelo físico

Complementa [`fisico.mmd`](fisico.mmd) con las reglas que la sintaxis de
`erDiagram` de Mermaid no puede expresar: restricciones `CHECK`, exclusiones
temporales, disparadores, políticas RLS e índices. El propio SQL en
`db/estructura/` y `db/indices_vistas/` es la fuente de autoridad; esto es un
resumen de navegación, no una segunda especificación.

## Restricciones de exclusión temporal (requieren `btree_gist`)

| Tabla | Regla |
| --- | --- |
| `condicion_comercial` | No puede haber dos condiciones con rango de vigencia solapado para el mismo par `(cliente_id, producto_id)`. Intervalo semiabierto `[vigente_desde, vigente_hasta)`. |
| `version_documental` | No puede haber dos versiones **publicadas** con vigencia solapada para el mismo `documento_id`. La exclusión es parcial (`WHERE estado = 'publicada'`): el historial (`sustituida`, `revocada`, `borrador`) queda fuera y puede solaparse sin bloquear la sustitución. |

## Restricciones `CHECK` no triviales

- `version_documental`: un `borrador` no tiene `vigente_desde` ni `publicada_en`; una versión no borrador sí los tiene (`version_documental_borrador_ck`, `version_documental_publicada_ck`). El estado `revocada` exige `revocada_en` y viceversa (`version_documental_revocada_ck`).
- `entrega`: `fecha_efectiva` es obligatoria si y solo si `estado = 'entregada'`.
- Rangos y dominios: `descuento_porcentaje` entre 0 y 100; importes `>= 0`; `sha256` valida contra `^[0-9a-f]{64}$`; `hash` en `resultado_estructurado` con el mismo patrón; textos obligatorios rechazan cadena vacía (`btrim(x) <> ''`).
- Enumeraciones cerradas expresadas con `CHECK ... IN (...)`, no con catálogos adicionales: `pedido.estado`, `entrega.estado`, `incidencia_operativa.tipo/estado`, `version_documental.estado`, `respuesta.tipo_resultado`, `evento_auditoria.accion/resultado`, `modelo_embedding.metrica`.

## Claves foráneas compuestas

- `actor` declara `UNIQUE (id, perfil_autorizado_id)` únicamente para habilitar la FK compuesta de `consulta (actor_id, perfil_efectivo_id) → actor (id, perfil_autorizado_id)`. Esto impide registrar en `consulta` un perfil que el actor no tiene: no hay delegación posible a nivel de integridad referencial, no solo de aplicación.

## Disparadores

- `evento_auditoria_inmutable_tg` (`BEFORE UPDATE OR DELETE ON evento_auditoria`) rechaza cualquier modificación o borrado, incluso si algún rol tuviera el privilegio por error. Es una segunda barrera detrás de los `REVOKE` de privilegios (ver más abajo). No bloquea `TRUNCATE`, que la recarga limpia usa como operación administrativa.

## Row-Level Security (RLS)

Definida en `db/indices_vistas/05_seguridad.sql` sobre `documento`,
`version_documental`, `fragmento` y `embedding`, con `FORCE ROW LEVEL SECURITY`
(alcanza también al propietario). Las políticas de lectura verifican
`app_clase_autorizada(clase_id)`, función `STABLE` que resuelve el perfil
efectivo desde `rag.actor` (variable de configuración local a la transacción)
contra `permiso_documental`. La vista `fragmento_recuperable`
(`03_indices.sql`) usa `security_invoker = true` para no convertirse en un
camino que eluda estas políticas.

## Índices

Ver el detalle y la justificación por consulta en
`db/indices_vistas/03_indices.sql`. Resumen:

- B-tree sobre cada clave foránea usada por un `JOIN` o filtro de las 9
  consultas (`producto.categoria_id`, `cliente.segmento_id`,
  `pedido.cliente_id`, `linea_pedido.producto_id`, `entrega.pedido_id`,
  `incidencia_operativa.entrega_id`, `documento.clase_id`,
  `embedding.modelo_id`, `actor.perfil_autorizado_id`, `consulta.actor_id`,
  `evidencia_documental.embedding_id`).
- Compuestos para patrones específicos: `condicion_comercial (cliente_id,
  producto_id, vigente_desde DESC)`, `version_documental (estado,
  vigente_desde, vigente_hasta)`, `evento_auditoria (accion, instante)`,
  `evento_auditoria (consulta_id, instante)` y `(respuesta_id, instante)`.
- HNSW sobre `embedding.vector` con `vector_cosine_ops` y parámetros por
  defecto: la estructura que hace viable la búsqueda por similitud.
- No se duplican índices ya cubiertos por una clave de unicidad o exclusión
  existente (ver comentario al inicio de `03_indices.sql`).
