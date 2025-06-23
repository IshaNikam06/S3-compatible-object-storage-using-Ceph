# Ceph S3-Compatible Cluster Setup

## Requirements
- Docker Desktop running on Windows 11
- Git Bash or PowerShell
- Python 3.11+ with pip

## Quick Setup

### 1. Create Project Directory
```bash
mkdir ceph-cluster
cd ceph-cluster
```

### 2. Download Files
Save these files in your project directory:
- `docker-compose.yml`
- `setup.sh` 
- `test_s3.py`

### 3. Install Python Dependencies
```bash
pip install boto3
```

### 4. Run Setup
```bash
# Make setup script executable (Git Bash)
chmod +x setup.sh
./setup.sh
```

### 5. Verify Cluster
```bash
# Check cluster status
docker exec ceph-mon ceph -s

# Should show HEALTH_WARN with 2 OSDs (normal for 2 OSD setup)
```

### 6. Test S3 API
```bash
python test_s3.py
```

### 7. Access Dashboard
- **URL:** https://localhost:8443
- **Login:** admin / admin123
- **Object Gateway:** Configured and accessible

## Architecture

**Master Node (ceph-mon + ceph-mgr + ceph-rgw):**
- Monitor: Cluster state management
- Manager: Dashboard and orchestration  
- RGW: S3 API gateway (port 8080)

**Worker Nodes:**
- ceph-osd1: Object Storage Daemon 1
- ceph-osd2: Object Storage Daemon 2

## Access Details

### S3 API
- **Endpoint:** http://localhost:8080
- **Access Key:** accesskey123
- **Secret Key:** secretkey123
- **Region:** us-east-1

### Dashboard
- **URL:** https://localhost:8443
- **Username:** admin
- **Password:** admin123
- **Object Gateway:** Fully configured with buckets visible

## Useful Commands

```bash
# Cluster status
docker exec ceph-mon ceph -s

# OSD status
docker exec ceph-mon ceph osd status

# List S3 buckets
docker exec ceph-mon radosgw-admin bucket list

# Create S3 user
docker exec ceph-rgw radosgw-admin user create --uid=newuser --display-name="New User"

# List S3 users
docker exec ceph-rgw radosgw-admin user list

# Stop cluster
docker-compose down

# Start cluster
docker-compose up -d

# View logs
docker logs ceph-mon
docker logs ceph-rgw
```

**Clean reset (if needed):**
```bash
docker-compose down
rm -rf ceph-data/
./setup.sh
```

**Restart existing cluster:**
```bash
docker-compose up -d
sleep 30
./setup.sh  # Will handle existing users gracefully
```

## What's Working
1 Master node (Monitor + Manager + RGW)  
2 Worker nodes (OSD1 + OSD2)  
S3 API fully functional  
Dashboard with Object Gateway configured  
S3 buckets and objects visible in dashboard  
Both HTTP endpoints accessible (8080, 8443)# S3-compatible-object-storage-using-Ceph
