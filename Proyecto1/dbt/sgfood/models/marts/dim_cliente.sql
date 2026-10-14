select
    id_cliente,
    nit::varchar              as nit,
    nombre_cliente::varchar   as nombre_cliente,
    tipo_cliente::varchar     as tipo_cliente,
    municipio::varchar        as municipio,
    departamento::varchar     as departamento,
    fecha_alta
from {{ ref('stg_cliente') }}

union all
select -1, 'DESCONOCIDO'::varchar, 'DESCONOCIDO'::varchar, 'DESCONOCIDO'::varchar,
       'DESCONOCIDO'::varchar, 'DESCONOCIDO'::varchar, null::date