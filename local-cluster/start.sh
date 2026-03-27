#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

echo "Starting local posemesh cluster..."
echo ""

docker compose up --build -d

echo ""
echo "Waiting for services to become healthy..."

services=(api dds ds ncs console)
for svc in "${services[@]}"; do
  printf "  %-10s " "$svc"
  timeout=120
  elapsed=0
  while [ $elapsed -lt $timeout ]; do
    status=$(docker compose ps --format json "$svc" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('Health',''))" 2>/dev/null || echo "")
    if [ "$status" = "healthy" ]; then
      echo "healthy"
      break
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  if [ $elapsed -ge $timeout ]; then
    echo "timeout (check: docker compose logs $svc)"
  fi
done

printf "  %-10s " "dms"
timeout=300
elapsed=0
while [ $elapsed -lt $timeout ]; do
  if curl -sf http://localhost:8081/health > /dev/null 2>&1; then
    echo "healthy"
    break
  fi
  sleep 2
  elapsed=$((elapsed + 2))
done
if [ $elapsed -ge $timeout ]; then
  echo "timeout (check: docker compose logs dms)"
fi

echo ""
echo "=============================="
echo " Local Posemesh Cluster Ready"
echo "=============================="
echo ""
echo "  Console:  http://localhost:3000"
echo "  API:      http://localhost:4002"
echo "  DDS:      http://localhost:8080"
echo "  DS:       http://localhost:4000"
echo "  NCS:      http://localhost:4008"
echo "  DMS:      http://localhost:8081"
echo "  MinIO:    http://localhost:9001"
echo ""
echo "  Test user: test@test.com / testtest"
echo ""
echo "  Rebuild a service:  docker compose build <service> && docker compose up -d <service>"
echo "  View logs:          docker compose logs -f <service>"
echo "  Stop cluster:       ./stop.sh"
echo ""
