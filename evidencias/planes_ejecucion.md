# Planes de ejecución

Capturados sobre PostgreSQL 17.11 con pgvector 0.8.6, contra una carga limpia
del conjunto sintético (semilla 42). Reproducibles con:

```bash
psql -d rag_distribuidora -c "EXPLAIN (ANALYZE, BUFFERS) <consulta>"
```

## Escala del conjunto

| Tabla | Filas |
| --- | ---: |
| `evento_auditoria` | 56 |
| `embedding` | 36 |
| `fragmento` | 32 |
| `linea_pedido` | 28 |
| `producto_proveedor` | 18 |
| `entrega` | 14 |
| `version_documental` | 14 |
| `condicion_comercial` | 12 |
| `pedido` | 12 |
| `producto` | 12 |

Ninguna tabla supera las 56 filas. Es la escala que corresponde a una prueba
funcional de diseño y **no** a un benchmark: los tiempos que siguen no deben
extrapolarse a un escenario productivo.

## Búsqueda vectorial: con y sin índice HNSW

Consulta: top-5 por distancia coseno sobre `embedding`, restringido al modelo
activo.

**Plan real, con el índice HNSW creado:**

```
Limit (actual rows=5 loops=1)
  Buffers: shared hit=4
  ->  Sort (actual rows=5 loops=1)
        Sort Method: top-N heapsort  Memory: 25kB
        ->  Seq Scan on embedding e (actual rows=32 loops=1)
              Filter: (modelo_id = 1)
              Rows Removed by Filter: 4
Execution Time: 0.043 ms
```

El planificador **no usa el índice**: con 36 vectores, recorrer la tabla entera
y ordenar 32 filas en memoria es más barato que descender por el grafo HNSW.
La decisión del optimizador es correcta para esta escala.

**Verificación de que el índice es funcional** (`enable_seqscan = off`, sólo
como diagnóstico, no como resultado):

```
Limit (actual rows=5 loops=1)
  ->  Index Scan using embedding_vector_hnsw_ix on embedding e (actual rows=5 loops=1)
```

El índice existe, es válido y resuelve la consulta por similitud cuando se lo
utiliza. Lo que la escala del conjunto no permite es que el optimizador lo
prefiera espontáneamente.

### Interpretación

Un `Seq Scan` sobre 36 filas no invalida la decisión de crear el índice HNSW.
El costo de la búsqueda exacta crece linealmente con la cantidad de vectores:
comparar contra 36 es trivial, contra 500.000 fragmentos deja de serlo. El
índice está justificado por el patrón de acceso —recuperación top-k por
distancia coseno, que es la operación central del copiloto— y por el
crecimiento esperado del corpus documental, no por el tiempo medido acá.

Forzar el uso del índice inflando artificialmente el conjunto habría producido
un número más vistoso y menos honesto.

## Índices B-tree

Los índices de `03_indices.sql` acompañan joins y filtros que las consultas
usan efectivamente:

| Índice | Consulta que lo justifica |
| --- | --- |
| `condicion_comercial_busqueda_ix` | C1: condición vigente por cliente, producto e instante |
| `entrega_pedido_ix`, `incidencia_entrega_ix` | C2: recorrido pedido → entrega → incidencia |
| `producto_categoria_ix`, `linea_pedido_producto_ix` | C3: importe neto por categoría |
| `cliente_segmento_ix` | C4: acumulación por segmento |
| `pedido_cliente_ix` | C5: clientes sin pedidos |
| `documento_clase_ix`, `version_documental_vigencia_ix` | C7: filtro de autorización y vigencia previo al ranking |
| `evento_auditoria_consulta_ix`, `evento_auditoria_respuesta_ix` | C9: correlación de la traza de una interacción |

A esta escala, la mayoría de los planes también resuelve con `Seq Scan` por el
mismo motivo. Las claves foráneas ya cubiertas por el prefijo de una
restricción de unicidad existente no recibieron índice propio, para no
duplicar estructuras: el detalle está comentado en `db/indices_vistas/03_indices.sql`.
