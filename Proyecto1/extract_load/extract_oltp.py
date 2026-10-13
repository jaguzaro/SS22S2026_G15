import logging
import sys
import time

import psycopg
from psycopg import sql

from config import (
    OLTP_SCHEMA,
    argumentos_comunes,
    configurar_logging,
    conninfo_dw,
    conninfo_oltp,
    marca_de_carga,
)
from contrato import COLUMNAS_AUDITORIA, ESQUEMA_RAW, TABLAS_OLTP

log = logging.getLogger("extract_oltp")


def copiar_tabla(origen, destino, tabla, columnas, loaded_at):
    fuente = f"sgfood_oltp.{OLTP_SCHEMA}.{tabla}"
    consulta = sql.SQL("COPY (SELECT {cols}, {fuente}::text, {momento}::timestamptz FROM {tabla} ORDER BY 1) TO STDOUT").format(
        cols=sql.SQL(", ").join(map(sql.Identifier, columnas)),
        fuente=sql.Literal(fuente),
        momento=sql.Literal(loaded_at),
        tabla=sql.Identifier(OLTP_SCHEMA, tabla),
    )
    carga = sql.SQL("COPY {tabla} ({cols}) FROM STDIN").format(
        tabla=sql.Identifier(ESQUEMA_RAW, tabla),
        cols=sql.SQL(", ").join(map(sql.Identifier, columnas + COLUMNAS_AUDITORIA)),
    )
    with destino.cursor() as cur_destino:
        cur_destino.execute(sql.SQL("TRUNCATE {}").format(sql.Identifier(ESQUEMA_RAW, tabla)))
        with origen.cursor().copy(consulta) as salida, cur_destino.copy(carga) as entrada:
            for bloque in salida:
                entrada.write(bloque)
        cur_destino.execute(sql.SQL("SELECT count(*) FROM {}").format(sql.Identifier(ESQUEMA_RAW, tabla)))
        return cur_destino.fetchone()[0]


def main():
    configurar_logging()
    args = argumentos_comunes("Extrae las tablas de sgfood_oltp y las carga en raw.").parse_args()
    loaded_at = marca_de_carga(args.loaded_at)
    inicio = time.monotonic()
    log.info("Extraccion OLTP -> raw, _loaded_at = %s", loaded_at.isoformat())
    try:
        with psycopg.connect(**conninfo_oltp()) as origen, psycopg.connect(**conninfo_dw()) as destino:
            origen.read_only = True
            for tabla, columnas in TABLAS_OLTP.items():
                filas = copiar_tabla(origen, destino, tabla, columnas, loaded_at)
                log.info("raw.%-15s %6d filas", tabla, filas)
    except psycopg.Error as error:
        log.error("La extraccion fallo y raw quedo sin cambios: %s", str(error).strip())
        return 1
    log.info("Extraccion OLTP completa: %d tablas en %.1f s", len(TABLAS_OLTP), time.monotonic() - inicio)
    return 0


if __name__ == "__main__":
    sys.exit(main())
