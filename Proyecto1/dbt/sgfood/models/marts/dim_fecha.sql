with calendario as (
    select d::date as fecha
    from generate_series('2024-01-01'::date, '2028-12-31'::date, interval '1 day') as d
),

base as (
    select
        to_char(fecha, 'YYYYMMDD')::integer                  as id_fecha,
        fecha,
        extract(year from fecha)::integer                    as anio,
        extract(quarter from fecha)::integer                 as trimestre,
        extract(month from fecha)::integer                   as mes,
        (array['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio',
               'Agosto','Septiembre','Octubre','Noviembre','Diciembre'])
            [extract(month from fecha)::integer]::varchar    as nombre_mes,
        extract(day from fecha)::integer                     as dia,
        extract(isodow from fecha)::integer                  as dia_semana,
        (array['Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'])
            [extract(isodow from fecha)::integer]::varchar   as nombre_dia,
        (extract(isodow from fecha) >= 6)                    as es_fin_de_semana,
        to_char(fecha, 'YYYY-MM')::varchar                   as periodo
    from calendario
)

select * from base
union all
select -1, null::date, null::integer, null::integer, null::integer,
       'DESCONOCIDO'::varchar, null::integer, null::integer,
       'DESCONOCIDO'::varchar, null::boolean, 'DESCONOCIDO'::varchar