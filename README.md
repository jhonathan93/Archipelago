# 🏝️ Archipelago

> **Arquitetura de microsserviços com Docker, Traefik, Monitoring e Load Balancing**

Uma infraestrutura completa de microsserviços onde cada serviço é uma "ilha" independente, conectada pela mesma rede, permitindo comunicação entre containers, balanceamento de carga e monitoramento avançado.

## 🚀 Funcionalidades

- ⚖️ **Load Balancing** automático entre múltiplas aplicações
- 🔄 **Proxy Reverso** com Traefik v2.11 e SSL automático
- 🗄️ **MySQL 8.0** com exporter para Prometheus
- 🚀 **Redis** com autenticação e monitoramento
- 📧 **MailHog** para testes de email em desenvolvimento  
- 🗄️ **MinIO** para armazenamento S3-compatível
- 📊 **Monitoring Stack** completo (Prometheus + Grafana)
- 📈 **Métricas** de todos os serviços com dashboards
- 🌐 **Roteamento por domínio** (.localhost)
- 🐳 **Containerização** completa com Docker Compose
- 🔗 **Comunicação entre microsserviços**

## 📋 Pré-requisitos

- Docker >= 20.10
- Docker Compose >= 2.0
- Portas disponíveis: 80, 3000, 3306, 6379, 8025, 8080, 9000, 9001, 9090, 9104, 9121
- 4GB+ de RAM recomendado

## 🏗️ Arquitetura

```
🌊 Archipelago
├── 🚦 Traefik (Proxy Reverso + Load Balancer + SSL)
├── 🗄️ MySQL 8.0 + Exporter (Banco de Dados + Métricas)
├── 🚀 Redis + Exporter (Cache + Sessões + Métricas)
├── 📧 MailHog (SMTP de Desenvolvimento)
├── 🗄️ MinIO (Armazenamento S3)
├── 📊 Prometheus (Coleta de Métricas)
├── 📈 Grafana (Dashboards e Visualização)
├── 🌐 App1 (Aplicação Web)
├── 🌐 App2 (Aplicação Web)
└── 🌐 App3 (Aplicação Web)
```

## 📁 Estrutura do Projeto

```
archipelago/
├── infrastructure/
│   ├── balancer/
│   │   └── docker-compose.yml
│   ├── database/
│   │   └── docker-compose.yml
│   ├── cache/
│   │   └── docker-compose.yml
│   ├── mailhog/
│   │   └── docker-compose.yml
│   ├── storage/
│   │   └── docker-compose.yml
│   └── monitoring/
│       ├── docker-compose.yml
│       └── prometheus.yml
├── applications/
│   ├── app1/
│   │   ├── docker-compose.yml
│   │   └── src/
│   ├── app2/
│   │   ├── docker-compose.yml
│   │   └── src/
│   └── app3/
│       ├── docker-compose.yml
│       └── src/
└── scripts/
    ├── start-all.sh
    ├── stop-all.sh
    ├── status.sh
    └── logs.sh
```

## ⚡ Início Rápido

### 1. Clone o repositório
```bash
git clone <seu-repo>
cd archipelago
```

### 2. Crie a rede externa
```bash
docker network create app-network
```

### 3. Configure permissões dos scripts
```bash
chmod +x scripts/*.sh
```

### 4. Suba todos os serviços
```bash
./scripts/start-all.sh
```

### 5. Verifique o status
```bash
./scripts/status.sh
```

## 🌐 Endpoints de Acesso

### Aplicações
- 🏠 **Load Balancer**: http://localhost
- 🌐 **App1**: http://app1.localhost  
- 🌐 **App2**: http://app2.localhost
- 🌐 **App3**: http://app3.localhost

### Infraestrutura
- ⚙️ **Traefik Dashboard**: http://localhost:8080
- 📧 **MailHog**: http://localhost:8025
- 🗄️ **MinIO Console**: http://localhost:9001

