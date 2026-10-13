# Arquitectura, extracción, carga y DAG de Airflow

Responsable: Joel (rol A). Cubre las fases A1 a A5 del
[plan de trabajo](plan_de_trabajo.md).

## 1. Arquitectura

```
┌───────────────────────── docker compose (proyecto sgfood) ─────────────────────────┐
│                                                                                    │
│  sgfood-postgres (PostgreSQL 16, localhost:5433)                                   │
│    ├─ sgfood_oltp   schema oltp_sgfood   ← data/oltp/sgfood_oltp.sql               │
│    └─ sgfood_dw     schemas raw · staging · intermediate · marts                   │
│                                                                                    │
│  sgfood-airflow (Airflow 3.3.2 standalone, localhost:8080)                         │
│    ├─ /opt/airflow/extract_load   scripts Python (este documento)                  │
│    ├─ /opt/airflow/dbt/sgfood     proyecto dbt (rol B), dbt en /opt/dbt-venv       │
│    └─ /opt/airflow/data, /sql     fuentes y DDL, solo lectura                      │
│                                                                                    │
│  sgfood-airflow-db (PostgreSQL 16)   metadatos de Airflow, separado del DW         │
└────────────────────────────────────────────────────────────────────────────────────┘
```

Decisiones:

- **Fuente transaccional y DW en el mismo servidor, en bases distintas.** El
  enunciado pide extraer de una base transaccional; `sgfood_oltp` hace ese papel y
  `sgfood_dw` nunca la consulta directamente. Toda la información entra por `raw`.
- **Metadatos de Airflow en su propio contenedor.** Así un `down -v` del DW no
  borra el historial de corridas y Airflow no comparte usuario con los datos.
- **dbt en un entorno virtual aparte** (`/opt/dbt-venv`). Airflow y dbt fijan
  versiones distintas de las mismas librerías; separados no chocan. `dbt` queda en
  el `PATH` del contenedor.
- **Las tareas llaman scripts, no funciones.** Cada paso es un script de
  `extract_load/` que se puede correr igual desde la terminal o desde Airflow, y
  comunica éxito o fallo por su código de salida. Lo que se prueba a mano es lo
  mismo que corre en el DAG.

## 2. Scripts de `extract_load/`

| Script | Qué hace | Tarea del DAG |
|---|---|---|
| `crear_raw.py` | Aplica `sql/01_raw_ddl.sql` (idempotente) | `crear_schemas_raw` |
| `extract_oltp.py` | Copia las 7 tablas de `sgfood_oltp` a `raw` | `extraer_oltp` |
| `load_csv.py` | Carga los 5 CSV de `data/csv` a `raw` | `cargar_csv` |
| `validate_raw.py` | Compara fuentes contra `raw` con `sql/validacion/10_carga_raw.sql` | `validar_raw` |
| `inject_quality_cases.py` | Inserta en `raw` los 10 casos de `data/calidad` | `inyectar_casos_calidad` |
| `contrato.py` | Columnas de las 12 tablas de `raw`, en orden | — |
| `config.py` | Conexiones, rutas y logging, desde variables de entorno | — |

Comportamiento común:

- **Reemplazo completo en una transacción.** Cada carga hace `TRUNCATE` + `COPY`
  de todas sus tablas dentro de una sola transacción. Si algo falla a mitad de
  camino, `raw` queda exactamente como estaba. Volver a correr da el mismo
  resultado.
- **`_loaded_at` compartido.** Las tres tareas reciben
  `--loaded-at` con la hora de inicio de la corrida del DAG. `validate_raw.py`
  exige que las 12 tablas tengan un único `_loaded_at` y que sea el de la corrida
  actual, así detecta una tabla que se quedó con datos de una corrida anterior.
- **`_source`.** `sgfood_oltp.oltp_sgfood.<tabla>` para la base,
  el nombre del archivo para los CSV y `casos_calidad_opcionales.csv` para los
  casos inyectados.
- **Logging** a consola (lo captura Airflow) y a `logs/extract_load.log`
  (en el contenedor, `airflow/logs/sgfood/extract_load.log`).
- **Código de salida 1** ante cualquier error, con un mensaje que dice qué falló.

### Extracción de la base transaccional

`COPY (SELECT ...) TO STDOUT` en la fuente conectado directo a `COPY ... FROM STDIN`
en el DW: los datos pasan en bloques sin convertirse a objetos Python, y las
columnas de auditoría se agregan en el mismo `SELECT`. La conexión a la fuente es
de solo lectura.

### Carga de CSV

- Lectura con `utf-8-sig`: los cinco archivos traen BOM y sin esto la primera
  columna se llamaría `﻿fecha_corte`.
- Antes de tocar la base se leen los cinco archivos y se compara el encabezado de
  cada uno con `contrato.py`. Un encabezado distinto detiene la carga completa.
- Celdas vacías se cargan como `NULL`. Los tipos los aplica PostgreSQL al hacer
  `COPY`; un valor que no encaja (`setenta` en una columna entera) hace fallar la
  transacción entera.
- `casos_calidad_opcionales.csv` no se carga en la corrida normal.

### Corrida de calidad

`inject_quality_cases.py` lee `data/calidad/casos_calidad_opcionales.csv` y, por
cada caso, copia una fila válida de la tabla, le pone el valor inválido en el campo
indicado y la inserta. Para que cada caso active solo la prueba que le corresponde:

- Las tablas con llave reciben una llave nueva (máximo + 1), así no se duplica
  ninguna existente. Al producto también se le da un SKU nuevo.
- Las tablas sin llave simple reciben un periodo nuevo: inventario con corte
  2026-09-30, metas en 2026-09, precio de proveedor con vigencia un día después.
