# Proyecto 1 · Plan de trabajo en pareja

SG-Food: flujo ELT con Python, Apache Airflow, dbt y PostgreSQL.
Grupo 15: Joel (jguzaro) y Alvaro (199817948).

El reparto sigue la costura natural del pipeline. La persona A es dueña de todo lo que
ocurre antes del schema `raw` y de la orquestación. La persona B es dueña de todo lo que
ocurre después de `raw`: dbt, el modelo dimensional, las pruebas y las consultas
analíticas. El único punto de contacto entre ambos es el contrato de `raw`, que se fija
en la Fase 0 y no se cambia sin avisar.

| Rol | Sugerido | Rúbrica que cubre | Puntos aprox. |
|---|---|---|---|
| A · Ingesta y orquestación | Joel | 1.1 flujo Python + Airflow (20), mitad de 2.2 integración y validación de carga (15), mitad de doc (5), mitad de repo (5) | 45 |
| B · Modelado y calidad | Alvaro | 2.1 DW + dbt (30), mitad de 2.2 pruebas dbt y consultas (15), mitad de doc (5), mitad de repo (5) | 55 |

B tiene más puntos y A tiene más infraestructura (Docker, Airflow, la corrida de calidad
y la integración final), así que en horas queda parejo. Los roles se pueden invertir sin
cambiar nada del plan.


## 1. Lo que trae el .zip (ya revisado)

| Archivo | Destino | Filas |
|---|---|---|
| `sgfood_oltp.sql` | BD fuente `sgfood_oltp`, schema `oltp_sgfood` | sucursal 6, categoria 8, marca 10, producto 80, cliente 250, venta 1,200, venta_detalle 3,209 |
| `inventario_bodega.csv` | raw | 3,840 (8 cortes mensuales × 6 sucursales × 80 productos) |
| `proveedores_precios.csv` | raw | 103 (12 proveedores; 23 productos tienen más de un proveedor) |
| `promociones.csv` | raw | 30 |
| `metas_ventas.csv` | raw | 48 (8 meses × 6 sucursales) |
| `devoluciones.csv` | raw | 80 |
| `casos_calidad_opcionales.csv` | **no** se carga en la corrida principal | 10 casos inválidos para probar los tests |
| `catalogo_insumos_sgfood.xlsx` | solo referencia (diccionario de datos) | — |

Cosas que ya se verificaron y conviene saber:

- Los cinco CSV traen BOM UTF-8. Leer con `encoding="utf-8-sig"`; si no, la primera
  columna se llama `﻿fecha_corte` y todo lo que dependa de ella falla.
- Los datos principales están limpios: subtotal = cantidad × precio × (1 − descuento) en
  las 3,209 líneas, ninguna devolución supera lo vendido ni es anterior a la venta, no
  hay stock negativo ni vencimientos anteriores al corte, no hay vacíos en los CSV.
- `venta.estado`: 1,129 COMPLETADA, 48 ANULADA, 23 PENDIENTE. Hay que decidir (B) si el
  hecho las filtra o las conserva con atributo de estado. Recomendado: conservarlas y
  que las medidas filtren.
- Ventas del 2026-01-01 al 2026-08-31. Las altas de cliente arrancan en 2024-01-01 y los
  vencimientos de inventario llegan a 2028-01-13; `dim_fecha` debe cubrir ese rango o el
  vencimiento se deja como atributo y no como llave.
- `proveedores_precios` necesita una regla para elegir un costo por producto (el de
  vigencia más reciente o el mínimo). Es la principal decisión de `intermediate`.
- La suma de `metas_ventas.meta_ventas` (9,257,592.56) es unas 11 veces lo vendido
  (838,452.07). No es un error de carga; documentarlo en las consultas analíticas.
- 394 registros de inventario están por debajo de `stock_minimo`: es un hallazgo de
  negocio, no un fallo de calidad.

Números de referencia (si salen, la carga está bien):

