CREATE SCHEMA IF NOT EXISTS raw;

CREATE TABLE IF NOT EXISTS raw.sucursal (
    id_sucursal   INTEGER,
    nombre        VARCHAR(100),
    ciudad        VARCHAR(100),
    departamento  VARCHAR(100),
    _source       TEXT,
    _loaded_at    TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS raw.categoria (
    id_categoria  INTEGER,
    nombre        VARCHAR(100),
    _source       TEXT,
    _loaded_at    TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS raw.marca (
    id_marca      INTEGER,
    nombre        VARCHAR(100),
    _source       TEXT,
    _loaded_at    TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS raw.producto (
    id_producto    INTEGER,
    sku            VARCHAR(20),
    nombre         VARCHAR(150),
    id_categoria   INTEGER,
    id_marca       INTEGER,
    unidad_medida  VARCHAR(30),
    costo_base     NUMERIC(12,2),
    precio_lista   NUMERIC(12,2),
    activo         BOOLEAN,
    _source        TEXT,
    _loaded_at     TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS raw.cliente (
    id_cliente    INTEGER,
    nit           VARCHAR(20),
    nombre        VARCHAR(150),
    tipo_cliente  VARCHAR(40),
    municipio     VARCHAR(100),
    departamento  VARCHAR(100),
    fecha_alta    DATE,
    _source       TEXT,
    _loaded_at    TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS raw.venta (
    id_venta      BIGINT,
    fecha         DATE,
    id_cliente    INTEGER,
    id_sucursal   INTEGER,
    canal         VARCHAR(30),
    metodo_pago   VARCHAR(30),
    estado        VARCHAR(20),
    _source       TEXT,
    _loaded_at    TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS raw.venta_detalle (
    id_detalle       BIGINT,
    id_venta         BIGINT,
    id_producto      INTEGER,
    cantidad         INTEGER,
    precio_unitario  NUMERIC(12,2),
    descuento        NUMERIC(5,4),
    subtotal         NUMERIC(14,2),
    _source          TEXT,
    _loaded_at       TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS raw.inventario_bodega (
    fecha_corte        DATE,
    id_sucursal        INTEGER,
    id_producto        INTEGER,
    stock_disponible   INTEGER,
    stock_minimo       INTEGER,
    stock_maximo       INTEGER,
    lote               VARCHAR(30),
    fecha_vencimiento  DATE,
    _source            TEXT,
    _loaded_at         TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS raw.proveedores_precios (
    id_proveedor     INTEGER,
    proveedor        VARCHAR(150),
    id_producto      INTEGER,
    costo_proveedor  NUMERIC(12,2),
    plazo_dias       INTEGER,
    fecha_vigencia   DATE,
    _source          TEXT,
    _loaded_at       TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS raw.promociones (
    id_promocion          INTEGER,
    nombre                VARCHAR(150),
    fecha_inicio          DATE,
    fecha_fin             DATE,
    id_categoria          INTEGER,
    porcentaje_descuento  NUMERIC(5,4),
    _source               TEXT,
    _loaded_at            TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS raw.metas_ventas (
    periodo        VARCHAR(7),
    id_sucursal    INTEGER,
    meta_ventas    NUMERIC(14,2),
    meta_unidades  INTEGER,
    _source        TEXT,
    _loaded_at     TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS raw.devoluciones (
    id_devolucion  INTEGER,
    fecha          DATE,
    id_venta       BIGINT,
    id_producto    INTEGER,
    cantidad       INTEGER,
    motivo         VARCHAR(100),
    _source        TEXT,
    _loaded_at     TIMESTAMPTZ
);
