#!/bin/bash
# gen-secrets.sh — generate all secrets for 9jagist infra .env
# Usage: bash gen-secrets.sh

echo "# ===== 9jagist Infra Secrets — $(date '+%Y-%m-%d') ====="
echo "# Copy these into your .env file on the infra server"
echo ""

echo "POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-32)"
echo "REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-32)"
echo "RABBIT_USERNAME=9jagist"
echo "RABBIT_PASSWORD=$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-32)"
echo ""
echo "PGADMIN_EMAIL=john.elesho@softbrainstech.com"
echo "PGADMIN_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-24)"
echo ""
echo "# ===== App / Auth service secrets ====="
echo "JWT_SECRET=$(openssl rand -base64 64 | tr -d '\n')"
echo "APP_INTERNAL_API_KEY=$(openssl rand -hex 32)"
echo "CLIENT_API_KEY=$(openssl rand -hex 24)"
