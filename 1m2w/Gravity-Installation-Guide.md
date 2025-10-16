# Gravity 安裝完整指南

## 環境資訊
- **Harbor Server**: 10.10.254.155 (starlux.harbor.com)
- **Master Node**: 10.10.254.151
- **Worker Nodes**: 10.10.254.152, 10.10.254.153
- **目標**: 安裝 Gravity 和 Gitea

## Gravity Images 清單
```
ghcr.io/brobridgeorg/gravity-adapter-mssql:v3.0.15-20250801
ghcr.io/brobridgeorg/nats-server:v1.3.25-20250801
ghcr.io/brobridgeorg/atomic:v1.0.0-20250801-ubi
ghcr.io/brobridgeorg/gravity-dispatcher:v0.0.31-20250801
```

---

# 第一階段：Harbor 拉取和推送 Images

## 步驟 1: 在 Harbor VM 拉取並推送鏡像

### 1.1 連接到 Harbor VM
```bash
ssh user@10.10.254.155
```

### 1.2 登入 Harbor
```bash
# 登入本地 Harbor
podman login starlux.harbor.com
# 輸入: admin / Harbor12345
```

### 1.3 創建 Gravity 項目
```bash
# 通過瀏覽器登入 Harbor Web UI: https://starlux.harbor.com
# 創建新項目 "gravity" (Public 或 Private)
```

### 1.4 拉取 Gravity 鏡像
```bash
# 拉取所有 Gravity 相關鏡像
echo "開始拉取 Gravity 鏡像..."

podman pull ghcr.io/brobridgeorg/gravity-adapter-mssql:v3.0.15-20250801
podman pull ghcr.io/brobridgeorg/nats-server:v1.3.25-20250801
podman pull ghcr.io/brobridgeorg/atomic:v1.0.0-20250801-ubi
podman pull ghcr.io/brobridgeorg/gravity-dispatcher:v0.0.31-20250801

echo "✅ Gravity 鏡像拉取完成"
```

### 1.5 重新標記並推送到 Harbor
```bash
# 標記鏡像為 Harbor 格式並推送
echo "開始推送鏡像到 Harbor..."

# Gravity Adapter MSSQL
podman tag ghcr.io/brobridgeorg/gravity-adapter-mssql:v3.0.15-20250801 starlux.harbor.com/gravity/gravity-adapter-mssql:v3.0.15-20250801
podman push starlux.harbor.com/gravity/gravity-adapter-mssql:v3.0.15-20250801

# NATS Server
podman tag ghcr.io/brobridgeorg/nats-server:v1.3.25-20250801 starlux.harbor.com/gravity/nats-server:v1.3.25-20250801
podman push starlux.harbor.com/gravity/nats-server:v1.3.25-20250801

# Atomic
podman tag ghcr.io/brobridgeorg/atomic:v1.0.0-20250801-ubi starlux.harbor.com/gravity/atomic:v1.0.0-20250801-ubi
podman push starlux.harbor.com/gravity/atomic:v1.0.0-20250801-ubi

# Gravity Dispatcher
podman tag ghcr.io/brobridgeorg/gravity-dispatcher:v0.0.31-20250801 starlux.harbor.com/gravity/gravity-dispatcher:v0.0.31-20250801
podman push starlux.harbor.com/gravity/gravity-dispatcher:v0.0.31-20250801

echo "✅ 所有鏡像已推送到 Harbor"
```

### 1.6 驗證 Harbor 中的鏡像
```bash
# 驗證鏡像是否成功推送
echo "驗證 Harbor 中的鏡像..."
podman search starlux.harbor.com/gravity/

# 或通過瀏覽器檢查 Harbor Web UI
echo "請檢查 Harbor Web UI: https://starlux.harbor.com"
```

---

# 第二階段：各節點從 Harbor 拉取到 Containerd

## 步驟 2: Master Node 拉取鏡像

### 2.1 連接到 Master Node
```bash
ssh user@10.10.254.151
```