- En las líneas de venta se recalcula el subtotal con los valores inválidos.
- La fila conserva el `_loaded_at` de la corrida.

Corre después de `validar_raw`, así la validación de conteos sigue siendo sobre los
datos de las fuentes. La siguiente corrida normal reemplaza `raw` y elimina los
casos.

## 3. DAG `sgfood_elt`

```
inicio → crear_schemas_raw → ┬ extraer_oltp ┬ → validar_raw → inyectar_casos_calidad
                             └ cargar_csv   ┘
       → dbt_deps → dbt_build → validar_marts → fin
```

| Configuración | Valor | Por qué |
|---|---|---|
| `schedule` | `@daily` | Ejecución programada (opcional recomendado del enunciado) |
| `catchup` | `False` | No se recalculan días pasados: cada corrida recarga todo |
| `max_active_runs` | 1 | Dos corridas a la vez harían `TRUNCATE` sobre la misma `raw` |
| `retries` | 2, cada 30 s | Cubre caídas momentáneas de la base |
| `retries` en `validar_raw`, `inyectar_casos_calidad`, `dbt_build` | 0 | Un fallo de datos no se arregla reintentando |
| `on_failure_callback` | `registrar_fallo` | Deja en el log tarea, intento, corrida y enlace al log |
| Parámetro `modo_calidad` | `False` | Activa la inyección de casos inválidos |

Las tareas de dbt usan `dbt deps` y `dbt build` con
`--project-dir /opt/airflow/dbt/sgfood --profiles-dir /opt/airflow/dbt/sgfood`, tal
como quedó en el contrato. El DAG no conoce los modelos: si `dbt build` termina
bien, la tarea queda en verde.

`validar_marts` es un marcador hasta que existan los hechos de B3; ahí ejecutará
`sql/validacion/30_reconciliacion.sql`.

## 4. Manual de implementación

Requisitos: Docker Desktop (o Docker Engine con Compose v2). Para correr los
scripts fuera de Docker, Python 3.10 a 3.13.

```bash
cd Proyecto1
cp .env.example .env
docker compose up -d --build
```

La primera vez construye la imagen de Airflow (unos minutos). Cuando
`docker compose ps` muestre `sgfood-airflow` como `healthy`:

- Interfaz de Airflow: http://localhost:8080 (sin usuario, modo desarrollo).
- El DAG `sgfood_elt` aparece activo y corre una vez al detectarse.
- Para correrlo a mano: botón *Trigger* en la interfaz, o
  `docker exec sgfood-airflow airflow dags trigger sgfood_elt`.
- Corrida de calidad: *Trigger* con `{"modo_calidad": true}`, o
  `docker exec sgfood-airflow airflow dags trigger sgfood_elt -c '{"modo_calidad": true}'`.

Si los puertos 5433 u 8080 están ocupados, cambiar `PG_HOST_PORT` o
`AIRFLOW_HOST_PORT` en `.env`. En Linux, poner `AIRFLOW_UID=$(id -u)` para que los
logs queden con el usuario propio.

Correr los scripts desde la terminal, sin Airflow:

```bash
python3.12 -m venv .venv && source .venv/bin/activate
pip install -r extract_load/requirements.txt
python extract_load/crear_raw.py
python extract_load/extract_oltp.py
python extract_load/load_csv.py
python extract_load/validate_raw.py
```

Toman la conexión de `.env` (`localhost:5433`).

Empezar desde cero: `docker compose down -v && docker compose up -d`.

## 5. Evidencia de las pruebas

| Fase | Prueba | Resultado |
|---|---|---|
| A1 | Extracción | 6 / 8 / 10 / 80 / 250 / 1,200 / 3,209 filas; `SUM(subtotal)` = 838,452.07 |
| A1 | Segunda corrida | Mismos conteos, un solo `_loaded_at` por tabla |
| A1 | Base apagada | Error de conexión claro, código 1 |
| A1 | Tabla fuente renombrada a mitad de la extracción | Código 1, `raw` sin cambios (las tablas ya copiadas se revierten) |
| A2 | Carga | 3,840 / 103 / 30 / 48 / 80 filas; `SUM(meta_ventas)` = 9,257,592.56; primera columna `fecha_corte` sin BOM |
| A2 | Encabezado alterado (`stock_min`) | Código 1, no se conecta a la base |
| A2 | Valor no numérico (`setenta`) | Código 1, `raw` sin cambios |
| A3 | Después de A1 + A2 | Las 12 tablas cuadran |
| A3 | Una fila borrada de `raw.venta` | `raw.venta: 1199 filas, fuente 1200 (diferencia -1)`, código 1 |
| A3 | `--loaded-at` distinto al cargado | Señala cada tabla que no es de esta corrida |
| A4 | Primera corrida automática | 9 tareas en verde en 15 s; las 12 tablas con el `_loaded_at` de la corrida |
| A4 | Dos corridas manuales seguidas | Ambas en verde; 3,209 líneas y 838,452.07 sin duplicar |
| A4 | PostgreSQL detenido | `crear_schemas_raw` con 3 intentos, callback registra el fallo, el resto `upstream_failed` |
| A5 | `modo_calidad=true` | Los 10 casos insertados con su incidencia en el log; la siguiente corrida normal los elimina |

Pendiente para cerrar A5, cuando B3 esté en `main`:

- [ ] `sql/validacion/30_reconciliacion.sql` y la tarea `validar_marts` real.
- [ ] Corrida desde cero con todos los tests de dbt en verde.
- [ ] Corrida con `modo_calidad=true` con `dbt_build` fallando en los tests esperados.
- [ ] Capturas en `docs/evidencias/A_*.png`: grafo del DAG en verde, log de
      `validar_raw`, corrida con fallo y corrida de calidad.
