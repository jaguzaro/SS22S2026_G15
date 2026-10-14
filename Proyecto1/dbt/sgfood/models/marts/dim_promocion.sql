select
    pr.id_promocion,
    pr.nombre_promocion::varchar   as nombre_promocion,
    pr.fecha_inicio,
    pr.fecha_fin,
    pr.id_categoria,
    c.nombre_categoria::varchar    as nombre_categoria,
    pr.porcentaje_descuento
from {{ ref('stg_promociones') }} pr
left join {{ ref('stg_categoria') }} c on pr.id_categoria = c.id_categoria

union all
select -1, 'SIN PROMOCION'::varchar, null::date, null::date, null::integer,
       'DESCONOCIDO'::varchar, null::numeric(5,4)