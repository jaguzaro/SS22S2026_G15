select
    id_cliente::integer             as id_cliente,
    trim(nit)::varchar              as nit,
    trim(nombre)::varchar           as nombre_cliente,
    upper(trim(tipo_cliente))       as tipo_cliente,
    trim(municipio)::varchar        as municipio,
    trim(departamento)::varchar     as departamento,
    fecha_alta::date                as fecha_alta,
    _loaded_at
from {{ source('raw', 'cliente') }}
