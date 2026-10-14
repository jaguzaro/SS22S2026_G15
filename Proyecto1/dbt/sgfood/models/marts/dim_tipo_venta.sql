with combinaciones as (
    select canal, metodo_pago, estado
    from (values ('MAYORISTA'), ('TELEVENTA'), ('TIENDA'), ('WEB')) c(canal)
    cross join (values ('CRÉDITO'), ('EFECTIVO'), ('TARJETA'), ('TRANSFERENCIA')) m(metodo_pago)
    cross join (values ('ANULADA'), ('COMPLETADA'), ('PENDIENTE')) e(estado)
)

select
    (row_number() over (order by canal, metodo_pago, estado))::integer as id_tipo_venta,
    canal::varchar        as canal,
    metodo_pago::varchar  as metodo_pago,
    estado::varchar       as estado
from combinaciones

union all
select -1, 'DESCONOCIDO'::varchar, 'DESCONOCIDO'::varchar, 'DESCONOCIDO'::varchar