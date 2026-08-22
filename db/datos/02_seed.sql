-- =============================================================================
-- 02_seed.sql - Carga reproducible del conjunto sintético
-- =============================================================================
--
-- ARCHIVO GENERADO. No editar a mano: se produce con
--     python scripts/generar_datos.py
--
-- Versión del generador : 1.0.0
-- Semilla               : 42
-- Instante de referencia: 2026-06-30T15:00:00Z
--
-- La carga es idempotente: vacía las tablas y vuelve a insertar el mismo
-- conjunto, de modo que dos ejecuciones limpias son equivalentes.
-- =============================================================================

SET TIME ZONE 'UTC';

BEGIN;

TRUNCATE
    evento_auditoria, evidencia_estructurada, evidencia_documental,
    resultado_estructurado, respuesta, consulta, permiso_documental, actor,
    documento_proveedor, documento_producto, embedding, fragmento,
    version_documental, documento, incidencia_operativa, entrega,
    linea_pedido, pedido, condicion_comercial, producto_proveedor,
    proveedor, cliente, producto, modelo_embedding, nivel_sensibilidad,
    clase_documental, perfil_autorizado, segmento_cliente, categoria_producto
    RESTART IDENTITY CASCADE;

-- --- Catálogos ---------------------------------------------------------
INSERT INTO categoria_producto (id, codigo, nombre) VALUES
    (1, 'CAT-FERR', 'Ferretería industrial'),
    (2, 'CAT-ELEC', 'Material eléctrico'),
    (3, 'CAT-SEGU', 'Seguridad industrial'),
    (4, 'CAT-EMBA', 'Embalaje y logística');
INSERT INTO segmento_cliente (id, codigo, nombre) VALUES
    (1, 'SEG-MAY', 'Mayorista'),
    (2, 'SEG-MIN', 'Minorista'),
    (3, 'SEG-CORP', 'Corporativo');
INSERT INTO perfil_autorizado (id, codigo, nombre) VALUES
    (1, 'OPS', 'Operaciones/Logística'),
    (2, 'COM', 'Comercial/Compras'),
    (3, 'ADM', 'Administración/Calidad');
INSERT INTO clase_documental (id, codigo, nombre, descripcion) VALUES
    (1, 'FICHA', 'Ficha de producto', 'Especificación técnica de un producto del catálogo.'),
    (2, 'PROC', 'Procedimiento logístico', 'Instructivo operativo de depósito y distribución.'),
    (3, 'POL', 'Política comercial', 'Condiciones, descuentos y plazos acordados.'),
    (4, 'CUMP', 'Cumplimiento de proveedor', 'Certificaciones y auditorías de proveedores.'),
    (5, 'LEGAL', 'Documentación legal', 'Contratos y documentación legal reservada.');
INSERT INTO nivel_sensibilidad (id, codigo, nombre, requiere_auditoria) VALUES
    (1, 'PUB', 'Pública', FALSE),
    (2, 'INT', 'Interna', FALSE),
    (3, 'RES', 'Restringida', TRUE);
INSERT INTO modelo_embedding (id, nombre, version, dimension, metrica, activo) VALUES
    (1, 'distribuidora-emb', 'v2', 32, 'coseno', TRUE),
    (2, 'distribuidora-emb', 'v1', 32, 'coseno', FALSE);

-- --- Núcleo operativo -------------------------------------------------
INSERT INTO producto (id, codigo, nombre, categoria_id, activo) VALUES
    (1, 'PRD-001', 'Taladro percutor industrial', 1, TRUE),
    (2, 'PRD-002', 'Juego de llaves combinadas', 1, TRUE),
    (3, 'PRD-003', 'Amoladora angular', 1, TRUE),
    (4, 'PRD-004', 'Cable unipolar 2.5 mm', 2, TRUE),
    (5, 'PRD-005', 'Tablero seccional modular', 2, TRUE),
    (6, 'PRD-006', 'Luminaria LED de galpón', 2, TRUE),
    (7, 'PRD-007', 'Casco de seguridad dieléctrico', 3, TRUE),
    (8, 'PRD-008', 'Guantes anticorte nivel 5', 3, TRUE),
    (9, 'PRD-009', 'Arnés de seguridad completo', 3, TRUE),
    (10, 'PRD-010', 'Film stretch para pallets', 4, TRUE),
    (11, 'PRD-011', 'Caja de cartón corrugado', 4, TRUE),
    (12, 'PRD-012', 'Zuncho de polipropileno', 4, FALSE);
INSERT INTO cliente (id, codigo, razon_social, segmento_id, activo) VALUES
    (1, 'CLI-001', 'Corralón del Norte', 1, TRUE),
    (2, 'CLI-002', 'Distribuidora Pampa', 1, TRUE),
    (3, 'CLI-003', 'Ferretería El Roble', 2, TRUE),
    (4, 'CLI-004', 'Insumos del Litoral', 2, TRUE),
    (5, 'CLI-005', 'Constructora Andina', 3, TRUE),
    (6, 'CLI-006', 'Servicios Integrales Sur', 3, TRUE);
INSERT INTO proveedor (id, codigo, razon_social, activo) VALUES
    (1, 'PROV-001', 'Herramientas del Plata', TRUE),
    (2, 'PROV-002', 'Electro Insumos Cuyo', TRUE),
    (3, 'PROV-003', 'Protección Laboral SA', TRUE),
    (4, 'PROV-004', 'Embalajes Rioplatenses', TRUE);
INSERT INTO producto_proveedor (producto_id, proveedor_id) VALUES
    (1, 1),
    (1, 2),
    (2, 1),
    (3, 1),
    (3, 2),
    (4, 2),
    (5, 2),
    (5, 3),
    (6, 2),
    (7, 3),
    (7, 4),
    (8, 3),
    (9, 3),
    (9, 4),
    (10, 4),
    (11, 1),
    (11, 4),
    (12, 4);
INSERT INTO condicion_comercial (id, cliente_id, producto_id, precio_unitario, descuento_porcentaje, vigente_desde, vigente_hasta) VALUES
    (1, 1, 1, 160217.27, 0, '2025-08-04', '2026-03-02'),
    (2, 1, 1, 185646.07, 5, '2026-03-02', '2026-07-30'),
    (3, 1, 1, 56579.47, 0, '2026-07-30', NULL),
    (4, 1, 2, 169498.17, 20, '2025-12-12', NULL),
    (5, 2, 1, 22647.77, 15, '2025-12-12', NULL),
    (6, 2, 4, 8913.89, 0, '2025-12-12', NULL),
    (7, 3, 5, 55440.86, 20, '2025-12-12', NULL),
    (8, 3, 7, 150902.66, 20, '2025-12-12', NULL),
    (9, 4, 8, 50510.58, 20, '2025-12-12', NULL),
    (10, 4, 10, 105460.44, 15, '2025-12-12', NULL),
    (11, 5, 3, 147727.16, 0, '2025-12-12', NULL),
    (12, 5, 11, 189943.03, 5, '2025-12-12', NULL);
INSERT INTO pedido (id, codigo, cliente_id, fecha, estado) VALUES
    (1, 'PED-001', 1, '2025-09-23', 'en_preparacion'),
    (2, 'PED-002', 2, '2025-10-13', 'entregado'),
    (3, 'PED-003', 3, '2025-11-02', 'pendiente'),
    (4, 'PED-004', 4, '2025-11-22', 'en_preparacion'),
    (5, 'PED-005', 5, '2025-12-12', 'entregado'),
    (6, 'PED-006', 1, '2026-01-01', 'pendiente'),
    (7, 'PED-007', 2, '2026-01-21', 'en_preparacion'),
    (8, 'PED-008', 3, '2026-02-10', 'entregado'),
    (9, 'PED-009', 4, '2026-03-02', 'pendiente'),
    (10, 'PED-010', 5, '2026-03-22', 'en_preparacion'),
    (11, 'PED-011', 1, '2026-04-11', 'entregado'),
    (12, 'PED-012', 2, '2026-05-01', 'cancelado');
