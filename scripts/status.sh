set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "${CYAN}$1${NC}"
}

print_status() {
    echo -e "${BLUE}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

is_container_running() {
    docker ps --format "table {{.Names}}" | grep -q "^$1$"
}

check_service_health() {
    local service_name=$1
    local health_check=$2
    local endpoint=${3:-"N/A"}

    if eval "$health_check" > /dev/null 2>&1; then
        print_success "$service_name - Saudável ($endpoint)"
        return 0
    else
        print_error "$service_name - Não responsivo ($endpoint)"
        return 1
    fi
}

get_container_info() {
    local container_name=$1

    if is_container_running "$container_name"; then
        local status=$(docker inspect "$container_name" --format '{{.State.Status}}')
        local uptime=$(docker inspect "$container_name" --format '{{.State.StartedAt}}' | xargs -I {} date -d {} '+%Y-%m-%d %H:%M:%S')
        local image=$(docker inspect "$container_name" --format '{{.Config.Image}}')

        echo "    Status: $status"
        echo "    Iniciado: $uptime"
        echo "    Imagem: $image"

        if [ "$status" = "running" ]; then
            local stats=$(docker stats "$container_name" --no-stream --format "CPU: {{.CPUPerc}} | MEM: {{.MemUsage}}")
            echo "    Recursos: $stats"
        fi
    else
        echo "    Status: Não está rodando"
    fi
}

print_header "🏝️  Archipelago - Status dos Serviços"
print_header "============================================="

if ! docker info > /dev/null 2>&1; then
    print_error "Docker não está rodando!"
    exit 1
fi

print_header "\n📡 Rede"
if docker network inspect app-network > /dev/null 2>&1; then
    print_success "app-network existe"
    connected_containers=$(docker network inspect app-network --format '{{len .Containers}}')
    echo "    Containers conectados: $connected_containers"
else
    print_error "app-network não encontrada"
fi

print_header "\n⚖️  Load Balancer"
echo "🔸 Traefik"
get_container_info "traefik"
check_service_health "Traefik API" "curl -f http://localhost:8080/ping" "http://localhost:8080"

print_header "\n🗄️  Serviços de Dados"

echo "🔸 MySQL"
get_container_info "mysql_db"
check_service_health "MySQL" "docker exec mysql_db mysqladmin -u root -padmin123 ping" "localhost:3306"

echo "🔸 MySQL Exporter"
get_container_info "mysql_exporter"
check_service_health "MySQL Exporter" "curl -f http://localhost:9104/metrics" "http://localhost:9104/metrics"

echo "🔸 Redis"
get_container_info "redis_cache"
check_service_health "Redis" "docker exec redis_cache redis-cli -a admin123 ping" "localhost:6379"

echo "🔸 Redis Exporter"
get_container_info "redis_exporter"
check_service_health "Redis Exporter" "curl -f http://localhost:9121/metrics" "http://localhost:9121/metrics"

print_header "\n💾 Storage"
echo "🔸 MinIO"
get_container_info "minio"
check_service_health "MinIO" "curl -f http://localhost:9000/minio/health/live" "http://localhost:9000"

print_header "\n📧 Email (Desenvolvimento)"
echo "🔸 MailHog"
get_container_info "mailhog"
check_service_health "MailHog" "curl -f http://localhost:8025/" "http://localhost:8025"

print_header "\n📊 Monitoring"

echo "🔸 Prometheus"
get_container_info "prometheus"
check_service_health "Prometheus" "curl -f http://localhost:9090/-/healthy" "http://localhost:9090"

echo "🔸 Grafana"
get_container_info "grafana"
check_service_health "Grafana" "curl -f http://localhost:3000/api/health" "http://localhost:3000"

print_header "\n🌐 Aplicações"

app_containers=("app1" "app2" "app3")
for app in "${app_containers[@]}"; do
    echo "🔸 $app"
    if is_container_running "$app"; then
        get_container_info "$app"
        check_service_health "$app" "curl -f http://$app.localhost/health || curl -f http://$app.localhost/" "http://$app.localhost"
    else
        print_warning "$app não está rodando"
    fi
    echo ""
done

print_header "📋 Resumo dos Endpoints"
echo "  🏠 Load Balancer: http://localhost"
echo "  ⚙️  Traefik Dashboard: http://localhost:8080"
echo "  📊 Prometheus: http://localhost:9090"
echo "  📈 Grafana: http://localhost:3000"
echo "  📧 MailHog: http://localhost:8025"
echo "  🗄️  MinIO Console: http://localhost:9001"
echo "  🌐 App1: http://app1.localhost"
echo "  🌐 App2: http://app2.localhost"
echo "  🌐 App3: http://app3.localhost"

print_header "\n💻 Recursos do Sistema"
echo "🔸 Docker"
docker_info=$(docker system df --format "Images: {{.TotalCount}} | Containers: {{.Active}}/{{.TotalCount}} | Volumes: {{.TotalCount}}")
echo "    $docker_info"

print_header "\n📈 Uso de Recursos (Containers Ativos)"
if [ "$(docker ps -q | wc -l)" -gt 0 ]; then
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}"
else
    echo "Nenhum container ativo"
fi

echo ""
print_status "✨ Status verificado em $(date '+%Y-%m-%d %H:%M:%S')"