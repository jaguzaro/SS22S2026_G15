import argparse
import logging
import sys

import psycopg

from config import SQL_DIR, configurar_logging, conninfo_dw

log = logging.getLogger("validate_marts")


def validar():
    consulta = (SQL_DIR / "validacion" / "30_reconciliacion.sql").read_text(encoding="utf-8")
    errores = []
    with psycopg.connect(**conninfo_dw()) as conexion:
        for _, control, esperado, obtenido in conexion.execute(consulta):
            cuadra = esperado == obtenido
            log.info("%-5s %-45s esperado %12s, obtenido %12s", "ok" if cuadra else "FALLA", control, esperado, obtenido)
            if not cuadra:
                errores.append(f"{control}: esperado {esperado}, obtenido {obtenido}")
    return errores


def main():
    configurar_logging()
    argparse.ArgumentParser(description="Reconcilia conteos y sumas de raw contra marts.").parse_args()
    try:
        errores = validar()
    except (OSError, psycopg.Error) as error:
        log.error("No se pudo reconciliar marts: %s", str(error).strip())
        return 1
    if errores:
        for error in errores:
            log.error(error)
        log.error("Reconciliacion de marts: %d controles no cuadran", len(errores))
        return 1
    log.info("Reconciliacion de marts: los controles cuadran con raw")
    return 0


if __name__ == "__main__":
    sys.exit(main())
