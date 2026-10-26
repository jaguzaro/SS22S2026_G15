-- 1. Resumen diario de viajes e ingreso, con promedio móvil de 7 días.
CREATE OR REPLACE TABLE `ss2-g15-nyc-taxi.nyc_taxi_g15.a_resumen_diario` AS
SELECT
  fecha, mes, nombre_mes, dia_semana, nombre_dia, es_fin_de_semana,
  viajes,
  ingreso_total,
  tarifa_promedio,
  distancia_promedio,
  duracion_promedio,
  ROUND(AVG(viajes) OVER (ORDER BY fecha ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 0) AS viajes_promedio_movil_7d
FROM (
  SELECT
    fecha, mes, nombre_mes, dia_semana, nombre_dia, es_fin_de_semana,
    COUNT(*)                      AS viajes,
    ROUND(SUM(total_amount), 2)   AS ingreso_total,
    ROUND(AVG(fare_amount), 2)    AS tarifa_promedio,
    ROUND(AVG(trip_distance), 2)  AS distancia_promedio,
    ROUND(AVG(duracion_min), 2)   AS duracion_promedio
  FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.viajes_limpios`
  GROUP BY fecha, mes, nombre_mes, dia_semana, nombre_dia, es_fin_de_semana
);

-- 2. Demanda por día de la semana y hora.
CREATE OR REPLACE TABLE `ss2-g15-nyc-taxi.nyc_taxi_g15.a_demanda_hora_dia` AS
SELECT
  dia_semana, nombre_dia, hora, franja_horaria,
  COUNT(*)                                          AS viajes,
  ROUND(COUNT(*) / COUNT(DISTINCT fecha), 0)        AS viajes_promedio,
  ROUND(AVG(velocidad_mph), 2)                      AS velocidad_promedio_mph,
  ROUND(AVG(duracion_min), 2)                       AS duracion_promedio,
  ROUND(AVG(fare_amount), 2)                        AS tarifa_promedio
FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.viajes_limpios`
GROUP BY dia_semana, nombre_dia, hora, franja_horaria;

-- 3. Zonas de origen con su ranking y polígono para el mapa.
CREATE OR REPLACE TABLE `ss2-g15-nyc-taxi.nyc_taxi_g15.a_zonas_origen` AS
WITH geom AS (
  SELECT zone_id, ST_UNION_AGG(zone_geom) AS zona_geom
  FROM `bigquery-public-data.new_york_taxi_trips.taxi_zone_geom`
  GROUP BY zone_id
),
por_zona AS (
  SELECT
    pickup_location_id, pickup_zona, pickup_borough,
    COUNT(*)                                    AS viajes,
    ROUND(SUM(total_amount), 2)                 AS ingreso_total,
    ROUND(AVG(fare_amount), 2)                  AS tarifa_promedio,
    ROUND(AVG(trip_distance), 2)                AS distancia_promedio,
    ROUND(AVG(propina_pct), 2)                  AS propina_pct_promedio,
    ROUND(COUNTIF(es_aeropuerto) / COUNT(*) * 100, 2) AS pct_viajes_aeropuerto
  FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.viajes_limpios`
  GROUP BY pickup_location_id, pickup_zona, pickup_borough
)
SELECT
  p.*,
  RANK() OVER (ORDER BY p.viajes DESC)        AS ranking_viajes,
  g.zona_geom
FROM por_zona p
JOIN geom g ON g.zone_id = p.pickup_location_id;

-- 4. Participación de cada tipo de pago por mes.
CREATE OR REPLACE TABLE `ss2-g15-nyc-taxi.nyc_taxi_g15.a_pagos_mes` AS
SELECT
  mes, nombre_mes, tipo_pago,
  COUNT(*)                                                               AS viajes,
  ROUND(COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY mes) * 100, 2)        AS pct_del_mes,
  ROUND(AVG(propina_pct), 2)                                             AS propina_pct_promedio,
  ROUND(AVG(total_amount), 2)                                            AS total_promedio
FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.viajes_limpios`
GROUP BY mes, nombre_mes, tipo_pago;

-- 5. Viajes entre distritos de origen y destino.
CREATE OR REPLACE TABLE `ss2-g15-nyc-taxi.nyc_taxi_g15.a_flujos_borough` AS
SELECT
  pickup_borough  AS borough_origen,
  dropoff_borough AS borough_destino,
  COUNT(*)                                       AS viajes,
  ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 3) AS pct_viajes,
  ROUND(AVG(fare_amount), 2)                     AS tarifa_promedio,
  ROUND(AVG(duracion_min), 2)                    AS duracion_promedio
FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.viajes_limpios`
GROUP BY borough_origen, borough_destino;
