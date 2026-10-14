-- SG-Food · DDL del Data Warehouse (sgfood_dw)
-- Las tablas del schema raw están en sql/01_raw_ddl.sql: correrlo antes que este script.
-- Este script es idempotente: se puede volver a correr.

CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS intermediate;
CREATE SCHEMA IF NOT EXISTS marts;

-- ========== DIMENSIONES ==========

CREATE TABLE IF NOT EXISTS marts.dim_fecha (
    id_fecha          INTEGER PRIMARY KEY,
    fecha             DATE,
    anio              INTEGER,
    trimestre         INTEGER,
    mes               INTEGER,
    nombre_mes        VARCHAR,
    dia               INTEGER,
    dia_semana        INTEGER,
    nombre_dia        VARCHAR,
    es_fin_de_semana  BOOLEAN,
    periodo           VARCHAR
);

CREATE TABLE IF NOT EXISTS marts.dim_sucursal (
    id_sucursal      INTEGER PRIMARY KEY,
    nombre_sucursal  VARCHAR,
    ciudad           VARCHAR,
    departamento     VARCHAR
);

CREATE TABLE IF NOT EXISTS marts.dim_cliente (
    id_cliente      INTEGER PRIMARY KEY,
    nit             VARCHAR,
    nombre_cliente  VARCHAR,
    tipo_cliente    VARCHAR,
    municipio       VARCHAR,
    departamento    VARCHAR,
    fecha_alta      DATE
);

CREATE TABLE IF NOT EXISTS marts.dim_proveedor (
    id_proveedor      INTEGER PRIMARY KEY,
    nombre_proveedor  VARCHAR
);

CREATE TABLE IF NOT EXISTS marts.dim_producto (
    id_producto              INTEGER PRIMARY KEY,
    sku                      VARCHAR,
    nombre_producto          VARCHAR,
    id_categoria             INTEGER,
    nombre_categoria         VARCHAR,
    id_marca                 INTEGER,
    nombre_marca             VARCHAR,
    unidad_medida            VARCHAR,
    costo_base               NUMERIC(12,2),
    precio_lista             NUMERIC(12,2),
    activo                   BOOLEAN,
    id_proveedor_vigente     INTEGER,
    costo_proveedor_vigente  NUMERIC(12,2)
);

CREATE TABLE IF NOT EXISTS marts.dim_promocion (
    id_promocion          INTEGER PRIMARY KEY,
    nombre_promocion      VARCHAR,
    fecha_inicio          DATE,
    fecha_fin             DATE,
    id_categoria          INTEGER,
    nombre_categoria      VARCHAR,
    porcentaje_descuento  NUMERIC(5,4)
);

CREATE TABLE IF NOT EXISTS marts.dim_tipo_venta (
    id_tipo_venta  INTEGER PRIMARY KEY,
    canal          VARCHAR,
    metodo_pago    VARCHAR,
    estado         VARCHAR
);

-- ========== HECHOS ==========

CREATE TABLE IF NOT EXISTS marts.fct_ventas (
    id_detalle       BIGINT PRIMARY KEY,
    id_venta         BIGINT,
    id_fecha         INTEGER REFERENCES marts.dim_fecha (id_fecha),
    id_cliente       INTEGER REFERENCES marts.dim_cliente (id_cliente),
    id_sucursal      INTEGER REFERENCES marts.dim_sucursal (id_sucursal),
    id_producto      INTEGER REFERENCES marts.dim_producto (id_producto),
    id_tipo_venta    INTEGER REFERENCES marts.dim_tipo_venta (id_tipo_venta),
    id_promocion     INTEGER REFERENCES marts.dim_promocion (id_promocion),
    cantidad         INTEGER,
    precio_unitario  NUMERIC(12,2),
    descuento        NUMERIC(5,4),
    subtotal         NUMERIC(14,2)
);

CREATE TABLE IF NOT EXISTS marts.fct_inventario (
    id_fecha           INTEGER REFERENCES marts.dim_fecha (id_fecha),
    id_sucursal        INTEGER REFERENCES marts.dim_sucursal (id_sucursal),
    id_producto        INTEGER REFERENCES marts.dim_producto (id_producto),
    stock_disponible   INTEGER,
    stock_minimo       INTEGER,
    stock_maximo       INTEGER,
    bajo_stock_minimo  BOOLEAN,
    lote               VARCHAR,
    fecha_vencimiento  DATE,
    PRIMARY KEY (id_fecha, id_sucursal, id_producto)
);

CREATE TABLE IF NOT EXISTS marts.fct_devoluciones (
    id_devolucion  INTEGER PRIMARY KEY,
    id_venta       BIGINT,
    id_fecha       INTEGER REFERENCES marts.dim_fecha (id_fecha),
    id_producto    INTEGER REFERENCES marts.dim_producto (id_producto),
    id_sucursal    INTEGER REFERENCES marts.dim_sucursal (id_sucursal),
    cantidad       INTEGER,
    motivo         VARCHAR
);

CREATE TABLE IF NOT EXISTS marts.fct_metas_ventas (
    id_fecha       INTEGER REFERENCES marts.dim_fecha (id_fecha),
    id_sucursal    INTEGER REFERENCES marts.dim_sucursal (id_sucursal),
    periodo        VARCHAR,
    meta_ventas    NUMERIC(14,2),
    meta_unidades  INTEGER,
    PRIMARY KEY (id_fecha, id_sucursal)
);