| Señal | Valor |
|---|---|
| Líneas de venta | 3,209 |
| Suma de subtotal, todas | 838,452.07 |
| Suma de subtotal, solo COMPLETADA | 780,201.72 |
| Suma de metas | 9,257,592.56 |


## 2. Arquitectura acordada

```
 sgfood_oltp (BD fuente)  ─┐
                           ├─ Python (A) ─► sgfood_dw.raw ─► dbt (B) ─► staging ─► intermediate ─► marts
 data/csv/*.csv  ──────────┘                                                 │
                                                                             └─ tests dbt + consultas SQL
 Airflow (A) orquesta todo: crear_schemas → extraer/cargar → validar_raw → dbt build → validar_marts
```

- Un contenedor PostgreSQL con dos bases: `sgfood_oltp` (fuente) y `sgfood_dw` (DW con
  schemas `raw`, `staging`, `intermediate`, `marts`). Airflow usa su propia base de
  metadatos, separada.
- dbt se instala en un entorno virtual aparte dentro de la imagen de Airflow
  (`/opt/dbt-venv`) para que sus dependencias no choquen con las de Airflow. El DAG lo
  llama con `BashOperator`.
- Conexiones por variables de entorno (`.env`, nunca versionado; `.env.example` sí).


## 3. Estructura del repositorio y dueños

Cada quien escribe solo en sus carpetas. Así los merges nunca chocan.

```
Proyecto1/
  README.md                         F  (se arma al final, ver Fase F)
  docker-compose.yml                0 → A
  Dockerfile.airflow                0 → A
  .env.example                      0 → A
  data/oltp/sgfood_oltp.sql         0  (copiado del zip, no se edita)
  data/csv/*.csv                    0  (copiado del zip, no se edita)
  data/calidad/casos_calidad_opcionales.csv   0
  data/referencia/                  0  (diccionario .xlsx y el .zip original)
  scripts/verificar_fase0.sh        0       comprobable de la Fase 0
  sql/00_init_databases.sql         0 → A   crea bases y schemas
  sql/01_raw_ddl.sql                0 → A   EL CONTRATO (ver 4)
  sql/02_dw_ddl.sql                 B       DDL de marts con PK y FK (entregable)
  sql/validacion/10_carga_raw.sql   A       conteos fuente vs raw
  sql/validacion/20_consultas_analiticas.sql  B
  sql/validacion/30_reconciliacion.sql        A       raw vs marts (conteos y sumas)
  extract_load/                     A       config.py, extract_oltp.py, load_csv.py,
                                            validate_raw.py, inject_quality_cases.py,
                                            requirements.txt
  airflow/dags/sgfood_elt.py        A
  dbt/sgfood/                       0 → B   dbt_project.yml, profiles.yml, packages.yml,
                                            models/{staging,intermediate,marts}, tests/,
                                            macros/, requirements.txt
  docs/plan_de_trabajo.md           este archivo
  docs/arquitectura_y_dag.md        A
  docs/modelo_dw_y_dbt.md           B
  docs/evidencias/A_*.png           A       capturas de Airflow y carga
  docs/evidencias/B_*.png           B       capturas de dbt (build, docs, lineage)
```

Ramas: `p1/base` (Fase 0), `p1/ingesta` (A), `p1/dbt` (B). Cada fase cerrada se integra a
`main` con un PR que revisa la otra persona. Nadie hace merge de su propio PR.


## 4. El contrato de `raw` (Fase 0, no se cambia sin avisar)

- Una tabla por fuente, mismo nombre que la fuente: `raw.sucursal`, `raw.categoria`,
  `raw.marca`, `raw.producto`, `raw.cliente`, `raw.venta`, `raw.venta_detalle`,
  `raw.inventario_bodega`, `raw.proveedores_precios`, `raw.promociones`,
  `raw.metas_ventas`, `raw.devoluciones`.
