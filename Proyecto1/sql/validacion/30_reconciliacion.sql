WITH ventas_raw AS (
    SELECT d.id_venta, d.cantidad, d.subtotal, v.estado
    FROM raw.venta_detalle d
    JOIN raw.venta v USING (id_venta)
),
ventas_marts AS (
    SELECT f.id_venta, f.cantidad, f.subtotal, t.estado,
           f.id_fecha, f.id_cliente, f.id_sucursal, f.id_producto, f.id_tipo_venta
    FROM marts.fct_ventas f
    JOIN marts.dim_tipo_venta t USING (id_tipo_venta)
)
SELECT  1 AS orden, 'fct_ventas: lineas' AS control,
        (SELECT count(*) FROM raw.venta_detalle)::numeric AS esperado,
        (SELECT count(*) FROM marts.fct_ventas)::numeric AS obtenido
UNION ALL
SELECT  2, 'fct_ventas: ventas distintas',
        (SELECT count(*) FROM raw.venta),
        (SELECT count(DISTINCT id_venta) FROM marts.fct_ventas)
UNION ALL
SELECT  3, 'fct_ventas: suma subtotal',
        (SELECT sum(subtotal) FROM raw.venta_detalle),
        (SELECT sum(subtotal) FROM marts.fct_ventas)
UNION ALL
SELECT  4, 'fct_ventas: suma cantidad',
        (SELECT sum(cantidad) FROM raw.venta_detalle),
        (SELECT sum(cantidad) FROM marts.fct_ventas)
UNION ALL
SELECT  5, 'fct_ventas: subtotal COMPLETADA',
        (SELECT sum(subtotal) FROM ventas_raw WHERE estado = 'COMPLETADA'),
        (SELECT sum(subtotal) FROM ventas_marts WHERE estado = 'COMPLETADA')
UNION ALL
SELECT  6, 'fct_ventas: lineas con dimension desconocida',
        0,
        (SELECT count(*) FROM ventas_marts
         WHERE -1 IN (id_fecha, id_cliente, id_sucursal, id_producto, id_tipo_venta))
UNION ALL
SELECT  7, 'fct_inventario: filas',
        (SELECT count(*) FROM raw.inventario_bodega),
        (SELECT count(*) FROM marts.fct_inventario)
UNION ALL
SELECT  8, 'fct_inventario: suma stock_disponible',
        (SELECT sum(stock_disponible) FROM raw.inventario_bodega),
        (SELECT sum(stock_disponible) FROM marts.fct_inventario)
UNION ALL
SELECT  9, 'fct_devoluciones: filas',
        (SELECT count(*) FROM raw.devoluciones),
        (SELECT count(*) FROM marts.fct_devoluciones)
UNION ALL
SELECT 10, 'fct_devoluciones: suma cantidad',
        (SELECT sum(cantidad) FROM raw.devoluciones),
        (SELECT sum(cantidad) FROM marts.fct_devoluciones)
UNION ALL
SELECT 11, 'fct_metas_ventas: filas',
        (SELECT count(*) FROM raw.metas_ventas),
        (SELECT count(*) FROM marts.fct_metas_ventas)
UNION ALL
SELECT 12, 'fct_metas_ventas: suma meta_ventas',
        (SELECT sum(meta_ventas) FROM raw.metas_ventas),
        (SELECT sum(meta_ventas) FROM marts.fct_metas_ventas)
UNION ALL
SELECT 13, 'dim_sucursal: miembros',
        (SELECT count(*) FROM raw.sucursal),
        (SELECT count(*) FROM marts.dim_sucursal WHERE id_sucursal <> -1)
UNION ALL
SELECT 14, 'dim_producto: miembros',
        (SELECT count(*) FROM raw.producto),
        (SELECT count(*) FROM marts.dim_producto WHERE id_producto <> -1)
UNION ALL
SELECT 15, 'dim_cliente: miembros',
        (SELECT count(*) FROM raw.cliente),
        (SELECT count(*) FROM marts.dim_cliente WHERE id_cliente <> -1)
UNION ALL
SELECT 16, 'dim_promocion: miembros',
        (SELECT count(*) FROM raw.promociones),
        (SELECT count(*) FROM marts.dim_promocion WHERE id_promocion <> -1)
UNION ALL
SELECT 17, 'dim_proveedor: miembros',
        (SELECT count(DISTINCT id_proveedor) FROM raw.proveedores_precios),
        (SELECT count(*) FROM marts.dim_proveedor WHERE id_proveedor <> -1)
ORDER BY orden;
