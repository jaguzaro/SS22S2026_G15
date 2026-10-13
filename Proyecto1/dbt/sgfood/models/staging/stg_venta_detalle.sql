select
    id_detalle::bigint              as id_detalle,
    id_venta::bigint                as id_venta,
    id_producto::integer            as id_producto,
    cantidad::integer               as cantidad,
    precio_unitario::numeric(12,2)  as precio_unitario,
    descuento::numeric(5,4)         as descuento,
    subtotal::numeric(14,2)         as subtotal,
    _loaded_at
from {{ source('raw', 'venta_detalle') }}
