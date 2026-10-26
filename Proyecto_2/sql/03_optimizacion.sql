-- 1. Copia de viajes_limpios sin particiones ni clustering, para comparar con los mismos datos.
CREATE OR REPLACE TABLE `ss2-g15-nyc-taxi.nyc_taxi_g15.a_viajes_sin_optimizar` AS
SELECT *
FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.viajes_limpios`;

-- 2. Consulta 1: filtro por fecha, en la tabla pública, sin optimizar y optimizada.
SET @@query_label = "comparacion:c1_fecha_publica";
SELECT DATE(pickup_datetime) AS fecha, COUNT(*) AS viajes, SUM(total_amount) AS ingreso
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
WHERE DATE(pickup_datetime) BETWEEN '2022-03-07' AND '2022-03-13'
GROUP BY fecha ORDER BY fecha;

SET @@query_label = "comparacion:c1_fecha_sin_optimizar";
SELECT fecha, COUNT(*) AS viajes, SUM(total_amount) AS ingreso
FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.a_viajes_sin_optimizar`
WHERE fecha BETWEEN '2022-03-07' AND '2022-03-13'
GROUP BY fecha ORDER BY fecha;

SET @@query_label = "comparacion:c1_fecha_optimizada";
SELECT fecha, COUNT(*) AS viajes, SUM(total_amount) AS ingreso
FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.viajes_limpios`
WHERE fecha BETWEEN '2022-03-07' AND '2022-03-13'
GROUP BY fecha ORDER BY fecha;

-- 3. Consulta 2: filtro por fecha y zona.
SET @@query_label = "comparacion:c2_fecha_zona_publica";
SELECT dropoff_location_id, COUNT(*) AS viajes, AVG(fare_amount) AS tarifa_promedio
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
WHERE DATE(pickup_datetime) BETWEEN '2022-03-01' AND '2022-03-31'
  AND pickup_location_id = '132'
GROUP BY dropoff_location_id ORDER BY viajes DESC LIMIT 10;

SET @@query_label = "comparacion:c2_fecha_zona_sin_optimizar";
SELECT dropoff_location_id, COUNT(*) AS viajes, AVG(fare_amount) AS tarifa_promedio
FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.a_viajes_sin_optimizar`
WHERE fecha BETWEEN '2022-03-01' AND '2022-03-31'
  AND pickup_location_id = '132'
GROUP BY dropoff_location_id ORDER BY viajes DESC LIMIT 10;

SET @@query_label = "comparacion:c2_fecha_zona_optimizada";
SELECT dropoff_location_id, COUNT(*) AS viajes, AVG(fare_amount) AS tarifa_promedio
FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.viajes_limpios`
WHERE fecha BETWEEN '2022-03-01' AND '2022-03-31'
  AND pickup_location_id = '132'
GROUP BY dropoff_location_id ORDER BY viajes DESC LIMIT 10;

-- 4. Consulta 3: filtro solo por zona.
SET @@query_label = "comparacion:c3_zona_publica";
SELECT EXTRACT(MONTH FROM pickup_datetime) AS mes, COUNT(*) AS viajes, AVG(trip_distance) AS distancia_promedio
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
WHERE pickup_location_id = '161'
GROUP BY mes ORDER BY mes;

SET @@query_label = "comparacion:c3_zona_sin_optimizar";
SELECT mes, COUNT(*) AS viajes, AVG(trip_distance) AS distancia_promedio
FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.a_viajes_sin_optimizar`
WHERE pickup_location_id = '161'
GROUP BY mes ORDER BY mes;

SET @@query_label = "comparacion:c3_zona_optimizada";
SELECT mes, COUNT(*) AS viajes, AVG(trip_distance) AS distancia_promedio
FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.viajes_limpios`
WHERE pickup_location_id = '161'
GROUP BY mes ORDER BY mes;

-- 5. Consulta 4: sin filtros, como control.
SET @@query_label = "comparacion:c4_sin_filtro_publica";
SELECT EXTRACT(MONTH FROM pickup_datetime) AS mes, SUM(total_amount) AS ingreso
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
GROUP BY mes ORDER BY mes;

SET @@query_label = "comparacion:c4_sin_filtro_sin_optimizar";
SELECT mes, SUM(total_amount) AS ingreso
FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.a_viajes_sin_optimizar`
GROUP BY mes ORDER BY mes;

SET @@query_label = "comparacion:c4_sin_filtro_optimizada";
SELECT mes, SUM(total_amount) AS ingreso
FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.viajes_limpios`
GROUP BY mes ORDER BY mes;

-- 6. Bytes procesados y tiempo de cada consulta, desde el historial de trabajos (correr con la caché desactivada).
SET @@query_label = "paso:medicion";

CREATE OR REPLACE TABLE `ss2-g15-nyc-taxi.nyc_taxi_g15.a_comparacion_optimizacion` AS
WITH ejecuciones AS (
  SELECT
    l.value                                         AS etiqueta,
    j.total_bytes_processed,
    j.total_bytes_billed,
    TIMESTAMP_DIFF(j.end_time, j.start_time, MILLISECOND) AS duracion_ms,
    j.total_slot_ms,
    j.creation_time
  FROM `ss2-g15-nyc-taxi.region-us.INFORMATION_SCHEMA.JOBS_BY_PROJECT` j,
       UNNEST(j.labels) l
  WHERE l.key = 'comparacion'
    AND j.statement_type = 'SELECT'
    AND j.state = 'DONE'
    AND j.error_result IS NULL
    AND j.cache_hit IS NOT TRUE
    AND j.creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  QUALIFY ROW_NUMBER() OVER (PARTITION BY l.value ORDER BY j.creation_time DESC) = 1
)
SELECT
  REGEXP_EXTRACT(etiqueta, r'^(c\d)')                                    AS consulta,
  CASE REGEXP_EXTRACT(etiqueta, r'^c(\d)')
    WHEN '1' THEN 'Filtro por fecha (1 semana)'
    WHEN '2' THEN 'Filtro por fecha y zona (JFK, marzo)'
    WHEN '3' THEN 'Filtro por zona (Midtown Center)'
    ELSE 'Sin filtros (control)'
  END                                                                    AS descripcion,
  CASE
    WHEN ENDS_WITH(etiqueta, '_publica') THEN '1 · Pública (estándar)'
    WHEN ENDS_WITH(etiqueta, '_sin_optimizar') THEN '2 · Sin optimizar'
    ELSE '3 · Optimizada'
  END                                                                    AS version,
  ROUND(total_bytes_processed / POW(1024, 2), 2)                         AS mb_procesados,
  ROUND(total_bytes_billed / POW(1024, 2), 2)                            AS mb_facturados,
  duracion_ms,
  total_slot_ms                                                          AS slot_ms
FROM ejecuciones;

SELECT
  o.consulta, o.descripcion, o.version, o.mb_procesados, o.mb_facturados, o.duracion_ms, o.slot_ms,
  ROUND((1 - o.mb_procesados / s.mb_procesados) * 100, 2) AS reduccion_vs_sin_optimizar_pct
FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.a_comparacion_optimizacion` o
JOIN `ss2-g15-nyc-taxi.nyc_taxi_g15.a_comparacion_optimizacion` s
  ON s.consulta = o.consulta AND s.version = '2 · Sin optimizar'
ORDER BY o.consulta, o.version;
