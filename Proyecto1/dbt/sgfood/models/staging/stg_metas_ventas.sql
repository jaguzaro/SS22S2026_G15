select
    trim(periodo)::varchar                          as periodo,
    to_date(trim(periodo) || '-01', 'YYYY-MM-DD')   as fecha_periodo,
    id_sucursal::integer                            as id_sucursal,
    meta_ventas::numeric(14,2)                      as meta_ventas,
    meta_unidades::integer                          as meta_unidades,
    _loaded_at
from {{ source('raw', 'metas_ventas') }}