select
    id_venta::bigint           as id_venta,
    fecha::date                as fecha,
    id_cliente::integer        as id_cliente,
    id_sucursal::integer       as id_sucursal,
    upper(trim(canal))         as canal,
    upper(trim(metodo_pago))   as metodo_pago,
    upper(trim(estado))        as estado,
    _loaded_at
from {{ source('raw', 'venta') }}