### 2.2 從 Harbor 拉取鏡像到本地
```bash
# 登入 Harbor
podman login starlux.harbor.com
# 輸入: admin / Harbor12345

# 拉取所有 Gravity 鏡像
echo "Master Node 開始拉取 Gravity 鏡像..."

podman pull starlux.harbor.com/gravity/gravity-adapter-mssql:v3.0.15-20250801
podman pull starlux.harbor.com/gravity/nats-server:v1.3.25-20250801
podman pull starlux.harbor.com/gravity/atomic:v1.0.0-20250801-ubi
podman pull starlux.harbor.com/gravity/gravity-dispatcher:v0.0.31-20250801

echo "✅ Master Node 鏡像拉取完成"
```

### 2.3 將鏡像導入到 Containerd
```bash
# 將 Podman 鏡像保存為 tar 文件
echo "導出鏡像為 tar 檔案..."

podman save starlux.harbor.com/gravity/gravity-adapter-mssql:v3.0.15-20250801 -o gravity-adapter-mssql.tar
podman save starlux.harbor.com/gravity/nats-server:v1.3.25-20250801 -o nats-server.tar
podman save starlux.harbor.com/gravity/atomic:v1.0.0-20250801-ubi -o atomic.tar
podman save starlux.harbor.com/gravity/gravity-dispatcher:v0.0.31-20250801 -o gravity-dispatcher.tar

# 使用 ctr 導入到 containerd
echo "導入鏡像到 containerd..."

sudo ctr -n k8s.io images import gravity-adapter-mssql.tar
sudo ctr -n k8s.io images import nats-server.tar
sudo ctr -n k8s.io images import atomic.tar
sudo ctr -n k8s.io images import gravity-dispatcher.tar

# 清理 tar 文件
rm -f *.tar

# 驗證 containerd 中的鏡像
echo "驗證 containerd 鏡像..."
sudo ctr -n k8s.io images ls | grep gravity
sudo ctr -n k8s.io images ls | grep nats
sudo ctr -n k8s.io images ls | grep atomic

echo "✅ Master Node containerd 鏡像導入完成"
```

## 步驟 3: Worker Node 1 拉取鏡像

### 3.1 連接到 Worker Node 1
```bash
ssh user@10.10.254.152
```

### 3.2 重複 Master Node 的步驟
```bash
# 登入 Harbor
podman login starlux.harbor.com

# 拉取鏡像
echo "Worker Node 1 開始拉取 Gravity 鏡像..."

podman pull starlux.harbor.com/gravity/gravity-adapter-mssql:v3.0.15-20250801
podman pull starlux.harbor.com/gravity/nats-server:v1.3.25-20250801
podman pull starlux.harbor.com/gravity/atomic:v1.0.0-20250801-ubi
podman pull starlux.harbor.com/gravity/gravity-dispatcher:v0.0.31-20250801

# 導出並導入到 containerd
podman save starlux.harbor.com/gravity/gravity-adapter-mssql:v3.0.15-20250801 -o gravity-adapter-mssql.tar
podman save starlux.harbor.com/gravity/nats-server:v1.3.25-20250801 -o nats-server.tar
podman save starlux.harbor.com/gravity/atomic:v1.0.0-20250801-ubi -o atomic.tar
podman save starlux.harbor.com/gravity/gravity-dispatcher:v0.0.31-20250801 -o gravity-dispatcher.tar

sudo ctr -n k8s.io images import gravity-adapter-mssql.tar
sudo ctr -n k8s.io images import nats-server.tar
sudo ctr -n k8s.io images import atomic.tar
sudo ctr -n k8s.io images import gravity-dispatcher.tar

rm -f *.tar

echo "✅ Worker Node 1 containerd 鏡像導入完成"
```

## 步驟 4: Worker Node 2 拉取鏡像

### 4.1 連接到 Worker Node 2
```bash
ssh user@10.10.254.153
```

