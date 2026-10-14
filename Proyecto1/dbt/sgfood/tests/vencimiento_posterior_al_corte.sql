select fecha_corte, id_sucursal, id_producto, fecha_vencimiento
from {{ ref('stg_inventario_bodega') }}
where fecha_vencimiento < fecha_corte
