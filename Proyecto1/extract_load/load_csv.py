import csv
import logging
import sys
import time

import psycopg
from psycopg import sql

from config import CSV_DIR, argumentos_comunes, configurar_logging, conninfo_dw, marca_de_carga
from contrato import COLUMNAS_AUDITORIA, ESQUEMA_RAW, TABLAS_CSV

log = logging.getLogger("load_csv")


class EncabezadoInvalido(Exception):
    pass


def leer_csv(ruta, columnas):
    with open(ruta, encoding="utf-8-sig", newline="") as archivo:
        lector = csv.reader(archivo)
        encabezado = [c.strip() for c in next(lector)]
        if encabezado != columnas:
            raise EncabezadoInvalido(
                f"{ruta.name}: encabezado {encabezado} no coincide con el contrato {columnas}"
            )
        return [[valor.strip() or None for valor in fila] for fila in lector if any(fila)]


def cargar_tabla(conexion, tabla, columnas, filas, fuente, loaded_at):
    carga = sql.SQL("COPY {tabla} ({cols}) FROM STDIN").format(
        tabla=sql.Identifier(ESQUEMA_RAW, tabla),
        cols=sql.SQL(", ").join(map(sql.Identifier, columnas + COLUMNAS_AUDITORIA)),
    )
    with conexion.cursor() as cur:
        cur.execute(sql.SQL("TRUNCATE {}").format(sql.Identifier(ESQUEMA_RAW, tabla)))
        with cur.copy(carga) as entrada:
            for fila in filas:
                entrada.write_row(fila + [fuente, loaded_at])
        cur.execute(sql.SQL("SELECT count(*) FROM {}").format(sql.Identifier(ESQUEMA_RAW, tabla)))
        return cur.fetchone()[0]


def main():
    configurar_logging()
    args = argumentos_comunes("Carga los CSV de data/csv en raw.").parse_args()
    loaded_at = marca_de_carga(args.loaded_at)
    inicio = time.monotonic()
    log.info("Carga CSV -> raw desde %s, _loaded_at = %s", CSV_DIR, loaded_at.isoformat())
    try:
        lecturas = {}
        for tabla, columnas in TABLAS_CSV.items():
            ruta = CSV_DIR / f"{tabla}.csv"
            lecturas[tabla] = (ruta, leer_csv(ruta, columnas))
            log.info("%-28s %6d filas leidas", ruta.name, len(lecturas[tabla][1]))
        with psycopg.connect(**conninfo_dw()) as conexion:
            for tabla, (ruta, filas) in lecturas.items():
                cargadas = cargar_tabla(conexion, tabla, TABLAS_CSV[tabla], filas, ruta.name, loaded_at)
                if cargadas != len(filas):
                    raise RuntimeError(f"raw.{tabla}: {cargadas} filas cargadas de {len(filas)} leidas")
                log.info("raw.%-24s %6d filas", tabla, cargadas)
    except (OSError, EncabezadoInvalido, RuntimeError, psycopg.Error) as error:
        log.error("La carga CSV fallo y raw quedo sin cambios: %s", str(error).strip())
        return 1
    log.info("Carga CSV completa: %d archivos en %.1f s", len(TABLAS_CSV), time.monotonic() - inicio)
    return 0


if __name__ == "__main__":
    sys.exit(main())