### 4.2 重複相同步驟
```bash
# 登入 Harbor
podman login starlux.harbor.com

# 拉取鏡像
echo "Worker Node 2 開始拉取 Gravity 鏡像..."

podman pull starlux.harbor.com/gravity/gravity-adapter-mssql:v3.0.15-20250801
podman pull starlux.harbor.com/gravity/nats-server:v1.3.25-20250801
podman pull starlux.harbor.com/gravity/atomic:v1.0.0-20250801-ubi
podman pull starlux.harbor.com/gravity/gravity-dispatcher:v0.0.31-20250801

# 導出並導入到 containerd
podman save starlux.harbor.com/gravity/gravity-adapter-mssql:v3.0.15-20250801 -o gravity-adapter-mssql.tar
podman save starlux.harbor.com/gravity/nats-server:v1.3.25-20250801 -o nats-server.tar
podman save starlux.harbor.com/gravity/atomic:v1.0.0-20250801-ubi -o atomic.tar
podman save starlux.harbor.com/gravity/gravity-dispatcher:v0.0.31-20250801 -o gravity-dispatcher.tar

sudo ctr -n k8s.io images import gravity-adapter-mssql.tar
sudo ctr -n k8s.io images import nats-server.tar
sudo ctr -n k8s.io images import atomic.tar
sudo ctr -n k8s.io images import gravity-dispatcher.tar

rm -f *.tar

echo "✅ Worker Node 2 containerd 鏡像導入完成"
```

---

# 第三階段：建置簡單 Gitea 環境

## 步驟 5: 在 Master Node 部署 Gitea

### 5.1 創建 Gitea 命名空間
```bash
# 在 Master Node 執行
ssh user@10.10.254.151

# 創建 Gitea 命名空間
kubectl create namespace gitea
```

### 5.2 創建 Gitea ConfigMap
```bash
# 創建 Gitea 配置
cat > gitea-config.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: gitea-config
  namespace: gitea
data:
  app.ini: |
    APP_NAME = Gitea: Git with a cup of tea
    RUN_MODE = prod
    RUN_USER = git

    [repository]
    ROOT = /data/git/repositories

    [repository.local]
    LOCAL_COPY_PATH = /data/gitea/tmp/local-repo

    [repository.upload]
    TEMP_PATH = /data/gitea/uploads

    [server]
    APP_DATA_PATH = /data/gitea
    DOMAIN = gitea.local
    SSH_DOMAIN = gitea.local
    HTTP_PORT = 3000
    ROOT_URL = http://gitea.local:3000/
    DISABLE_SSH = false
    SSH_PORT = 22
    SSH_LISTEN_PORT = 22
    LFS_START_SERVER = true
    LFS_CONTENT_PATH = /data/git/lfs
    LFS_JWT_SECRET = 

    [database]
    PATH = /data/gitea/gitea.db
    DB_TYPE = sqlite3
    HOST =
    NAME =
    USER =
    PASSWD =
    LOG_SQL = false
    SCHEMA =
    SSL_MODE = disable

    [indexer]
    ISSUE_INDEXER_PATH = /data/gitea/indexers/issues.bleve

    [session]
    PROVIDER_CONFIG = /data/gitea/sessions
    PROVIDER = file

    [picture]
    AVATAR_UPLOAD_PATH = /data/gitea/avatars
    REPOSITORY_AVATAR_UPLOAD_PATH = /data/gitea/repo-avatars
    DISABLE_GRAVATAR = false
    ENABLE_FEDERATED_AVATAR = true

    [attachment]
    PATH = /data/gitea/attachments
    ALLOWED_TYPES = image/jpeg|image/png|application/zip|application/gzip

    [log]
    MODE = console
    LEVEL = info
    ROOT_PATH = /data/gitea/log

    [security]
    INSTALL_LOCK = false
    SECRET_KEY = 
    REVERSE_PROXY_LIMIT = 1
    REVERSE_PROXY_TRUSTED_PROXIES = *
    INTERNAL_TOKEN = 
    PASSWORD_HASH_ALGO = pbkdf2

    [mailer]
    ENABLED = false

    [service]
    DISABLE_REGISTRATION = false
    ALLOW_ONLY_EXTERNAL_REGISTRATION = false
    REQUIRE_SIGNIN_VIEW = false
    NO_REPLY_ADDRESS = noreply.localhost
    ENABLE_NOTIFY_MAIL = false

    [webhook]
    QUEUE_LENGTH = 1000

    [other]
    SHOW_FOOTER_BRANDING = false
    SHOW_FOOTER_VERSION = false
    SHOW_FOOTER_TEMPLATE_LOAD_TIME = false

EOF

kubectl apply -f gitea-config.yaml
```

