select
    id_producto::integer          as id_producto,
    trim(sku)::varchar            as sku,
    trim(nombre)::varchar         as nombre_producto,
    id_categoria::integer         as id_categoria,
    id_marca::integer             as id_marca,
    trim(unidad_medida)::varchar  as unidad_medida,
    costo_base::numeric(12,2)     as costo_base,
    precio_lista::numeric(12,2)   as precio_lista,
    activo::boolean               as activo,
    _loaded_at
from {{ source('raw', 'producto') }}