- Mismas columnas y mismos nombres que la fuente, en el mismo orden.
- Tipos: los de la fuente para las tablas OLTP; para los CSV, los del diccionario del
  .xlsx. La limpieza y el casteo fino es trabajo de staging (B), no de raw.
- Dos columnas de auditoría al final de cada tabla: `_source` (texto: `oltp` o nombre del
  archivo) y `_loaded_at` (timestamp de la corrida).
- Sin PK ni FK en raw (se necesita para que la corrida de calidad pueda insertar datos
  inválidos y que los tests de dbt los atrapen).
- Carga por reemplazo completo (`TRUNCATE` + `INSERT`) dentro de una transacción: la
  carga es idempotente.
- dbt se conecta con: host, puerto, usuario, password y base `sgfood_dw` desde las
  variables `DW_HOST`, `DW_PORT`, `DW_USER`, `DW_PASSWORD`, `DW_DB`; target `dev`.
  Desde la máquina local el puerto es 5433 (`PG_HOST_PORT`); desde un contenedor de la
  misma red de Docker es `postgres:5432`.
- Cada carpeta de `models/` construye en el schema del mismo nombre, sin prefijo
  (`marts.fct_ventas`, no `staging_marts.fct_ventas`). Lo asegura
  `macros/generate_schema_name.sql`.
- El DAG llama a dbt así y solo así:
  `dbt build --project-dir /opt/airflow/dbt/sgfood --profiles-dir /opt/airflow/dbt/sgfood`.
  Mientras ese comando pase, A no necesita saber qué modelos hay.


## 5. Fases

Cada fase termina con un comprobable concreto. No se pasa a la siguiente sin que el
comprobable pase y quede registrado (captura o salida pegada en el PR).

### Fase 0 · Base común (juntos, una sesión de ~2 h; A hace los commits, B revisa)

Entregables:

1. Estructura de carpetas de la sección 3, `.gitignore` (`.env`, `target/`, `logs/`,
   `dbt_packages/`, `__pycache__/`, `.venv/`).
2. Contenido del zip copiado a `data/`.
3. `docker-compose.yml` con PostgreSQL. Al levantar, `00_init_databases.sql` crea
   `sgfood_oltp` y `sgfood_dw`, carga `sgfood_oltp.sql` en la primera y crea los cuatro
   schemas en la segunda. Airflow todavía no.
4. `sql/01_raw_ddl.sql` con las 12 tablas vacías del contrato.
5. Esqueleto dbt en `dbt/sgfood` con `profiles.yml` leyendo variables de entorno,
   `dbt_utils` en `packages.yml` y la macro de nombres de schema.
6. `.env.example` y `scripts/verificar_fase0.sh`.

Comprobable (`./scripts/verificar_fase0.sh` revisa los tres primeros; en Windows,
correrlo desde Git Bash):

- [x] `docker compose down -v && docker compose up -d postgres` levanta sin errores.
- [x] En `sgfood_oltp`: las 7 tablas con 6 / 8 / 10 / 80 / 250 / 1,200 / 3,209 filas y
      `SUM(subtotal)` = 838,452.07.
- [x] En `sgfood_dw`: existen los schemas `raw`, `staging`, `intermediate`, `marts` y las
      12 tablas de `raw`, vacías, con las mismas columnas y tipos que su fuente.
      `01_raw_ddl.sql` se puede volver a correr.
- [x] `dbt debug` dice `All checks passed!`, `dbt deps` instala `dbt_utils` y
      `dbt build` termina con código 0 sin modelos. Un modelo de prueba en
      `models/marts/` queda en `marts.`, sin prefijo.
- [ ] Lo mismo en la máquina de la otra persona.
- [ ] PR `p1/base` integrado a `main`. A partir de aquí cada quien crea su rama desde
      `main`.


### Persona A · Ingesta y orquestación

**A1 · Extracción OLTP → raw**