INSERT INTO linea_pedido (id, pedido_id, numero_linea, producto_id, cantidad, precio_unitario, descuento_porcentaje) VALUES
    (1, 1, 1, 5, 10, 54613.13, 10),
    (2, 1, 2, 6, 7, 24093.72, 0),
    (3, 1, 3, 7, 23, 212026.1, 20),
    (4, 2, 1, 1, 47, 115396.8, 0),
    (5, 2, 2, 5, 25, 20621.25, 10),
    (6, 3, 1, 4, 46, 18319.23, 5),
    (7, 3, 2, 6, 50, 73057.6, 0),
    (8, 3, 3, 10, 15, 216754.43, 15),
    (9, 3, 4, 11, 18, 113899.17, 10),
    (10, 4, 1, 3, 23, 53167.25, 10),
    (11, 4, 2, 6, 45, 234226.99, 0),
    (12, 5, 1, 3, 47, 61957.92, 15),
    (13, 5, 2, 9, 25, 68217.01, 20),
    (14, 5, 3, 10, 15, 171468.95, 0),
    (15, 6, 1, 1, 21, 100890.03, 0),
    (16, 6, 2, 4, 14, 228370.89, 20),
    (17, 7, 1, 4, 42, 125308.58, 15),
    (18, 7, 2, 6, 10, 66955.16, 5),
    (19, 8, 1, 5, 48, 146561.91, 20),
    (20, 8, 2, 9, 26, 91137.11, 5),
    (21, 8, 3, 11, 33, 123885.44, 0),
    (22, 9, 1, 2, 41, 40835.52, 15),
    (23, 9, 2, 3, 39, 16818.4, 15),
    (24, 10, 1, 8, 34, 63602.12, 20),
    (25, 10, 2, 10, 1, 170390.57, 0),
    (26, 11, 1, 9, 49, 67439.47, 10),
    (27, 11, 2, 11, 8, 74081.53, 5),
    (28, 12, 1, 8, 1, 238500.17, 10);
INSERT INTO entrega (id, codigo, pedido_id, fecha_programada, fecha_efectiva, estado) VALUES
    (1, 'ENT-001', 1, '2025-09-28', '2025-09-28', 'entregada'),
    (2, 'ENT-002', 2, '2025-10-18', '2025-10-18', 'entregada'),
    (3, 'ENT-003', 3, '2025-11-07', '2025-11-07', 'entregada'),
    (4, 'ENT-004', 4, '2025-11-27', '2025-11-27', 'entregada'),
    (5, 'ENT-005', 5, '2025-12-17', NULL, 'demorada'),
    (6, 'ENT-006', 6, '2026-01-06', '2026-01-06', 'entregada'),
    (7, 'ENT-007', 7, '2026-01-26', '2026-01-26', 'entregada'),
    (8, 'ENT-008', 8, '2026-02-15', '2026-02-15', 'entregada'),
    (9, 'ENT-009', 9, '2026-03-07', '2026-03-07', 'entregada'),
    (10, 'ENT-010', 10, '2026-03-27', '2026-03-27', 'entregada'),
    (11, 'ENT-011', 11, '2026-04-16', '2026-04-16', 'entregada'),
    (12, 'ENT-012', 3, '2025-11-14', '2025-11-14', 'entregada'),
    (13, 'ENT-013', 3, '2025-11-22', NULL, 'en_transito'),
    (14, 'ENT-014', 5, '2025-12-27', NULL, 'en_transito');
INSERT INTO incidencia_operativa (id, codigo, entrega_id, fecha, tipo, descripcion, estado) VALUES
    (1, 'INC-001', 5, '2025-12-18', 'demora', 'La unidad de reparto acumuló demora por corte de ruta.', 'abierta'),
    (2, 'INC-002', 2, '2025-10-19', 'faltante', 'Se detectó faltante de bultos contra el remito emitido.', 'cerrada'),
    (3, 'INC-003', 6, '2026-01-07', 'dano', 'Un pallet presentó daño de film y embalaje al arribar.', 'cerrada'),
    (4, 'INC-004', 9, '2026-03-08', 'direccion_erronea', 'El domicilio declarado no coincidió con el de entrega.', 'cerrada');

-- --- Núcleo documental ------------------------------------------------
INSERT INTO documento (id, codigo, titulo, clase_id, sensibilidad_id, procedencia, activo) VALUES
    (1, 'DOC-001', 'Ficha técnica del taladro percutor industrial', 1, 1, 'Compras', TRUE),
    (2, 'DOC-002', 'Ficha técnica del tablero seccional modular', 1, 1, 'Compras', TRUE),
    (3, 'DOC-003', 'Procedimiento de gestión de entregas demoradas', 2, 2, 'Operaciones', TRUE),
    (4, 'DOC-004', 'Procedimiento de devoluciones y logística inversa', 2, 2, 'Operaciones', TRUE),
    (5, 'DOC-005', 'Política comercial de descuentos por volumen', 3, 2, 'Comercial', TRUE),
    (6, 'DOC-006', 'Política comercial de plazos de pago', 3, 2, 'Comercial', TRUE),
    (7, 'DOC-007', 'Certificaciones vigentes de proveedores homologados', 4, 2, 'Calidad', TRUE),
    (8, 'DOC-008', 'Programa anual de auditorías a proveedores', 4, 2, 'Calidad', TRUE),
    (9, 'DOC-009', 'Contrato marco de distribución mayorista', 5, 3, 'Legales', TRUE),
    (10, 'DOC-010', 'Ficha técnica del arnés de seguridad completo', 1, 1, 'Compras', TRUE);
INSERT INTO version_documental (id, documento_id, numero_version, estado, vigente_desde, vigente_hasta, publicada_en, revocada_en, ruta_relativa, nombre_archivo, tipo_mime, tamano_bytes, sha256) VALUES
    (1, 1, 1, 'publicada', '2025-07-25T15:00:00Z', NULL, '2025-07-25T15:00:00Z', NULL, 'data/ejemplos/documentos/DOC-001-v1.md', 'DOC-001-v1.md', 'text/markdown', 385, '51556f61a9475f622acf2349f6e693b4e1745e9365a7deb6daebfb7e4dc82b13'),
    (2, 2, 1, 'sustituida', '2025-07-25T15:00:00Z', '2025-09-23T15:00:00Z', '2025-07-25T15:00:00Z', NULL, 'data/ejemplos/documentos/DOC-002-v1.md', 'DOC-002-v1.md', 'text/markdown', 383, 'cfd41d87baae7356fcf539d22ae8784f17b7d020c86f089c9c99473299866332'),
    (3, 2, 2, 'publicada', '2025-09-23T15:00:00Z', NULL, '2025-09-23T15:00:00Z', NULL, 'data/ejemplos/documentos/DOC-002-v2.md', 'DOC-002-v2.md', 'text/markdown', 532, '64940bd633c15b88f43a0edd9b8f8584fb892eae3464f38763c9c06608eb18c8'),
    (4, 3, 1, 'sustituida', '2025-07-25T15:00:00Z', '2025-09-23T15:00:00Z', '2025-07-25T15:00:00Z', NULL, 'data/ejemplos/documentos/DOC-003-v1.md', 'DOC-003-v1.md', 'text/markdown', 378, 'ad5d901b8b37fdc6753a0430b673fe5fac3ebc495476b1259d813d0c8707070f'),
    (5, 3, 2, 'publicada', '2025-09-23T15:00:00Z', NULL, '2025-09-23T15:00:00Z', NULL, 'data/ejemplos/documentos/DOC-003-v2.md', 'DOC-003-v2.md', 'text/markdown', 644, '36f6132b38d7eb7f50826261b9fe5c49389f0baeb6571f6580443fcc466593fe'),
    (6, 4, 1, 'publicada', '2025-07-25T15:00:00Z', NULL, '2025-07-25T15:00:00Z', NULL, 'data/ejemplos/documentos/DOC-004-v1.md', 'DOC-004-v1.md', 'text/markdown', 381, '20fc49451562b4e3f36541a38f75202b68c432db5c6ad4971370e2cb91342275'),
    (7, 5, 1, 'sustituida', '2025-07-25T15:00:00Z', '2025-09-23T15:00:00Z', '2025-07-25T15:00:00Z', NULL, 'data/ejemplos/documentos/DOC-005-v1.md', 'DOC-005-v1.md', 'text/markdown', 348, '30c633a74d4fc87b465e6e46d0906f27d2a915e1be308e1a1bd2eb128818fbe1'),
    (8, 5, 2, 'publicada', '2025-09-23T15:00:00Z', NULL, '2025-09-23T15:00:00Z', NULL, 'data/ejemplos/documentos/DOC-005-v2.md', 'DOC-005-v2.md', 'text/markdown', 488, '3bb40dc3d3bf97cdc7a4d395261373d5de74f2add64a0c6aac38038eb5ee5cb8'),
    (9, 6, 1, 'revocada', '2025-07-25T15:00:00Z', '2025-10-23T15:00:00Z', '2025-07-25T15:00:00Z', '2025-10-23T15:00:00Z', 'data/ejemplos/documentos/DOC-006-v1.md', 'DOC-006-v1.md', 'text/markdown', 340, '8e139c92e570ec4377313682fc652ba79aef68c19e8f7a00e830fc4803d5bbca'),
    (10, 7, 1, 'publicada', '2025-07-25T15:00:00Z', NULL, '2025-07-25T15:00:00Z', NULL, 'data/ejemplos/documentos/DOC-007-v1.md', 'DOC-007-v1.md', 'text/markdown', 333, '18b6aa9498ede25063f8b0a6575a6c9b74628bb3ebd666d71903d9c699b5c703'),
    (11, 8, 1, 'borrador', NULL, NULL, NULL, NULL, 'data/ejemplos/documentos/DOC-008-v1.md', 'DOC-008-v1.md', 'text/markdown', 325, 'f7a10af6c7abd77c6823360f1eb38793f82763b3b1930dac3065823558f3c9d3'),
    (12, 9, 1, 'sustituida', '2025-07-25T15:00:00Z', '2025-09-23T15:00:00Z', '2025-07-25T15:00:00Z', NULL, 'data/ejemplos/documentos/DOC-009-v1.md', 'DOC-009-v1.md', 'text/markdown', 333, '46e396d54e986e0fcd018d9503fdef7b25df4b1480079fce6aa75448612890aa'),
    (13, 9, 2, 'publicada', '2025-09-23T15:00:00Z', NULL, '2025-09-23T15:00:00Z', NULL, 'data/ejemplos/documentos/DOC-009-v2.md', 'DOC-009-v2.md', 'text/markdown', 333, 'c72ed4cd41fd712c796705b8d0ea5b8f943ee340d4c787db6b41445947936cd3'),
    (14, 10, 1, 'publicada', '2025-07-25T15:00:00Z', NULL, '2025-07-25T15:00:00Z', NULL, 'data/ejemplos/documentos/DOC-010-v1.md', 'DOC-010-v1.md', 'text/markdown', 386, '98fc437ea4372e091cc5629e2b1c24b40a345d4844d8b9a1f9ddd3ce45c78f48');
