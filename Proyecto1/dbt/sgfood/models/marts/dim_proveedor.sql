select
    id_proveedor,
    min(nombre_proveedor)::varchar as nombre_proveedor
from {{ ref('stg_proveedores_precios') }}
group by id_proveedor

union all
select -1, 'DESCONOCIDO'::varchar