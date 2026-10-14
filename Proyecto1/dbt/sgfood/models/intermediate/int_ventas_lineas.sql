select
    d.id_detalle,
    d.id_venta,
    v.fecha,
    v.id_cliente,
    v.id_sucursal,
    d.id_producto,
    v.canal,
    v.metodo_pago,
    v.estado,
    d.cantidad,
    d.precio_unitario,
    d.descuento,
    d.subtotal
from {{ ref('stg_venta_detalle') }} d
left join {{ ref('stg_venta') }} v
    on d.id_venta = v.id_venta