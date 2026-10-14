select d.id_devolucion, d.fecha as fecha_devolucion, v.fecha as fecha_venta
from {{ ref('stg_devoluciones') }} d
join {{ ref('stg_venta') }} v on d.id_venta = v.id_venta
where d.fecha < v.fecha