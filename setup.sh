#!/bin/bash

# Ceph Docker Cluster Setup
set -e

echo "Setting up Ceph cluster directories..."
mkdir -p ceph-data/{lib,etc,logs,osd1,osd2}

echo "Starting core services..."
docker-compose up -d ceph-mon
sleep 30
docker-compose up -d ceph-mgr
sleep 20

echo "Creating bootstrap keyrings..."
docker exec ceph-mon mkdir -p /var/lib/ceph/bootstrap-{osd,mds,rgw}

# Delete any existing bootstrap keys to avoid conflicts
docker exec ceph-mon ceph auth del client.bootstrap-osd 2>/dev/null || true
docker exec ceph-mon ceph auth del client.bootstrap-mds 2>/dev/null || true
docker exec ceph-mon ceph auth del client.bootstrap-rgw 2>/dev/null || true

# Create new bootstrap keys
docker exec ceph-mon bash -c "ceph auth get-or-create client.bootstrap-osd mon 'profile bootstrap-osd' mgr 'allow r' -o /var/lib/ceph/bootstrap-osd/ceph.keyring"
docker exec ceph-mon bash -c "ceph auth get-or-create client.bootstrap-mds mon 'profile bootstrap-mds' mgr 'allow r' -o /var/lib/ceph/bootstrap-mds/ceph.keyring"
docker exec ceph-mon bash -c "ceph auth get-or-create client.bootstrap-rgw mon 'profile bootstrap-rgw' mgr 'allow r' -o /var/lib/ceph/bootstrap-rgw/ceph.keyring"

echo "Starting OSDs..."
docker-compose up -d ceph-osd1 ceph-osd2
sleep 30

echo "Starting RGW..."
# Copy config file from monitor to shared directory
MSYS_NO_PATHCONV=1 docker exec ceph-mon cp /etc/ceph/ceph.conf /var/lib/ceph/
cp ceph-data/lib/ceph.conf ceph-data/etc/
docker-compose up -d ceph-rgw
sleep 30
# Create RGW keyring
docker exec ceph-mon ceph auth get-or-create client.rgw.ceph-rgw osd 'allow rwx' mon 'allow rw' -o /var/lib/ceph/ceph.client.rgw.ceph-rgw.keyring || true
docker restart ceph-rgw
sleep 30

echo "Configuring RGW port..."
# Configure RGW to listen on port 8080 
docker exec ceph-mon ceph config set client.rgw.ceph-rgw rgw_frontends "beast port=8080"
docker restart ceph-rgw
sleep 20

echo "Checking cluster status..."
docker exec ceph-mon ceph -s

echo "Creating S3 user..."
# Create S3 user via monitor if no user exists
docker exec ceph-mon radosgw-admin user create \
  --uid=s3user \
  --display-name="S3 User" \
  --access-key=accesskey123 \
  --secret-key=secretkey123 2>/dev/null || echo "S3 user already exists"

echo "Setting up dashboard..."
# Enable dashboard
docker exec ceph-mgr ceph mgr module enable dashboard
docker exec ceph-mgr ceph dashboard create-self-signed-cert
# Create admin user 
echo "admin123" | docker exec -i ceph-mgr ceph dashboard ac-user-create admin -i - administrator 2>/dev/null || echo "Dashboard admin user already exists"
# Configure dashboard to bind to all interfaces
docker exec ceph-mgr ceph config set mgr mgr/dashboard/server_addr 0.0.0.0

echo "Creating dashboard RGW user..."
# Create system user for dashboard 
DASHBOARD_USER=$(docker exec ceph-rgw radosgw-admin user create --uid=dashboard --display-name="Dashboard User" --system 2>/dev/null || docker exec ceph-rgw radosgw-admin user info --uid=dashboard)
echo "$DASHBOARD_USER"

# Extract keys from output and configure dashboard
ACCESS_KEY=$(echo "$DASHBOARD_USER" | grep -o '"access_key": "[^"]*"' | cut -d'"' -f4)
SECRET_KEY=$(echo "$DASHBOARD_USER" | grep -o '"secret_key": "[^"]*"' | cut -d'"' -f4)

# Get RGW container IP
RGW_IP=$(docker inspect ceph-rgw | grep '"IPAddress"' | tail -1 | cut -d'"' -f4)

echo "Configuring dashboard RGW connection..."
# Set dashboard RGW credentials and connection
docker exec ceph-mgr sh -c "printf '$ACCESS_KEY' > /tmp/ak && ceph dashboard set-rgw-api-access-key -i /tmp/ak"
docker exec ceph-mgr sh -c "printf '$SECRET_KEY' > /tmp/sk && ceph dashboard set-rgw-api-secret-key -i /tmp/sk"
docker exec ceph-mgr ceph dashboard set-rgw-api-host $RGW_IP
docker exec ceph-mgr ceph dashboard set-rgw-api-port 8080
docker exec ceph-mgr ceph dashboard set-rgw-api-scheme http

# Restart dashboard to apply all changes
docker restart ceph-mgr
sleep 20

echo "Verifying services..."
# Test S3 endpoint
echo "Testing S3 endpoint..."
curl -s http://localhost:8080 >/dev/null && echo "✅ S3 endpoint responding" || echo "❌ S3 endpoint not responding"

# Test dashboard
echo "Testing dashboard..."
curl -k -s https://localhost:8443 >/dev/null && echo "✅ Dashboard responding" || echo "❌ Dashboard not responding"

echo "Setup complete!"
echo ""
echo "=== Ceph Cluster Information ==="
echo "Dashboard: https://localhost:8443"
echo "Dashboard login: admin / admin123"
echo "S3 endpoint: http://localhost:8080"
echo "S3 Access Key: accesskey123"
echo "S3 Secret Key: secretkey123"
echo ""
echo "=== Architecture ==="
echo "1 Master node: ceph-mon (Monitor + Manager + RGW)"
echo "2 Worker nodes: ceph-osd1, ceph-osd2"
echo "S3 API via RGW available"
echo "Dashboard with Object Gateway configured"