"""Pruebas de regresión del generador de datos."""

from __future__ import annotations

import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from scripts.generacion import construccion as datos
from scripts.generacion.artefactos import escribir_artefactos


RAIZ = Path(__file__).resolve().parents[1]

HASHES_ESPERADOS = {
    "db/datos/02_seed.sql": "bf8c60d2d95093f4c32087847641354fc080434c52bb058110f82a7275434462",
    "data/ejemplos/manifiesto.json": "a85b34a59543e56eb91510be15ab951bab813f518f33cbe706ba6eb4310a4bdf",
    "data/ejemplos/documentos/DOC-001-v1.md": "51556f61a9475f622acf2349f6e693b4e1745e9365a7deb6daebfb7e4dc82b13",
    "data/ejemplos/documentos/DOC-002-v1.md": "cfd41d87baae7356fcf539d22ae8784f17b7d020c86f089c9c99473299866332",
    "data/ejemplos/documentos/DOC-002-v2.md": "64940bd633c15b88f43a0edd9b8f8584fb892eae3464f38763c9c06608eb18c8",
    "data/ejemplos/documentos/DOC-003-v1.md": "ad5d901b8b37fdc6753a0430b673fe5fac3ebc495476b1259d813d0c8707070f",
    "data/ejemplos/documentos/DOC-003-v2.md": "36f6132b38d7eb7f50826261b9fe5c49389f0baeb6571f6580443fcc466593fe",
    "data/ejemplos/documentos/DOC-004-v1.md": "20fc49451562b4e3f36541a38f75202b68c432db5c6ad4971370e2cb91342275",
    "data/ejemplos/documentos/DOC-005-v1.md": "30c633a74d4fc87b465e6e46d0906f27d2a915e1be308e1a1bd2eb128818fbe1",
    "data/ejemplos/documentos/DOC-005-v2.md": "3bb40dc3d3bf97cdc7a4d395261373d5de74f2add64a0c6aac38038eb5ee5cb8",
    "data/ejemplos/documentos/DOC-006-v1.md": "8e139c92e570ec4377313682fc652ba79aef68c19e8f7a00e830fc4803d5bbca",
    "data/ejemplos/documentos/DOC-007-v1.md": "18b6aa9498ede25063f8b0a6575a6c9b74628bb3ebd666d71903d9c699b5c703",
    "data/ejemplos/documentos/DOC-008-v1.md": "f7a10af6c7abd77c6823360f1eb38793f82763b3b1930dac3065823558f3c9d3",
    "data/ejemplos/documentos/DOC-009-v1.md": "46e396d54e986e0fcd018d9503fdef7b25df4b1480079fce6aa75448612890aa",
    "data/ejemplos/documentos/DOC-009-v2.md": "c72ed4cd41fd712c796705b8d0ea5b8f943ee340d4c787db6b41445947936cd3",
    "data/ejemplos/documentos/DOC-010-v1.md": "98fc437ea4372e091cc5629e2b1c24b40a345d4844d8b9a1f9ddd3ce45c78f48",
}


def sha256(contenido: str) -> str:
    return hashlib.sha256(contenido.encode("utf-8")).hexdigest()


def ejecutar_generador(raiz: Path) -> None:
    programa = (
        "import sys; from pathlib import Path; "
        "from scripts.generacion.artefactos import generar_artefactos; "
        "generar_artefactos(Path(sys.argv[1]))"
    )
    subprocess.run(
        [sys.executable, "-c", programa, str(raiz)],
        cwd=RAIZ,
        check=True,
        capture_output=True,
        text=True,
    )


def leer_artefactos(raiz: Path) -> dict[str, bytes]:
    return {
        ruta: (raiz / ruta).read_bytes()
        for ruta in HASHES_ESPERADOS
    }


class GeneradorDatosTest(unittest.TestCase):
    def test_conserva_las_salidas_publicadas(self) -> None:
        with tempfile.TemporaryDirectory() as directorio:
            artefactos = escribir_artefactos(Path(directorio))

        self.assertEqual(set(artefactos), set(HASHES_ESPERADOS))
        for ruta, contenido in artefactos.items():
            with self.subTest(ruta=ruta):
                self.assertEqual(sha256(contenido), HASHES_ESPERADOS[ruta])
                self.assertEqual(contenido.encode("utf-8"), (RAIZ / ruta).read_bytes())

    def test_dos_generaciones_son_identicas(self) -> None:
        with tempfile.TemporaryDirectory() as primero, tempfile.TemporaryDirectory() as segundo:
            raiz_primera = Path(primero)
            raiz_segunda = Path(segundo)
            ejecutar_generador(raiz_primera)
            ejecutar_generador(raiz_segunda)
            artefactos_primero = leer_artefactos(raiz_primera)
            artefactos_segundo = leer_artefactos(raiz_segunda)

        self.assertEqual(artefactos_primero, artefactos_segundo)

    def test_conserva_los_oraculos_vectoriales(self) -> None:
        self.assertEqual(datos.esperado_vectorial, 10)
        self.assertEqual(datos.esperado_hibrida_com, 18)

        manifiesto = json.loads(
            (RAIZ / "data/ejemplos/manifiesto.json").read_text(encoding="utf-8")
        )
        self.assertEqual(
            manifiesto["oraculos_vectoriales"]["consulta_vectorial"]["fragmento_esperado"],
            datos.esperado_vectorial,
        )
        self.assertEqual(
            manifiesto["oraculos_vectoriales"]["consulta_hibrida"]["fragmento_esperado_comercial"],
            datos.esperado_hibrida_com,
        )


if __name__ == "__main__":
    unittest.main()
