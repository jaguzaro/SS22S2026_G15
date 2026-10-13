import argparse
import csv
import logging
import sys
from datetime import date, timedelta

import psycopg
from psycopg import sql

from config import CASOS_CALIDAD, configurar_logging, conninfo_dw
from contrato import ESQUEMA_RAW, TABLAS_CSV, TABLAS_OLTP

log = logging.getLogger("inject_quality_cases")

ENTIDADES = {
    "cliente": "cliente",
    "producto": "producto",
    "venta": "venta",
    "venta_detalle": "venta_detalle",
    "inventario": "inventario_bodega",
    "proveedores_precios": "proveedores_precios",
    "metas_ventas": "metas_ventas",
    "devoluciones": "devoluciones",
}

LLAVES = {
    "cliente": "id_cliente",
    "producto": "id_producto",
    "venta": "id_venta",
    "venta_detalle": "id_detalle",
    "devoluciones": "id_devolucion",
}

ORDEN_PLANTILLA = {
    "inventario_bodega": "fecha_corte, id_sucursal, id_producto",
    "proveedores_precios": "id_producto, id_proveedor, fecha_vigencia",
    "metas_ventas": "periodo, id_sucursal",
}


def leer_casos():
    with open(CASOS_CALIDAD, encoding="utf-8-sig", newline="") as archivo:
        return list(csv.DictReader(archivo))


def plantilla(cur, tabla, desplazamiento):
    orden = ORDEN_PLANTILLA.get(tabla, LLAVES.get(tabla))
    cur.execute(
        sql.SQL("SELECT * FROM {} ORDER BY {} LIMIT 1 OFFSET %s").format(
            sql.Identifier(ESQUEMA_RAW, tabla), sql.SQL(orden)
        ),
        (desplazamiento,),
    )
    columnas = [d.name for d in cur.description]
    fila = cur.fetchone()
    if fila is None:
        raise RuntimeError(f"raw.{tabla} esta vacia; correr la carga normal antes de inyectar casos")
    return dict(zip(columnas, fila))


def siguiente_llave(cur, tabla, llave):
    cur.execute(
        sql.SQL("SELECT coalesce(max({}), 0) + 1 FROM {}").format(
            sql.Identifier(llave), sql.Identifier(ESQUEMA_RAW, tabla)
        )
    )
    return cur.fetchone()[0]


def fila_invalida(cur, tabla, campo, valor, desplazamiento):
    fila = plantilla(cur, tabla, desplazamiento)
    if tabla in LLAVES:
        fila[LLAVES[tabla]] = siguiente_llave(cur, tabla, LLAVES[tabla])
    if tabla == "producto":
        fila["sku"] = f"QA{fila['id_producto']}"
    if tabla == "inventario_bodega":
        fila["fecha_corte"] = date(2026, 9, 30)
        fila["lote"] = f"QA{desplazamiento:08d}"
    if tabla == "proveedores_precios":
        fila["fecha_vigencia"] = fila["fecha_vigencia"] + timedelta(days=1)
    if tabla == "metas_ventas":
        fila["periodo"] = "2026-09"
    fila[campo] = valor
    if tabla == "venta_detalle":
        cantidad = int(fila["cantidad"])
        descuento = float(fila["descuento"])
        fila["subtotal"] = round(cantidad * float(fila["precio_unitario"]) * (1 - descuento), 2)
    fila["_source"] = CASOS_CALIDAD.name
    return fila


def insertar(cur, tabla, fila):
    columnas = list(fila)
    cur.execute(
        sql.SQL("INSERT INTO {} ({}) VALUES ({})").format(
            sql.Identifier(ESQUEMA_RAW, tabla),
            sql.SQL(", ").join(map(sql.Identifier, columnas)),
            sql.SQL(", ").join(sql.Placeholder() * len(columnas)),
        ),
        [fila[c] for c in columnas],
    )


def main():
    configurar_logging()
    argparse.ArgumentParser(description="Inserta en raw los casos invalidos de data/calidad para probar los tests de dbt.").parse_args()
    contrato = {**TABLAS_OLTP, **TABLAS_CSV}
    try:
        casos = leer_casos()
        usados = {}
        with psycopg.connect(**conninfo_dw()) as conexion, conexion.cursor() as cur:
            for caso in casos:
                tabla = ENTIDADES.get(caso["entidad"])
                if tabla is None or caso["campo"] not in contrato[tabla]:
                    raise RuntimeError(f"caso no reconocido: {caso}")
                valor = caso["valor_prueba"].strip() or None
                desplazamiento = usados.get(tabla, 0)
                usados[tabla] = desplazamiento + 1
                fila = fila_invalida(cur, tabla, caso["campo"], valor, desplazamiento)
                insertar(cur, tabla, fila)
                log.info(
                    "raw.%-20s %-18s = %-10s %s",
                    tabla, caso["campo"], valor if valor is not None else "NULL", caso["tipo_incidencia"],
                )
    except (OSError, RuntimeError, psycopg.Error) as error:
        log.error("No se inyectaron los casos de calidad: %s", str(error).strip())
        return 1
    log.warning("Se inyectaron %d casos invalidos en raw. Los tests de dbt deben fallar.", len(casos))
    return 0


if __name__ == "__main__":
    sys.exit(main())
