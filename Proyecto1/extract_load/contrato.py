TABLAS_OLTP = {
    "sucursal": ["id_sucursal", "nombre", "ciudad", "departamento"],
    "categoria": ["id_categoria", "nombre"],
    "marca": ["id_marca", "nombre"],
    "producto": [
        "id_producto", "sku", "nombre", "id_categoria", "id_marca",
        "unidad_medida", "costo_base", "precio_lista", "activo",
    ],
    "cliente": [
        "id_cliente", "nit", "nombre", "tipo_cliente", "municipio",
        "departamento", "fecha_alta",
    ],
    "venta": [
        "id_venta", "fecha", "id_cliente", "id_sucursal", "canal",
        "metodo_pago", "estado",
    ],
    "venta_detalle": [
        "id_detalle", "id_venta", "id_producto", "cantidad",
        "precio_unitario", "descuento", "subtotal",
    ],
}

TABLAS_CSV = {
    "inventario_bodega": [
        "fecha_corte", "id_sucursal", "id_producto", "stock_disponible",
        "stock_minimo", "stock_maximo", "lote", "fecha_vencimiento",
    ],
    "proveedores_precios": [
        "id_proveedor", "proveedor", "id_producto", "costo_proveedor",
        "plazo_dias", "fecha_vigencia",
    ],
    "promociones": [
        "id_promocion", "nombre", "fecha_inicio", "fecha_fin",
        "id_categoria", "porcentaje_descuento",
    ],
    "metas_ventas": ["periodo", "id_sucursal", "meta_ventas", "meta_unidades"],
    "devoluciones": [
        "id_devolucion", "fecha", "id_venta", "id_producto", "cantidad", "motivo",
    ],
}

COLUMNAS_AUDITORIA = ["_source", "_loaded_at"]

ESQUEMA_RAW = "raw"
