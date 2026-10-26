-- Tabla compartida: viajes de 2022 limpios, particionada por fecha y con clustering por zona.
CREATE OR REPLACE TABLE `ss2-g15-nyc-taxi.nyc_taxi_g15.viajes_limpios`
PARTITION BY fecha
CLUSTER BY pickup_location_id, dropoff_location_id
AS

-- Convierte montos y códigos a tipos numéricos.
WITH base AS (
  SELECT
    vendor_id,
    pickup_datetime,
    dropoff_datetime,
    passenger_count,
    CAST(trip_distance AS FLOAT64)                      AS trip_distance,
    SAFE_CAST(SAFE_CAST(rate_code AS FLOAT64) AS INT64) AS rate_code,
    SAFE_CAST(payment_type AS INT64)                    AS payment_type,
    CAST(fare_amount AS FLOAT64)                        AS fare_amount,
    CAST(extra AS FLOAT64)                              AS extra,
    CAST(mta_tax AS FLOAT64)                            AS mta_tax,
    CAST(tip_amount AS FLOAT64)                         AS tip_amount,
    CAST(tolls_amount AS FLOAT64)                       AS tolls_amount,
    CAST(imp_surcharge AS FLOAT64)                      AS imp_surcharge,
    CAST(airport_fee AS FLOAT64)                        AS airport_fee,
    CAST(total_amount AS FLOAT64)                       AS total_amount,
    pickup_location_id,
    dropoff_location_id,
    TIMESTAMP_DIFF(dropoff_datetime, pickup_datetime, SECOND) / 60.0 AS duracion_min
  FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
),

-- Descarta los registros inválidos encontrados en la exploración.
filtrados AS (
  SELECT *
  FROM base
  WHERE DATE(pickup_datetime) BETWEEN '2022-01-01' AND '2022-11-30'
    AND duracion_min BETWEEN 1 AND 180
    AND trip_distance > 0 AND trip_distance <= 100
    AND trip_distance / (duracion_min / 60) <= 80
    AND fare_amount >= 2.5 AND fare_amount <= 500
    AND total_amount > 0
    AND passenger_count BETWEEN 1 AND 6
    AND rate_code BETWEEN 1 AND 6
    AND payment_type BETWEEN 1 AND 4
    AND pickup_location_id NOT IN ('264', '265')
    AND dropoff_location_id NOT IN ('264', '265')
),

-- Una fila por zona (la 56 y la 103 vienen repetidas en la tabla pública).
zonas AS (
  SELECT zone_id, ANY_VALUE(zone_name) AS zone_name, ANY_VALUE(borough) AS borough
  FROM `bigquery-public-data.new_york_taxi_trips.taxi_zone_geom`
  GROUP BY zone_id
)

-- Agrega las columnas derivadas de fecha, hora, montos y ubicación.
SELECT
  DATE(f.pickup_datetime)                                 AS fecha,
  EXTRACT(MONTH FROM f.pickup_datetime)                   AS mes,
  CASE EXTRACT(MONTH FROM f.pickup_datetime)
    WHEN 1 THEN 'Enero' WHEN 2 THEN 'Febrero' WHEN 3 THEN 'Marzo' WHEN 4 THEN 'Abril'
    WHEN 5 THEN 'Mayo' WHEN 6 THEN 'Junio' WHEN 7 THEN 'Julio' WHEN 8 THEN 'Agosto'
    WHEN 9 THEN 'Septiembre' WHEN 10 THEN 'Octubre' WHEN 11 THEN 'Noviembre' ELSE 'Diciembre'
  END                                                     AS nombre_mes,
  EXTRACT(DAYOFWEEK FROM f.pickup_datetime)               AS dia_semana,
  CASE EXTRACT(DAYOFWEEK FROM f.pickup_datetime)
    WHEN 1 THEN 'Domingo' WHEN 2 THEN 'Lunes' WHEN 3 THEN 'Martes' WHEN 4 THEN 'Miércoles'
    WHEN 5 THEN 'Jueves' WHEN 6 THEN 'Viernes' ELSE 'Sábado'
  END                                                     AS nombre_dia,
  EXTRACT(DAYOFWEEK FROM f.pickup_datetime) IN (1, 7)     AS es_fin_de_semana,
  EXTRACT(HOUR FROM f.pickup_datetime)                    AS hora,
  CASE
    WHEN EXTRACT(HOUR FROM f.pickup_datetime) < 6  THEN 'Madrugada'
    WHEN EXTRACT(HOUR FROM f.pickup_datetime) < 12 THEN 'Mañana'
    WHEN EXTRACT(HOUR FROM f.pickup_datetime) < 18 THEN 'Tarde'
    ELSE 'Noche'
  END                                                     AS franja_horaria,
  f.pickup_datetime,
  f.dropoff_datetime,
  ROUND(f.duracion_min, 2)                                AS duracion_min,
  f.vendor_id,
  f.passenger_count,
  f.trip_distance,
  ROUND(f.trip_distance / (f.duracion_min / 60), 2)       AS velocidad_mph,
  f.rate_code,
  CASE f.rate_code
    WHEN 1 THEN 'Tarifa estándar' WHEN 2 THEN 'JFK' WHEN 3 THEN 'Newark'
    WHEN 4 THEN 'Nassau o Westchester' WHEN 5 THEN 'Tarifa negociada' ELSE 'Viaje compartido'
  END                                                     AS tipo_tarifa,
  f.payment_type,
  CASE f.payment_type
    WHEN 1 THEN 'Tarjeta' WHEN 2 THEN 'Efectivo' WHEN 3 THEN 'Sin cargo' ELSE 'Disputa'
  END                                                     AS tipo_pago,
  f.fare_amount,
  f.extra,
  f.mta_tax,
  f.tip_amount,
  f.tolls_amount,
  f.imp_surcharge,
  f.airport_fee,
  f.total_amount,
  IF(f.payment_type = 1 AND f.tip_amount <= f.fare_amount,
     ROUND(f.tip_amount / f.fare_amount * 100, 2), NULL)  AS propina_pct,
  f.pickup_location_id,
  zo.zone_name                                            AS pickup_zona,
  zo.borough                                              AS pickup_borough,
  f.dropoff_location_id,
  zd.zone_name                                            AS dropoff_zona,
  zd.borough                                              AS dropoff_borough,
  (f.pickup_location_id IN ('1', '132', '138')
    OR f.dropoff_location_id IN ('1', '132', '138')
    OR f.rate_code IN (2, 3))                             AS es_aeropuerto
FROM filtrados f
JOIN zonas zo ON zo.zone_id = f.pickup_location_id
JOIN zonas zd ON zd.zone_id = f.dropoff_location_id;
