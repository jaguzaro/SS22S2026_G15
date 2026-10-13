select
    id_promocion::integer                as id_promocion,
    trim(nombre)::varchar                as nombre_promocion,
    fecha_inicio::date                   as fecha_inicio,
    fecha_fin::date                      as fecha_fin,
    id_categoria::integer                as id_categoria,
    porcentaje_descuento::numeric(5,4)   as porcentaje_descuento,
    _loaded_at
from {{ source('raw', 'promociones') }}
