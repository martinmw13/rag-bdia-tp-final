# Diagramas

Fuente canónica de los cuatro diagramas exigidos por la especificación
(`docs/specs/capa-datos-rag-distribuidora/impl-modelo-datos.md`): conceptual,
lógico, físico y de arquitectura. Los `.mmd` son la autoridad; cualquier
render (SVG/PNG) que se incluya en el informe se regenera a partir de ellos,
nunca se edita a mano.

Los renders publicados viven un nivel más arriba, en `docs/`, con los nombres
que enumera la consigna, de modo que quien corrige los encuentre donde los
busca:

| Fuente | Render publicado |
| --- | --- |
| `conceptual.mmd` | [`docs/modelo_conceptual.png`](../modelo_conceptual.png) |
| `logico.mmd` | [`docs/modelo_logico_o_equivalente.png`](../modelo_logico_o_equivalente.png) |
| `fisico.mmd` | [`docs/modelo_fisico_o_equivalente.png`](../modelo_fisico_o_equivalente.png) |
| `arquitectura.mmd` | [`docs/arquitectura.png`](../arquitectura.png) |

| Archivo | Contenido | Nivel |
| --- | --- | --- |
| [`conceptual.mmd`](conceptual.mmd) | Entidades y relaciones de negocio, sin atributos ni tipos. | Conceptual |
| [`logico.mmd`](logico.mmd) | Atributos, tipos lógicos (independientes del motor) y claves PK/FK/UK. | Lógico |
| [`fisico.mmd`](fisico.mmd) + [`fisico_notas.md`](fisico_notas.md) | Tipos exactos de PostgreSQL, más las reglas que `erDiagram` no puede expresar (`CHECK`, `EXCLUDE`, triggers, RLS, índices). | Físico |
| [`arquitectura.mmd`](arquitectura.mmd) | Instancia única de PostgreSQL, flujo de datos (generación → carga → documento/versionado → fragmentación → embeddings → recuperación autorizada → evidencia → auditoría) y roles técnicos. | Arquitectura |

Todos se verificaron sintácticamente contra el parser real de Mermaid
(`mermaid.parse`, paquete `@mermaid-js/mermaid-cli`); no se ejecutaron
manualmente contra un layout renderizado.

## Cómo regenerar los renders

Requiere Node.js. No es una dependencia del proyecto (que sigue sin
dependencias fuera de la biblioteca estándar de Python): es una herramienta
de documentación que se ejecuta una vez para generar las imágenes.

```bash
npx -y @mermaid-js/mermaid-cli -i docs/diagramas/conceptual.mmd   -o docs/modelo_conceptual.png
npx -y @mermaid-js/mermaid-cli -i docs/diagramas/logico.mmd       -o docs/modelo_logico_o_equivalente.png
npx -y @mermaid-js/mermaid-cli -i docs/diagramas/fisico.mmd       -o docs/modelo_fisico_o_equivalente.png
npx -y @mermaid-js/mermaid-cli -i docs/diagramas/arquitectura.mmd -o docs/arquitectura.png
```

Los renders publicados están a 2400 px de ancho. Es suficiente para leer cada
etiqueta y mantiene los cuatro archivos en unos 2 MB en total; a la resolución
por defecto de la herramienta ocupaban más del triple sin ganar legibilidad.
Para reducirlos después de generarlos, en macOS alcanza con:

```bash
sips -Z 2400 docs/modelo_conceptual.png
```

La primera ejecución descarga Chromium vía Puppeteer. Alternativa sin
instalar nada localmente: pegar el contenido de cada `.mmd` en
[mermaid.live](https://mermaid.live) y exportar el SVG, o usar la extensión
"Markdown Preview Mermaid Support" de VS Code para previsualizar sin
exportar.

## Convenciones

- Nombres de entidad en `MAYUSCULA_CON_GUION_BAJO`, iguales a la tabla física
  correspondiente, para que conceptual → lógico → físico se lean como el
  mismo modelo en tres niveles de detalle creciente.
- El diagrama conceptual no repite atributos: si una relación necesita
  aclaración de cardinalidad de negocio, se explica en el nombre de la
  relación, no agregando atributos.
- El diagrama de arquitectura marca con línea punteada el punto donde un
  copiloto/LLM consumiría la evidencia — está fuera de alcance del TP y se
  representa solo para dar contexto del problema, como aclara
  `docs/especificacion.md`.