INSERT INTO fragmento (id, version_id, posicion, titulo, contenido, pagina) VALUES
    (1, 1, 1, 'Alcance y aplicación', 'La ficha describe el uso previsto del artículo dentro del catálogo mayorista y las condiciones en que la distribuidora lo comercializa.', NULL),
    (2, 1, 2, 'Especificaciones técnicas', 'Se detallan medidas, materiales, tolerancias y requisitos de conservación declarados por el proveedor homologado.', NULL),
    (3, 2, 1, 'Alcance y aplicación', 'La ficha describe el uso previsto del artículo dentro del catálogo mayorista y las condiciones en que la distribuidora lo comercializa.', NULL),
    (4, 2, 2, 'Especificaciones técnicas', 'Se detallan medidas, materiales, tolerancias y requisitos de conservación declarados por el proveedor homologado.', NULL),
    (5, 3, 1, 'Alcance y aplicación', 'La ficha describe el uso previsto del artículo dentro del catálogo mayorista y las condiciones en que la distribuidora lo comercializa.', NULL),
    (6, 3, 2, 'Especificaciones técnicas', 'Se detallan medidas, materiales, tolerancias y requisitos de conservación declarados por el proveedor homologado.', NULL),
    (7, 3, 3, 'Condiciones de almacenamiento', 'El artículo debe estibarse en estanterías señalizadas, protegido de humedad y a distancia de fuentes de calor.', NULL),
    (8, 4, 1, 'Objetivo del procedimiento', 'Fijar los pasos que Operaciones debe seguir para encauzar el desvío y dejar registro trazable de cada decisión.', NULL),
    (9, 4, 2, 'Responsables intervinientes', 'El responsable de depósito inicia el circuito y coordina con distribución y atención al cliente según la criticidad.', NULL),
    (10, 5, 1, 'Objetivo del procedimiento', 'Fijar los pasos que Operaciones debe seguir para encauzar el desvío y dejar registro trazable de cada decisión.', NULL),
    (11, 5, 2, 'Responsables intervinientes', 'El responsable de depósito inicia el circuito y coordina con distribución y atención al cliente según la criticidad.', NULL),
    (12, 5, 3, 'Registro de la incidencia', 'Toda desviación se asienta con tipo, fecha y descripción, quedando asociada a la entrega afectada.', NULL),
    (13, 5, 4, 'Comunicación al cliente', 'El aviso se cursa dentro de las veinticuatro horas, informando la nueva fecha comprometida y su motivo.', NULL),
    (14, 6, 1, 'Objetivo del procedimiento', 'Fijar los pasos que Operaciones debe seguir para encauzar el desvío y dejar registro trazable de cada decisión.', NULL),
    (15, 6, 2, 'Responsables intervinientes', 'El responsable de depósito inicia el circuito y coordina con distribución y atención al cliente según la criticidad.', NULL),
    (16, 7, 1, 'Criterio general', 'La política fija los límites dentro de los cuales Comercial puede pactar condiciones sin autorización adicional.', NULL),
    (17, 7, 2, 'Escalas aplicables', 'Las escalas se calculan sobre el volumen acumulado del período y no son acumulables con acuerdos particulares.', NULL),
    (18, 8, 1, 'Criterio general', 'La política fija los límites dentro de los cuales Comercial puede pactar condiciones sin autorización adicional.', NULL),
    (19, 8, 2, 'Escalas aplicables', 'Las escalas se calculan sobre el volumen acumulado del período y no son acumulables con acuerdos particulares.', NULL),
    (20, 8, 3, 'Excepciones y autorizaciones', 'Cualquier condición fuera de escala requiere autorización expresa y queda registrada con su fundamento.', NULL),
    (21, 9, 1, 'Criterio general', 'La política fija los límites dentro de los cuales Comercial puede pactar condiciones sin autorización adicional.', NULL),
    (22, 9, 2, 'Escalas aplicables', 'Las escalas se calculan sobre el volumen acumulado del período y no son acumulables con acuerdos particulares.', NULL),
    (23, 10, 1, 'Alcance del control', 'El control abarca a los proveedores homologados que abastecen artículos críticos del catálogo.', NULL),
    (24, 10, 2, 'Evidencia requerida', 'Cada proveedor aporta certificados vigentes, informes de ensayo y constancias de las acciones correctivas.', NULL),
    (25, 11, 1, 'Alcance del control', 'El control abarca a los proveedores homologados que abastecen artículos críticos del catálogo.', NULL),
    (26, 11, 2, 'Evidencia requerida', 'Cada proveedor aporta certificados vigentes, informes de ensayo y constancias de las acciones correctivas.', NULL),
    (27, 12, 1, 'Objeto del contrato', 'El instrumento regula la relación de distribución, su territorio y las obligaciones recíprocas de las partes.', NULL),
    (28, 12, 2, 'Confidencialidad', 'La información intercambiada se considera reservada y no puede difundirse fuera del ámbito autorizado.', NULL),
    (29, 13, 1, 'Objeto del contrato', 'El instrumento regula la relación de distribución, su territorio y las obligaciones recíprocas de las partes.', NULL),
    (30, 13, 2, 'Confidencialidad', 'La información intercambiada se considera reservada y no puede difundirse fuera del ámbito autorizado.', NULL),
    (31, 14, 1, 'Alcance y aplicación', 'La ficha describe el uso previsto del artículo dentro del catálogo mayorista y las condiciones en que la distribuidora lo comercializa.', NULL),
    (32, 14, 2, 'Especificaciones técnicas', 'Se detallan medidas, materiales, tolerancias y requisitos de conservación declarados por el proveedor homologado.', NULL);

