-- 1. Regresión lineal v1, sin regularización, con split temporal.
CREATE OR REPLACE MODEL `ss2-g15-nyc-taxi.nyc_taxi_g15.modelo_lineal_v1`
OPTIONS (
  model_type = 'LINEAR_REG', input_label_cols = ['fare_amount'],
  data_split_method = 'CUSTOM', data_split_col = 'es_evaluacion',
  l2_reg = 0, max_iterations = 20
) AS
SELECT fare_amount, trip_distance, passenger_count, hora, dia_semana, es_fin_de_semana,
       pickup_location_id, dropoff_location_id, pickup_borough, dropoff_borough,
       tipo_tarifa, es_aeropuerto, es_hora_pico, es_mismo_borough, es_evaluacion
FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.b_viajes_ml`
WHERE conjunto IN ('entrenamiento', 'evaluacion');

-- 2. Regresión lineal v2, con regularización L2.
CREATE OR REPLACE MODEL `ss2-g15-nyc-taxi.nyc_taxi_g15.modelo_lineal_v2`
OPTIONS (
  model_type = 'LINEAR_REG', input_label_cols = ['fare_amount'],
  data_split_method = 'CUSTOM', data_split_col = 'es_evaluacion',
  l2_reg = 1, max_iterations = 20
) AS
SELECT fare_amount, trip_distance, passenger_count, hora, dia_semana, es_fin_de_semana,
       pickup_location_id, dropoff_location_id, pickup_borough, dropoff_borough,
       tipo_tarifa, es_aeropuerto, es_hora_pico, es_mismo_borough, es_evaluacion
FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.b_viajes_ml`
WHERE conjunto IN ('entrenamiento', 'evaluacion');

-- 3. Árbol con boosting v1.
CREATE OR REPLACE MODEL `ss2-g15-nyc-taxi.nyc_taxi_g15.modelo_arbol_v1`
OPTIONS (
  model_type = 'BOOSTED_TREE_REGRESSOR', input_label_cols = ['fare_amount'],
  data_split_method = 'CUSTOM', data_split_col = 'es_evaluacion',
  max_iterations = 50, learn_rate = 0.1, max_tree_depth = 6, subsample = 0.8
) AS
SELECT fare_amount, trip_distance, passenger_count, hora, dia_semana, es_fin_de_semana,
       pickup_location_id, dropoff_location_id, pickup_borough, dropoff_borough,
       tipo_tarifa, es_aeropuerto, es_hora_pico, es_mismo_borough, es_evaluacion
FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.b_viajes_ml`
WHERE conjunto IN ('entrenamiento', 'evaluacion');

-- 4. Árbol con boosting v2, más profundo y con learn_rate mayor.
CREATE OR REPLACE MODEL `ss2-g15-nyc-taxi.nyc_taxi_g15.modelo_arbol_v2`
OPTIONS (
  model_type = 'BOOSTED_TREE_REGRESSOR', input_label_cols = ['fare_amount'],
  data_split_method = 'CUSTOM', data_split_col = 'es_evaluacion',
  max_iterations = 50, learn_rate = 0.2, max_tree_depth = 8, subsample = 0.8
) AS
SELECT fare_amount, trip_distance, passenger_count, hora, dia_semana, es_fin_de_semana,
       pickup_location_id, dropoff_location_id, pickup_borough, dropoff_borough,
       tipo_tarifa, es_aeropuerto, es_hora_pico, es_mismo_borough, es_evaluacion
FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.b_viajes_ml`
WHERE conjunto IN ('entrenamiento', 'evaluacion');

-- 5. Árbol v2 con split aleatorio del 20 %, para comparar contra el temporal.
CREATE OR REPLACE MODEL `ss2-g15-nyc-taxi.nyc_taxi_g15.modelo_arbol_v2_random`
OPTIONS (
  model_type = 'BOOSTED_TREE_REGRESSOR', input_label_cols = ['fare_amount'],
  data_split_method = 'RANDOM', data_split_eval_fraction = 0.2,
  max_iterations = 50, learn_rate = 0.2, max_tree_depth = 8, subsample = 0.8
) AS
SELECT fare_amount, trip_distance, passenger_count, hora, dia_semana, es_fin_de_semana,
       pickup_location_id, dropoff_location_id, pickup_borough, dropoff_borough,
       tipo_tarifa, es_aeropuerto, es_hora_pico, es_mismo_borough
FROM `ss2-g15-nyc-taxi.nyc_taxi_g15.b_viajes_ml`
WHERE conjunto IN ('entrenamiento', 'evaluacion');
