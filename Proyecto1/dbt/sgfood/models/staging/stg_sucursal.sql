select
    id_sucursal::integer         as id_sucursal,
    trim(nombre)::varchar        as nombre_sucursal,
    trim(ciudad)::varchar        as ciudad,
    trim(departamento)::varchar  as departamento,
    _loaded_at
from {{ source('raw', 'sucursal') }}