-- --- Embeddings -------------------------------------------------------
INSERT INTO embedding (id, fragmento_id, modelo_id, vector, generado_en) VALUES
    (1, 1, 1, '[0.42564269,0.07102313,0.01796157,-0.06577294,0.04250542,0.39846951,0.01795765,-0.04647060,-0.00995220,-0.05426707,0.42180553,0.10450933,0.10368704,0.03700571,0.01398093,0.24617939,-0.01223364,0.11763223,0.08037433,-0.03801074,0.27309905,0.03041421,-0.07154355,0.06475154,0.08230423,0.42691484,0.02318352,-0.06173518,0.04969435,0.10960401,0.25729317,0.02213339]', '2026-05-31T15:00:00Z'),
    (2, 2, 1, '[0.37949331,0.12300810,0.11497399,0.07561904,0.06079760,0.40359719,-0.00512521,0.05667721,-0.01092070,0.10833369,0.34434031,-0.03936689,-0.08104064,-0.09078409,0.02998732,0.37537901,-0.09392151,0.06487100,-0.08220830,-0.08027587,0.24913662,-0.02066423,0.02097505,-0.03243825,0.01446117,0.36422712,0.06838649,0.10442852,0.03503907,-0.04047930,0.34921000,-0.00329679]', '2026-05-31T15:00:00Z'),
    (3, 3, 1, '[0.27041173,0.05523114,-0.01566102,-0.00244407,0.10289524,0.26106882,0.05394510,0.05225223,-0.08399372,0.07133933,0.43474128,-0.07267267,-0.05351875,0.02668280,-0.06547997,0.29115742,0.00954461,0.10537303,-0.08055662,0.08990869,0.44762544,-0.07531591,0.05364016,0.02768381,-0.09466292,0.27016440,0.07723805,-0.04309744,-0.00353490,0.01390267,0.44964586,0.11187786]', '2026-05-31T15:00:00Z'),
    (4, 4, 1, '[0.30498228,-0.10379281,-0.00771666,0.12493988,0.08995337,0.33482764,0.06804476,0.07643671,0.08951593,0.05945328,0.38466937,-0.05733611,-0.05045627,-0.08985452,0.07773133,0.27932687,-0.02672494,-0.09191848,0.01365472,0.12317534,0.39566965,-0.09025136,0.02133553,0.10633777,-0.08737062,0.28105983,0.10893021,-0.00441227,0.12867093,0.03663949,0.40749596,-0.09449212]', '2026-05-31T15:00:00Z'),
    (5, 5, 1, '[0.26485005,0.05430509,0.03308067,-0.02423961,-0.03704715,0.40022722,-0.02474312,-0.03593030,-0.06696465,0.05157048,0.35128090,0.11687424,0.11842116,-0.09496472,0.04596379,0.37564313,-0.07408129,0.02672517,0.01941213,-0.06660112,0.32635512,-0.08126540,-0.04084335,-0.03146806,0.00381848,0.37108811,-0.02743036,0.12950461,0.08879228,0.02472271,0.39979816,0.03063345]', '2026-05-31T15:00:00Z'),
    (6, 6, 1, '[0.45385553,-0.07218115,0.10361662,-0.03566628,0.10624624,0.41088110,-0.06041014,-0.03174188,-0.04788552,-0.01786854,0.39841598,0.09789376,0.01902068,-0.03869513,0.11043302,0.25390432,0.04827158,0.09254526,-0.08568583,-0.01998476,0.27206667,0.12669293,-0.05901789,0.00459137,0.06447341,0.36968374,-0.07030016,0.11880638,0.06114879,-0.06186131,0.25055179,-0.01189112]', '2026-05-31T15:00:00Z'),
    (7, 7, 1, '[0.34093357,0.00172111,-0.07990590,-0.01198345,0.10761659,0.42923312,-0.08031281,-0.01342307,0.05480126,0.05161719,0.29909593,0.02909371,0.09533433,0.11619025,0.06898464,0.41946365,-0.03889681,-0.05451611,0.07959087,-0.05145463,0.31142879,-0.05096897,0.10580698,0.07590873,-0.00208159,0.36563096,0.06595063,-0.03649194,-0.05521126,0.05884340,0.30516877,-0.08055904]', '2026-05-31T15:00:00Z'),
    (8, 8, 1, '[0.01131264,0.29211700,0.11451181,-0.01658245,0.09194446,0.10364966,0.29749882,0.05495204,-0.00533340,-0.03295914,-0.08117101,0.42435451,-0.01623957,0.02023574,0.05944288,0.09727421,0.32244258,-0.09080965,0.10496692,-0.03696665,0.03664209,0.47280646,-0.08835352,0.04032547,-0.01749775,0.08408328,0.34669899,0.12967355,-0.07051717,0.11014491,-0.05336202,0.25635000]', '2026-05-31T15:00:00Z'),
    (9, 9, 1, '[0.00332715,0.36556838,0.08861938,0.06107061,0.11941416,0.07262406,0.29122811,0.00223119,0.12139682,0.11492631,0.04640409,0.39859989,-0.06837621,0.11015487,0.01968897,0.05647410,0.32096276,0.06345386,0.03057689,-0.05290085,0.05602203,0.33315668,0.07517897,-0.05700201,0.03395972,-0.00357591,0.43781800,-0.02710623,-0.04867770,0.08384149,0.04260659,0.32005708]', '2026-05-31T15:00:00Z'),
    (10, 10, 1, '[0.00426703,0.36866993,0.01893943,0.07868831,0.11381018,0.06647175,0.36512247,-0.02914270,0.05122427,0.04179487,-0.06940346,0.42711012,-0.03948659,-0.02351102,0.08140074,-0.05799195,0.23557761,0.11890709,0.04010602,0.07334992,0.00714919,0.41318315,0.03257759,0.06274687,-0.00795663,-0.00464221,0.25701014,0.05625024,0.09960633,0.09279342,0.09808499,0.39040601]', '2026-05-31T15:00:00Z'),
    (11, 11, 1, '[-0.04802528,0.44338060,0.06496957,0.01017118,0.03216423,0.11744595,0.28167001,-0.06827655,0.01019329,0.02594122,0.03252413,0.32807852,0.07902391,0.00496603,0.09317732,0.11141814,0.35400020,0.11493170,0.00575715,-0.06216134,0.10418816,0.35952571,0.07820127,0.09906459,-0.03417653,0.08433526,0.36770354,-0.04319239,0.00432633,0.06914599,-0.04431798,0.33247201]', '2026-05-31T15:00:00Z'),
    (12, 12, 1, '[0.10214376,0.24883651,-0.05866967,-0.00835733,-0.05824183,-0.04499283,0.32126798,-0.01965765,0.00960243,-0.07785925,0.08911402,0.31576643,0.07544299,0.11363502,-0.08711848,0.09946349,0.35611376,0.01199783,0.11291559,-0.02664939,-0.00685117,0.42457167,0.08972883,0.02526703,0.06782442,0.08195885,0.42590850,0.01443534,-0.03221296,0.01387471,-0.00709589,0.37630401]', '2026-05-31T15:00:00Z'),
    (13, 13, 1, '[0.07888747,0.37544977,0.08776296,0.10432167,0.11713948,0.02357329,0.41373694,0.03567642,0.05057394,-0.07074249,0.00146786,0.40534036,-0.05025641,-0.03382522,-0.01974701,0.00693321,0.29443681,0.09596193,-0.03003305,0.11095523,-0.00000875,0.39864856,0.01020312,0.06859682,-0.07741782,0.11110515,0.27070402,-0.07395406,0.11222936,-0.07989578,-0.08182915,0.27553553]', '2026-05-31T15:00:00Z'),
    (14, 14, 1, '[0.09463629,0.38278605,-0.04148312,0.01177327,-0.06961767,0.11922958,0.34736694,-0.03747245,-0.01194479,0.04176059,0.12285024,0.40477186,0.08071422,-0.05842862,-0.02505545,0.03559507,0.45247950,0.03494063,0.11022627,-0.01049184,0.11780503,0.28692980,0.03863458,0.09267450,-0.04050770,0.06244992,0.31032767,0.05951899,0.08699942,0.08489180,0.03270533,0.25129337]', '2026-05-31T15:00:00Z'),
    (15, 15, 1, '[0.02516201,0.39153710,-0.07984060,0.05115250,-0.09258807,-0.00035043,0.35275000,0.00269799,-0.01345247,0.10640176,0.00863333,0.27640489,-0.05557479,0.02267193,0.05181227,0.04399120,0.44997060,0.07992777,0.00979577,0.09149536,0.03868485,0.31473777,-0.03987196,0.11614765,-0.03230265,0.00660990,0.41167667,0.03356251,0.05582661,-0.01929170,0.01645940,0.31535123]', '2026-05-31T15:00:00Z'),
    (16, 16, 1, '[0.01787380,-0.01500873,0.35929793,-0.03363118,0.04478065,0.11512968,0.03478050,0.42328537,-0.05558230,-0.04312059,-0.00222408,0.03462818,0.35483138,0.01503538,0.07344214,0.00811858,-0.09864441,0.36818796,-0.00272626,-0.04263770,0.06157930,-0.01149181,0.43241387,-0.01775072,0.14399847,0.03344202,-0.01575556,0.40770640,-0.02695074,-0.04580075,0.07578137,-0.02473959]', '2026-05-31T15:00:00Z'),
    (17, 17, 1, '[0.07287811,0.11916669,0.41884269,-0.04981988,0.07192641,-0.03091275,0.03876326,0.43443071,0.04036644,0.12576138,0.09285092,-0.02651819,0.34556251,-0.02517822,0.06511961,-0.06427596,-0.08231707,0.27738473,-0.02743281,0.11765607,0.04950834,0.07508378,0.28808060,-0.08971676,-0.02916807,0.01408909,-0.01662396,0.48011691,-0.03625856,0.09932578,-0.06705684,-0.07790451]', '2026-05-31T15:00:00Z'),
    (18, 18, 1, '[0.01669997,0.03535414,0.41089579,-0.05768069,0.08656904,0.11675351,-0.07223792,0.31502462,0.03120916,0.00016817,0.03953358,0.04440994,0.43041796,-0.00766235,0.10786744,-0.02582438,0.03787068,0.35454011,0.03351842,-0.07769597,0.11915611,-0.06916384,0.42758369,0.04596237,-0.03297917,-0.07311150,-0.03840011,0.38148239,-0.05662944,-0.00150671,0.05993115,0.01192368]', '2026-05-31T15:00:00Z'),
    (19, 19, 1, '[-0.08664854,-0.02881763,0.33381566,0.10055614,-0.07792407,-0.04119606,-0.03414882,0.44893404,0.03947627,0.08794681,-0.04925605,-0.06805490,0.32070653,-0.06030991,-0.03390482,-0.06183864,-0.08053683,0.44924662,0.04066574,0.09255006,0.11449763,0.00537600,0.37591681,-0.02519873,-0.00291950,-0.03240764,0.02820097,0.36891297,0.04134320,0.10730578,0.07224278,0.04262833]', '2026-05-31T15:00:00Z'),
    (20, 20, 1, '[-0.08215036,-0.03932704,0.39356240,0.09386981,0.03621363,-0.08323000,0.07367568,0.42458922,0.03391999,0.07332742,-0.05065896,0.02183952,0.34462126,-0.02894444,0.12264131,0.00431898,0.08411150,0.45572382,0.01151571,-0.00148829,-0.01989688,-0.06554590,0.28527572,-0.00079298,0.01688469,0.05212755,-0.00315344,0.41174146,-0.07986594,-0.06903405,-0.03437650,-0.06315826]', '2026-05-31T15:00:00Z'),
    (21, 21, 1, '[0.08196269,0.10315952,0.46285189,-0.09506954,0.10418236,0.01068786,-0.08289410,0.39251427,0.04755807,0.01906830,0.00611278,-0.08348902,0.33482293,-0.06526673,-0.02923226,0.10681677,0.01590555,0.28016009,0.04925368,0.08810533,0.06755838,-0.02401789,0.27667291,-0.00170161,-0.04376588,0.09776525,-0.06929487,0.49088101,0.05331286,-0.05999800,0.11870613,-0.02835274]', '2026-05-31T15:00:00Z'),
    (22, 22, 1, '[0.06018267,0.00001766,0.34747347,0.01179026,0.00858751,-0.05618930,-0.04664986,0.37172821,0.06866635,-0.05787721,-0.07171856,0.07414132,0.42465351,-0.01567413,0.07726292,-0.03076150,-0.08567333,0.39801571,0.08758890,0.03414111,0.05074647,0.09335483,0.34001260,0.01430576,-0.01721711,0.07210709,-0.00792634,0.44093150,0.09425570,0.11732652,-0.03664830,-0.00673085]', '2026-05-31T15:00:00Z'),
    (23, 23, 1, '[0.09921726,-0.00104263,-0.02189428,0.37490025,0.11214662,-0.00769542,0.12903169,0.08489129,0.41521759,-0.05929060,0.12371973,-0.06511362,0.12383888,0.34315364,-0.07094172,0.09674621,-0.07108874,0.11147367,0.27185017,-0.06108079,0.10257699,0.12487544,-0.07669207,0.44438017,-0.03386354,0.04680517,-0.00403571,-0.07545647,0.34238146,0.05831158,0.02662044,0.12131368]', '2026-05-31T15:00:00Z'),
    (24, 24, 1, '[0.05154733,0.11510294,0.01768905,0.42256144,0.04926989,-0.04404692,0.06559289,-0.03121855,0.34610882,-0.07925591,0.13726821,0.08411782,0.07034573,0.31514563,-0.06072724,-0.02827117,-0.09423581,-0.02219734,0.30432184,-0.01388499,0.00372632,-0.04174815,-0.00081773,0.45689099,-0.05738850,-0.05860468,0.04732701,-0.00801298,0.45721633,0.02005917,0.04090544,-0.04467648]', '2026-05-31T15:00:00Z'),
    (25, 25, 1, '[0.04379198,0.00869253,0.04948713,0.41150862,0.00981101,-0.02514820,0.02582118,-0.06722202,0.42062664,0.11262864,-0.02288034,0.10758564,0.05410701,0.32450056,-0.02229630,0.11493572,0.08619273,-0.06076808,0.30964638,-0.01110963,-0.02352627,0.05587160,-0.07744129,0.39795354,-0.00385754,-0.08016558,0.08850180,0.07142666,0.42620983,0.09746679,0.06490420,0.08215863]', '2026-05-31T15:00:00Z'),
    (26, 26, 1, '[0.09821448,0.07259084,-0.03732666,0.40166307,-0.03956558,-0.04538205,-0.03319517,0.06852880,0.39472075,0.05347576,-0.05613014,-0.06411078,0.04271876,0.24805300,0.07518344,-0.07696338,-0.01018226,-0.05721143,0.42335876,-0.01786612,0.00001971,-0.04323399,0.07476086,0.41667711,-0.00998155,0.01740346,-0.02878323,-0.05053675,0.42424941,0.10652502,0.11119798,-0.02422754]', '2026-05-31T15:00:00Z'),
    (27, 27, 1, '[0.09777409,0.08355589,0.01137341,-0.07308604,0.41818984,-0.04078448,0.05606930,0.05565725,-0.00386671,0.43787244,0.03049476,-0.06986191,-0.00447635,-0.03243724,0.28268693,-0.01006116,0.07168935,-0.03293088,-0.00738793,0.39334784,-0.00944055,0.05574972,0.01204934,0.04386841,0.45880822,-0.01878134,0.04183452,0.04990806,0.04727596,0.35589608,0.06138862,0.05024911]', '2026-05-31T15:00:00Z'),
    (28, 28, 1, '[-0.06787480,-0.08408161,-0.08592990,0.13190142,0.29719638,-0.04103562,0.02775195,-0.00608005,-0.01008678,0.48652287,0.06386438,0.02835312,0.03906567,0.07070690,0.47198882,0.05442099,0.09503989,0.04549845,0.11897891,0.33437268,0.06245491,-0.04501872,0.00665517,-0.04073738,0.35321896,0.12849332,-0.01092213,0.11049100,0.05212726,0.28457014,-0.03170144,0.12560300]', '2026-05-31T15:00:00Z'),
    (29, 29, 1, '[0.11452415,0.08773494,-0.06948037,-0.04363278,0.39305837,0.11926357,-0.07830030,-0.01757681,0.12306833,0.42471212,-0.04511374,0.08894257,0.02979025,0.03669582,0.43030840,-0.03914869,0.07704187,0.08010566,0.03875589,0.31531795,0.12203969,0.12279069,0.02678717,0.08222401,0.27940108,0.09680423,-0.06086759,-0.01226850,0.08006011,0.38218985,-0.08576864,-0.03220159]', '2026-05-31T15:00:00Z'),
    (30, 30, 1, '[-0.06926594,0.00133310,-0.07241174,-0.08443204,0.39358815,-0.01280619,0.04277686,0.00878287,-0.04651910,0.43362238,0.07483105,0.11838731,0.05843166,-0.02730233,0.44039760,-0.09220877,0.13994484,0.10364053,0.00260806,0.31192386,0.07126952,0.00675680,0.11611123,-0.02238743,0.32161184,-0.06940199,0.05013223,0.04078481,0.07120988,0.37742132,0.04367094,-0.02891793]', '2026-05-31T15:00:00Z'),
    (31, 31, 1, '[0.37479730,0.00204684,0.08849089,-0.07317498,0.05552725,0.46344674,0.03090209,0.10573608,0.00201602,0.11111922,0.35294491,0.09666685,-0.00544929,0.07336874,-0.02597828,0.32881706,-0.03971288,0.12672204,0.06317557,0.01254422,0.27610245,-0.08009479,0.00244636,0.07693622,-0.01166248,0.28536642,-0.08614125,0.12744430,0.03336708,0.05917187,0.35222911,0.10766913]', '2026-05-31T15:00:00Z'),
    (32, 32, 1, '[0.46535019,0.00030813,0.11448161,-0.08574138,-0.03103353,0.31972695,-0.07366068,0.01987549,-0.06181738,0.01403298,0.44361027,-0.01656004,0.03119144,-0.07104676,-0.03313240,0.29973938,0.00173860,0.03228017,0.08010469,0.04635375,0.40370034,0.03130130,0.04340532,0.05471742,0.06297281,0.25405999,-0.03435955,0.07894120,0.11580049,-0.01634939,0.28937299,-0.06447622]', '2026-05-31T15:00:00Z'),
    (33, 1, 2, '[0.35878434,-0.18250728,0.12454744,0.23012180,-0.17236688,0.30076452,-0.04228084,-0.00685875,-0.14234138,-0.07180575,0.20650557,0.21621715,0.05834874,0.18966124,-0.14317803,0.40318865,-0.19157322,-0.17702090,-0.01167589,-0.02041038,0.33579418,-0.02490657,-0.11574227,0.01998771,-0.05646843,0.10886531,0.09584844,0.05693576,0.02665938,-0.07327748,0.15900356,0.23590052]', '2025-12-12T15:00:00Z'),
    (34, 8, 2, '[-0.20176936,0.16165040,0.23239636,0.14562848,0.14407393,-0.08736313,0.12048399,0.01401292,-0.01852009,-0.16549533,0.03117251,0.17417386,0.04391713,0.09721612,-0.05581019,-0.03489321,0.42375523,-0.01580719,-0.00433335,-0.19051686,-0.07585084,0.27127689,-0.03130903,0.08361087,-0.08732994,-0.03101192,0.53303909,-0.14468392,0.23351291,-0.00416630,0.10772817,0.23840199]', '2025-12-12T15:00:00Z'),
    (35, 17, 2, '[-0.01399121,-0.17117019,0.29095427,-0.03121848,-0.18409994,0.19210373,0.13285217,0.18923790,0.14867847,-0.18517728,0.07936779,0.03061533,0.17609327,0.14730567,-0.05466362,0.23376759,0.08517244,0.15413806,-0.17262327,-0.09985853,-0.13903786,-0.14883836,0.44463060,-0.18566476,0.23047472,0.07686133,-0.00104946,0.35179229,0.05382921,0.10212822,0.19757841,0.08400795]', '2025-12-12T15:00:00Z'),
    (36, 26, 2, '[0.23929316,-0.06573763,0.23213838,0.22665963,-0.01213977,0.00126872,0.07597815,0.15182825,0.35324811,-0.05252425,-0.18024889,-0.00203237,-0.19707185,0.25084725,-0.08235264,0.08208561,0.23507935,-0.17284258,0.35447135,-0.03756055,0.05250008,0.22443972,0.12542877,0.10014688,0.20366291,0.04851191,-0.12780331,0.06384758,0.31183730,0.22604501,-0.00719162,0.15855917]', '2025-12-12T15:00:00Z');

