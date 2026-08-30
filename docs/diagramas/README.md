# Diagramas

Las fuentes Mermaid de esta carpeta forman los modelos conceptual, lógico y
físico, además de la arquitectura general. Cada nivel tiene una vista índice y
vistas temáticas legibles dentro del informe. Los archivos `.mmd` son la fuente
canónica; los PNG se regeneran y no se editan a mano.

## Organización

| Nivel | Vista índice | Vistas temáticas |
| --- | --- | --- |
| Conceptual | [`conceptual.mmd`](conceptual.mmd) | [`conceptual_operacion.mmd`](conceptual_operacion.mmd), [`conceptual_documentos_recuperacion.mmd`](conceptual_documentos_recuperacion.mmd), [`conceptual_acceso_interaccion_evidencia.mmd`](conceptual_acceso_interaccion_evidencia.mmd) |
| Lógico | [`logico.mmd`](logico.mmd) | [`logico_operacion.mmd`](logico_operacion.mmd), [`logico_documentos_recuperacion.mmd`](logico_documentos_recuperacion.mmd), [`logico_acceso_interaccion_evidencia.mmd`](logico_acceso_interaccion_evidencia.mmd) |
| Físico | [`fisico.mmd`](fisico.mmd) | [`fisico_operacion.mmd`](fisico_operacion.mmd), [`fisico_recuperacion.mmd`](fisico_recuperacion.mmd), [`fisico_seguridad.mmd`](fisico_seguridad.mmd) y [`fisico_notas.md`](fisico_notas.md) |
| Arquitectura | [`arquitectura.mmd`](arquitectura.mmd) | Recorrido general de los datos y límite de la implementación |

Las vistas índice se publican con los nombres generales solicitados en la
consigna:

| Fuente | Render publicado |
| --- | --- |
| `conceptual.mmd` | [`docs/modelo_conceptual.png`](../modelo_conceptual.png) |
| `logico.mmd` | [`docs/modelo_logico_o_equivalente.png`](../modelo_logico_o_equivalente.png) |
| `fisico.mmd` | [`docs/modelo_fisico_o_equivalente.png`](../modelo_fisico_o_equivalente.png) |
| `arquitectura.mmd` | [`docs/arquitectura.png`](../arquitectura.png) |

El modelo conceptual explica entidades, atributos relevantes, relaciones,
cardinalidades y restricciones del dominio. El modelo lógico distribuye todas
las tablas y columnas entre tres vistas. El modelo físico usa tipos concretos de
PostgreSQL y se completa con las notas sobre `CHECK`, `EXCLUDE`, índices,
triggers y RLS. El DDL conserva la definición exhaustiva de la implementación.

## Regeneración

Requiere Node.js y `@mermaid-js/mermaid-cli`. Desde la raíz del repositorio:

```bash
MMD="npx -y @mermaid-js/mermaid-cli -t neutral -b white"

$MMD -i docs/diagramas/conceptual.mmd -o docs/modelo_conceptual.png -w 2200
$MMD -i docs/diagramas/conceptual_operacion.mmd -o docs/conceptual_operacion.png -w 2600
$MMD -i docs/diagramas/conceptual_documentos_recuperacion.mmd -o docs/conceptual_documentos_recuperacion.png -w 2600
$MMD -i docs/diagramas/conceptual_acceso_interaccion_evidencia.mmd -o docs/conceptual_acceso_interaccion_evidencia.png -w 2600

$MMD -i docs/diagramas/logico.mmd -o docs/modelo_logico_o_equivalente.png -w 2200
$MMD -i docs/diagramas/logico_operacion.mmd -o docs/logico_operacion.png -w 3000
$MMD -i docs/diagramas/logico_documentos_recuperacion.mmd -o docs/logico_documentos_recuperacion.png -w 3000
$MMD -i docs/diagramas/logico_acceso_interaccion_evidencia.mmd -o docs/logico_acceso_interaccion_evidencia.png -w 3000

$MMD -i docs/diagramas/fisico.mmd -o docs/modelo_fisico_o_equivalente.png -w 2200
$MMD -i docs/diagramas/fisico_operacion.mmd -o docs/fisico_operacion.png -w 3000
$MMD -i docs/diagramas/fisico_recuperacion.mmd -o docs/fisico_recuperacion.png -w 3000
$MMD -i docs/diagramas/fisico_seguridad.mmd -o docs/fisico_seguridad.png -w 3000

$MMD -i docs/diagramas/arquitectura.mmd -o docs/arquitectura.png -w 1800
```

El tema neutral y el fondo blanco mantienen una presentación uniforme. Los
anchos mayores se reservan para los modelos ER, que contienen atributos. Las
fuentes fueron validadas con el parser y el renderizador de Mermaid.

## Convenciones

- Los nombres de entidad usan `MAYUSCULA_CON_GUION_BAJO` y corresponden con las
  tablas del esquema.
- Las vistas conceptuales omiten claves técnicas y tipos de PostgreSQL.
- Las vistas lógicas usan tipos independientes del motor y aclaran claves o
  restricciones compuestas en las columnas involucradas.
- Las vistas físicas muestran tipos de PostgreSQL. Las reglas que Mermaid no
  representa con precisión se desarrollan en [`fisico_notas.md`](fisico_notas.md).
- La arquitectura muestra la aplicación y el LLM sólo como contexto; ambos
  permanecen fuera del alcance de la implementación.
