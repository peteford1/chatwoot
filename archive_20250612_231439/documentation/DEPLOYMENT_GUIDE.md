# Chatwoot Deployment Guide - Separated Frontend & Backend

This guide covers deploying Chatwoot with a separated frontend (Vue.js) and backend (Rails API) architecture.

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │    Backend      │
│   (Vue.js)      │◄──►│   (Rails API)   │
│   Port: 3001    │    │   Port: 3000    │
└─────────────────┘    └─────────────────┘
         │                       │
         │              ┌─────────────────┐
         │              │   PostgreSQL    │
         │              │   Database      │
         │              └─────────────────┘
         │                       │
         │              ┌─────────────────┐
         │              │     Redis       │
         │              │   (WebSockets)  │
         │              └─────────────────┘
```

## 📁 Directory Structure

```
chatwoot/                 # Backend Rails API
├── app/
├── config/
├── docker/
│   └── Dockerfile.backend
└── ...

CW_UI/                    # Frontend Vue.js App
├── src/
├── dist/
├── Dockerfile
├── docker-compose.yml
└── ...
```

## 🚀 Deployment Options

### Option 1: Docker Compose (Recommended for Development)

#### Backend (Rails API)
```bash
cd chatwoot
docker build -f docker/Dockerfile.backend -t chatwoot-backend .
docker run -p 3000:3000 \
  -e DATABASE_URL=postgresql://user:pass@host:5432/chatwoot \
  -e REDIS_URL=redis://redis:6379 \
  -e FRONTEND_URL=http://localhost:3001 \
  chatwoot-backend
```

#### Frontend (Vue.js)
```bash
cd CW_UI
docker build -t chatwoot-frontend .
docker run -p 3001:3001 \
  -e VITE_API_BASE_URL=http://localhost:3000 \
  -e VITE_WEBSOCKET_URL=ws://localhost:3000/cable \
  chatwoot-frontend
```

### Option 2: Azure Container Apps (Production)

#### Backend Deployment
```bash
# Build and push backend image
az acr build --registry myregistry \
  --image chatwoot-backend:latest \
  --file docker/Dockerfile.backend .

# Deploy backend container app
az containerapp create \
  --name chatwoot-backend \
  --resource-group mygroup \
  --environment myenv \
  --image myregistry.azurecr.io/chatwoot-backend:latest \
  --target-port 3000 \
  --ingress external \
  --env-vars \
    DATABASE_URL=secretref:database-url \
    REDIS_URL=secretref:redis-url \
    FRONTEND_URL=https://frontend.domain.com
```

#### Frontend Deployment
```bash
# Build and push frontend image
az acr build --registry myregistry \
  --image chatwoot-frontend:latest \
  --file Dockerfile \
  ../CW_UI

# Deploy frontend container app
az containerapp create \
  --name chatwoot-frontend \
  --resource-group mygroup \
  --environment myenv \
  --image myregistry.azurecr.io/chatwoot-frontend:latest \
  --target-port 3001 \
  --ingress external \
  --env-vars \
    VITE_API_BASE_URL=https://backend.domain.com \
    VITE_WEBSOCKET_URL=wss://backend.domain.com/cable
```

### Option 3: Static Hosting + Container Backend

#### Frontend (Static Hosting)
```bash
cd CW_UI
pnpm install
VITE_API_BASE_URL=https://api.yourdomain.com pnpm build
# Deploy dist/ folder to Netlify, Vercel, or Azure Static Web Apps
```

#### Backend (Container Service)
```bash
cd chatwoot
docker build -f docker/Dockerfile.backend -t chatwoot-backend .
# Deploy to Azure Container Instances, AWS ECS, or Google Cloud Run
```

## 🔧 Environment Configuration

### Backend Environment Variables
```env
# Database
DATABASE_URL=postgresql://user:pass@host:5432/chatwoot_production
REDIS_URL=redis://redis:6379

# CORS Configuration
FRONTEND_URL=https://your-frontend-domain.com

# Rails Configuration
RAILS_ENV=production
SECRET_KEY_BASE=your-secret-key

