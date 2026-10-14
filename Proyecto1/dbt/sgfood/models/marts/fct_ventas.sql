select
    l.id_detalle,
    l.id_venta,
    coalesce(f.id_fecha, -1)                       as id_fecha,
    coalesce(c.id_cliente, -1)                     as id_cliente,
    coalesce(s.id_sucursal, -1)                    as id_sucursal,
    coalesce(p.id_producto, -1)                    as id_producto,
    coalesce(tv.id_tipo_venta, -1)                 as id_tipo_venta,
    coalesce(pr.id_promocion, -1)                  as id_promocion,
    l.cantidad,
    l.precio_unitario,
    l.descuento,
    l.subtotal
from {{ ref('int_ventas_lineas') }} l
left join {{ ref('int_promocion_por_linea') }} ip on l.id_detalle = ip.id_detalle
left join {{ ref('dim_fecha') }} f on f.fecha = l.fecha
left join {{ ref('dim_cliente') }} c on c.id_cliente = l.id_cliente
left join {{ ref('dim_sucursal') }} s on s.id_sucursal = l.id_sucursal
left join {{ ref('dim_producto') }} p on p.id_producto = l.id_producto
left join {{ ref('dim_tipo_venta') }} tv
    on tv.canal = l.canal and tv.metodo_pago = l.metodo_pago and tv.estado = l.estado
left join {{ ref('dim_promocion') }} pr on pr.id_promocion = ip.id_promocion
