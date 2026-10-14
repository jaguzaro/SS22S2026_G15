with vendido as (
    select id_venta, id_producto, sum(cantidad) as cantidad_vendida
    from {{ ref('int_ventas_lineas') }}
    group by 1, 2
),
devuelto as (
    select id_venta, id_producto, sum(cantidad) as cantidad_devuelta
    from {{ ref('stg_devoluciones') }}
    group by 1, 2
)
select d.id_venta, d.id_producto, d.cantidad_devuelta, v.cantidad_vendida
from devuelto d
left join vendido v
    on d.id_venta = v.id_venta and d.id_producto = v.id_producto
where v.cantidad_vendida is null
   or d.cantidad_devuelta > v.cantidad_vendida
   