### 5.3 創建 Gitea PV 和 PVC
```bash
# 創建持久卷聲明
cat > gitea-storage.yaml << 'EOF'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: gitea-pv
  namespace: gitea
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: /opt/gitea-data
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - master-node  # 請替換為實際的 master node 名稱
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: gitea-pvc
  namespace: gitea
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: local-storage
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF

# 創建數據目錄
sudo mkdir -p /opt/gitea-data
sudo chown -R 1000:1000 /opt/gitea-data

kubectl apply -f gitea-storage.yaml
```

### 5.4 部署 Gitea
```bash
# 創建 Gitea Deployment
cat > gitea-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gitea
  namespace: gitea
  labels:
    app: gitea
spec:
  replicas: 1
  selector:
    matchLabels:
      app: gitea
  template:
    metadata:
      labels:
        app: gitea
    spec:
      containers:
      - name: gitea
        image: gitea/gitea:1.21.5
        ports:
        - containerPort: 3000
          name: http
        - containerPort: 22
          name: ssh
        env:
        - name: USER_UID
          value: "1000"
        - name: USER_GID
          value: "1000"
        volumeMounts:
        - name: gitea-data
          mountPath: /data
        - name: gitea-config
          mountPath: /data/gitea/conf
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /api/healthz
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /api/healthz
            port: 3000
          initialDelaySeconds: 15
          periodSeconds: 5
      volumes:
      - name: gitea-data
        persistentVolumeClaim:
          claimName: gitea-pvc
      - name: gitea-config
        configMap:
          name: gitea-config
---
apiVersion: v1
kind: Service
metadata:
  name: gitea-service
  namespace: gitea
spec:
  selector:
    app: gitea
  ports:
  - name: http
    port: 3000
    targetPort: 3000
    nodePort: 30300
  - name: ssh
    port: 22
    targetPort: 22
    nodePort: 30022
  type: NodePort
EOF

kubectl apply -f gitea-deployment.yaml
```

### 5.5 驗證 Gitea 部署
```bash
# 檢查 Pod 狀態
kubectl get pods -n gitea

# 檢查服務
kubectl get services -n gitea

# 查看 Pod 日誌
kubectl logs -f deployment/gitea -n gitea

# 檢查 Gitea 是否可以訪問
curl -I http://localhost:30300
```

### 5.6 訪問 Gitea
```bash
echo "Gitea 安裝完成！"
echo "訪問地址:"
echo "- HTTP: http://10.10.254.151:30300"
echo "- SSH: ssh://10.10.254.151:30022"
echo ""
echo "初始設置："
echo "1. 打開瀏覽器訪問 http://10.10.254.151:30300"
echo "2. 完成初始配置"
echo "3. 創建管理員帳號"
```

---

# 第四階段：Gravity 安裝

## 步驟 6: 準備 Gravity 安裝

### 6.1 創建 Gravity 命名空間
```bash
# 在 Master Node 執行
kubectl create namespace gravity
```

### 6.2 創建 Gravity ConfigMap
```bash
# 創建 NATS 配置
cat > gravity-nats-config.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: nats-config
  namespace: gravity
data:
  nats-server.conf: |
    # NATS Server Configuration
    port: 4222
    http_port: 8222
    
    # Logging options
    log_file: "/tmp/nats-server.log"
    logtime: true
    debug: false
    trace: false
    
    # Client connection options
    max_connections: 64K
    max_control_line: 4KB
    max_payload: 64MB
    max_pending: 256MB
    
    # Clustering options (if needed)
    cluster {
      port: 6222
      routes = []
    }
    
    # JetStream
    jetstream {
      store_dir: "/data/jetstream"
      max_memory_store: 1GB
      max_file_store: 10GB
    }
EOF

kubectl apply -f gravity-nats-config.yaml
```

