"""Tipos internos del conjunto sintético."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import NamedTuple


class Documento(NamedTuple):
    id: int
    codigo: str
    titulo: str
    clase_id: int
    sensibilidad_id: int
    procedencia: str
    activo: bool


class VersionDocumental(NamedTuple):
    id: int
    documento_id: int
    numero_version: int
    estado: str
    vigente_desde: datetime | None
    vigente_hasta: datetime | None
    publicada_en: datetime | None
    revocada_en: datetime | None
    ruta_relativa: str
    nombre_archivo: str
    tipo_mime: str
    tamano_bytes: int
    sha256: str


class Fragmento(NamedTuple):
    id: int
    version_id: int
    posicion: int
    titulo: str
    contenido: str
    pagina: int | None
    clase_id: int
    titulo_documento: str


class Embedding(NamedTuple):
    id: int
    fragmento_id: int
    modelo_id: int
    vector: list[float]
    generado_en: datetime


class Escenario(NamedTuple):
    codigo: str
    actor_id: int
    pregunta: str
    tipo_resultado: str
    naturaleza: str


class EventoAuditoria(NamedTuple):
    id: int
    actor_id: int
    perfil_id: int
    instante: datetime
    accion: str
    resultado: str
    recurso_tipo: str
    recurso_id: int | None
    consulta_id: int | None
    respuesta_id: int | None
    ranking: int | None
    score: float | None
    detalles: str


@dataclass(frozen=True)
class ConjuntoDatos:
    """Colecciones documentales, vectoriales y de interacción."""

    documentos: list[Documento]
    versiones: list[VersionDocumental]
    fragmentos: list[Fragmento]
    embeddings: list[Embedding]
    escenarios: list[Escenario]
    eventos: list[EventoAuditoria]
