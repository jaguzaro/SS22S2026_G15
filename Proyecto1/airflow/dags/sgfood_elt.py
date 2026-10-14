import logging
from datetime import datetime, timedelta

from airflow.providers.standard.operators.bash import BashOperator
from airflow.providers.standard.operators.empty import EmptyOperator
from airflow.sdk import DAG, Param

EXTRACT_LOAD = "/opt/airflow/extract_load"
DBT_PROJECT = "/opt/airflow/dbt/sgfood"
DBT_ARGS = f"--project-dir {DBT_PROJECT} --profiles-dir {DBT_PROJECT}"
LOADED_AT = "--loaded-at '{{ dag_run.start_date.isoformat() }}'"

log = logging.getLogger("sgfood_elt")


def registrar_fallo(context):
    ti = context["ti"]
    log.error(
        "Fallo en %s.%s (intento %s, corrida %s). Log: %s",
        ti.dag_id,
        ti.task_id,
        ti.try_number,
        context["run_id"],
        ti.log_url,
    )


with DAG(
    dag_id="sgfood_elt",
    description="SG-Food: extraccion y carga a raw, dbt build y validaciones",
    start_date=datetime(2026, 10, 1),
    schedule="@daily",
    catchup=False,
    max_active_runs=1,
    default_args={
        "owner": "grupo15",
        "retries": 2,
        "retry_delay": timedelta(seconds=30),
        "on_failure_callback": registrar_fallo,
    },
    params={
        "modo_calidad": Param(
            False,
            type="boolean",
            description="Inyecta en raw los casos invalidos de data/calidad para que los tests de dbt fallen",
        ),
    },
    tags=["sgfood", "elt", "proyecto1"],
) as dag:
    inicio = EmptyOperator(task_id="inicio")

    crear_schemas_raw = BashOperator(
        task_id="crear_schemas_raw",
        bash_command=f"cd {EXTRACT_LOAD} && python crear_raw.py",
    )

    extraer_oltp = BashOperator(
        task_id="extraer_oltp",
        bash_command=f"cd {EXTRACT_LOAD} && python extract_oltp.py {LOADED_AT}",
    )

    cargar_csv = BashOperator(
        task_id="cargar_csv",
        bash_command=f"cd {EXTRACT_LOAD} && python load_csv.py {LOADED_AT}",
    )

    validar_raw = BashOperator(
        task_id="validar_raw",
        bash_command=f"cd {EXTRACT_LOAD} && python validate_raw.py {LOADED_AT}",
        retries=0,
    )

    inyectar_casos_calidad = BashOperator(
        task_id="inyectar_casos_calidad",
        bash_command=(
            "{% if params.modo_calidad %}"
            f"cd {EXTRACT_LOAD} && python inject_quality_cases.py"
            "{% else %}"
            "echo 'modo_calidad desactivado: no se inyectan casos'"
            "{% endif %}"
        ),
        retries=0,
    )

    dbt_deps = BashOperator(
        task_id="dbt_deps",
        bash_command=f"dbt deps {DBT_ARGS}",
    )

    dbt_build = BashOperator(
        task_id="dbt_build",
        bash_command=(
            "{% if params.modo_calidad %}"
            f"dbt run --select staging intermediate {DBT_ARGS} && dbt test --select staging intermediate {DBT_ARGS}"
            "{% else %}"
            f"dbt build {DBT_ARGS}"
            "{% endif %}"
        ),
        retries=0,
    )

    validar_marts = BashOperator(
        task_id="validar_marts",
        bash_command=f"cd {EXTRACT_LOAD} && python validate_marts.py",
        retries=0,
    )

    fin = EmptyOperator(task_id="fin")

    inicio >> crear_schemas_raw >> [extraer_oltp, cargar_csv] >> validar_raw
    validar_raw >> inyectar_casos_calidad >> dbt_deps >> dbt_build >> validar_marts >> fin
