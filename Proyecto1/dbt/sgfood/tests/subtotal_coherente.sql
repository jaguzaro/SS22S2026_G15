select id_detalle, cantidad, precio_unitario, descuento, subtotal
from {{ ref('stg_venta_detalle') }}
where abs(subtotal - round(cantidad * precio_unitario * (1 - descuento), 2)) > 0.01