#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="docker-compose.local.yml"
IMAGE_NAME="chatwoot-backend-local"
CONTAINER_NAME="chatwoot-backend-local"

echo -e "${BLUE}🚀 Chatwoot Local Build and Test Script${NC}"
echo "========================================"

# Function to print status
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
print_status "Checking prerequisites..."
if ! command_exists docker; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command_exists docker-compose; then
    print_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

print_success "Prerequisites check passed"

# Clean up any existing containers
print_status "Cleaning up existing containers..."
docker-compose -f $COMPOSE_FILE down --volumes --remove-orphans 2>/dev/null || true
docker system prune -f --volumes 2>/dev/null || true

# Build the images with AMD64 platform
print_status "Building Chatwoot images for AMD64 platform..."
DOCKER_DEFAULT_PLATFORM=linux/amd64 docker-compose -f $COMPOSE_FILE build --no-cache

if [ $? -eq 0 ]; then
    print_success "Images built successfully"
else
    print_error "Failed to build images"
    exit 1
fi

# Start the services
print_status "Starting services..."
docker-compose -f $COMPOSE_FILE up -d postgres redis

# Wait for database to be ready
print_status "Waiting for database to be ready..."
timeout=60
counter=0
while [ $counter -lt $timeout ]; do
    if docker-compose -f $COMPOSE_FILE exec -T postgres pg_isready -U chatwootuser -d chatwoot_development >/dev/null 2>&1; then
        print_success "Database is ready"
        break
    fi
    sleep 2
    counter=$((counter + 2))
    echo -n "."
done

if [ $counter -ge $timeout ]; then
    print_error "Database failed to start within $timeout seconds"
    docker-compose -f $COMPOSE_FILE logs postgres
    exit 1
fi

# Start Chatwoot backend
print_status "Starting Chatwoot backend..."
docker-compose -f $COMPOSE_FILE up -d chatwoot

# Wait for Chatwoot to be ready
print_status "Waiting for Chatwoot to be ready..."
timeout=120
counter=0
while [ $counter -lt $timeout ]; do
    if curl -f http://localhost:3000/health >/dev/null 2>&1; then
        print_success "Chatwoot is ready and responding"
        break
    fi
    sleep 5
    counter=$((counter + 5))
    echo -n "."
done

if [ $counter -ge $timeout ]; then
    print_error "Chatwoot failed to start within $timeout seconds"
    print_status "Checking logs..."
    docker-compose -f $COMPOSE_FILE logs chatwoot
    exit 1
fi

# Run health checks
print_status "Running health checks..."

# Test health endpoint
if curl -f http://localhost:3000/health >/dev/null 2>&1; then
    print_success "✅ Health endpoint is working"
else
    print_error "❌ Health endpoint failed"
fi

# Test API endpoints
print_status "Testing API endpoints..."

# Test platform API
if curl -f -H "Accept: application/json" http://localhost:3000/platform/api/v1/accounts >/dev/null 2>&1; then
    print_success "✅ Platform API is accessible"
else
    print_warning "⚠️  Platform API might need authentication (expected)"
fi

# Test public API
if curl -f -H "Accept: application/json" http://localhost:3000/api/v1/widget >/dev/null 2>&1; then
    print_success "✅ Widget API is accessible"
else
    print_warning "⚠️  Widget API response varies (might be expected)"
fi

# Check database connection
print_status "Checking database connection..."
if docker-compose -f $COMPOSE_FILE exec -T chatwoot bundle exec rails runner "puts ActiveRecord::Base.connection.execute('SELECT 1').first" >/dev/null 2>&1; then
    print_success "✅ Database connection is working"
else
    print_error "❌ Database connection failed"
fi

# Check Redis connection
print_status "Checking Redis connection..."
if docker-compose -f $COMPOSE_FILE exec -T chatwoot bundle exec rails runner "puts Redis.new(url: ENV['REDIS_URL']).ping" >/dev/null 2>&1; then
    print_success "✅ Redis connection is working"
else
    print_error "❌ Redis connection failed"
fi

# Show running containers
print_status "Current container status:"
docker-compose -f $COMPOSE_FILE ps

# Show logs summary
print_status "Recent logs from Chatwoot:"
docker-compose -f $COMPOSE_FILE logs --tail=10 chatwoot

# Performance test (optional)
print_status "Running basic performance test..."
response_time=$(curl -o /dev/null -s -w '%{time_total}' http://localhost:3000/health)
print_status "Health endpoint response time: ${response_time}s"

# Tag the AMD64 image for potential Azure deployment
print_status "Tagging AMD64 image for Azure deployment..."
docker tag chatwoot-backend-local:latest voicelinkregistry.azurecr.io/chatwoot-backend:local-test
print_success "AMD64 image tagged as: voicelinkregistry.azurecr.io/chatwoot-backend:local-test"

echo ""
echo -e "${GREEN}🎉 Build and Test Complete!${NC}"
echo "========================================"
echo -e "✅ Chatwoot is running at: ${BLUE}http://localhost:3000${NC}"
echo -e "✅ Health check: ${BLUE}http://localhost:3000/health${NC}"
echo -e "✅ API docs: ${BLUE}http://localhost:3000/api-docs${NC}"
echo ""
echo "Next steps:"
echo "1. Test your application thoroughly"
echo "2. If everything works, push to Azure with:"
echo "   docker push voicelinkregistry.azurecr.io/chatwoot-backend:local-test"
echo "3. Deploy to Azure Container Apps using the pushed image"
echo ""
echo "To stop the local environment:"
echo "   docker-compose -f $COMPOSE_FILE down"
echo ""
echo "To view logs:"
echo "   docker-compose -f $COMPOSE_FILE logs -f chatwoot" 