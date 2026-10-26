-- 1. Estructura: columnas y tipos de la tabla pública.
SELECT column_name, data_type, is_nullable
FROM `bigquery-public-data.new_york_taxi_trips.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'tlc_yellow_trips_2022'
ORDER BY ordinal_position;

-- 2. Volumen y rango de fechas.
SELECT
  COUNT(*)                                          AS total_viajes,
  MIN(pickup_datetime)                              AS primera_salida,
  MAX(pickup_datetime)                              AS ultima_salida,
  COUNTIF(EXTRACT(YEAR FROM pickup_datetime) <> 2022) AS fuera_de_2022,
  COUNTIF(EXTRACT(MONTH FROM pickup_datetime) = 12
          AND EXTRACT(YEAR FROM pickup_datetime) = 2022) AS viajes_diciembre
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`;

-- 3. Calidad: registros que incumplen cada regla de limpieza.
SELECT
  COUNTIF(dropoff_datetime <= pickup_datetime)                          AS llegada_no_posterior,
  COUNTIF(TIMESTAMP_DIFF(dropoff_datetime, pickup_datetime, MINUTE) > 180) AS duracion_mayor_3h,
  COUNTIF(passenger_count IS NULL)                                      AS pasajeros_nulos,
  COUNTIF(passenger_count = 0)                                          AS pasajeros_cero,
  COUNTIF(passenger_count > 6)                                          AS pasajeros_mas_de_6,
  COUNTIF(trip_distance <= 0)                                           AS distancia_cero,
  COUNTIF(trip_distance > 100)                                          AS distancia_mayor_100,
  COUNTIF(fare_amount <= 0)                                             AS tarifa_no_positiva,
  COUNTIF(fare_amount > 500)                                            AS tarifa_mayor_500,
  COUNTIF(rate_code IS NULL OR rate_code = '99.0')                      AS tipo_tarifa_desconocido,
  COUNTIF(payment_type IN ('0', '5'))                                   AS tipo_pago_desconocido,
  COUNTIF(pickup_location_id IN ('264', '265'))                         AS zona_origen_desconocida
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`;

-- 4. Distribuciones categóricas con su porcentaje.
WITH conteos AS (
  SELECT 'payment_type' AS columna, payment_type AS valor, COUNT(*) AS viajes
  FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022` GROUP BY valor
  UNION ALL
  SELECT 'rate_code', rate_code, COUNT(*)
  FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022` GROUP BY rate_code
  UNION ALL
  SELECT 'vendor_id', vendor_id, COUNT(*)
  FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022` GROUP BY vendor_id
)
SELECT
  columna,
  IFNULL(valor, 'NULL') AS valor,
  viajes,
  ROUND(viajes / SUM(viajes) OVER (PARTITION BY columna) * 100, 2) AS porcentaje
FROM conteos
ORDER BY columna, viajes DESC;

-- 5. Filas que quedan después de la limpieza.
SELECT
  (SELECT COUNT(*) FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`) AS filas_publicas,
  COUNT(*)                                                                                AS filas_limpias,
  ROUND(COUNT(*) / (SELECT COUNT(*) FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`) * 100, 2) AS pct_conservado,
  COUNT(DISTINCT fecha)                                                                   AS dias,
  MIN(fecha)                                                                              AS desde,
  MAX(fecha)                                                                              AS hasta
FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.viajes_limpios`;

-- 6. Métricas descriptivas de las variables numéricas.
SELECT
  'distancia_millas' AS variable,
  ROUND(AVG(trip_distance), 2) AS promedio, ROUND(STDDEV(trip_distance), 2) AS desviacion,
  APPROX_QUANTILES(trip_distance, 4) AS cuartiles
FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.viajes_limpios`
UNION ALL
SELECT 'duracion_min', ROUND(AVG(duracion_min), 2), ROUND(STDDEV(duracion_min), 2), APPROX_QUANTILES(duracion_min, 4)
FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.viajes_limpios`
UNION ALL
SELECT 'tarifa_usd', ROUND(AVG(fare_amount), 2), ROUND(STDDEV(fare_amount), 2), APPROX_QUANTILES(fare_amount, 4)
FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.viajes_limpios`
UNION ALL
SELECT 'total_usd', ROUND(AVG(total_amount), 2), ROUND(STDDEV(total_amount), 2), APPROX_QUANTILES(total_amount, 4)
FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.viajes_limpios`
UNION ALL
SELECT 'propina_pct_tarjeta', ROUND(AVG(propina_pct), 2), ROUND(STDDEV(propina_pct), 2), APPROX_QUANTILES(propina_pct, 4)
FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.viajes_limpios`
UNION ALL
SELECT 'velocidad_mph', ROUND(AVG(velocidad_mph), 2), ROUND(STDDEV(velocidad_mph), 2), APPROX_QUANTILES(velocidad_mph, 4)
FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.viajes_limpios`;

-- 7. Viajes e ingreso por mes, con variación contra el mes anterior.
WITH mensual AS (
  SELECT mes, nombre_mes, COUNT(*) AS viajes, ROUND(SUM(total_amount), 2) AS ingreso_total
  FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.viajes_limpios`
  GROUP BY mes, nombre_mes
)
SELECT
  mes, nombre_mes, viajes, ingreso_total,
  ROUND((viajes - LAG(viajes) OVER (ORDER BY mes)) / LAG(viajes) OVER (ORDER BY mes) * 100, 2) AS variacion_viajes_pct
FROM mensual
ORDER BY mes;

-- 8. Viajes por día con promedio móvil de 7 días.
SELECT
  fecha,
  COUNT(*) AS viajes,
  ROUND(AVG(COUNT(*)) OVER (ORDER BY fecha ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 0) AS promedio_movil_7d
FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.viajes_limpios`
GROUP BY fecha
ORDER BY fecha;

-- 9. Demanda, velocidad y tarifa por día de la semana y hora.
SELECT
  dia_semana, nombre_dia, hora,
  COUNT(*)                     AS viajes,
  ROUND(AVG(velocidad_mph), 2) AS velocidad_promedio_mph,
  ROUND(AVG(fare_amount), 2)   AS tarifa_promedio
FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.viajes_limpios`
GROUP BY dia_semana, nombre_dia, hora
ORDER BY dia_semana, hora;

-- 10. Tipo de pago por franja horaria y propina promedio.
SELECT
  tipo_pago, franja_horaria,
  COUNT(*) AS viajes,
  ROUND(COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY franja_horaria) * 100, 2) AS pct_de_la_franja,
  ROUND(AVG(propina_pct), 2) AS propina_pct_promedio
FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.viajes_limpios`
GROUP BY tipo_pago, franja_horaria
ORDER BY franja_horaria, viajes DESC;

-- 11. Las 5 zonas de origen con más viajes en cada distrito.
WITH por_zona AS (
  SELECT
    pickup_borough, pickup_zona,
    COUNT(*) AS viajes,
    ROUND(AVG(fare_amount), 2) AS tarifa_promedio,
    ROUND(AVG(trip_distance), 2) AS distancia_promedio
  FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.viajes_limpios`
  GROUP BY pickup_borough, pickup_zona
)
SELECT *
FROM por_zona
QUALIFY ROW_NUMBER() OVER (PARTITION BY pickup_borough ORDER BY viajes DESC) <= 5
ORDER BY pickup_borough, viajes DESC;

-- 12. Viajes de aeropuerto contra el resto.
SELECT
  es_aeropuerto,
  COUNT(*) AS viajes,
  ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 2) AS pct_viajes,
  ROUND(SUM(total_amount) / SUM(SUM(total_amount)) OVER () * 100, 2) AS pct_ingreso,
  ROUND(AVG(trip_distance), 2) AS distancia_promedio,
  ROUND(AVG(total_amount), 2)  AS total_promedio,
  ROUND(AVG(propina_pct), 2)   AS propina_pct_promedio
FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.viajes_limpios`
GROUP BY es_aeropuerto;
