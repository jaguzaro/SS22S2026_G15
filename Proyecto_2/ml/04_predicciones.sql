-- 1. Viajes de noviembre con un identificador estable.
CREATE OR REPLACE TABLE `ss2-g15-nyc-taxi.nyc_taxi_g15.b_viajes_nuevos` AS
SELECT
  ROW_NUMBER() OVER (ORDER BY pickup_datetime, pickup_location_id,
                     dropoff_location_id, fare_amount, trip_distance) AS id,
  *
FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.b_viajes_ml`
WHERE conjunto = 'nuevo';

-- 2. Tarifa real y predicha por el lineal v2 y el árbol v2 para cada viaje de noviembre.
CREATE OR REPLACE TABLE `ss2-g15-nyc-taxi.nyc_taxi_g15.b_predicciones` AS
WITH lineal AS (
  SELECT id, predicted_fare_amount AS pred_lineal_v2
  FROM ML.PREDICT(MODEL `ss2-g15-nyc-taxi.nyc_taxi_g15.modelo_lineal_v2`,
                  TABLE `ss2-g15-nyc-taxi.nyc_taxi_g15.b_viajes_nuevos`)
),
arbol AS (
  SELECT id, predicted_fare_amount AS pred_arbol_v2
  FROM ML.PREDICT(MODEL `ss2-g15-nyc-taxi.nyc_taxi_g15.modelo_arbol_v2`,
                  TABLE `ss2-g15-nyc-taxi.nyc_taxi_g15.b_viajes_nuevos`)
)
SELECT
  n.id, n.fecha, n.pickup_datetime, n.hora, n.pickup_borough, n.es_aeropuerto,
  n.fare_amount AS tarifa_real,
  l.pred_lineal_v2,
  a.pred_arbol_v2,
  ABS(n.fare_amount - l.pred_lineal_v2) AS error_lineal_v2,
  ABS(n.fare_amount - a.pred_arbol_v2)  AS error_arbol_v2
FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.b_viajes_nuevos` n
JOIN lineal l USING (id)
JOIN arbol  a USING (id);
