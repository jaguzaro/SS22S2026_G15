import logging
import sys

import psycopg

from config import SQL_DIR, configurar_logging, conninfo_dw

log = logging.getLogger("crear_raw")


def main():
    configurar_logging()
    ruta = SQL_DIR / "01_raw_ddl.sql"
    try:
        with psycopg.connect(**conninfo_dw()) as conexion:
            conexion.execute(ruta.read_text(encoding="utf-8"))
            tablas = conexion.execute(
                "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'raw'"
            ).fetchone()[0]
    except (OSError, psycopg.Error) as error:
        log.error("No se pudo aplicar %s: %s", ruta.name, str(error).strip())
        return 1
    log.info("%s aplicado: %d tablas en raw", ruta.name, tablas)
    return 0


if __name__ == "__main__":
    sys.exit(main())
