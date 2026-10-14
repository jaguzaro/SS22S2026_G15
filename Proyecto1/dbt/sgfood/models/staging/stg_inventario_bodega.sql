select
    fecha_corte::date          as fecha_corte,
    id_sucursal::integer       as id_sucursal,
    id_producto::integer       as id_producto,
    stock_disponible::integer  as stock_disponible,
    stock_minimo::integer      as stock_minimo,
    stock_maximo::integer      as stock_maximo,
    trim(lote)::varchar        as lote,
    fecha_vencimiento::date    as fecha_vencimiento,
    _loaded_at
from {{ source('raw', 'inventario_bodega') }}
