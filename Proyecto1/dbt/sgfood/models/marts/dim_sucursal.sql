select
    id_sucursal,
    nombre_sucursal::varchar as nombre_sucursal,
    ciudad::varchar          as ciudad,
    departamento::varchar    as departamento
from {{ ref('stg_sucursal') }}

union all
select -1, 'DESCONOCIDO'::varchar, 'DESCONOCIDO'::varchar, 'DESCONOCIDO'::varchar