-- --- Vínculos documentales opcionales ---------------------------------
INSERT INTO documento_producto (documento_id, producto_id) VALUES
    (1, 1),
    (2, 5),
    (10, 9);
INSERT INTO documento_proveedor (documento_id, proveedor_id) VALUES
    (7, 1),
    (7, 3),
    (9, 4);

-- --- Acceso -----------------------------------------------------------
INSERT INTO actor (id, codigo, nombre, perfil_autorizado_id, activo) VALUES
    (1, 'ACT-001', 'Lucía Bengochea', 1, TRUE),
    (2, 'ACT-002', 'Rodrigo Paz', 1, TRUE),
    (3, 'ACT-003', 'Marina Duarte', 2, TRUE),
    (4, 'ACT-004', 'Esteban Correa', 2, TRUE),
    (5, 'ACT-005', 'Valeria Ibarra', 3, TRUE),
    (6, 'ACT-006', 'Hernán Vidal', 3, FALSE);
INSERT INTO permiso_documental (perfil_id, clase_id) VALUES
    (1, 1),
    (1, 2),
    (2, 1),
    (2, 3),
    (3, 1),
    (3, 2),
    (3, 4),
    (3, 5);

-- --- Interacción, evidencia y auditoría --------------------------------
INSERT INTO consulta (id, actor_id, perfil_efectivo_id, pregunta, instante) VALUES
    (1, 3, 2, '¿Qué condición comercial se aplica hoy al taladro percutor para el Corralón del Norte?', '2026-06-30T13:30:00Z'),
    (2, 1, 1, '¿Qué pedidos y entregas requieren atención esta semana?', '2026-06-30T13:45:00Z'),
    (3, 3, 2, '¿Cuál es el importe neto facturado por categoría de producto?', '2026-06-30T14:00:00Z'),
    (4, 3, 2, '¿Cuáles son los productos principales de cada segmento de cliente?', '2026-06-30T14:15:00Z'),
    (5, 3, 2, '¿Qué clientes no registran pedidos históricos?', '2026-06-30T14:30:00Z'),
    (6, 1, 1, '¿Cómo debo proceder ante una entrega demorada?', '2026-06-30T14:45:00Z'),
    (7, 1, 1, '¿Qué descuentos por volumen puedo ofrecer a un cliente mayorista?', '2026-06-30T15:00:00Z');
