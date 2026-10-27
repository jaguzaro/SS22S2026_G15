-- ml/01_features.sql
-- Crea la tabla de trabajo de BigQuery ML a partir de viajes_limpios.
-- Objetivo de los modelos: estimar fare_amount (tarifa) con datos conocidos al pedir el taxi.
--
-- Columnas de viajes_limpios que NO se usan como variables de entrada (data leakage):
--   total_amount, tip_amount, tolls_amount, extra, mta_tax, imp_surcharge, airport_fee, propina_pct
--     -> contienen la tarifa o se conocen hasta el final del viaje.
--   dropoff_datetime, duracion_min, velocidad_mph
--     -> solo se saben al llegar. dropoff_datetime se usa únicamente para el hash del muestreo.
-- Nota: trip_distance se usa como distancia estimada de la ruta al pedir el taxi.
CREATE OR REPLACE TABLE `ss2-g15-nyc-taxi.nyc_taxi_g15.b_viajes_ml` AS
SELECT
  -- Columnas de referencia (no son variables de entrada; sirven para el tablero)
  fecha,
  pickup_datetime,

  -- Variable objetivo
  fare_amount,

  -- Variables de entrada originales
  trip_distance,
  passenger_count,
  hora,
  CAST(dia_semana AS STRING)                          AS dia_semana,
  es_fin_de_semana,
  pickup_location_id,
  dropoff_location_id,
  pickup_borough,
  dropoff_borough,
  tipo_tarifa,
  es_aeropuerto,

  -- Variables derivadas
  (NOT es_fin_de_semana AND hora BETWEEN 16 AND 19)   AS es_hora_pico,
  (pickup_borough = dropoff_borough)                  AS es_mismo_borough,

  -- Split temporal: enero-agosto entrena, septiembre-octubre evalúa, noviembre queda como registros nuevos
  CASE
    WHEN fecha < '2022-09-01' THEN 'entrenamiento'
    WHEN fecha < '2022-11-01' THEN 'evaluacion'
    ELSE 'nuevo'
  END                                                 AS conjunto,
  (fecha BETWEEN '2022-09-01' AND '2022-10-31')       AS es_evaluacion

FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.viajes_limpios`
-- Muestra reproducible de ~5 % de los viajes (hash de campos del viaje, sin RAND())
WHERE MOD(ABS(FARM_FINGERPRINT(CONCAT(
        CAST(pickup_datetime AS STRING), CAST(dropoff_datetime AS STRING),
        pickup_location_id, dropoff_location_id,
        CAST(fare_amount AS STRING), CAST(trip_distance AS STRING)))), 100) < 5;