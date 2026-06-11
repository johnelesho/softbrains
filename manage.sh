#!/usr/bin/env bash
# =============================================================================
# manage-prod-infra.sh  — 9jagist prod infra server management (188.245.227.228)
# Location on server: /opt/9jagist/infra/manage.sh
#
# Usage:
#   bash manage.sh <command> [service]
#
# Commands:
#   start              Start all services
#   stop               Stop all services (containers remain)
#   restart [svc]      Restart all services, or one specific service
#   redeploy [svc]     Pull latest image + restart (one or all)
#   pull [svc]         Pull latest image(s) without restarting
#   destroy            !! Remove containers, networks, AND volumes (asks confirmation)
#   logs [svc]         Tail logs (all or specific service)
#   status             Show running containers
#   health             Quick healthcheck — show container states
#   backup             Dump postgres databases to /opt/9jagist/infra/backups/
# =============================================================================
set -euo pipefail

COMPOSE_DIR="."
COMPOSE_FILE="$COMPOSE_DIR/compose.yml"
ENV_FILE="$COMPOSE_DIR/.env"
BACKUP_DIR="$COMPOSE_DIR/backups"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${GREEN}[prod-infra]${NC} $*"; }
warn()  { echo -e "${YELLOW}[warn]${NC} $*"; }
die()   { echo -e "${RED}[error]${NC} $*" >&2; exit 1; }
title() { echo -e "\n${CYAN}══ $* ══${NC}"; }

cd "$COMPOSE_DIR"
[ -f "$COMPOSE_FILE" ] || die "Compose file not found: $COMPOSE_FILE"
[ -f "$ENV_FILE" ]     || die ".env not found: $ENV_FILE — copy from .env.example and fill in values"

DC="docker compose --env-file $ENV_FILE -f $COMPOSE_FILE"

# Load POSTGRES_PASSWORD from .env for backup commands
source <(grep -E '^POSTGRES_PASSWORD=' "$ENV_FILE")

cmd="${1:-help}"
svc="${2:-}"

case "$cmd" in

  start)
    if [ -n "$svc" ]; then
      title "Starting $svc"
      $DC up -d "$svc"
      info "$svc started."
    else
      title "Starting all prod-infra services"
      $DC up -d
      info "All services started."
    fi
    ;;

  stop)
    if [ -n "$svc" ]; then
      title "Stopping $svc"
      warn "Stopping $svc may affect app server connectivity."
      $DC stop "$svc"
      info "$svc stopped."
    else
      title "Stopping all prod-infra services"
      warn "Stopping infra will take down postgres, redis, rabbit, kafka."
      warn "The prod app server will lose connectivity to all backends."
      $DC stop
      info "All services stopped (containers preserved, data safe)."
    fi
    ;;

  restart)
    if [ -n "$svc" ]; then
      title "Restarting $svc"
      $DC restart "$svc"
      info "$svc restarted."
    else
      title "Restarting all prod-infra services"
      warn "Brief downtime for app server connections."
      $DC restart
      info "All services restarted."
    fi
    ;;

  redeploy)
    if [ -n "$svc" ]; then
      title "Redeploying $svc"
      $DC pull "$svc"
      $DC up -d --no-deps "$svc"
      docker image prune -f
      info "$svc redeployed."
    else
      title "Redeploying all prod-infra services"
      warn "Brief downtime for app server connections."
      $DC pull
      $DC up -d
      docker image prune -f
      info "All services redeployed."
    fi
    ;;

  pull)
    if [ -n "$svc" ]; then
      title "Pulling $svc"
      $DC pull "$svc"
    else
      title "Pulling all images"
      $DC pull
    fi
    info "Pull complete."
    ;;

  destroy)
    warn "═══════════════════════════════════════════════════"
    warn " DANGER: This destroys ALL infra data permanently."
    warn " Postgres databases, Redis data, RabbitMQ queues,"
    warn " Kafka topics — EVERYTHING will be deleted."
    warn "═══════════════════════════════════════════════════"
    warn "Run 'bash manage.sh backup' first to save a dump."
    echo -n "  Type 'yes-destroy-prod-infra' to confirm: "
    read -r confirm
    if [ "$confirm" = "yes-destroy-prod-infra" ]; then
      title "Destroying prod-infra environment"
      $DC down --volumes --remove-orphans
      info "Prod-infra environment destroyed."
    else
      info "Aborted — nothing changed."
    fi
    ;;

  logs)
    if [ -n "$svc" ]; then
      $DC logs -f --tail=100 "$svc"
    else
      $DC logs -f --tail=50
    fi
    ;;

  status)
    title "Service status"
    $DC ps
    ;;

  health)
    title "Container health"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" \
      | grep -E "(NAME|postgres|redis|rabbit|zookeeper|kafka|pgadmin)" \
      || echo "(no matching containers running)"
    ;;

  backup)
    title "Backing up postgres databases"
    mkdir -p "$BACKUP_DIR"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)

    info "Dumping naijagistdb..."
    docker exec naijagist-postgres pg_dump \
      -U postgres naijagistdb \
      | gzip > "$BACKUP_DIR/naijagistdb_${TIMESTAMP}.sql.gz"

    info "Dumping authdb..."
    docker exec naijagist-auth-postgres pg_dump \
      -U postgres authdb \
      | gzip > "$BACKUP_DIR/authdb_${TIMESTAMP}.sql.gz"

    info "Backups written to $BACKUP_DIR:"
    ls -lh "$BACKUP_DIR"/*_${TIMESTAMP}*.gz
    ;;

  help|*)
    echo ""
    echo "  Usage: bash manage.sh <command> [service]"
    echo ""
    echo "  Commands:"
    echo "    start              Start all services"
    echo "    stop               Stop all services"
    echo "    restart [svc]      Restart all or one service"
    echo "    redeploy [svc]     Pull latest image + restart"
    echo "    pull [svc]         Pull latest image(s)"
    echo "    destroy            !! Remove containers, networks, volumes"
    echo "    logs [svc]         Tail logs"
    echo "    status             Show container status"
    echo "    health             Quick health overview"
    echo "    backup             Dump postgres DBs to backups/"
    echo ""
    echo "  Services: postgres auth-postgres redis rabbitmq"
    echo "            zookeeper kafka kafka-ui pgadmin"
    echo ""
    ;;
esac