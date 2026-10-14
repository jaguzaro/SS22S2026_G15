select
    d.id_devolucion,
    d.id_venta,
    coalesce(f.id_fecha, -1)       as id_fecha,
    coalesce(p.id_producto, -1)    as id_producto,
    coalesce(s.id_sucursal, -1)    as id_sucursal,
    d.cantidad,
    d.motivo
from {{ ref('stg_devoluciones') }} d
left join {{ ref('stg_venta') }} v on v.id_venta = d.id_venta
left join {{ ref('dim_fecha') }} f on f.fecha = d.fecha
left join {{ ref('dim_producto') }} p on p.id_producto = d.id_producto
left join {{ ref('dim_sucursal') }} s on s.id_sucursal = v.id_sucursal