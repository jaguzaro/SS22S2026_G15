import logging
import sys

import psycopg
from psycopg import sql

from config import (
    CSV_DIR,
    OLTP_SCHEMA,
    SQL_DIR,
    argumentos_comunes,
    configurar_logging,
    conninfo_dw,
    conninfo_oltp,
    marca_de_carga,
)
from contrato import COLUMNAS_AUDITORIA, ESQUEMA_RAW, TABLAS_CSV, TABLAS_OLTP
from load_csv import EncabezadoInvalido, leer_csv

log = logging.getLogger("validate_raw")


def conteos_fuente():
    conteos = {}
    with psycopg.connect(**conninfo_oltp()) as conexion:
        for tabla in TABLAS_OLTP:
            consulta = sql.SQL("SELECT count(*) FROM {}").format(sql.Identifier(OLTP_SCHEMA, tabla))
            conteos[tabla] = conexion.execute(consulta).fetchone()[0]
    for tabla, columnas in TABLAS_CSV.items():
        conteos[tabla] = len(leer_csv(CSV_DIR / f"{tabla}.csv", columnas))
    return conteos


def columnas_raw(conexion):
    filas = conexion.execute(
        "SELECT table_name, column_name FROM information_schema.columns "
        "WHERE table_schema = %s ORDER BY table_name, ordinal_position",
        (ESQUEMA_RAW,),
    ).fetchall()
    columnas = {}
    for tabla, columna in filas:
        columnas.setdefault(tabla, []).append(columna)
    return columnas


def validar(loaded_at_esperado):
    errores = []
    fuente = conteos_fuente()
    contrato = {**TABLAS_OLTP, **TABLAS_CSV}
    with psycopg.connect(**conninfo_dw()) as conexion:
        columnas = columnas_raw(conexion)
        for tabla, esperadas in contrato.items():
            if columnas.get(tabla) != esperadas + COLUMNAS_AUDITORIA:
                errores.append(f"raw.{tabla}: columnas {columnas.get(tabla)} no siguen el contrato")
        if errores:
            return errores
        consulta = (SQL_DIR / "validacion" / "10_carga_raw.sql").read_text(encoding="utf-8")
        for _, tabla, filas, cargas, ultima, sin_auditoria in conexion.execute(consulta):
            diferencia = filas - fuente[tabla]
            estado = "ok" if diferencia == 0 else "FALLA"
            log.info("%-5s raw.%-20s %6d filas, fuente %6d", estado, tabla, filas, fuente[tabla])
            if diferencia:
                errores.append(f"raw.{tabla}: {filas} filas, fuente {fuente[tabla]} (diferencia {diferencia:+d})")
            if filas and cargas != 1:
                errores.append(f"raw.{tabla}: {cargas} valores distintos de _loaded_at, se esperaba 1")
            if sin_auditoria:
                errores.append(f"raw.{tabla}: {sin_auditoria} filas sin _source o _loaded_at")
            if loaded_at_esperado and filas and ultima != loaded_at_esperado:
                errores.append(f"raw.{tabla}: _loaded_at {ultima.isoformat()} no es de esta corrida")
    return errores


def main():
    configurar_logging()
    parser = argumentos_comunes("Compara los conteos de las fuentes contra raw.")
    args = parser.parse_args()
    esperado = marca_de_carga(args.loaded_at) if args.loaded_at else None
    try:
        errores = validar(esperado)
    except (OSError, EncabezadoInvalido, psycopg.Error) as error:
        log.error("No se pudo validar raw: %s", str(error).strip())
        return 1
    if errores:
        for error in errores:
            log.error(error)
        log.error("Validacion de raw: %d problemas", len(errores))
        return 1
    log.info("Validacion de raw: las 12 tablas cuadran con sus fuentes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