### 6.3 部署 NATS Server
```bash
# 創建 NATS Deployment
cat > gravity-nats-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nats-server
  namespace: gravity
  labels:
    app: nats-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nats-server
  template:
    metadata:
      labels:
        app: nats-server
    spec:
      containers:
      - name: nats-server
        image: starlux.harbor.com/gravity/nats-server:v1.3.25-20250801
        ports:
        - containerPort: 4222
          name: nats
        - containerPort: 8222
          name: monitor
        - containerPort: 6222
          name: cluster
        command:
        - "/nats-server"
        args:
        - "-c"
        - "/etc/nats-server/nats-server.conf"
        volumeMounts:
        - name: nats-config
          mountPath: /etc/nats-server
        - name: nats-data
          mountPath: /data
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /
            port: 8222
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 8222
          initialDelaySeconds: 15
          periodSeconds: 5
      volumes:
      - name: nats-config
        configMap:
          name: nats-config
      - name: nats-data
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: nats-service
  namespace: gravity
spec:
  selector:
    app: nats-server
  ports:
  - name: nats
    port: 4222
    targetPort: 4222
  - name: monitor
    port: 8222
    targetPort: 8222
  type: ClusterIP
EOF

kubectl apply -f gravity-nats-deployment.yaml
```

### 6.4 部署 Gravity Dispatcher
```bash
# 創建 Gravity Dispatcher Deployment
cat > gravity-dispatcher-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gravity-dispatcher
  namespace: gravity
  labels:
    app: gravity-dispatcher
spec:
  replicas: 1
  selector:
    matchLabels:
      app: gravity-dispatcher
  template:
    metadata:
      labels:
        app: gravity-dispatcher
    spec:
      containers:
      - name: gravity-dispatcher
        image: starlux.harbor.com/gravity/gravity-dispatcher:v0.0.31-20250801
        ports:
        - containerPort: 8080
          name: http
        env:
        - name: GRAVITY_NATS_HOST
          value: "nats-service.gravity.svc.cluster.local:4222"
        - name: GRAVITY_HTTP_PORT
          value: "8080"
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 15
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: gravity-dispatcher-service
  namespace: gravity
spec:
  selector:
    app: gravity-dispatcher
  ports:
  - name: http
    port: 8080
    targetPort: 8080
    nodePort: 30800
  type: NodePort
EOF

kubectl apply -f gravity-dispatcher-deployment.yaml
```

### 6.5 部署 Atomic
```bash
# 創建 Atomic Deployment
cat > gravity-atomic-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: atomic
  namespace: gravity
  labels:
    app: atomic
spec:
  replicas: 1
  selector:
    matchLabels:
      app: atomic
  template:
    metadata:
      labels:
        app: atomic
    spec:
      containers:
      - name: atomic
        image: starlux.harbor.com/gravity/atomic:v1.0.0-20250801-ubi
        ports:
        - containerPort: 8080
          name: http
        env:
        - name: ATOMIC_NATS_HOST
          value: "nats-service.gravity.svc.cluster.local:4222"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
---
apiVersion: v1
kind: Service
metadata:
  name: atomic-service
  namespace: gravity
spec:
  selector:
    app: atomic
  ports:
  - name: http
    port: 8080
    targetPort: 8080
  type: ClusterIP
EOF

kubectl apply -f gravity-atomic-deployment.yaml
```

