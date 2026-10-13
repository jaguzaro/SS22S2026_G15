#!/usr/bin/env bash
set -uo pipefail

fallos=0
q() { docker compose exec -T postgres psql -U "${PG_USER:-sgfood}" -d "$1" -tAc "$2"; }
check() {
    if [ "$2" = "$3" ]; then echo "  ok     $1 = $2"
    else echo "  FALLA  $1 = $2 (esperado $3)"; fallos=$((fallos + 1)); fi
}

echo "Base fuente sgfood_oltp"
for par in sucursal:6 categoria:8 marca:10 producto:80 cliente:250 venta:1200 venta_detalle:3209; do
    t=${par%%:*}; n=${par##*:}
    check "oltp_sgfood.$t" "$(q sgfood_oltp "SELECT count(*) FROM oltp_sgfood.$t")" "$n"
done
check "suma subtotal" "$(q sgfood_oltp "SELECT sum(subtotal) FROM oltp_sgfood.venta_detalle")" "838452.07"

echo "Data Warehouse sgfood_dw"
check "schemas" "$(q sgfood_dw "SELECT string_agg(schema_name, ',' ORDER BY schema_name) FROM information_schema.schemata WHERE schema_name IN ('raw','staging','intermediate','marts')")" "intermediate,marts,raw,staging"
check "tablas en raw" "$(q sgfood_dw "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'raw'")" "12"
check "filas en raw" "$(q sgfood_dw "SELECT coalesce(sum(n_live_tup), 0) FROM pg_stat_user_tables WHERE schemaname = 'raw'")" "0"

echo "Contrato idempotente"
if docker compose exec -T postgres psql -q -U "${PG_USER:-sgfood}" -d sgfood_dw -v ON_ERROR_STOP=1 -f /sql/01_raw_ddl.sql >/dev/null 2>&1; then
    echo "  ok     01_raw_ddl.sql se puede volver a correr"
else
    echo "  FALLA  01_raw_ddl.sql no es reejecutable"; fallos=$((fallos + 1))
fi

echo
if [ "$fallos" -eq 0 ]; then echo "Fase 0 en base de datos: todo bien. Falta correr dbt debug."
else echo "Fase 0: $fallos comprobaciones fallaron."; exit 1; fi
