# Proyecto 2 · Análisis de datos masivos en BigQuery

Seminario de Sistemas 2 · Grupo 15

| Integrante | Carnet |
|---|---|
| Joel | 202201395 |
| Alvaro | 199817948 |

## Dataset

Usamos `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`, con los viajes de taxi amarillo de Nueva York en 2022. Tiene 36,256,539 registros con fechas, distancia, pasajeros, zonas de origen y destino, tipo de pago y montos. Para los nombres de las zonas usamos `taxi_zone_geom`, del mismo dataset.

Al explorarlo encontramos:

- 1,241,840 viajes sin pasajeros, tipo de tarifa ni tipo de pago.
- Viajes con distancia, tarifa o duración en cero o negativas, y fechas desde 2001 hasta 2023.
- No hay datos de diciembre: el año termina el 30 de noviembre.
- El 17 y 18 de septiembre están incompletos en la fuente.

Todo corre en el proyecto `ss2-g15-nyc-taxi`, dataset `nyc_taxi_g15`, en la región US.

## Scripts

| Script | Qué hace |
|---|---|
| `sql/00_viajes_limpios.sql` | Crea la tabla limpia que usa todo el proyecto |
| `sql/01_exploracion.sql` | Exploración: estructura, volumen, calidad, distribuciones y patrones |
| `sql/02_transformaciones.sql` | Tablas resumidas para el tablero |
| `sql/03_optimizacion.sql` | Comparación de consultas estándar contra optimizadas |
| `ml/` | Modelos de BigQuery ML |

Se corren en ese orden. El de optimización se corre con la caché desactivada.

## Transformaciones

`viajes_limpios` deja fuera los viajes con fechas fuera de rango, duración menor a 1 minuto o mayor a 3 horas, distancia en cero o mayor a 100 millas, tarifa menor a 2.50 USD, pasajeros en cero o más de 6, y códigos o zonas desconocidas. Quedan **32,875,149 viajes**, el 90.67 % del total.

Le agregamos estas columnas:

- **Fecha y hora:** mes, día de la semana, fin de semana, hora y franja horaria.
- **Viaje:** duración en minutos y velocidad promedio.
- **Pago:** tipo de pago y de tarifa en texto, y la propina como porcentaje de la tarifa (solo con tarjeta, porque la propina en efectivo no se registra).
- **Ubicación:** nombre de zona y distrito de origen y destino, y si el viaje es de aeropuerto.

Para el tablero creamos tablas resumidas: viajes por día (`a_resumen_diario`), por día y hora (`a_demanda_hora_dia`), por zona (`a_zonas_origen`), por tipo de pago y mes (`a_pagos_mes`) y entre distritos (`a_flujos_borough`).

## Optimización

`viajes_limpios` está **particionada por fecha** y tiene **clustering por zona de origen y destino**. Elegimos esas columnas porque casi todas las consultas filtran por un periodo y muchas por una zona.

Para medir la mejora corrimos las mismas consultas en tres tablas:

- la pública, que es la consulta estándar;
- una copia de `viajes_limpios` sin particiones ni clustering;
- `viajes_limpios`, la optimizada.

| Consulta | Pública | Sin optimizar | Optimizada | Reducción |
|---|---:|---:|---:|---:|
| Una semana de marzo | 829.85 MB | 501.63 MB | 11.29 MB | 97.75 % |
| Salidas de JFK en marzo | 1,162.18 MB | 803.06 MB | 71.31 MB | 91.12 % |
| Una zona en todo el año | 996.84 MB | 653.13 MB | 577.17 MB | 11.63 % |
| Sin filtros | 829.85 MB | 501.63 MB | 501.63 MB | 0 % |

La reducción se calcula contra la copia sin optimizar, que tiene los mismos datos.

- **La partición es la que más ahorra:** al filtrar una semana, BigQuery solo lee 7 de los 334 días.
- **El clustering ayuda cuando se combina con la fecha.** Si se filtra solo por zona, igual tiene que abrir todos los días, y el ahorro es pequeño.
- **Sin filtros no hay ahorro**, como se esperaba.
- **El tiempo también baja:** la consulta de una semana pasó de 354 a 176 ms.

## Hallazgos

- **La hora pico es a las 6 de la tarde, de martes a jueves**, con unos 7,700 viajes por hora. La más baja es las 3 de la mañana, con unos 200.
- **El tráfico casi duplica la duración de un viaje.** La velocidad promedio baja a 9.2 mph un jueves a las 4 de la tarde y sube a 23.6 mph un domingo a las 6 de la mañana.
- **Enero es el mes con menos viajes**, con 2.25 millones. Marzo y octubre son los de más, con 3.31 millones cada uno.
- **El 91 % de los viajes sale de Manhattan**, y el 85 % empieza y termina ahí.
- **Los viajes de aeropuerto son el 10 % del total pero dejan el 27 % del ingreso:** en promedio cuestan 56.77 USD, contra 16.75 del resto.
- **El 80 % paga con tarjeta**, y la propina típica es del 26 % de la tarifa.

## Modelos de BigQuery ML

_Pendiente._

## Informe visual

_Enlace pendiente._

## Evidencias

- `evidencias/A_resultados_exploracion.txt`: resultados de la exploración.
- `evidencias/A_comparacion_bytes.csv`: bytes procesados y tiempo de cada consulta comparada.