`extract_load/extract_oltp.py`: conecta a `sgfood_oltp`, lee las 7 tablas, agrega
`_source` y `_loaded_at`, y las escribe en `raw` por reemplazo en una transacción.
Logging a archivo y a consola; código de salida distinto de cero si falla. Configuración
solo desde variables de entorno (`config.py`).

- [ ] Una corrida deja en raw: 6 / 8 / 10 / 80 / 250 / 1,200 / 3,209.
- [ ] Una segunda corrida deja exactamente los mismos conteos (idempotente).
- [ ] `SUM(subtotal)` en `raw.venta_detalle` = 838,452.07.
- [ ] Con la base apagada, el script termina con error claro y código ≠ 0.

**A2 · Carga de CSV → raw**

`extract_load/load_csv.py`: lee los 5 CSV con `utf-8-sig`, valida que los encabezados
coincidan con el contrato antes de cargar (si no, falla sin tocar raw), castea a los
tipos del diccionario y carga por reemplazo. Ignora `casos_calidad_opcionales.csv`.

- [ ] Conteos: 3,840 / 103 / 30 / 48 / 80.
- [ ] La primera columna de cada tabla se llama bien (sin BOM).
- [ ] `SUM(meta_ventas)` = 9,257,592.56.
- [ ] Con un CSV al que se le cambia un encabezado, el script falla y raw no cambia.
- [ ] Segunda corrida idempotente.

**A3 · Validación de la carga**

`extract_load/validate_raw.py` + `sql/validacion/10_carga_raw.sql`: compara conteos de
la fuente (OLTP y líneas de cada CSV) contra raw; revisa que `_loaded_at` sea de la
corrida actual. Termina con código ≠ 0 si algo no cuadra.

- [ ] Pasa después de A1 + A2.
- [ ] Si se borra a mano una fila de `raw.venta`, falla e indica qué tabla y por cuánto.

**A4 · DAG de Airflow**

Airflow agregado al `docker-compose.yml` con `Dockerfile.airflow` (Airflow + dbt en
venv aparte). `airflow/dags/sgfood_elt.py`:

```
inicio
  → crear_schemas_raw                 (ejecuta 01_raw_ddl.sql, idempotente con IF NOT EXISTS)
  → [extraer_oltp, cargar_csv]        (en paralelo)
  → validar_raw
  → dbt_deps → dbt_build              (el comando del contrato)
  → validar_marts                     (30_reconciliacion.sql, ver A5)
  → fin
```

Con `retries` y `retry_delay`, `on_failure_callback` que registre el fallo,
`schedule` diario y `catchup=False` (opcional recomendado), conexiones vía variables de
entorno o Airflow Connections. Mientras B no tenga modelos, `dbt_build` corre igual sobre
el esqueleto (no falla, no construye nada) y `validar_marts` puede quedar como
`EmptyOperator`.

- [ ] DAG visible en la UI, sin errores de import.
- [ ] Una corrida manual queda toda en verde. Captura del grafo y del log de
      `validar_raw` en `docs/evidencias/A_*`.
- [ ] Apagar PostgreSQL a mitad de corrida: la tarea reintenta, falla y queda el log.
- [ ] Doble corrida seguida: mismos conteos (el DAG es idempotente).

**A5 · Integración y corrida de calidad** (empieza cuando B3 esté en `main`)

- `sql/validacion/30_reconciliacion.sql`: conteos y sumas raw vs marts (por ejemplo,
  3,209 líneas y 838,452.07 en raw = en `fct_ventas`). `validar_marts` lo ejecuta.
- `extract_load/inject_quality_cases.py`: después de la carga normal, inserta en raw los
  10 casos de `casos_calidad_opcionales.csv`. Se activa con un parámetro del DAG
  (`modo_calidad=true`), nunca por defecto.

- [ ] Corrida desde cero (`docker compose down -v`, `up`, disparar DAG): todo verde,
      incluidos los tests de B. Anotar duración.
