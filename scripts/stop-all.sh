set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠${NC} $1"
}

print_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ✗${NC} $1"
}

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRASTRUCTURE_DIR="$BASE_DIR/infrastructure"
APPLICATIONS_DIR="$BASE_DIR/applications"
ENV_FILE="$BASE_DIR/.env"

stop_service() {
    local service_path=$1
    local service_name=$2

    if [ ! -d "$service_path" ]; then
        print_warning "Diretório não encontrado: $service_path"
        return 0
    fi

    print_status "Parando $service_name..."
    cd "$service_path"

    if [ -f "$ENV_FILE" ]; then
        if docker compose --env-file "$ENV_FILE" down; then
            print_success "$service_name parado"
        else
            print_error "Erro ao parar $service_name"
            return 1
        fi
    else
        if docker compose down; then
            print_success "$service_name parado"
        else
            print_error "Erro ao parar $service_name"
            return 1
        fi
    fi
}

stop_service_with_volumes() {
    local service_path=$1
    local service_name=$2

    if [ ! -d "$service_path" ]; then
        print_warning "Diretório não encontrado: $service_path"
        return 0
    fi

    print_status "Parando $service_name (removendo volumes)..."
    cd "$service_path"

    if [ -f "$ENV_FILE" ]; then
        if docker compose --env-file "$ENV_FILE" down -v; then
            print_success "$service_name parado com volumes removidos"
        else
            print_error "Erro ao parar $service_name"
            return 1
        fi
    else
        if docker compose down -v; then
            print_success "$service_name parado com volumes removidos"
        else
            print_error "Erro ao parar $service_name"
            return 1
        fi
    fi
}

print_status "🏝️  Parando Archipelago - Infraestrutura de Microsserviços"
print_status "=================================================="

REMOVE_VOLUMES=false
if [[ "$1" == "--volumes" || "$1" == "-v" ]]; then
    REMOVE_VOLUMES=true
    print_warning "⚠️  ATENÇÃO: Volumes serão removidos (dados serão perdidos!)"
    echo "Pressione Ctrl+C nos próximos 5 segundos para cancelar..."
    sleep 5
fi

print_status "📍 Etapa 1/4: Parando Aplicações..."

if [ -d "$APPLICATIONS_DIR" ]; then
    for app_dir in "$APPLICATIONS_DIR"/*; do
        if [ -d "$app_dir" ] && [ -f "$app_dir/docker-compose.yml" ]; then
            app_name=$(basename "$app_dir")
            if [ "$REMOVE_VOLUMES" = true ]; then
                stop_service_with_volumes "$app_dir" "$app_name"
            else
                stop_service "$app_dir" "$app_name"
            fi
        fi
    done
else
    print_warning "Diretório de aplicações não encontrado: $APPLICATIONS_DIR"
fi

print_status "📍 Etapa 2/4: Parando Monitoring..."

if [ "$REMOVE_VOLUMES" = true ]; then
    stop_service_with_volumes "$INFRASTRUCTURE_DIR/monitoring" "Prometheus & Grafana"
else
    stop_service "$INFRASTRUCTURE_DIR/monitoring" "Prometheus & Grafana"
fi

print_status "📍 Etapa 3/4: Parando Serviços de Suporte..."

if [ "$REMOVE_VOLUMES" = true ]; then
    stop_service_with_volumes "$INFRASTRUCTURE_DIR/storage" "MinIO"
    stop_service_with_volumes "$INFRASTRUCTURE_DIR/mailhog" "MailHog"
else
    stop_service "$INFRASTRUCTURE_DIR/storage" "MinIO"
    stop_service "$INFRASTRUCTURE_DIR/mailhog" "MailHog"
fi

print_status "📍 Etapa 4/4: Parando Serviços Core..."

if [ "$REMOVE_VOLUMES" = true ]; then
    stop_service_with_volumes "$INFRASTRUCTURE_DIR/cache" "Redis"
    stop_service_with_volumes "$INFRASTRUCTURE_DIR/database" "MySQL"
    stop_service_with_volumes "$INFRASTRUCTURE_DIR/balancer" "Traefik"
else
    stop_service "$INFRASTRUCTURE_DIR/cache" "Redis"
    stop_service "$INFRASTRUCTURE_DIR/database" "MySQL"
    stop_service "$INFRASTRUCTURE_DIR/balancer" "Traefik"
fi

if [[ "$1" == "--cleanup" || "$1" == "-c" ]]; then
    print_status "🧹 Realizando limpeza completa..."

    print_status "Removendo containers órfãos..."
    docker container prune -f

    print_status "Removendo imagens não utilizadas..."
    docker image prune -f

    if [ "$REMOVE_VOLUMES" = true ]; then
        print_status "Removendo volumes não utilizados..."
        docker volume prune -f
    fi

    print_status "Removendo networks não utilizadas..."
    docker network prune -f

    print_success "Limpeza completa realizada"
fi

print_status "🔍 Verificando containers restantes..."
remaining_containers=$(docker ps -q --filter "network=app-network" 2>/dev/null | wc -l)

if [ "$remaining_containers" -eq 0 ]; then
    print_success "🎉 Todos os serviços foram parados com sucesso!"

    if docker network inspect app-network > /dev/null 2>&1; then
        network_containers=$(docker network inspect app-network --format '{{len .Containers}}' 2>/dev/null || echo "0")
        if [ "$network_containers" -eq 0 ]; then
            print_status "Removendo rede app-network..."
            docker network rm app-network
            print_success "Rede removida"
        fi
    fi
else
    print_warning "⚠️  Ainda existem $remaining_containers containers rodando na rede app-network"
    print_status "Execute 'docker ps' para ver detalhes"
fi

echo ""
print_status "📋 Uso:"
echo "  ./scripts/stop-all.sh              # Para todos os serviços"
echo "  ./scripts/stop-all.sh --volumes    # Para e remove volumes (DADOS PERDIDOS)"
echo "  ./scripts/stop-all.sh --cleanup    # Para e limpa recursos Docker"
echo ""

print_status "🏝️  Archipelago parado!"