### 6.6 部署 Gravity Adapter MSSQL（示例配置）
```bash
# 創建 Gravity Adapter MSSQL Deployment
cat > gravity-adapter-mssql-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gravity-adapter-mssql
  namespace: gravity
  labels:
    app: gravity-adapter-mssql
spec:
  replicas: 1
  selector:
    matchLabels:
      app: gravity-adapter-mssql
  template:
    metadata:
      labels:
        app: gravity-adapter-mssql
    spec:
      containers:
      - name: gravity-adapter-mssql
        image: starlux.harbor.com/gravity/gravity-adapter-mssql:v3.0.15-20250801
        env:
        - name: GRAVITY_NATS_HOST
          value: "nats-service.gravity.svc.cluster.local:4222"
        - name: GRAVITY_ADAPTER_ID
          value: "mssql-adapter"
        # 請根據實際需求配置 MSSQL 連接參數
        - name: MSSQL_HOST
          value: "your-mssql-host"
        - name: MSSQL_PORT
          value: "1433"
        - name: MSSQL_DATABASE
          value: "your-database"
        - name: MSSQL_USERNAME
          value: "your-username"
        - name: MSSQL_PASSWORD
          value: "your-password"
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: gravity-adapter-mssql-service
  namespace: gravity
spec:
  selector:
    app: gravity-adapter-mssql
  ports:
  - name: http
    port: 8080
    targetPort: 8080
  type: ClusterIP
EOF

# 注意：請根據實際的 MSSQL 配置修改環境變數後再應用
# kubectl apply -f gravity-adapter-mssql-deployment.yaml
```

---

# 第五階段：驗證和測試

## 步驟 7: 驗證所有服務

### 7.1 檢查所有 Pod 狀態
```bash
# 檢查 Gitea
kubectl get pods -n gitea
kubectl get services -n gitea

# 檢查 Gravity
kubectl get pods -n gravity
kubectl get services -n gravity
```

### 7.2 檢查服務訪問
```bash
echo "=== 服務訪問資訊 ==="
echo "Gitea:"
echo "- Web UI: http://10.10.254.151:30300"
echo "- SSH: ssh://10.10.254.151:30022"
echo ""
echo "Gravity:"
echo "- Dispatcher: http://10.10.254.151:30800"
echo "- NATS Monitor: kubectl port-forward -n gravity svc/nats-service 8222:8222"
echo ""
echo "驗證命令:"
echo "curl -I http://10.10.254.151:30300  # Gitea"
echo "curl -I http://10.10.254.151:30800  # Gravity Dispatcher"
```

### 7.3 檢查鏡像使用情況
```bash
# 在所有節點檢查鏡像
for node in 10.10.254.151 10.10.254.152 10.10.254.153; do
    echo "=== 檢查節點 $node ==="
    ssh user@$node "sudo ctr -n k8s.io images ls | grep -E '(gravity|nats|atomic)'"
done
```

---

# 故障排除

## 常見問題

### 1. 鏡像拉取失敗
```bash
# 檢查 Harbor 連接
podman login starlux.harbor.com

# 檢查鏡像是否存在
podman search starlux.harbor.com/gravity/

# 重新拉取
podman pull starlux.harbor.com/gravity/nats-server:v1.3.25-20250801
```

### 2. Containerd 導入失敗
```bash
# 檢查 containerd 狀態
sudo systemctl status containerd

# 檢查命名空間
sudo ctr namespaces ls

# 重新導入鏡像
sudo ctr -n k8s.io images import your-image.tar
```

### 3. Pod 啟動失敗
```bash
# 檢查 Pod 詳情
kubectl describe pod <pod-name> -n <namespace>

# 查看日誌
kubectl logs <pod-name> -n <namespace>

# 檢查節點資源
kubectl describe node
```

---

# 完成檢查清單

## ✅ 安裝完成檢查清單

- [ ] Harbor 中包含所有 Gravity 鏡像
- [ ] 所有節點的 containerd 中有 Gravity 鏡像
- [ ] Gitea 部署成功並可訪問
- [ ] NATS Server 運行正常
- [ ] Gravity Dispatcher 運行正常
- [ ] Atomic 服務運行正常
- [ ] 所有服務可以相互通信

## 🎉 安裝完成

完成以上步驟後：

1. **Gitea** 運行在 `http://10.10.254.151:30300`
2. **Gravity Dispatcher** 運行在 `http://10.10.254.151:30800`
3. 所有 **Gravity 組件** 都已部署在 Kubernetes 集群中
4. 你可以在 **Gitea** 中手動創建帳號和倉庫

接下來你可以：
- 在 Gitea 中創建管理員帳號
- 配置 Gravity 的具體業務邏輯
- 根據需求調整 MSSQL Adapter 的配置