- [ ] Corrida con `modo_calidad=true`: `dbt_build` falla y el log nombra los tests que
      atraparon cada caso. Captura. Volver a correr normal deja todo verde de nuevo.
- [ ] `docs/arquitectura_y_dag.md` escrito: arquitectura, tareas del DAG, manejo de
      errores, variables, cómo levantar.


### Persona B · Modelado y calidad

Si A1/A2 todavía no están en `main` cuando B los necesita, B carga raw a mano con
`\copy` o `INSERT ... SELECT` desde `sgfood_oltp` en su máquina. Eso no se versiona; solo
sirve para no esperar.

**B1 · Sources y staging**

`models/staging/_sources.yml` con las 12 tablas de raw y tests de source (`unique` y
`not_null` en las llaves). Un `stg_*` por tabla: nombres consistentes, tipos explícitos,
`trim`, textos normalizados, sin columnas de auditoría salvo `_loaded_at`.
Materialización `view` en schema `staging`.

- [ ] `dbt build --select staging` en verde.
- [ ] Cada `stg_*` tiene el mismo conteo que su tabla raw.
- [ ] `dbt docs generate` funciona.

**B2 · Intermediate y dimensiones**

Intermediate (schema `intermediate`, `ephemeral` o `view`):
`int_ventas_lineas` (detalle + cabecera de venta), `int_costo_proveedor_vigente` (una
fila por producto con la regla elegida, documentada), `int_promocion_por_linea` (qué
promoción aplica por fecha y categoría, si alguna).

Dimensiones (schema `marts`, `table`, con `contract: enforced` y PK):
`dim_fecha` (calendario que cubra todas las fechas usadas como llave),
`dim_producto` (con categoría, marca y costo de proveedor),
`dim_cliente`, `dim_sucursal`, `dim_proveedor`, `dim_promocion`, y una dimensión
basura `dim_tipo_venta` (canal × método de pago × estado). Cada dimensión con miembro
-1 DESCONOCIDO, igual que en la Práctica 1.

- [ ] `dbt build --select +marts` (solo dims) en verde.
- [ ] Conteos: productos 80 + 1, clientes 250 + 1, sucursales 6 + 1.
- [ ] `int_costo_proveedor_vigente` tiene exactamente 80 filas, una por producto.
- [ ] `dim_fecha` sin huecos ni duplicados.

**B3 · Hechos**

`fct_ventas` (grano: línea de venta, 3,209), `fct_inventario` (snapshot mensual,
3,840), `fct_devoluciones` (80), `fct_metas_ventas` (sucursal × mes, 48). FK hacia las
dimensiones con `constraints` de tipo `foreign_key` en el contrato y además tests
`relationships`.

- [ ] Conteos exactos de arriba.
- [ ] `SUM(subtotal)` en `fct_ventas` = 838,452.07; solo COMPLETADA = 780,201.72.
- [ ] Ninguna FK cae en -1 con los datos limpios (si cae, hay un join mal).
- [ ] `\d marts.fct_ventas` en psql muestra PK y FK reales.

**B4 · Pruebas de calidad**

Tests genéricos en los `.yml` (`unique`, `not_null`, `relationships`,
`accepted_values` para estado, canal y método de pago, rangos con `dbt_utils`) y tests
singulares en `tests/`. Que cubran uno a uno los 10 casos de
`casos_calidad_opcionales.csv`:

| Caso | Test que lo atrapa |
|---|---|
| NULL en id_cliente | `not_null` en `stg_cliente.id_cliente` |
| precio_lista negativo | rango ≥ 0 en `stg_producto` |
| FK huérfana en venta | `relationships` venta → cliente |
| cantidad cero | rango > 0 en `stg_venta_detalle` |
| descuento > 100 % | rango 0–1 |
| stock negativo | rango ≥ 0 en `stg_inventario_bodega` |
| vencimiento anterior al corte | singular |
| costo de proveedor nulo | `not_null` |
| meta cero | rango > 0 |
| devolución mayor a lo vendido | singular contra `int_ventas_lineas` |

