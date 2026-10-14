select
    coalesce(f.id_fecha, -1)       as id_fecha,
    coalesce(s.id_sucursal, -1)    as id_sucursal,
    m.periodo,
    m.meta_ventas,
    m.meta_unidades
from {{ ref('stg_metas_ventas') }} m
left join {{ ref('dim_fecha') }} f on f.fecha = m.fecha_periodo
left join {{ ref('dim_sucursal') }} s on s.id_sucursal = m.id_sucursal