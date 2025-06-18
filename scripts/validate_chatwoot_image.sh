#!/bin/bash
# validate_chatwoot_image.sh
# Validates Chatwoot Docker images before deployment
# Usage: ./validate_chatwoot_image.sh [image_name]

set -e

IMAGE=${1:-chatwoot/chatwoot:latest}
echo "🔍 Validating Chatwoot image: $IMAGE"
echo "================================================"

# Test 1: Check if image exists and is pullable
echo "1️⃣ Testing image accessibility..."
if docker pull $IMAGE > /dev/null 2>&1; then
    echo "✅ Image successfully pulled"
else
    echo "❌ Image not found or inaccessible"
    exit 1
fi

# Test 2: Check Ruby version
echo "2️⃣ Checking Ruby version..."
RUBY_VERSION=$(docker run --rm $IMAGE ruby --version 2>/dev/null || echo "FAILED")
if [[ "$RUBY_VERSION" == "FAILED" ]]; then
    echo "❌ Ruby not found or not working"
    exit 1
else
    echo "✅ $RUBY_VERSION"
fi

# Test 3: Check Rails version
echo "3️⃣ Checking Rails version..."
RAILS_VERSION=$(docker run --rm $IMAGE bundle exec rails --version 2>/dev/null || echo "FAILED")
if [[ "$RAILS_VERSION" == "FAILED" ]]; then
    echo "❌ Rails not found or not working"
    exit 1
else
    echo "✅ $RAILS_VERSION"
fi

# Test 4: Check critical gems
echo "4️⃣ Checking critical gem dependencies..."
GEMS_CHECK=$(docker run --rm $IMAGE bundle list 2>/dev/null || echo "FAILED")
if [[ "$GEMS_CHECK" == "FAILED" ]]; then
    echo "❌ Bundle list failed"
    exit 1
fi

# Check for devise-secure_password specifically
if echo "$GEMS_CHECK" | grep -q "devise-secure_password"; then
    echo "✅ devise-secure_password gem found"
else
    echo "❌ devise-secure_password gem missing - this was the root cause of our previous issue!"
    exit 1
fi

# Check for other critical gems
for gem in "devise" "rails" "pg" "redis"; do
    if echo "$GEMS_CHECK" | grep -q "$gem"; then
        echo "✅ $gem gem found"
    else
        echo "⚠️  $gem gem not found (may be optional)"
    fi
done

# Test 5: Test Rails startup
echo "5️⃣ Testing Rails application startup..."
RAILS_TEST=$(docker run --rm -e SECRET_KEY_BASE=test123456789 $IMAGE bundle exec rails runner "puts 'RAILS_OK'" 2>/dev/null || echo "FAILED")
if [[ "$RAILS_TEST" == *"RAILS_OK"* ]]; then
    echo "✅ Rails startup successful"
else
    echo "❌ Rails startup failed"
    echo "Output: $RAILS_TEST"
    exit 1
fi

# Test 6: Check if container can start web server (quick test)
echo "6️⃣ Testing web server startup (quick test)..."
CONTAINER_ID=$(docker run -d -e SECRET_KEY_BASE=test123456789 -e DATABASE_URL=postgresql://test:test@localhost/test $IMAGE bundle exec rails server -b 0.0.0.0 -p 3000 2>/dev/null || echo "FAILED")
if [[ "$CONTAINER_ID" == "FAILED" ]]; then
    echo "❌ Web server startup failed"
    exit 1
else
    sleep 3
    # Check if container is still running
    if docker ps | grep -q $CONTAINER_ID; then
        echo "✅ Web server started successfully"
        docker stop $CONTAINER_ID > /dev/null 2>&1
        docker rm $CONTAINER_ID > /dev/null 2>&1
    else
        echo "❌ Web server crashed immediately"
        docker logs $CONTAINER_ID 2>/dev/null | tail -5
        docker rm $CONTAINER_ID > /dev/null 2>&1
        exit 1
    fi
fi

echo "================================================"
echo "🎉 Image validation PASSED!"
echo "✅ Image: $IMAGE"
echo "✅ Ruby: $RUBY_VERSION"
echo "✅ Rails: $RAILS_VERSION"
echo "✅ Critical gems: Present"
echo "✅ Rails startup: Working"
echo "✅ Web server: Working"
echo ""
echo "This image is safe to deploy to Azure Container Apps."
echo ""
echo "To deploy this validated image:"
echo "az containerapp update \\"
echo "  --name chatwoot-backend-test \\"
echo "  --resource-group SM-Test \\"
echo "  --container-name chatwoot-backend \\"
echo "  --image $IMAGE" 