INSERT INTO respuesta (id, consulta_id, tipo_resultado, contenido, instante) VALUES
    (1, 1, 'exito', 'Se resolvió con datos operativos estructurados y se conserva el snapshot consultado.', '2026-06-30T13:30:02Z'),
    (2, 2, 'exito', 'Se resolvió con datos operativos estructurados y se conserva el snapshot consultado.', '2026-06-30T13:45:02Z'),
    (3, 3, 'exito', 'Se resolvió con datos operativos estructurados y se conserva el snapshot consultado.', '2026-06-30T14:00:02Z'),
    (4, 4, 'exito', 'Se resolvió con datos operativos estructurados y se conserva el snapshot consultado.', '2026-06-30T14:15:02Z'),
    (5, 5, 'exito', 'Se resolvió con datos operativos estructurados y se conserva el snapshot consultado.', '2026-06-30T14:30:02Z'),
    (6, 6, 'exito', 'Se recuperó el procedimiento vigente aplicable y se cita la fuente utilizada.', '2026-06-30T14:45:02Z'),
    (7, 7, 'sin_fuente_autorizada', 'No hay fuentes autorizadas para el perfil efectivo que respondan la consulta. No se expone contenido ni evidencia.', '2026-06-30T15:00:02Z');
INSERT INTO resultado_estructurado (id, tipo_consulta, parametros, contenido, generado_en, hash) VALUES
    (1, 'ESC-01', '{"escenario": "ESC-01", "instante_referencia": "2026-06-30T15:00:00Z"}', '{"escenario": "ESC-01", "filas": 2}', '2026-06-30T13:30:02Z', 'a6ccc1472461ba43418147318a5c1c2c69742a0a5e1610473f6839c648f48c38'),
    (2, 'ESC-02', '{"escenario": "ESC-02", "instante_referencia": "2026-06-30T15:00:00Z"}', '{"escenario": "ESC-02", "filas": 3}', '2026-06-30T13:45:02Z', '0e0ff255d818f682ec520bc412be20a2dd4b45d8090aac58899301b31709d501'),
    (3, 'ESC-03', '{"escenario": "ESC-03", "instante_referencia": "2026-06-30T15:00:00Z"}', '{"escenario": "ESC-03", "filas": 4}', '2026-06-30T14:00:02Z', 'a2e0d501b23b9593fa414abf40a4d51ab192e49466ac82c136b82e059c7c9b29'),
    (4, 'ESC-04', '{"escenario": "ESC-04", "instante_referencia": "2026-06-30T15:00:00Z"}', '{"escenario": "ESC-04", "filas": 5}', '2026-06-30T14:15:02Z', '5779edd673d5dc931054b58c784059b1853b4e9a1e1744031c3e7d262f489bbe'),
    (5, 'ESC-05', '{"escenario": "ESC-05", "instante_referencia": "2026-06-30T15:00:00Z"}', '{"escenario": "ESC-05", "filas": 6}', '2026-06-30T14:30:02Z', '30ab999d049b60ff851986fab03254f11515320359b731b533f39832724f0e8f');
