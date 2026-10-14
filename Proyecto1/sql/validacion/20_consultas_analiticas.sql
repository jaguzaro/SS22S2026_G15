-- SG-Food · Consultas analíticas de validación (sobre el schema marts)
-- Convención: las medidas de ventas consideran solo estado COMPLETADA.

-- 1. Ventas reales vs meta por sucursal y mes
-- Nota: la suma de metas (9,257,592.56) es ~11 veces lo vendido (838,452.07);
-- no es un error de carga, las metas son un dato de entrada tal como se recibió.
WITH ventas AS (
    SELECT f.id_sucursal, d.periodo, SUM(f.subtotal) AS ventas_reales
    FROM marts.fct_ventas f
    JOIN marts.dim_fecha d ON d.id_fecha = f.id_fecha
    JOIN marts.dim_tipo_venta tv ON tv.id_tipo_venta = f.id_tipo_venta
    WHERE tv.estado = 'COMPLETADA'
    GROUP BY 1, 2
)
SELECT s.nombre_sucursal, m.periodo, m.meta_ventas,
       COALESCE(v.ventas_reales, 0) AS ventas_reales,
       ROUND(COALESCE(v.ventas_reales, 0) / NULLIF(m.meta_ventas, 0) * 100, 2) AS pct_cumplimiento
FROM marts.fct_metas_ventas m
JOIN marts.dim_sucursal s ON s.id_sucursal = m.id_sucursal
LEFT JOIN ventas v ON v.id_sucursal = m.id_sucursal AND v.periodo = m.periodo
ORDER BY m.periodo, s.nombre_sucursal;

-- Resultado: 48 filas (8 periodos x 6 sucursales), 2026-01 a 2026-08.
-- pct_cumplimiento minimo 3.39 (Amatitlan 2026-02), maximo 16.62 (Villa Nueva 2026-02).
-- Ejemplo: Amatitlan 2026-01 -> meta 199958.95, ventas_reales 18088.88, 9.05 %.
-- Suma de metas 9,257,592.56 vs ventas COMPLETADA 780,201.72: las metas son ~11x lo real.


-- 2. Top 10 productos por ingreso y por margen (precio vs costo de proveedor vigente)
SELECT p.nombre_producto,
       SUM(f.subtotal) AS ingreso,
       SUM(f.subtotal - f.cantidad * p.costo_proveedor_vigente) AS margen
FROM marts.fct_ventas f
JOIN marts.dim_producto p ON p.id_producto = f.id_producto
JOIN marts.dim_tipo_venta tv ON tv.id_tipo_venta = f.id_tipo_venta
WHERE tv.estado = 'COMPLETADA'
GROUP BY p.nombre_producto
ORDER BY ingreso DESC
LIMIT 10;

-- Resultado: 10 filas. Top 3: Palomitas 19516.00 (margen 4478.98),
-- Cloro 18337.30 (3124.34), Muffin chocolate 17660.10 (3892.03).


-- 2b. Top 10 por margen
SELECT p.nombre_producto,
       SUM(f.subtotal) AS ingreso,
       SUM(f.subtotal - f.cantidad * p.costo_proveedor_vigente) AS margen
FROM marts.fct_ventas f
JOIN marts.dim_producto p ON p.id_producto = f.id_producto
JOIN marts.dim_tipo_venta tv ON tv.id_tipo_venta = f.id_tipo_venta
WHERE tv.estado = 'COMPLETADA'
GROUP BY p.nombre_producto
ORDER BY margen DESC
LIMIT 10;
-- Resultado: 10 filas. Top 3: Atun en lata 6781.91 (ingreso 17512.35),
-- Jabon de platos 6059.81 (16839.26), Cepillo dental 5896.49 (15286.64).

-- 3. Ingreso por canal y método de pago (solo COMPLETADA)
SELECT tv.canal, tv.metodo_pago, SUM(f.subtotal) AS ingreso
FROM marts.fct_ventas f
JOIN marts.dim_tipo_venta tv ON tv.id_tipo_venta = f.id_tipo_venta
WHERE tv.estado = 'COMPLETADA'
GROUP BY 1, 2
ORDER BY 1, 2;
-- Resultado: 16 filas (4 canales x 4 metodos). Mayor: MAYORISTA/TRANSFERENCIA 91720.39.
-- Menor: TELEVENTA/CREDITO 19349.01. La suma de las 16 filas = 780201.72.

-- 4. Tasa de devolución por categoría y por motivo (unidades devueltas / vendidas)
WITH vendido AS (
    SELECT p.nombre_categoria, SUM(f.cantidad) AS unidades_vendidas
    FROM marts.fct_ventas f
    JOIN marts.dim_producto p ON p.id_producto = f.id_producto
    JOIN marts.dim_tipo_venta tv ON tv.id_tipo_venta = f.id_tipo_venta
    WHERE tv.estado = 'COMPLETADA'
    GROUP BY 1
)
SELECT p.nombre_categoria, d.motivo,
       SUM(d.cantidad) AS unidades_devueltas,
       ROUND(SUM(d.cantidad)::numeric / v.unidades_vendidas * 100, 2) AS tasa_pct
FROM marts.fct_devoluciones d
JOIN marts.dim_producto p ON p.id_producto = d.id_producto
JOIN vendido v ON v.nombre_categoria = p.nombre_categoria
GROUP BY p.nombre_categoria, d.motivo, v.unidades_vendidas
ORDER BY 1, 2;
-- Resultado: 33 filas (categoria x motivo). Mayor tasa: Lacteos/Producto danado 0.56 % (12 uds).
-- Menor: Congelados/Producto danado 0.04 % (1 ud). Total devuelto = 80 registros de devolucion.

-- 5. Productos bajo stock mínimo por sucursal en el último corte
SELECT s.nombre_sucursal, COUNT(*) AS productos_bajo_minimo
FROM marts.fct_inventario i
JOIN marts.dim_sucursal s ON s.id_sucursal = i.id_sucursal
WHERE i.bajo_stock_minimo
  AND i.id_fecha = (SELECT MAX(id_fecha) FROM marts.fct_inventario)
GROUP BY 1
ORDER BY 2 DESC;
-- Resultado: 6 filas, corte 2026-08-31. Central Guatemala 15, Escuintla 11, Antigua 9,
-- Villa Nueva 8, Amatitlan 4, Mixco 3 (total 50 productos bajo minimo en el ultimo corte).

-- 6. Ventas en periodos con promoción vs sin promoción, por categoría
SELECT p.nombre_categoria,
       CASE WHEN f.id_promocion = -1 THEN 'SIN PROMOCION' ELSE 'CON PROMOCION' END AS tipo,
       COUNT(*) AS lineas,
       SUM(f.subtotal) AS ingreso
FROM marts.fct_ventas f
JOIN marts.dim_producto p ON p.id_producto = f.id_producto
JOIN marts.dim_tipo_venta tv ON tv.id_tipo_venta = f.id_tipo_venta
WHERE tv.estado = 'COMPLETADA'
GROUP BY 1, 2
ORDER BY 1, 2;
-- Resultado: 16 filas (8 categorias x CON/SIN PROMOCION). Mayor ingreso con promocion:
-- Snacks 44391.98 (144 lineas). Lineas totales COMPLETADA = 3014 (ver suma de columna lineas).