### Monitoring
- 📊 **Prometheus**: http://localhost:9090
- 📈 **Grafana**: http://localhost:3000

## 🔧 Configurações

### Variáveis de Ambiente (.env)
```env
# Database
MYSQL_ROOT_PASSWORD=seu_password_seguro
MYSQL_DATABASE=minha_app

# Cache
REDIS_PASSWORD=seu_redis_password

# MinIO
MINIO_ROOT_USER=admin
MINIO_ROOT_PASSWORD=seu_minio_password

# Grafana
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=seu_grafana_password

# Network
NETWORK_NAME=app-network
```

## 📊 Monitoramento

### Métricas Coletadas
- **Traefik**: Requisições, latência, status codes
- **MySQL**: Conexões, queries, performance
- **Redis**: Memória, comandos, hit rate
- **MinIO**: Storage, requests, bandwidth
- **Sistema**: CPU, memória, disco, rede

### Dashboards Grafana
- **Overview**: Visão geral do sistema
- **Applications**: Métricas das aplicações
- **Infrastructure**: Status dos serviços
- **Database**: Performance do MySQL
- **Cache**: Estatísticas do Redis
- **Storage**: Uso do MinIO

## 🔄 Load Balancing

O Traefik distribui automaticamente o tráfego entre as aplicações:

## 📜 Scripts Úteis

### Gerenciamento de Serviços
```bash
# Subir toda a infraestrutura
./scripts/start-all.sh

# Parar todos os serviços
./scripts/stop-all.sh

# Ver status dos containers
./scripts/status.sh

# Seguir logs em tempo real
./scripts/logs.sh [service_name]
```

### Comandos Docker Específicos
```bash
# Ver logs de um serviço específico
docker logs -f traefik
docker logs -f mysql_db
docker logs -f redis_cache

# Acessar container
docker exec -it mysql_db mysql -u root -p
docker exec -it redis_cache redis-cli -a admin123
```

## 🚨 Troubleshooting

### Problemas Comuns

#### 1. 404 em localhost
```bash
# Verifique containers rodando
docker ps

# Veja logs do Traefik
docker logs traefik

# Confirme rotas no dashboard
curl http://localhost:8080/api/http/routers
```

#### 2. Aplicações não conectam aos serviços
```bash
# Verifique a rede
docker network inspect app-network

# Teste conectividade
docker exec app1 ping mysql_db
docker exec app1 ping redis_cache
```

#### 3. Prometheus não coleta métricas
```bash
# Verifique configuração
docker exec prometheus cat /etc/prometheus/prometheus.yml

# Teste endpoints
curl http://localhost:9090/targets
```

#### 4. Grafana sem dados
```bash
# Verifique datasource Prometheus
curl http://localhost:3000/api/datasources

# Teste conectividade
docker exec grafana ping prometheus
```

## 🤝 Contribuindo

1. Fork o projeto
2. Crie uma branch (`git checkout -b feature/nova-funcionalidade`)
3. Siga os padrões de código e documentação
4. Adicione testes se necessário
5. Commit suas mudanças (`git commit -am 'Adiciona nova funcionalidade'`)
6. Push para a branch (`git push origin feature/nova-funcionalidade`)
7. Abra um Pull Request

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo [LICENSE](LICENSE) para mais detalhes.

---

**🏝️ Archipelago** - *Onde cada microsserviço é uma ilha, mas todos estão conectados pelo mesmo oceano digital.*

---

## 📊 Status do Projeto

![Docker](https://img.shields.io/badge/Docker-20.10%2B-blue)
![Traefik](https://img.shields.io/badge/Traefik-v2.11-green)
![MySQL](https://img.shields.io/badge/MySQL-8.0-orange)
![Redis](https://img.shields.io/badge/Redis-Alpine-red)
![Prometheus](https://img.shields.io/badge/Prometheus-Latest-yellow)
![Grafana](https://img.shields.io/badge/Grafana-Latest-purple)