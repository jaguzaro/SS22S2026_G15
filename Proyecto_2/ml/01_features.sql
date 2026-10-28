-- Tabla de trabajo para los modelos: muestra de ~5 % de viajes_limpios, sin columnas que filtren la tarifa.
CREATE OR REPLACE TABLE `ss2-g15-nyc-taxi.nyc_taxi_g15.b_viajes_ml` AS
SELECT
  fecha,
  pickup_datetime,
  fare_amount,
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
  (NOT es_fin_de_semana AND hora BETWEEN 16 AND 19)   AS es_hora_pico,
  (pickup_borough = dropoff_borough)                  AS es_mismo_borough,
  CASE
    WHEN fecha < '2022-09-01' THEN 'entrenamiento'
    WHEN fecha < '2022-11-01' THEN 'evaluacion'
    ELSE 'nuevo'
  END                                                 AS conjunto,
  (fecha BETWEEN '2022-09-01' AND '2022-10-31')       AS es_evaluacion
FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.viajes_limpios`
WHERE MOD(ABS(FARM_FINGERPRINT(CONCAT(
        CAST(pickup_datetime AS STRING), CAST(dropoff_datetime AS STRING),
        pickup_location_id, dropoff_location_id,
        CAST(fare_amount AS STRING), CAST(trip_distance AS STRING)))), 100) < 5;
