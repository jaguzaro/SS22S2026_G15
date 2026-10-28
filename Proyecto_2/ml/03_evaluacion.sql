-- 1. Métricas de cada modelo sobre su propio conjunto de evaluación.
SELECT 'modelo_lineal_v1' AS modelo, 'temporal' AS split, mean_absolute_error AS mae,
       SQRT(mean_squared_error) AS rmse, r2_score AS r2
FROM ML.EVALUATE(MODEL `ss2-g15-nyc-taxi.nyc_taxi_g15.modelo_lineal_v1`)
UNION ALL
SELECT 'modelo_lineal_v2', 'temporal', mean_absolute_error, SQRT(mean_squared_error), r2_score
FROM ML.EVALUATE(MODEL `ss2-g15-nyc-taxi.nyc_taxi_g15.modelo_lineal_v2`)
UNION ALL
SELECT 'modelo_arbol_v1', 'temporal', mean_absolute_error, SQRT(mean_squared_error), r2_score
FROM ML.EVALUATE(MODEL `ss2-g15-nyc-taxi.nyc_taxi_g15.modelo_arbol_v1`)
UNION ALL
SELECT 'modelo_arbol_v2', 'temporal', mean_absolute_error, SQRT(mean_squared_error), r2_score
FROM ML.EVALUATE(MODEL `ss2-g15-nyc-taxi.nyc_taxi_g15.modelo_arbol_v2`)
UNION ALL
SELECT 'modelo_arbol_v2_random', 'aleatorio 20%', mean_absolute_error, SQRT(mean_squared_error), r2_score
FROM ML.EVALUATE(MODEL `ss2-g15-nyc-taxi.nyc_taxi_g15.modelo_arbol_v2_random`);

-- 2. Los 20 viajes con mayor error del lineal v1.
SELECT fare_amount, predicted_fare_amount,
       ABS(fare_amount - predicted_fare_amount) AS error_abs,
       trip_distance, pickup_location_id, dropoff_location_id,
       pickup_borough, dropoff_borough, tipo_tarifa, es_aeropuerto
FROM ML.PREDICT(
  MODEL `ss2-g15-nyc-taxi.nyc_taxi_g15.modelo_lineal_v1`,
  (SELECT * FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.b_viajes_ml` WHERE conjunto = 'evaluacion'))
ORDER BY error_abs DESC
LIMIT 20;

-- 3. Los dos árboles v2 sobre noviembre, que ninguno vio al entrenar.
SELECT 'modelo_arbol_v2 (split temporal)' AS modelo,
       mean_absolute_error AS mae, SQRT(mean_squared_error) AS rmse, r2_score AS r2
FROM ML.EVALUATE(
  MODEL `ss2-g15-nyc-taxi.nyc_taxi_g15.modelo_arbol_v2`,
  (SELECT * FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.b_viajes_ml` WHERE conjunto = 'nuevo'))
UNION ALL
SELECT 'modelo_arbol_v2_random (split aleatorio)',
       mean_absolute_error, SQRT(mean_squared_error), r2_score
FROM ML.EVALUATE(
  MODEL `ss2-g15-nyc-taxi.nyc_taxi_g15.modelo_arbol_v2_random`,
  (SELECT * FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.b_viajes_ml` WHERE conjunto = 'nuevo'));

-- 4. Pérdida por iteración de los dos árboles.
SELECT 'modelo_arbol_v1' AS modelo, * FROM ML.TRAINING_INFO(MODEL `ss2-g15-nyc-taxi.nyc_taxi_g15.modelo_arbol_v1`)
ORDER BY iteration;

SELECT 'modelo_arbol_v2' AS modelo, * FROM ML.TRAINING_INFO(MODEL `ss2-g15-nyc-taxi.nyc_taxi_g15.modelo_arbol_v2`)
ORDER BY iteration;
