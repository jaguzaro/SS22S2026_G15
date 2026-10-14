select
    id_categoria::integer   as id_categoria,
    trim(nombre)::varchar   as nombre_categoria,
    _loaded_at
from {{ source('raw', 'categoria') }}
