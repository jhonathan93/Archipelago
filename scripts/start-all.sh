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

if ! docker info > /dev/null 2>&1; then
    print_error "Docker não está rodando. Por favor, inicie o Docker primeiro."
    exit 1
fi

if ! command -v docker compose &> /dev/null; then
    print_error "Docker Compose não encontrado. Por favor, instale o Docker Compose."
    exit 1
fi

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRASTRUCTURE_DIR="$BASE_DIR/infrastructure"
APPLICATIONS_DIR="$BASE_DIR/applications"
ENV_FILE="$BASE_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
    print_error "Arquivo .env não encontrado em: $ENV_FILE"
    print_status "Execute './scripts/dev-setup.sh' primeiro ou crie o arquivo .env"
    exit 1
fi

print_status "📋 Usando arquivo .env: $ENV_FILE"

if ! docker network inspect app-network > /dev/null 2>&1; then
    print_warning "Rede 'app-network' não encontrada. Criando..."
    docker network create app-network
    print_success "Rede 'app-network' criada com sucesso"
fi

wait_for_service() {
    local service_name=$1
    local health_check=$2
    local max_attempts=${3:-30}
    local attempt=1

    print_status "Aguardando $service_name ficar pronto..."

    while [ $attempt -le $max_attempts ]; do
        if eval "$health_check" > /dev/null 2>&1; then
            print_success "$service_name está pronto!"
            return 0
        fi

        echo -n "."
        sleep 2
        ((attempt++))
    done

    print_error "$service_name não ficou pronto após $((max_attempts * 2)) segundos"
    return 1
}

start_service() {
    local service_path=$1
    local service_name=$2
    local health_check=$3

    if [ ! -d "$service_path" ]; then
        print_error "Diretório não encontrado: $service_path"
        return 1
    fi

    print_status "Iniciando $service_name..."
    cd "$service_path"

    if docker compose --env-file "$ENV_FILE" up -d; then
        print_success "$service_name iniciado"

        if [ -n "$health_check" ]; then
            wait_for_service "$service_name" "$health_check"
        fi
    else
        print_error "Falha ao iniciar $service_name"
        return 1
    fi
}

print_status "🏝️  Iniciando Archipelago - Infraestrutura de Microsserviços"
print_status "=================================================="

print_status "📍 Etapa 1/6: Iniciando Load Balancer..."
start_service "$INFRASTRUCTURE_DIR/balancer" "Traefik" "curl -f http://localhost:8080/ping"

print_status "📍 Etapa 2/6: Iniciando Serviços de Dados..."
start_service "$INFRASTRUCTURE_DIR/database" "MySQL" "docker exec mysql_db mysqladmin -u root -p\${MYSQL_ROOT_PASSWORD:-admin123} ping"
start_service "$INFRASTRUCTURE_DIR/cache" "Redis" "docker exec redis_cache redis-cli -a \${REDIS_PASSWORD:-admin123} ping"

print_status "📍 Etapa 3/6: Iniciando Serviços de Suporte..."
start_service "$INFRASTRUCTURE_DIR/storage" "MinIO" "curl -f http://localhost:9000/minio/health/live"
start_service "$INFRASTRUCTURE_DIR/mailhog" "MailHog" "curl -f http://localhost:8025/"

print_status "📍 Etapa 4/6: Iniciando Monitoring..."
start_service "$INFRASTRUCTURE_DIR/monitoring" "Prometheus & Grafana" "curl -f http://localhost:9090/-/healthy"

wait_for_service "Grafana" "curl -f http://localhost:3000/api/health"

print_status "📍 Etapa 5/6: Iniciando Aplicações..."

if [ -d "$APPLICATIONS_DIR" ]; then
    for app_dir in "$APPLICATIONS_DIR"/*; do
        if [ -d "$app_dir" ] && [ -f "$app_dir/docker-compose.yml" ]; then
            app_name=$(basename "$app_dir")
            start_service "$app_dir" "$app_name" "curl -f http://$app_name.localhost/health || curl -f http://$app_name.localhost/"
        fi
    done
else
    print_warning "Diretório de aplicações não encontrado: $APPLICATIONS_DIR"
fi

print_status "📍 Etapa 6/6: Verificação Final..."

echo ""
print_status "🔍 Verificando status dos serviços..."

services=(
    "traefik|curl -f http://localhost:8080/ping|Load Balancer"
    "mysql_db|docker exec mysql_db mysqladmin -u root -p\${MYSQL_ROOT_PASSWORD:-admin123} ping|MySQL"
    "redis_cache|docker exec redis_cache redis-cli -a \${REDIS_PASSWORD:-admin123} ping|Redis"
    "minio|curl -f http://localhost:9000/minio/health/live|MinIO"
    "mailhog|curl -f http://localhost:8025/|MailHog"
    "prometheus|curl -f http://localhost:9090/-/healthy|Prometheus"
    "grafana|curl -f http://localhost:3000/api/health|Grafana"
)

all_healthy=true

for service_info in "${services[@]}"; do
    IFS='|' read -r container_name health_check display_name <<< "$service_info"

    if eval "$health_check" > /dev/null 2>&1; then
        print_success "$display_name está saudável"
    else
        print_error "$display_name não está respondendo"
        all_healthy=false
    fi
done

echo ""
if [ "$all_healthy" = true ]; then
    print_success "🎉 Todos os serviços estão rodando com sucesso!"
    echo ""
    print_status "📋 Endpoints disponíveis:"
    echo "  🏠 Load Balancer: http://localhost"
    echo "  ⚙️ Traefik Dashboard: http://localhost:8080"
    echo "  📊 Prometheus: http://localhost:9090"
    echo "  📈 Grafana: http://localhost:3000 (admin/admin123)"
    echo "  📧 MailHog: http://localhost:8025"
    echo "  🗄️ MinIO Console: http://localhost:9001 (admin/admin123)"
    echo ""
    print_status "🌐 Aplicações:"
    echo "  • App1: http://app1.localhost"
    echo "  • App2: http://app2.localhost"
    echo "  • App3: http://app3.localhost"
    echo ""
else
    print_warning "⚠️  Alguns serviços podem não estar funcionando corretamente."
    print_status "Execute './scripts/status.sh' para mais detalhes."
fi

print_status "🏝️  Archipelago iniciado com sucesso!"