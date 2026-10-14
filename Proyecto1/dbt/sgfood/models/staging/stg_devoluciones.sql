select
    id_devolucion::integer   as id_devolucion,
    fecha::date              as fecha,
    id_venta::bigint         as id_venta,
    id_producto::integer     as id_producto,
    cantidad::integer        as cantidad,
    trim(motivo)::varchar    as motivo,
    _loaded_at
from {{ source('raw', 'devoluciones') }}
