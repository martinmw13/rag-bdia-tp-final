"""Operaciones vectoriales usadas por el conjunto sintético."""

from __future__ import annotations

import math
import random


def normalizar(vector: list[float]) -> list[float]:
    norma = math.sqrt(sum(x * x for x in vector))
    if norma == 0:
        raise ValueError("no se puede normalizar el vector nulo")
    return [round(x / norma, 8) for x in vector]


def vector_tematico(
    centroide: list[float], ruido: float, rng: random.Random
) -> list[float]:
    """Genera un vector normalizado alrededor de un centroide temático."""
    return normalizar([c + rng.uniform(-ruido, ruido) for c in centroide])


def distancia_coseno(a: list[float], b: list[float]) -> float:
    return 1.0 - sum(x * y for x, y in zip(a, b))


def fragmento_esperado(
    vector_consulta: list[float],
    recuperables: list[int],
    vectores_por_fragmento: dict[int, list[float]],
) -> int:
    """Devuelve el fragmento más cercano dentro del universo indicado."""
    return min(
        recuperables,
        key=lambda fid: (
            distancia_coseno(vector_consulta, vectores_por_fragmento[fid]),
            fid,
        ),
    )
