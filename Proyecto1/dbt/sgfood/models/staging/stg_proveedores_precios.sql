select
    id_proveedor::integer           as id_proveedor,
    trim(proveedor)::varchar        as nombre_proveedor,
    id_producto::integer            as id_producto,
    costo_proveedor::numeric(12,2)  as costo_proveedor,
    plazo_dias::integer             as plazo_dias,
    fecha_vigencia::date            as fecha_vigencia,
    _loaded_at
from {{ source('raw', 'proveedores_precios') }}