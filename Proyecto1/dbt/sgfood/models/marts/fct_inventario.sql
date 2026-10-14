select
    coalesce(f.id_fecha, -1)       as id_fecha,
    coalesce(s.id_sucursal, -1)    as id_sucursal,
    coalesce(p.id_producto, -1)    as id_producto,
    i.stock_disponible,
    i.stock_minimo,
    i.stock_maximo,
    (i.stock_disponible < i.stock_minimo)  as bajo_stock_minimo,
    i.lote,
    i.fecha_vencimiento
from {{ ref('stg_inventario_bodega') }} i
left join {{ ref('dim_fecha') }} f on f.fecha = i.fecha_corte
left join {{ ref('dim_sucursal') }} s on s.id_sucursal = i.id_sucursal
left join {{ ref('dim_producto') }} p on p.id_producto = i.id_producto