with lineas as (
    select
        l.id_detalle,
        l.fecha,
        p.id_categoria
    from {{ ref('int_ventas_lineas') }} l
    left join {{ ref('stg_producto') }} p
        on l.id_producto = p.id_producto
),

candidatas as (
    select
        l.id_detalle,
        pr.id_promocion,
        pr.porcentaje_descuento,
        row_number() over (
            partition by l.id_detalle
            order by pr.porcentaje_descuento desc, pr.id_promocion asc
        ) as rn
    from lineas l
    inner join {{ ref('stg_promociones') }} pr
        on pr.id_categoria = l.id_categoria
       and l.fecha between pr.fecha_inicio and pr.fecha_fin
)

select
    l.id_detalle,
    c.id_promocion,
    c.porcentaje_descuento as porcentaje_descuento_promo
from lineas l
left join candidatas c
    on l.id_detalle = c.id_detalle
   and c.rn = 1
