# Evidencia de seguridad

Capturada sobre PostgreSQL 17.11 con `db/indices_vistas/05_seguridad.sql`
aplicado. Todas las lecturas se hacen con `rag_runtime`, que **no** es
propietario, **no** es superusuario y **no** tiene `BYPASSRLS`:

Las aserciones se repiten con:

```bash
scripts/validar_base.sh rag_distribuidora_validacion
```

```
    rolname     | rolsuper | rolbypassrls
----------------+----------+--------------
 rag_auditor    | f        | f
 rag_documental | f        | f
 rag_ingesta    | f        | f
 rag_runtime    | f        | f
```

## Matriz de autorización: 15 combinaciones

Fragmentos visibles por perfil y clase documental, contados desde el runtime
con el contexto de un actor de cada perfil.

| Perfil | FICHA | PROC | POL | CUMP | LEGAL |
| --- | ---: | ---: | ---: | ---: | ---: |
| Operaciones/Logística (ACT-001) | 7 | 6 | **0** | **0** | **0** |
| Comercial/Compras (ACT-003) | 7 | **0** | 3 | **0** | **0** |
| Administración/Calidad (ACT-005) | 7 | 6 | **0** | 2 | 2 |

Coincide exactamente con la matriz acordada: dos clases visibles para
Operaciones, dos para Comercial y cuatro para Administración. Las siete
combinaciones restantes devuelven cero filas.

Ninguna cláusula `WHERE` de las consultas produce esos ceros. Las políticas de
RLS eliminan los fragmentos prohibidos antes, por lo que esas filas no son
visibles para la transacción.

Los conteos incluyen sólo versiones publicadas y vigentes con embeddings del
modelo activo. Las versiones sustituidas, revocadas y en borrador tampoco son
visibles mediante consultas directas a `version_documental`, `fragmento` o
`embedding`.

## Contextos inválidos

Todos devuelven cero fragmentos. La denegación es el comportamiento por
defecto, no una excepción programada:

| Contexto | Fragmentos visibles |
| --- | ---: |
| Ausente (nunca se llamó a `set_config`) | 0 |
| Vacío (`''`) | 0 |
| Actor inexistente (`ACT-999`) | 0 |
| Actor existente pero inactivo (`ACT-006`) | 0 |

## Autorización previa al ranking

El mismo vector de consulta, ejecutado por dos perfiles distintos:

Para **Comercial/Compras (ACT-003)**, la política comercial encabeza el resultado:

```
 fragmento_id | documento | clase |       titulo                 | distancia
--------------+-----------+-------+------------------------------+-----------
           18 | DOC-005   | POL   | Criterio general             |  0.004778
           20 | DOC-005   | POL   | Excepciones y autorizaciones |  0.098887
           19 | DOC-005   | POL   | Escalas aplicables           |  0.116021
           31 | DOC-010   | FICHA | Alcance y aplicación         |  0.722421
           32 | DOC-010   | FICHA | Especificaciones técnicas    |  0.783020
```

Para **Operaciones/Logística (ACT-001)**, el mismo vector no devuelve fragmentos POL:

```
 fragmento_id | documento | clase | distancia
--------------+-----------+-------+-----------
           31 | DOC-010   | FICHA |  0.722421
           32 | DOC-010   | FICHA |  0.783020
            5 | DOC-002   | FICHA |  0.804507
            2 | DOC-001   | FICHA |  0.811672
            6 | DOC-002   | FICHA |  0.812570
```

Los fragmentos 18, 19 y 20 son los más cercanos al vector en términos absolutos
y aun así no aparecen para Operaciones, ni siquiera en la quinta posición.
Quedaron fuera del universo antes de calcular el orden. Este filtro previo al
ranking evita que un `LIMIT` exponga contenido prohibido.

## Intentos rechazados

| Operación | Rol | Resultado |
| --- | --- | --- |
| `UPDATE evento_auditoria` | `rag_runtime` | `ERROR: permission denied for table evento_auditoria` |
| `INSERT INTO evento_auditoria` | `rag_runtime` | `ERROR: permission denied for table evento_auditoria` |
| `DELETE FROM evento_auditoria` | `rag_runtime` | `ERROR: permission denied for table evento_auditoria` |
| `UPDATE evento_auditoria` | propietario | `ERROR: evento_auditoria es append-only: UPDATE rechazado` |
| `UPDATE producto` | `rag_runtime` | `ERROR: permission denied for table producto` |
| `INSERT INTO permiso_documental` | `rag_runtime` | `ERROR: permission denied for table permiso_documental` |

La auditoría tiene dos barreras. Los privilegios alcanzan para los roles
operativos; el disparador `evento_auditoria_inmutable_tg` cubre además el caso
en que alguien concediera `UPDATE` por error, e incluso alcanza al propietario
del esquema.

Las inserciones de consultas, respuestas y evidencias generan sus eventos por
trigger. La publicación, sustitución y revocación registran el cambio dentro de
la misma transacción. `rag_documental` ejecuta esas operaciones sin recibir
`UPDATE` directo sobre `version_documental`.

## Trazabilidad

Reconstrucción del escenario ESC-06, leída con `rag_auditor` bajo las mismas
políticas de RLS y con contexto de Administración/Calidad:

```
        instante        |  actor  | perfil |        accion        | resultado | ranking
------------------------+---------+--------+----------------------+-----------+--------
 2026-06-30 14:45:00+00 | ACT-001 | OPS    | consulta_iniciada    | permitido |
 2026-06-30 14:45:02+00 | ACT-001 | OPS    | fragmento_recuperado | permitido |      1
 2026-06-30 14:45:02+00 | ACT-001 | OPS    | fragmento_recuperado | permitido |      2
 2026-06-30 14:45:02+00 | ACT-001 | OPS    | fragmento_recuperado | permitido |      3
 2026-06-30 14:45:02+00 | ACT-001 | OPS    | evidencia_utilizada  | permitido |
 2026-06-30 14:45:02+00 | ACT-001 | OPS    | respuesta_generada   | permitido |
```

La evidencia identifica la fuente exacta (embedding, fragmento, versión,
documento y modelo), en lugar de apuntar al documento vigente:

```
 ranking |   score    | documento | version | estado    | fragmento                   | modelo
---------+------------+-----------+---------+-----------+-----------------------------+----------------------
       1 | 0.00476254 | DOC-003   |       2 | publicada | Objetivo del procedimiento  | distribuidora-emb v2
       2 | 0.09060761 | DOC-003   |       2 | publicada | Comunicación al cliente     | distribuidora-emb v2
       3 | 0.10655176 | DOC-003   |       2 | publicada | Responsables intervinientes | distribuidora-emb v2
```

Por eso la respuesta seguirá siendo explicable cuando DOC-003 v2 sea sustituido
por una v3: la evidencia apunta al embedding que efectivamente se usó.

El acceso denegado queda correlacionado, con actor, perfil, recurso y motivo,
sin copiar el contenido del documento al que no se accedió y sin evidencia
asociada:

```
 actor   | perfil | accion          | resultado | detalles                                                   | tipo_resultado        | evidencias
---------+--------+-----------------+-----------+------------------------------------------------------------+-----------------------+-----------
 ACT-001 | OPS    | acceso_denegado | denegado  | {"motivo": "perfil sin permiso sobre la clase documental"} | sin_fuente_autorizada |          0
```