Más dos singulares de coherencia: subtotal = cantidad × precio × (1 − descuento) con
tolerancia de 0.01, y devolución no anterior a la venta.

- [ ] `dbt build` completo en verde con datos limpios.
- [ ] Cada fila de la tabla anterior tiene su test y está en el repo.
- [ ] Antes de que A5 exista, B prueba al menos dos casos insertándolos a mano en su
      raw local y confirma que fallan.
- [ ] Captura de `dbt build` y del grafo de lineage de `dbt docs` en
      `docs/evidencias/B_*`.

**B5 · DDL entregable y consultas analíticas**

`sql/02_dw_ddl.sql`: schemas, tablas raw (o `\i 01_raw_ddl.sql`), dimensiones y hechos
con PK y FK. Debe coincidir con lo que construye dbt; se comprueba corriéndolo en una
base vacía.

`sql/validacion/20_consultas_analiticas.sql`, con el resultado esperado anotado en un
comentario debajo de cada consulta:

1. Ventas reales vs meta por sucursal y mes (y la nota de que las metas son ~11× lo real).
2. Top 10 productos por ingreso y por margen (precio vs costo de proveedor).
3. Ingreso por canal y método de pago, solo COMPLETADA.
4. Tasa de devolución por categoría y por motivo.
5. Productos bajo stock mínimo por sucursal en el último corte.
6. Ventas en periodos con promoción vs sin promoción, por categoría.

- [ ] `02_dw_ddl.sql` corre sin errores en una base vacía.
- [ ] Las 6 consultas corren y sus resultados anotados se reproducen.
- [ ] `docs/modelo_dw_y_dbt.md` escrito: diagrama estrella, grano de cada hecho,
      decisiones (estado de venta, costo vigente, miembro -1, materializaciones), lista
      de tests.


### Fase F · Cierre (juntos)

1. **Validación cruzada**: A sigue el manual de B desde cero en su máquina y B sigue el
   de A en la suya. Lo que no funcione siguiendo solo el texto se corrige en el
   documento, no de palabra.
2. README armado por una sola persona (B, porque A cerró la integración) a partir de
   los dos documentos de `docs/`: nombre del proyecto, integrantes, descripción del
   pipeline, DAG, modelo del DW, estructura dbt, justificación de diseño, manual de
   implementación, evidencias.
3. Comprobable final, en una máquina limpia:
   - [ ] `git clone` → `cp .env.example .env` → `docker compose up -d` → disparar el DAG
         → todo verde.
   - [ ] `dbt build` en verde, `dbt docs` generado.
   - [ ] Las consultas de `20_consultas_analiticas.sql` dan lo anotado.
   - [ ] La corrida de calidad falla donde debe.
   - [ ] README con ambos integrantes y commits de los dos en la historia.


## 6. Calendario sugerido (semana 11)

| Día | A | B |
|---|---|---|
| 1 | Fase 0 juntos · A1 | Fase 0 juntos · B1 |
| 2 | A2 · A3 | B1 · B2 |
| 3 | A4 | B2 · B3 |
| 4 | A4 (pruebas de fallo) | B4 |
| 5 | A5 | B5 |
| 6 | Fase F juntos | Fase F juntos |

Dependencias reales entre los dos, todas cubiertas:

| Quién espera | A qué | Cómo no bloquearse |
|---|---|---|
| B1 | datos en raw | carga manual local, no versionada |
| A4 | proyecto dbt | el esqueleto de la Fase 0 ya pasa `dbt build` |
| A5 | marts de B3 | A5 es la última fase de A; mientras tanto A4 queda completo |
| B4 | corrida de calidad de A5 | B inserta a mano dos casos en su raw local |
