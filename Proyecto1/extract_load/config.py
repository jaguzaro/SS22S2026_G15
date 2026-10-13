import argparse
import logging
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

from dotenv import load_dotenv

PROYECTO_DIR = Path(__file__).resolve().parent.parent
load_dotenv(PROYECTO_DIR / ".env", override=False)

DATA_DIR = Path(os.getenv("SGFOOD_DATA_DIR", PROYECTO_DIR / "data"))
SQL_DIR = Path(os.getenv("SGFOOD_SQL_DIR", PROYECTO_DIR / "sql"))
LOG_DIR = Path(os.getenv("SGFOOD_LOG_DIR", PROYECTO_DIR / "logs"))
CSV_DIR = DATA_DIR / "csv"
CASOS_CALIDAD = DATA_DIR / "calidad" / "casos_calidad_opcionales.csv"

OLTP_SCHEMA = os.getenv("OLTP_SCHEMA", "oltp_sgfood")


def _conninfo(prefijo, base_por_defecto):
    return {
        "host": os.getenv(f"{prefijo}_HOST", "localhost"),
        "port": int(os.getenv(f"{prefijo}_PORT", "5433")),
        "user": os.getenv(f"{prefijo}_USER", "sgfood"),
        "password": os.getenv(f"{prefijo}_PASSWORD", ""),
        "dbname": os.getenv(f"{prefijo}_DB", base_por_defecto),
        "connect_timeout": int(os.getenv("DB_CONNECT_TIMEOUT", "10")),
        "application_name": "sgfood_extract_load",
    }


def conninfo_dw():
    return _conninfo("DW", "sgfood_dw")


def conninfo_oltp():
    return _conninfo("OLTP", "sgfood_oltp")


def configurar_logging():
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    formato = logging.Formatter("%(asctime)s %(levelname)-7s %(name)s  %(message)s")
    raiz = logging.getLogger()
    raiz.setLevel(logging.INFO)
    raiz.handlers.clear()
    for handler in (
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(LOG_DIR / "extract_load.log", encoding="utf-8"),
    ):
        handler.setFormatter(formato)
        raiz.addHandler(handler)


def marca_de_carga(texto):
    if not texto:
        return datetime.now(timezone.utc)
    momento = datetime.fromisoformat(texto)
    return momento if momento.tzinfo else momento.replace(tzinfo=timezone.utc)


def argumentos_comunes(descripcion):
    parser = argparse.ArgumentParser(description=descripcion)
    parser.add_argument(
        "--loaded-at",
        help="Marca de tiempo ISO 8601 para _loaded_at. Por defecto, el momento actual.",
    )
    return parser
