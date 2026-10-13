SELECT  1 AS orden, 'sucursal' AS tabla, count(*) AS filas,
       count(DISTINCT _loaded_at) AS cargas_distintas, max(_loaded_at) AS ultima_carga,
       count(*) FILTER (WHERE _source IS NULL OR _loaded_at IS NULL) AS filas_sin_auditoria
FROM raw.sucursal
UNION ALL
SELECT  2 AS orden, 'categoria' AS tabla, count(*) AS filas,
       count(DISTINCT _loaded_at) AS cargas_distintas, max(_loaded_at) AS ultima_carga,
       count(*) FILTER (WHERE _source IS NULL OR _loaded_at IS NULL) AS filas_sin_auditoria
FROM raw.categoria
UNION ALL
SELECT  3 AS orden, 'marca' AS tabla, count(*) AS filas,
       count(DISTINCT _loaded_at) AS cargas_distintas, max(_loaded_at) AS ultima_carga,
       count(*) FILTER (WHERE _source IS NULL OR _loaded_at IS NULL) AS filas_sin_auditoria
FROM raw.marca
UNION ALL
SELECT  4 AS orden, 'producto' AS tabla, count(*) AS filas,
       count(DISTINCT _loaded_at) AS cargas_distintas, max(_loaded_at) AS ultima_carga,
       count(*) FILTER (WHERE _source IS NULL OR _loaded_at IS NULL) AS filas_sin_auditoria
FROM raw.producto
UNION ALL
SELECT  5 AS orden, 'cliente' AS tabla, count(*) AS filas,
       count(DISTINCT _loaded_at) AS cargas_distintas, max(_loaded_at) AS ultima_carga,
       count(*) FILTER (WHERE _source IS NULL OR _loaded_at IS NULL) AS filas_sin_auditoria
FROM raw.cliente
UNION ALL
SELECT  6 AS orden, 'venta' AS tabla, count(*) AS filas,
       count(DISTINCT _loaded_at) AS cargas_distintas, max(_loaded_at) AS ultima_carga,
       count(*) FILTER (WHERE _source IS NULL OR _loaded_at IS NULL) AS filas_sin_auditoria
FROM raw.venta
UNION ALL
SELECT  7 AS orden, 'venta_detalle' AS tabla, count(*) AS filas,
       count(DISTINCT _loaded_at) AS cargas_distintas, max(_loaded_at) AS ultima_carga,
       count(*) FILTER (WHERE _source IS NULL OR _loaded_at IS NULL) AS filas_sin_auditoria
FROM raw.venta_detalle
UNION ALL
SELECT  8 AS orden, 'inventario_bodega' AS tabla, count(*) AS filas,
       count(DISTINCT _loaded_at) AS cargas_distintas, max(_loaded_at) AS ultima_carga,
       count(*) FILTER (WHERE _source IS NULL OR _loaded_at IS NULL) AS filas_sin_auditoria
FROM raw.inventario_bodega
UNION ALL
SELECT  9 AS orden, 'proveedores_precios' AS tabla, count(*) AS filas,
       count(DISTINCT _loaded_at) AS cargas_distintas, max(_loaded_at) AS ultima_carga,
       count(*) FILTER (WHERE _source IS NULL OR _loaded_at IS NULL) AS filas_sin_auditoria
FROM raw.proveedores_precios
UNION ALL
SELECT 10 AS orden, 'promociones' AS tabla, count(*) AS filas,
       count(DISTINCT _loaded_at) AS cargas_distintas, max(_loaded_at) AS ultima_carga,
       count(*) FILTER (WHERE _source IS NULL OR _loaded_at IS NULL) AS filas_sin_auditoria
FROM raw.promociones
UNION ALL
SELECT 11 AS orden, 'metas_ventas' AS tabla, count(*) AS filas,
       count(DISTINCT _loaded_at) AS cargas_distintas, max(_loaded_at) AS ultima_carga,
       count(*) FILTER (WHERE _source IS NULL OR _loaded_at IS NULL) AS filas_sin_auditoria
FROM raw.metas_ventas
UNION ALL
SELECT 12 AS orden, 'devoluciones' AS tabla, count(*) AS filas,
       count(DISTINCT _loaded_at) AS cargas_distintas, max(_loaded_at) AS ultima_carga,
       count(*) FILTER (WHERE _source IS NULL OR _loaded_at IS NULL) AS filas_sin_auditoria
FROM raw.devoluciones
ORDER BY orden;
