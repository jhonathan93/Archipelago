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

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

declare -A CONTAINERS=(
    ["traefik"]="Load Balancer"
    ["mysql_db"]="MySQL Database"
    ["mysql_exporter"]="MySQL Exporter"
    ["redis_cache"]="Redis Cache"
    ["redis_exporter"]="Redis Exporter"
    ["minio"]="MinIO Storage"
    ["mailhog"]="MailHog SMTP"
    ["prometheus"]="Prometheus"
    ["grafana"]="Grafana"
    ["app1"]="Aplicação 1"
    ["app2"]="Aplicação 2"
    ["app3"]="Aplicação 3"
)

show_help() {
    print_header "🏝️  Archipelago - Visualizador de Logs"
    echo ""
    echo "Uso:"
    echo "  ./scripts/logs.sh [CONTAINER] [OPÇÕES]"
    echo ""
    echo "Containers disponíveis:"
    for container in "${!CONTAINERS[@]}"; do
        printf "  %-15s - %s\n" "$container" "${CONTAINERS[$container]}"
    done
    echo ""
    echo "Opções:"
    echo "  -f, --follow     Seguir logs em tempo real (padrão)"
    echo "  -n, --lines N    Mostrar últimas N linhas (padrão: 50)"
    echo "  --since TEMPO    Mostrar logs desde TEMPO (ex: 1h, 30m, 2023-01-01)"
    echo "  --until TEMPO    Mostrar logs até TEMPO"
    echo "  --no-follow      Mostrar logs sem seguir"
    echo "  -h, --help       Mostrar esta ajuda"
    echo ""
    echo "Exemplos:"
    echo "  ./scripts/logs.sh traefik"
    echo "  ./scripts/logs.sh mysql_db -n 100"
    echo "  ./scripts/logs.sh redis_cache --since 1h"
    echo "  ./scripts/logs.sh app1 --no-follow"
    echo "  ./scripts/logs.sh                    # Logs de todos os containers"
}

container_exists() {
    docker ps -a --format "{{.Names}}" | grep -q "^$1$"
}

show_container_logs() {
    local container=$1
    local follow=${2:-true}
    local lines=${3:-50}
    local since=${4:-""}
    local until=${5:-""}

    if ! container_exists "$container"; then
        print_error "Container '$container' não encontrado"
        return 1
    fi

    local cmd="docker logs"

    if [ "$follow" = true ]; then
        cmd="$cmd -f"
    fi

    cmd="$cmd --tail $lines"

    if [ -n "$since" ]; then
        cmd="$cmd --since $since"
    fi

    if [ -n "$until" ]; then
        cmd="$cmd --until $until"
    fi

    cmd="$cmd $container"

    local description="${CONTAINERS[$container]:-$container}"
    print_header "📋 Logs: $description ($container)"
    print_status "Comando: $cmd"
    echo ""

    eval "$cmd"
}

show_all_logs() {
    local follow=${1:-true}
    local lines=${2:-10}
    local since=${3:-""}

    print_header "📋 Logs de Todos os Containers (últimas $lines linhas cada)"
    echo ""

    for container in "${!CONTAINERS[@]}"; do
        if container_exists "$container"; then
            echo ""
            print_status "=== ${CONTAINERS[$container]} ($container) ==="
            show_container_logs "$container" false "$lines" "$since"
            echo ""
        fi
    done

    if [ "$follow" = true ]; then
        echo ""
        print_status "🔄 Seguindo logs de todos os containers (Ctrl+C para parar)..."
        for container in "${!CONTAINERS[@]}"; do
            if container_exists "$container"; then
                print_status "=== ${CONTAINERS[$container]} ($container) ==="
                docker logs -f "$container" &
            fi
        done
        wait
    fi
}

CONTAINER=""
FOLLOW=true
LINES=50
SINCE=""
UNTIL=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -f|--follow)
            FOLLOW=true
            shift
            ;;
        --no-follow)
            FOLLOW=false
            shift
            ;;
        -n|--lines)
            LINES="$2"
            shift 2
            ;;
        --since)
            SINCE="$2"
            shift 2
            ;;
        --until)
            UNTIL="$2"
            shift 2
            ;;
        -*)
            print_error "Opção desconhecida: $1"
            show_help
            exit 1
            ;;
        *)
            if [ -z "$CONTAINER" ]; then
                CONTAINER="$1"
            else
                print_error "Muitos argumentos"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

if ! docker info > /dev/null 2>&1; then
    print_error "Docker não está rodando!"
    exit 1
fi

if [ -z "$CONTAINER" ]; then
    show_all_logs "$FOLLOW" "$LINES" "$SINCE"
else
    if [[ -n "${CONTAINERS[$CONTAINER]}" ]]; then
        show_container_logs "$CONTAINER" "$FOLLOW" "$LINES" "$SINCE" "$UNTIL"
    else
        print_error "Container '$CONTAINER' não reconhecido"
        echo ""
        echo "Containers disponíveis:"
        for container in "${!CONTAINERS[@]}"; do
            printf "  %-15s - %s\n" "$container" "${CONTAINERS[$container]}"
        done
        exit 1
    fi
fi