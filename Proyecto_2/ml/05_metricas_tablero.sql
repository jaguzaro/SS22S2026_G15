-- ml/05_metricas_tablero.sql
-- Tabla con las métricas de los modelos, para la página de predicciones del tablero.
CREATE OR REPLACE TABLE `ss2-g15-nyc-taxi.nyc_taxi_g15.b_metricas_modelos` AS

-- Cada modelo sobre su propio conjunto de evaluación.
SELECT 'modelo_lineal_v1' AS modelo, 'Evaluación temporal (sep-oct)' AS evaluacion,
       ROUND(mean_absolute_error, 3) AS mae, ROUND(SQRT(mean_squared_error), 3) AS rmse, ROUND(r2_score, 3) AS r2
FROM ML.EVALUATE(MODEL `ss2-g15-nyc-taxi.nyc_taxi_g15.modelo_lineal_v1`)
UNION ALL
SELECT 'modelo_lineal_v2', 'Evaluación temporal (sep-oct)',
       ROUND(mean_absolute_error, 3), ROUND(SQRT(mean_squared_error), 3), ROUND(r2_score, 3)
FROM ML.EVALUATE(MODEL `ss2-g15-nyc-taxi.nyc_taxi_g15.modelo_lineal_v2`)
UNION ALL
SELECT 'modelo_arbol_v1', 'Evaluación temporal (sep-oct)',
       ROUND(mean_absolute_error, 3), ROUND(SQRT(mean_squared_error), 3), ROUND(r2_score, 3)
FROM ML.EVALUATE(MODEL `ss2-g15-nyc-taxi.nyc_taxi_g15.modelo_arbol_v1`)
UNION ALL
SELECT 'modelo_arbol_v2', 'Evaluación temporal (sep-oct)',
       ROUND(mean_absolute_error, 3), ROUND(SQRT(mean_squared_error), 3), ROUND(r2_score, 3)
FROM ML.EVALUATE(MODEL `ss2-g15-nyc-taxi.nyc_taxi_g15.modelo_arbol_v2`)
UNION ALL
SELECT 'modelo_arbol_v2_random', 'Evaluación aleatoria (20 %)',
       ROUND(mean_absolute_error, 3), ROUND(SQRT(mean_squared_error), 3), ROUND(r2_score, 3)
FROM ML.EVALUATE(MODEL `ss2-g15-nyc-taxi.nyc_taxi_g15.modelo_arbol_v2_random`)

-- Los modelos elegidos sobre noviembre (datos nuevos que no vieron al entrenar).
UNION ALL
SELECT 'modelo_lineal_v2', 'Noviembre (datos nuevos)',
       ROUND(mean_absolute_error, 3), ROUND(SQRT(mean_squared_error), 3), ROUND(r2_score, 3)
FROM ML.EVALUATE(MODEL `ss2-g15-nyc-taxi.nyc_taxi_g15.modelo_lineal_v2`,
  (SELECT * FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.b_viajes_ml` WHERE conjunto = 'nuevo'))
UNION ALL
SELECT 'modelo_arbol_v2', 'Noviembre (datos nuevos)',
       ROUND(mean_absolute_error, 3), ROUND(SQRT(mean_squared_error), 3), ROUND(r2_score, 3)
FROM ML.EVALUATE(MODEL `ss2-g15-nyc-taxi.nyc_taxi_g15.modelo_arbol_v2`,
  (SELECT * FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.b_viajes_ml` WHERE conjunto = 'nuevo'))
UNION ALL
SELECT 'modelo_arbol_v2_random', 'Noviembre (datos nuevos)',
       ROUND(mean_absolute_error, 3), ROUND(SQRT(mean_squared_error), 3), ROUND(r2_score, 3)
FROM ML.EVALUATE(MODEL `ss2-g15-nyc-taxi.nyc_taxi_g15.modelo_arbol_v2_random`,
  (SELECT * FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.b_viajes_ml` WHERE conjunto = 'nuevo'));