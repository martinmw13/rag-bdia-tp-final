# Informe técnico en LaTeX

`informe.tex` compone el documento y `secciones/` permite repartir la redacción entre integrantes.

## Edición colaborativa

- Editar preferentemente un archivo de `secciones/` por persona.
- Reemplazar cada `\pendiente{...}` con texto final respaldado por los artefactos del repositorio.
- El informe debe explicar y justificar decisiones; no copiar SQL o salidas extensas.

## Compilación

Desde esta carpeta ejecutar `latexmk -pdf informe.tex`. Como alternativa, ejecutar `pdflatex informe.tex` dos veces.

El PDF final debe copiarse como `docs/informe.pdf`.
