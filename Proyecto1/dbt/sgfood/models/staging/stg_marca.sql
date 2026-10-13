select
    id_marca::integer       as id_marca,
    trim(nombre)::varchar   as nombre_marca,
    _loaded_at
from {{ source('raw', 'marca') }}
