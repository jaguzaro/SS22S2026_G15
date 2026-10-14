select
    p.id_producto,
    p.sku::varchar                           as sku,
    p.nombre_producto::varchar               as nombre_producto,
    p.id_categoria,
    c.nombre_categoria::varchar              as nombre_categoria,
    p.id_marca,
    m.nombre_marca::varchar                  as nombre_marca,
    p.unidad_medida::varchar                 as unidad_medida,
    p.costo_base,
    p.precio_lista,
    p.activo,
    cp.id_proveedor                          as id_proveedor_vigente,
    cp.costo_proveedor                       as costo_proveedor_vigente
from {{ ref('stg_producto') }} p
left join {{ ref('stg_categoria') }} c on p.id_categoria = c.id_categoria
left join {{ ref('stg_marca') }} m on p.id_marca = m.id_marca
left join {{ ref('int_costo_proveedor_vigente') }} cp on p.id_producto = cp.id_producto

union all
select -1, 'DESCONOCIDO'::varchar, 'DESCONOCIDO'::varchar, null::integer,
       'DESCONOCIDO'::varchar, null::integer, 'DESCONOCIDO'::varchar,
       'DESCONOCIDO'::varchar, null::numeric(12,2), null::numeric(12,2),
       null::boolean, null::integer, null::numeric(12,2)