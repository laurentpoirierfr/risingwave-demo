#!/bin/sh
# Applique les scripts SQL de sources/MV/sinks à RisingWave.
set -e

PSQL="psql -h risingwave-standalone -p 4566 -U root -d dev"

for f in /sql/01_sources.sql /sql/02_materialized_views.sql \
         /sql/03_sinks.sql /sql/04_client_360.sql; do
  echo "==> applying $f"
  $PSQL -f "$f"
done

echo "Tous les objets RisingWave ont été créés."