# Optional: External Services
SMTP_ADDRESS=smtp.gmail.com
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=your-app-password
```

### Frontend Environment Variables
```env
# API Configuration
VITE_API_BASE_URL=https://your-backend-domain.com
VITE_WEBSOCKET_URL=wss://your-backend-domain.com/cable

# Environment
VITE_ENVIRONMENT=production

# Optional: Analytics & Monitoring
VITE_SENTRY_DSN=your-sentry-dsn
VITE_ANALYTICS_KEY=your-analytics-key
```

## 🔒 Security Considerations

### CORS Configuration
The backend is configured to accept requests from the frontend URL:

```ruby
# config/application.rb
config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch('FRONTEND_URL', 'http://localhost:3001')
    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true
  end
end
```

### Authentication
- JWT tokens are used for API authentication
- WebSocket connections use the same authentication mechanism
- Cookies are enabled for session management

## 📊 Monitoring & Logging

### Backend Monitoring
- Rails logs are output to STDOUT
- Use application monitoring tools (New Relic, Datadog, etc.)
- Health check endpoint: `GET /api/v1/health`

### Frontend Monitoring
- Sentry for error tracking
- Analytics integration available
- Performance monitoring via browser dev tools

## 🚀 Scaling Considerations

### Horizontal Scaling
- **Frontend**: Can be deployed to CDN/static hosting (infinite scale)
- **Backend**: Scale container instances based on CPU/memory usage
- **Database**: Use read replicas for read-heavy workloads
- **Redis**: Use Redis Cluster for high availability

### Performance Optimization
- **Frontend**: 
  - Code splitting implemented
  - Asset optimization via Vite
  - CDN for static assets
- **Backend**:
  - Database query optimization
  - Redis caching
  - Background job processing with Sidekiq

## 🔄 CI/CD Pipeline

### GitHub Actions Example
```yaml
name: Deploy Chatwoot

on:
  push:
    branches: [main]

jobs:
  deploy-backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build and deploy backend
        run: |
          az acr build --registry ${{ secrets.ACR_NAME }} \
            --image chatwoot-backend:${{ github.sha }} \
            --file docker/Dockerfile.backend .
          
  deploy-frontend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build and deploy frontend
        run: |
          cd CW_UI
          pnpm install
          pnpm build
          # Deploy to static hosting
```

## 🛠️ Development Workflow

### Local Development
```bash
# Terminal 1: Start backend
cd chatwoot
bundle install
rails server -p 3000

# Terminal 2: Start frontend
cd CW_UI
pnpm install
pnpm dev
```

### Testing
```bash
# Backend tests
cd chatwoot
bundle exec rspec

# Frontend tests
cd CW_UI
pnpm test
```

## 📝 Migration Notes

### From Monolithic to Separated Architecture

1. **Database**: No changes required - same PostgreSQL database
2. **Authentication**: JWT tokens work across both applications
3. **WebSockets**: Action Cable continues to work with CORS enabled
4. **File Uploads**: Backend handles file storage, frontend proxies requests
5. **Routing**: Frontend handles all UI routing, backend provides API endpoints

### Rollback Strategy
If needed to rollback to monolithic architecture:
1. Restore `app/javascript` from backup
2. Revert `config/application.rb` changes
3. Restore original `package.json`
4. Run `bundle exec rails assets:precompile`

## 🆘 Troubleshooting

### Common Issues

**CORS Errors**
- Ensure `FRONTEND_URL` environment variable is set correctly
- Check that frontend URL matches exactly (including protocol and port)

**WebSocket Connection Issues**
- Verify `VITE_WEBSOCKET_URL` uses correct protocol (ws:// or wss://)
- Check that Action Cable is properly configured

**API Request Failures**
- Confirm `VITE_API_BASE_URL` is accessible from frontend
- Verify authentication tokens are being sent correctly

### Health Checks
```bash
# Backend health check
curl http://localhost:3000/api/v1/health

# Frontend health check
curl http://localhost:3001/

# WebSocket connection test
wscat -c ws://localhost:3000/cable
```

## 📞 Support

For deployment issues:
1. Check application logs
2. Verify environment variables
3. Test network connectivity between services
4. Review CORS configuration

This separated architecture provides better scalability, independent deployment cycles, and improved development experience while maintaining all Chatwoot functionality. 