INSERT INTO evidencia_documental (id, respuesta_id, embedding_id, ranking, score) VALUES
    (1, 6, 10, 1, 0.00476254),
    (2, 6, 13, 2, 0.09060761),
    (3, 6, 11, 3, 0.10655176);
INSERT INTO evidencia_estructurada (id, respuesta_id, resultado_estructurado_id) VALUES
    (1, 1, 1),
    (2, 2, 2),
    (3, 3, 3),
    (4, 4, 4),
    (5, 5, 5);
INSERT INTO evento_auditoria (id, actor_id, perfil_efectivo_id, instante, accion, resultado, recurso_tipo, recurso_id, consulta_id, respuesta_id, ranking, score, detalles) VALUES
    (1, 5, 3, '2025-07-24T15:00:00Z', 'carga_borrador', 'permitido', 'version_documental', 1, NULL, NULL, NULL, NULL, '{"documento": "DOC-001", "version": 1}'),
    (2, 5, 3, '2025-07-25T15:00:00Z', 'publicacion', 'permitido', 'version_documental', 1, NULL, NULL, NULL, NULL, '{"documento": "DOC-001", "version": 1}'),
    (3, 5, 3, '2025-07-24T15:00:00Z', 'carga_borrador', 'permitido', 'version_documental', 2, NULL, NULL, NULL, NULL, '{"documento": "DOC-002", "version": 1}'),
    (4, 5, 3, '2025-07-25T15:00:00Z', 'publicacion', 'permitido', 'version_documental', 2, NULL, NULL, NULL, NULL, '{"documento": "DOC-002", "version": 1}'),
    (5, 5, 3, '2025-09-23T15:00:00Z', 'sustitucion', 'permitido', 'version_documental', 2, NULL, NULL, NULL, NULL, '{"documento": "DOC-002", "version": 1}'),
    (6, 5, 3, '2025-09-22T15:00:00Z', 'carga_borrador', 'permitido', 'version_documental', 3, NULL, NULL, NULL, NULL, '{"documento": "DOC-002", "version": 2}'),
    (7, 5, 3, '2025-09-23T15:00:00Z', 'publicacion', 'permitido', 'version_documental', 3, NULL, NULL, NULL, NULL, '{"documento": "DOC-002", "version": 2}'),
    (8, 5, 3, '2025-07-24T15:00:00Z', 'carga_borrador', 'permitido', 'version_documental', 4, NULL, NULL, NULL, NULL, '{"documento": "DOC-003", "version": 1}'),
    (9, 5, 3, '2025-07-25T15:00:00Z', 'publicacion', 'permitido', 'version_documental', 4, NULL, NULL, NULL, NULL, '{"documento": "DOC-003", "version": 1}'),
    (10, 5, 3, '2025-09-23T15:00:00Z', 'sustitucion', 'permitido', 'version_documental', 4, NULL, NULL, NULL, NULL, '{"documento": "DOC-003", "version": 1}'),
    (11, 5, 3, '2025-09-22T15:00:00Z', 'carga_borrador', 'permitido', 'version_documental', 5, NULL, NULL, NULL, NULL, '{"documento": "DOC-003", "version": 2}'),
    (12, 5, 3, '2025-09-23T15:00:00Z', 'publicacion', 'permitido', 'version_documental', 5, NULL, NULL, NULL, NULL, '{"documento": "DOC-003", "version": 2}'),
    (13, 5, 3, '2025-07-24T15:00:00Z', 'carga_borrador', 'permitido', 'version_documental', 6, NULL, NULL, NULL, NULL, '{"documento": "DOC-004", "version": 1}'),
    (14, 5, 3, '2025-07-25T15:00:00Z', 'publicacion', 'permitido', 'version_documental', 6, NULL, NULL, NULL, NULL, '{"documento": "DOC-004", "version": 1}'),
    (15, 5, 3, '2025-07-24T15:00:00Z', 'carga_borrador', 'permitido', 'version_documental', 7, NULL, NULL, NULL, NULL, '{"documento": "DOC-005", "version": 1}'),
    (16, 5, 3, '2025-07-25T15:00:00Z', 'publicacion', 'permitido', 'version_documental', 7, NULL, NULL, NULL, NULL, '{"documento": "DOC-005", "version": 1}'),
    (17, 5, 3, '2025-09-23T15:00:00Z', 'sustitucion', 'permitido', 'version_documental', 7, NULL, NULL, NULL, NULL, '{"documento": "DOC-005", "version": 1}'),
    (18, 5, 3, '2025-09-22T15:00:00Z', 'carga_borrador', 'permitido', 'version_documental', 8, NULL, NULL, NULL, NULL, '{"documento": "DOC-005", "version": 2}'),
    (19, 5, 3, '2025-09-23T15:00:00Z', 'publicacion', 'permitido', 'version_documental', 8, NULL, NULL, NULL, NULL, '{"documento": "DOC-005", "version": 2}'),
    (20, 5, 3, '2025-07-24T15:00:00Z', 'carga_borrador', 'permitido', 'version_documental', 9, NULL, NULL, NULL, NULL, '{"documento": "DOC-006", "version": 1}'),
    (21, 5, 3, '2025-07-25T15:00:00Z', 'publicacion', 'permitido', 'version_documental', 9, NULL, NULL, NULL, NULL, '{"documento": "DOC-006", "version": 1}'),
    (22, 5, 3, '2025-10-23T15:00:00Z', 'revocacion', 'permitido', 'version_documental', 9, NULL, NULL, NULL, NULL, '{"documento": "DOC-006", "version": 1}'),
    (23, 5, 3, '2025-07-24T15:00:00Z', 'carga_borrador', 'permitido', 'version_documental', 10, NULL, NULL, NULL, NULL, '{"documento": "DOC-007", "version": 1}'),
    (24, 5, 3, '2025-07-25T15:00:00Z', 'publicacion', 'permitido', 'version_documental', 10, NULL, NULL, NULL, NULL, '{"documento": "DOC-007", "version": 1}'),
    (25, 5, 3, '2025-05-05T15:00:00Z', 'carga_borrador', 'permitido', 'version_documental', 11, NULL, NULL, NULL, NULL, '{"documento": "DOC-008", "version": 1}'),
    (26, 5, 3, '2025-07-24T15:00:00Z', 'carga_borrador', 'permitido', 'version_documental', 12, NULL, NULL, NULL, NULL, '{"documento": "DOC-009", "version": 1}'),
    (27, 5, 3, '2025-07-25T15:00:00Z', 'publicacion', 'permitido', 'version_documental', 12, NULL, NULL, NULL, NULL, '{"documento": "DOC-009", "version": 1}'),
    (28, 5, 3, '2025-09-23T15:00:00Z', 'sustitucion', 'permitido', 'version_documental', 12, NULL, NULL, NULL, NULL, '{"documento": "DOC-009", "version": 1}'),
    (29, 5, 3, '2025-09-22T15:00:00Z', 'carga_borrador', 'permitido', 'version_documental', 13, NULL, NULL, NULL, NULL, '{"documento": "DOC-009", "version": 2}'),
    (30, 5, 3, '2025-09-23T15:00:00Z', 'publicacion', 'permitido', 'version_documental', 13, NULL, NULL, NULL, NULL, '{"documento": "DOC-009", "version": 2}'),
    (31, 5, 3, '2025-07-24T15:00:00Z', 'carga_borrador', 'permitido', 'version_documental', 14, NULL, NULL, NULL, NULL, '{"documento": "DOC-010", "version": 1}'),
    (32, 5, 3, '2025-07-25T15:00:00Z', 'publicacion', 'permitido', 'version_documental', 14, NULL, NULL, NULL, NULL, '{"documento": "DOC-010", "version": 1}'),
    (33, 3, 2, '2026-06-30T13:30:00Z', 'consulta_iniciada', 'permitido', 'consulta', 1, 1, NULL, NULL, NULL, '{"escenario": "ESC-01"}'),
    (34, 3, 2, '2026-06-30T13:30:02Z', 'evidencia_utilizada', 'permitido', 'resultado_estructurado', 1, 1, 1, NULL, NULL, '{}'),
    (35, 3, 2, '2026-06-30T13:30:02Z', 'respuesta_generada', 'permitido', 'respuesta', 1, 1, 1, NULL, NULL, '{"tipo_resultado": "exito"}'),
    (36, 1, 1, '2026-06-30T13:45:00Z', 'consulta_iniciada', 'permitido', 'consulta', 2, 2, NULL, NULL, NULL, '{"escenario": "ESC-02"}'),
    (37, 1, 1, '2026-06-30T13:45:02Z', 'evidencia_utilizada', 'permitido', 'resultado_estructurado', 2, 2, 2, NULL, NULL, '{}'),
    (38, 1, 1, '2026-06-30T13:45:02Z', 'respuesta_generada', 'permitido', 'respuesta', 2, 2, 2, NULL, NULL, '{"tipo_resultado": "exito"}'),
    (39, 3, 2, '2026-06-30T14:00:00Z', 'consulta_iniciada', 'permitido', 'consulta', 3, 3, NULL, NULL, NULL, '{"escenario": "ESC-03"}'),
    (40, 3, 2, '2026-06-30T14:00:02Z', 'evidencia_utilizada', 'permitido', 'resultado_estructurado', 3, 3, 3, NULL, NULL, '{}'),
    (41, 3, 2, '2026-06-30T14:00:02Z', 'respuesta_generada', 'permitido', 'respuesta', 3, 3, 3, NULL, NULL, '{"tipo_resultado": "exito"}'),
    (42, 3, 2, '2026-06-30T14:15:00Z', 'consulta_iniciada', 'permitido', 'consulta', 4, 4, NULL, NULL, NULL, '{"escenario": "ESC-04"}'),
    (43, 3, 2, '2026-06-30T14:15:02Z', 'evidencia_utilizada', 'permitido', 'resultado_estructurado', 4, 4, 4, NULL, NULL, '{}'),
    (44, 3, 2, '2026-06-30T14:15:02Z', 'respuesta_generada', 'permitido', 'respuesta', 4, 4, 4, NULL, NULL, '{"tipo_resultado": "exito"}'),
    (45, 3, 2, '2026-06-30T14:30:00Z', 'consulta_iniciada', 'permitido', 'consulta', 5, 5, NULL, NULL, NULL, '{"escenario": "ESC-05"}'),
    (46, 3, 2, '2026-06-30T14:30:02Z', 'evidencia_utilizada', 'permitido', 'resultado_estructurado', 5, 5, 5, NULL, NULL, '{}'),
    (47, 3, 2, '2026-06-30T14:30:02Z', 'respuesta_generada', 'permitido', 'respuesta', 5, 5, 5, NULL, NULL, '{"tipo_resultado": "exito"}'),
    (48, 1, 1, '2026-06-30T14:45:00Z', 'consulta_iniciada', 'permitido', 'consulta', 6, 6, NULL, NULL, NULL, '{"escenario": "ESC-06"}'),
    (49, 1, 1, '2026-06-30T14:45:02Z', 'fragmento_recuperado', 'permitido', 'fragmento', 10, 6, 6, 1, 0.00476254, '{}'),
    (50, 1, 1, '2026-06-30T14:45:02Z', 'fragmento_recuperado', 'permitido', 'fragmento', 13, 6, 6, 2, 0.09060761, '{}'),
    (51, 1, 1, '2026-06-30T14:45:02Z', 'fragmento_recuperado', 'permitido', 'fragmento', 11, 6, 6, 3, 0.10655176, '{}'),
    (52, 1, 1, '2026-06-30T14:45:02Z', 'evidencia_utilizada', 'permitido', 'embedding', NULL, 6, 6, NULL, NULL, '{}'),
    (53, 1, 1, '2026-06-30T14:45:02Z', 'respuesta_generada', 'permitido', 'respuesta', 6, 6, 6, NULL, NULL, '{"tipo_resultado": "exito"}'),
    (54, 1, 1, '2026-06-30T15:00:00Z', 'consulta_iniciada', 'permitido', 'consulta', 7, 7, NULL, NULL, NULL, '{"escenario": "ESC-07"}'),
    (55, 1, 1, '2026-06-30T15:00:02Z', 'acceso_denegado', 'denegado', 'clase_documental', 3, 7, 7, NULL, NULL, '{"motivo": "perfil sin permiso sobre la clase documental"}'),
    (56, 1, 1, '2026-06-30T15:00:02Z', 'respuesta_generada', 'permitido', 'respuesta', 7, 7, 7, NULL, NULL, '{"tipo_resultado": "sin_fuente_autorizada"}');

