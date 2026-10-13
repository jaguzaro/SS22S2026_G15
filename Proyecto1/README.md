# Proyecto 1 · SG-Food: flujo ELT con Python, Airflow, dbt y PostgreSQL

Seminario de Sistemas 2, Universidad de San Carlos de Guatemala. Grupo 15.

| Integrante | Usuario / carnet | Rol |
|---|---|---|
| Joel | jguzaro | A · Ingesta y orquestación (Python + Airflow) |
| Alvaro | 199817948 | B · Modelado y calidad (dbt + Data Warehouse) |

> Este README está en construcción. Se completa en la Fase F a partir de
> `docs/arquitectura_y_dag.md` (A) y `docs/modelo_dw_y_dbt.md` (B). El reparto y las
> fases están en [`docs/plan_de_trabajo.md`](docs/plan_de_trabajo.md).

## Estado

- [x] Fase 0 · Base común: PostgreSQL con la fuente y el contrato de `raw`, esqueleto dbt
- [ ] A1–A5 · Extracción, carga, validación, DAG de Airflow, integración
- [ ] B1–B5 · Staging, dimensiones, hechos, pruebas, DDL y consultas analíticas
- [ ] Fase F · Cierre

## Estructura

```
docker-compose.yml        PostgreSQL (Airflow se agrega en A4)
.env.example              variables de conexión; copiar a .env
data/oltp/                fuente transaccional (sgfood_oltp.sql)
data/csv/                 fuentes CSV que se cargan con Python
data/calidad/             casos inválidos, solo para la corrida de calidad
data/referencia/          diccionario de datos (.xlsx) y el .zip original
sql/00_init_databases.sql crea sgfood_oltp y sgfood_dw con sus schemas
sql/01_raw_ddl.sql        contrato del schema raw (12 tablas)
extract_load/             scripts Python de extracción y carga (A)
airflow/dags/             DAG del pipeline (A)
dbt/sgfood/               proyecto dbt (B)
scripts/                  utilidades de verificación
docs/                     plan, documentación técnica, enunciado y evidencias
```

## Levantar el entorno (Fase 0)

Requisitos: Docker y Python 3.10–3.13 (dbt todavía no soporta 3.14).

```bash
cd Proyecto1
cp .env.example .env
docker compose up -d postgres
./scripts/verificar_fase0.sh
```

El contenedor crea dos bases al iniciar con el volumen vacío:

- `sgfood_oltp`: la fuente transaccional, schema `oltp_sgfood`.
- `sgfood_dw`: el Data Warehouse, schemas `raw`, `staging`, `intermediate` y `marts`.

Queda expuesto en `localhost:5433` (cambiar `PG_HOST_PORT` en `.env` si está ocupado).
Para empezar desde cero: `docker compose down -v && docker compose up -d postgres`.

dbt:

```bash
python3.12 -m venv .venv && source .venv/bin/activate
pip install -r dbt/sgfood/requirements.txt
set -a && source .env && set +a
cd dbt/sgfood
dbt debug --profiles-dir .
dbt deps --profiles-dir .
```

En Windows (PowerShell), las variables se cargan con:
`Get-Content .env | Where-Object { $_ -match '^\w' } | ForEach-Object { $k, $v = $_ -split '=', 2; Set-Item "env:$k" $v }`
