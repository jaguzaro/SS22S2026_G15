with ranked as (
    select
        id_producto,
        id_proveedor,
        nombre_proveedor,
        costo_proveedor,
        plazo_dias,
        fecha_vigencia,
        row_number() over (
            partition by id_producto
            order by fecha_vigencia desc, costo_proveedor asc, id_proveedor asc
        ) as rn
    from {{ ref('stg_proveedores_precios') }}
)

select
    id_producto,
    id_proveedor,
    nombre_proveedor,
    costo_proveedor,
    plazo_dias,
    fecha_vigencia
from ranked
where rn = 1