-- --- Sincronización de secuencias --------------------------------------
SELECT setval(pg_get_serial_sequence('categoria_producto', 'id'), (SELECT COALESCE(max(id), 1) FROM categoria_producto));
SELECT setval(pg_get_serial_sequence('segmento_cliente', 'id'), (SELECT COALESCE(max(id), 1) FROM segmento_cliente));
SELECT setval(pg_get_serial_sequence('perfil_autorizado', 'id'), (SELECT COALESCE(max(id), 1) FROM perfil_autorizado));
SELECT setval(pg_get_serial_sequence('clase_documental', 'id'), (SELECT COALESCE(max(id), 1) FROM clase_documental));
SELECT setval(pg_get_serial_sequence('nivel_sensibilidad', 'id'), (SELECT COALESCE(max(id), 1) FROM nivel_sensibilidad));
SELECT setval(pg_get_serial_sequence('modelo_embedding', 'id'), (SELECT COALESCE(max(id), 1) FROM modelo_embedding));
SELECT setval(pg_get_serial_sequence('producto', 'id'), (SELECT COALESCE(max(id), 1) FROM producto));
SELECT setval(pg_get_serial_sequence('cliente', 'id'), (SELECT COALESCE(max(id), 1) FROM cliente));
SELECT setval(pg_get_serial_sequence('proveedor', 'id'), (SELECT COALESCE(max(id), 1) FROM proveedor));
SELECT setval(pg_get_serial_sequence('condicion_comercial', 'id'), (SELECT COALESCE(max(id), 1) FROM condicion_comercial));
SELECT setval(pg_get_serial_sequence('pedido', 'id'), (SELECT COALESCE(max(id), 1) FROM pedido));
SELECT setval(pg_get_serial_sequence('linea_pedido', 'id'), (SELECT COALESCE(max(id), 1) FROM linea_pedido));
SELECT setval(pg_get_serial_sequence('entrega', 'id'), (SELECT COALESCE(max(id), 1) FROM entrega));
SELECT setval(pg_get_serial_sequence('incidencia_operativa', 'id'), (SELECT COALESCE(max(id), 1) FROM incidencia_operativa));
SELECT setval(pg_get_serial_sequence('documento', 'id'), (SELECT COALESCE(max(id), 1) FROM documento));
SELECT setval(pg_get_serial_sequence('version_documental', 'id'), (SELECT COALESCE(max(id), 1) FROM version_documental));
SELECT setval(pg_get_serial_sequence('fragmento', 'id'), (SELECT COALESCE(max(id), 1) FROM fragmento));
SELECT setval(pg_get_serial_sequence('embedding', 'id'), (SELECT COALESCE(max(id), 1) FROM embedding));
SELECT setval(pg_get_serial_sequence('actor', 'id'), (SELECT COALESCE(max(id), 1) FROM actor));
SELECT setval(pg_get_serial_sequence('consulta', 'id'), (SELECT COALESCE(max(id), 1) FROM consulta));
SELECT setval(pg_get_serial_sequence('respuesta', 'id'), (SELECT COALESCE(max(id), 1) FROM respuesta));
SELECT setval(pg_get_serial_sequence('resultado_estructurado', 'id'), (SELECT COALESCE(max(id), 1) FROM resultado_estructurado));
SELECT setval(pg_get_serial_sequence('evidencia_documental', 'id'), (SELECT COALESCE(max(id), 1) FROM evidencia_documental));
SELECT setval(pg_get_serial_sequence('evidencia_estructurada', 'id'), (SELECT COALESCE(max(id), 1) FROM evidencia_estructurada));
SELECT setval(pg_get_serial_sequence('evento_auditoria', 'id'), (SELECT COALESCE(max(id), 1) FROM evento_auditoria));

COMMIT;
