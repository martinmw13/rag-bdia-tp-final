# Informe técnico en LaTeX

`informe.tex` compone el documento y `secciones/` permite repartir la redacción
entre integrantes. Mientras el texto siga en revisión, las fuentes y el PDF de
lectura permanecen en esta carpeta. Al cerrar el informe se publicará una copia
final en `docs/informe.pdf`.

## Edición colaborativa

- Editar preferentemente un archivo de `secciones/` por persona.
- Respaldar cada afirmación técnica con los artefactos del repositorio.
- El informe debe explicar y justificar decisiones; no copiar SQL o salidas extensas.

## Compilación

Desde esta carpeta ejecutar `latexmk -pdf informe.tex`. Como alternativa,
ejecutar `pdflatex informe.tex` dos veces.

Los archivos auxiliares de compilación están ignorados por Git. `informe.pdf`
se conserva como vista previa revisable. La copia `docs/informe.pdf` se genera
después de la revisión académica final.
