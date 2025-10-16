# Harbor + Gravity 完整重建指南

## 環境資訊
- **Harbor Server**: 10.10.254.155 (starlux.harbor.com)
- **Master Node**: 10.10.254.151
- **Worker Nodes**: 10.10.254.152, 10.10.254.153
- **統一使用**: Docker (不使用 Podman)
- **目標**: 完全重建 Harbor，部署 Gravity，建置 Gitea

---

# 第一階段：完全清理 Harbor 環境

## 步驟 1: Harbor VM 完全清理 (10.10.254.155)

### 1.1 連接到 Harbor VM
```bash
ssh user@10.10.254.155
```

### 1.2 停止並清理所有 Docker 容器和鏡像
```bash
echo "🧹 開始清理所有 Docker 容器和鏡像..."

sudo docker stop $(sudo docker ps -aq) 2>/dev/null || echo "無運行中的容器"
sudo docker rm $(sudo docker ps -aq) 2>/dev/null || echo "無容器需要移除"
sudo docker rmi -f $(sudo docker images -aq) 2>/dev/null || echo "無鏡像需要移除"
sudo docker system prune -a -f --volumes
sudo docker network prune -f

echo "✅ Docker 完全清理完成"
```

### 1.3 移除所有 Harbor 相關目錄
```bash
echo "🧹 清理 Harbor 相關目錄..."

sudo rm -rf /opt/harbor/
sudo rm -rf /opt/harbor-offline-installer-*.tgz
sudo rm -rf /data/
sudo rm -rf /var/log/harbor/
rm -rf ~/harbor-cert/

echo "✅ Harbor 目錄清理完成"
```

### 1.4 清理系統配置和憑證
```bash
echo "🧹 清理系統配置..."

sudo rm -rf /etc/containerd/certs.d/
sudo rm -rf /etc/containers/
sudo rm -f /etc/docker/daemon.json
sudo sed -i '/starlux.harbor.com/d' /etc/hosts
sudo sed -i '/harbor.brobridge.com/d' /etc/hosts
rm -rf ~/.docker/config.json 2>/dev/null || echo "Docker 配置不存在"

echo "✅ 系統配置清理完成"
```

### 1.5 移除 Docker 和相關套件
```bash
echo "🧹 移除 Docker 和相關套件..."

sudo systemctl stop docker
sudo systemctl stop containerd
sudo apt purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo apt purge -y docker docker-engine docker.io runc
sudo apt autoremove -y
sudo rm -f /usr/local/bin/docker-compose
sudo rm -f /usr/bin/docker-compose
sudo rm -f /usr/share/keyrings/docker-archive-keyring.gpg
sudo rm -f /etc/apt/sources.list.d/docker.list
sudo apt purge -y podman
sudo apt autoremove -y
sudo apt clean
sudo apt autoclean

echo "✅ Docker 套件完全移除"
```

### 1.6 清理系統緩存和重啟
```bash
echo "🧹 最終清理..."

# 清理 APT 緩存
sudo apt clean
sudo apt autoclean


echo "✅ Harbor VM 完全清理完成"
echo "請重啟系統以確保完全清理: sudo reboot"
```

## 步驟 2: 所有 K8s 節點清理 (10.10.254.151-153)

### 2.1 Master Node 清理 (10.10.254.151)
```bash
# 連接到 Master Node
ssh user@10.10.254.151

echo "🧹 清理 Master Node..."

sudo docker stop $(sudo docker ps -aq) 2>/dev/null || echo "無容器運行"
sudo docker rm $(sudo docker ps -aq) 2>/dev/null || echo "無容器需要移除"
sudo docker rmi $(sudo docker images | grep starlux.harbor.com | awk '{print $3}') 2>/dev/null || echo "無 Harbor 鏡像"
sudo rm -rf /etc/containerd/certs.d/starlux.harbor.com/
sudo rm -rf /etc/containerd/certs.d/harbor.brobridge.com/
sudo rm -rf /etc/containerd/certs.d/10.10.254.155/
sudo rm -rf /etc/containers/
sudo rm -f /etc/docker/daemon.json
sudo sed -i '/starlux.harbor.com/d' /etc/hosts
sudo sed -i '/harbor.brobridge.com/d' /etc/hosts
rm -rf ~/.docker/config.json 2>/dev/null || echo "Docker 配置不存在"
rm -f ~/harbor-certs.tar.gz ~/harbor.crt
sudo systemctl restart containerd 2>/dev/null || echo "Containerd 服務重啟"

echo "✅ Master Node 清理完成"
```

### 2.2 Worker Node 1 清理 (10.10.254.152)
```bash
# 連接到 Worker Node 1
ssh user@10.10.254.152

echo "🧹 清理 Worker Node 1..."

sudo docker stop $(sudo docker ps -aq) 2>/dev/null || echo "無容器運行"
sudo docker rm $(sudo docker ps -aq) 2>/dev/null || echo "無容器需要移除"
sudo docker rmi $(sudo docker images | grep starlux.harbor.com | awk '{print $3}') 2>/dev/null || echo "無 Harbor 鏡像"
sudo rm -rf /etc/containerd/certs.d/starlux.harbor.com/
sudo rm -rf /etc/containerd/certs.d/harbor.brobridge.com/
sudo rm -rf /etc/containerd/certs.d/10.10.254.155/
sudo rm -rf /etc/containers/
sudo rm -f /etc/docker/daemon.json
sudo sed -i '/starlux.harbor.com/d' /etc/hosts
sudo sed -i '/harbor.brobridge.com/d' /etc/hosts
rm -rf ~/.docker/config.json 2>/dev/null || echo "Docker 配置不存在"
rm -f ~/harbor-certs.tar.gz ~/harbor.crt
sudo systemctl restart containerd 2>/dev/null || echo "Containerd 服務重啟"

echo "✅ Worker Node 1 清理完成"
```

### 2.3 Worker Node 2 清理 (10.10.254.153)
```bash
# 連接到 Worker Node 2
ssh user@10.10.254.153

echo "🧹 清理 Worker Node 2..."

sudo docker stop $(sudo docker ps -aq) 2>/dev/null || echo "無容器運行"
sudo docker rm $(sudo docker ps -aq) 2>/dev/null || echo "無容器需要移除"
sudo docker rmi $(sudo docker images | grep starlux.harbor.com | awk '{print $3}') 2>/dev/null || echo "無 Harbor 鏡像"
sudo rm -rf /etc/containerd/certs.d/starlux.harbor.com/
sudo rm -rf /etc/containerd/certs.d/harbor.brobridge.com/
sudo rm -rf /etc/containerd/certs.d/10.10.254.155/
sudo rm -rf /etc/containers/
sudo rm -f /etc/docker/daemon.json
sudo sed -i '/starlux.harbor.com/d' /etc/hosts
sudo sed -i '/harbor.brobridge.com/d' /etc/hosts
rm -rf ~/.docker/config.json 2>/dev/null || echo "Docker 配置不存在"
rm -f ~/harbor-certs.tar.gz ~/harbor.crt
sudo systemctl restart containerd 2>/dev/null || echo "Containerd 服務重啟"

echo "✅ Worker Node 2 清理完成"
```

---

# 第二階段：Harbor VM 重新安裝 (10.10.254.155)

## 步驟 3: 重新安裝 Docker

### 3.1 連接到 Harbor VM（清理後重啟）
```bash
# 如果之前重啟了系統
ssh user@10.10.254.155
```

### 3.2 安裝 Docker
```bash
echo "🚀 開始安裝 Docker..."

# 更新系統
sudo apt update && sudo apt upgrade -y

# 安裝必要套件
sudo apt install -y curl wget vim net-tools openssl ca-certificates \
    apt-transport-https gnupg lsb-release

# 添加 Docker GPG 密鑰
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# 添加 Docker 倉庫
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 安裝 Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 啟動 Docker 服務
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER

# 安裝 Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# 驗證安裝
docker --version
docker-compose --version

echo "✅ Docker 安裝完成"
```

### 3.3 配置 Docker 信任不安全的 Registry
```bash
# 創建 Docker daemon 配置
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json << 'EOF'
{
  "insecure-registries": ["starlux.harbor.com", "10.10.254.155"],
  "registry-mirrors": []
}
EOF

# 重啟 Docker 服務
sudo systemctl daemon-reload
sudo systemctl restart docker

echo "✅ Docker Registry 配置完成"
```

## 步驟 4: 生成 SSL 憑證

### 4.1 創建憑證工作目錄
```bash
# 創建工作目錄
mkdir -p ~/harbor-cert && cd ~/harbor-cert
```

### 4.2 生成 SSL 憑證
```bash
# 創建 OpenSSL 配置文件
cat > openssl.cnf << 'EOF'
[ req ]
default_bits = 2048
default_md = sha256
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[ req_distinguished_name ]
C = TW
ST = Taiwan
L = Taipei
O = StarLux
OU = IT Department
CN = starlux.harbor.com

[ v3_req ]
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = starlux.harbor.com
IP.1 = 10.10.254.155
EOF

# 生成私鑰和憑證
openssl req -x509 -nodes -newkey rsa:4096 \
  -keyout harbor.key \
  -out harbor.crt \
  -days 3650 \
  -config openssl.cnf \
  -extensions v3_req

# 驗證憑證內容
openssl x509 -in harbor.crt -text -noout | grep -A 10 "Subject Alternative Name"

echo "✅ SSL 憑證生成完成"
```

### 4.3 配置憑證目錄
```bash
# 創建 Harbor 憑證目錄
sudo mkdir -p /data/cert/

# 複製憑證到正確位置
sudo cp harbor.crt harbor.key /data/cert/

# 設置憑證權限
sudo chmod 644 /data/cert/harbor.crt
sudo chmod 600 /data/cert/harbor.key
sudo chown root:root /data/cert/*

# 驗證憑證文件
ls -la /data/cert/

echo "✅ 憑證配置完成"
```

## 步驟 5: 安裝 Harbor

### 5.1 下載 Harbor
```bash
# 進入安裝目錄
cd /opt
sudo wget https://github.com/goharbor/harbor/releases/download/v2.9.0/harbor-offline-installer-v2.9.0.tgz

# 解壓縮
sudo tar xzf harbor-offline-installer-v2.9.0.tgz
sudo chown -R $USER:$USER harbor
cd harbor
```

### 5.2 配置 Harbor
```bash
# 複製配置模板
cp harbor.yml.tmpl harbor.yml

# 編輯配置文件（重要：需要手動編輯）
vim harbor.yml
```

**Harbor 配置內容 (harbor.yml):**
```yaml
# 主機名設定
hostname: starlux.harbor.com

# HTTP 配置 (用於重定向到 HTTPS)
http:
  port: 80

# HTTPS 配置
https:
  port: 443
  certificate: /data/cert/harbor.crt
  private_key: /data/cert/harbor.key

# 外部 URL
external_url: https://starlux.harbor.com

# 管理員密碼
harbor_admin_password: Harbor12345

# 資料庫配置
database:
  password: root123
  max_idle_conns: 50
  max_open_conns: 1000

# 數據存儲路徑
data_volume: /data

# 日誌配置
log:
  level: info
  local:
    rotate_count: 50
    rotate_size: 200M
    location: /var/log/harbor
```

### 5.3 安裝 Harbor
```bash
# 執行預安裝腳本
sudo ./prepare

# 安裝 Harbor
sudo ./install.sh

# 等待安裝完成，檢查容器狀態
sleep 30
sudo docker-compose ps

echo "✅ Harbor 安裝完成"
```

## 步驟 6: 配置防火牆和 DNS

### 6.1 配置防火牆
```bash
# 啟用防火牆
sudo ufw --force enable

# 允許 SSH
sudo ufw allow ssh

# 允許 Harbor 端口
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# 查看防火牆狀態
sudo ufw status verbose

echo "✅ 防火牆配置完成"
```

### 6.2 配置 DNS (hosts 文件)
```bash
# 編輯 hosts 文件
echo "10.10.254.155    starlux.harbor.com" | sudo tee -a /etc/hosts

# 驗證 DNS 解析
ping -c 3 starlux.harbor.com

echo "✅ DNS 配置完成"
```

### 6.3 驗證 Harbor 安裝
```bash
# 測試 HTTPS 連接
curl -k -I https://starlux.harbor.com

# 測試 HTTP 連接（應該重定向到 HTTPS）
curl -I http://starlux.harbor.com

echo "Harbor Web UI 可以通過以下地址訪問："
echo "https://starlux.harbor.com"
echo "用戶名: admin"
echo "密碼: Harbor12345"
```

---

# 第三階段：所有節點配置 Docker

## 步驟 7: Master Node Docker 配置 (10.10.254.151)

### 7.1 連接到 Master Node
```bash
ssh user@10.10.254.151
```

### 7.2 安裝 Docker（如果尚未安裝）
```bash
# 檢查 Docker 是否已安裝
if ! command -v docker &> /dev/null; then
    echo "安裝 Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
else
    echo "Docker 已安裝"
fi
```

### 7.3 配置 Docker Registry
```bash
# 配置 Docker daemon 信任 Harbor
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json << 'EOF'
{
  "insecure-registries": ["starlux.harbor.com", "10.10.254.155"],
  "registry-mirrors": []
}
EOF

# 重啟 Docker 服務
sudo systemctl daemon-reload
sudo systemctl restart docker

echo "✅ Master Node Docker 配置完成"
```

### 7.4 配置 DNS 和測試
```bash
# 配置 hosts 文件
echo "10.10.254.155    starlux.harbor.com" | sudo tee -a /etc/hosts

# 測試網絡連通性
ping -c 3 starlux.harbor.com

# 測試 Harbor 訪問
curl -k -I https://starlux.harbor.com

echo "✅ Master Node 配置完成"
```

## 步驟 8: Worker Node 1 配置 (10.10.254.152)

### 8.1 連接到 Worker Node 1
```bash
ssh user@10.10.254.152
```

### 8.2 執行相同的 Docker 配置
```bash
# 安裝 Docker（如果需要）
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
fi

# 配置 Docker daemon
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json << 'EOF'
{
  "insecure-registries": ["starlux.harbor.com", "10.10.254.155"],
  "registry-mirrors": []
}
EOF

# 重啟服務
sudo systemctl daemon-reload
sudo systemctl restart docker

# 配置 DNS
echo "10.10.254.155    starlux.harbor.com" | sudo tee -a /etc/hosts

# 測試連接
ping -c 3 starlux.harbor.com
curl -k -I https://starlux.harbor.com

echo "✅ Worker Node 1 配置完成"
```

## 步驟 9: Worker Node 2 配置 (10.10.254.153)

### 9.1 連接到 Worker Node 2
```bash
ssh user@10.10.254.153
```

### 9.2 執行相同的 Docker 配置
```bash
# 安裝 Docker（如果需要）
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
fi

# 配置 Docker daemon
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json << 'EOF'
{
  "insecure-registries": ["starlux.harbor.com", "10.10.254.155"],
  "registry-mirrors": []
}
EOF

# 重啟服務
sudo systemctl daemon-reload
sudo systemctl restart docker

# 配置 DNS
echo "10.10.254.155    starlux.harbor.com" | sudo tee -a /etc/hosts

# 測試連接
ping -c 3 starlux.harbor.com
curl -k -I https://starlux.harbor.com

echo "✅ Worker Node 2 配置完成"
```

---

# 第四階段：拉取和推送 Gravity Images

## 步驟 10: Harbor VM 拉取 Gravity 鏡像 (10.10.254.155)

### 10.1 創建 Harbor 項目
```bash
# 登入 Harbor Web UI: https://starlux.harbor.com
# 用戶名: admin, 密碼: Harbor12345
# 創建項目 "gravity" (設為 Public)

echo "請通過瀏覽器登入 Harbor 創建 gravity 項目："
echo "1. 訪問: https://starlux.harbor.com"
echo "2. 登入: admin / Harbor12345"
echo "3. 創建項目: gravity (Public)"
echo ""
read -p "項目創建完成後按 Enter 繼續: "
```

### 10.2 拉取 Gravity 鏡像
```bash
echo "🚀 開始拉取 Gravity 鏡像..."

# 拉取所有 Gravity 鏡像
docker pull ghcr.io/brobridgeorg/gravity-adapter-mssql:v3.0.15-20250801
docker pull ghcr.io/brobridgeorg/nats-server:v1.3.25-20250801
docker pull ghcr.io/brobridgeorg/atomic:v1.0.0-20250801-ubi
docker pull ghcr.io/brobridgeorg/gravity-dispatcher:v0.0.31-20250801

echo "✅ Gravity 鏡像拉取完成"
```

### 10.3 登入 Harbor 並推送鏡像
```bash
# 登入 Harbor
docker login starlux.harbor.com
# 輸入用戶名: admin
# 輸入密碼: Harbor12345

echo "🚀 開始標記和推送鏡像到 Harbor..."

# 標記並推送 gravity-adapter-mssql
docker tag ghcr.io/brobridgeorg/gravity-adapter-mssql:v3.0.15-20250801 starlux.harbor.com/gravity/gravity-adapter-mssql:v3.0.15-20250801
docker push starlux.harbor.com/gravity/gravity-adapter-mssql:v3.0.15-20250801

# 標記並推送 nats-server
docker tag ghcr.io/brobridgeorg/nats-server:v1.3.25-20250801 starlux.harbor.com/gravity/nats-server:v1.3.25-20250801
docker push starlux.harbor.com/gravity/nats-server:v1.3.25-20250801

# 標記並推送 atomic
docker tag ghcr.io/brobridgeorg/atomic:v1.0.0-20250801-ubi starlux.harbor.com/gravity/atomic:v1.0.0-20250801-ubi
docker push starlux.harbor.com/gravity/atomic:v1.0.0-20250801-ubi

# 標記並推送 gravity-dispatcher
docker tag ghcr.io/brobridgeorg/gravity-dispatcher:v0.0.31-20250801 starlux.harbor.com/gravity/gravity-dispatcher:v0.0.31-20250801
docker push starlux.harbor.com/gravity/gravity-dispatcher:v0.0.31-20250801

echo "✅ 所有鏡像推送到 Harbor 完成"
```

## 步驟 11: 各節點拉取 Harbor 鏡像

### 11.1 Master Node 拉取鏡像 (10.10.254.151)
```bash
# 連接到 Master Node
ssh user@10.10.254.151

# 登入 Harbor
docker login starlux.harbor.com
# 輸入: admin / Harbor12345

echo "🚀 Master Node 開始拉取 Gravity 鏡像..."

# 拉取所有 Gravity 鏡像
docker pull starlux.harbor.com/gravity/gravity-adapter-mssql:v3.0.15-20250801
docker pull starlux.harbor.com/gravity/nats-server:v1.3.25-20250801
docker pull starlux.harbor.com/gravity/atomic:v1.0.0-20250801-ubi
docker pull starlux.harbor.com/gravity/gravity-dispatcher:v0.0.31-20250801

# 驗證鏡像
docker images | grep starlux.harbor.com

echo "✅ Master Node 鏡像拉取完成"
```

### 11.2 Worker Node 1 拉取鏡像 (10.10.254.152)
```bash
# 連接到 Worker Node 1
ssh user@10.10.254.152

# 登入 Harbor
docker login starlux.harbor.com

# 拉取鏡像
echo "🚀 Worker Node 1 開始拉取 Gravity 鏡像..."
docker pull starlux.harbor.com/gravity/gravity-adapter-mssql:v3.0.15-20250801
docker pull starlux.harbor.com/gravity/nats-server:v1.3.25-20250801
docker pull starlux.harbor.com/gravity/atomic:v1.0.0-20250801-ubi
docker pull starlux.harbor.com/gravity/gravity-dispatcher:v0.0.31-20250801

docker images | grep starlux.harbor.com
echo "✅ Worker Node 1 鏡像拉取完成"
```

### 11.3 Worker Node 2 拉取鏡像 (10.10.254.153)
```bash
# 連接到 Worker Node 2
ssh user@10.10.254.153

# 登入 Harbor
docker login starlux.harbor.com

# 拉取鏡像
echo "🚀 Worker Node 2 開始拉取 Gravity 鏡像..."
docker pull starlux.harbor.com/gravity/gravity-adapter-mssql:v3.0.15-20250801
docker pull starlux.harbor.com/gravity/nats-server:v1.3.25-20250801
docker pull starlux.harbor.com/gravity/atomic:v1.0.0-20250801-ubi
docker pull starlux.harbor.com/gravity/gravity-dispatcher:v0.0.31-20250801

docker images | grep starlux.harbor.com
echo "✅ Worker Node 2 鏡像拉取完成"
```

---

# 第五階段：Gitea 和 Gravity 部署

## 步驟 12: 部署 Gitea (10.10.254.151 - Master Node)

### 12.1 創建 Gitea 命名空間
```bash
# 在 Master Node 執行
ssh user@10.10.254.151

kubectl create namespace gitea
```

### 12.2 部署簡單的 Gitea
```bash
# 創建 Gitea 部署文件
cat > gitea-simple.yaml << 'EOF'
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
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gitea
  namespace: gitea
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
        - name: GITEA__database__DB_TYPE
          value: "sqlite3"
        - name: GITEA__database__PATH
          value: "/data/gitea/gitea.db"
        volumeMounts:
        - name: gitea-data
          mountPath: /data
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
      volumes:
      - name: gitea-data
        persistentVolumeClaim:
          claimName: gitea-pvc
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

# 部署 Gitea
kubectl apply -f gitea-simple.yaml

echo "✅ Gitea 部署完成"
echo "訪問地址: http://10.10.254.151:30300"
```

## 步驟 13: 部署 Gravity (10.10.254.151 - Master Node)

### 13.1 創建 Gravity 命名空間
```bash
kubectl create namespace gravity
```

### 13.2 部署 NATS Server
```bash
cat > gravity-nats.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nats-server
  namespace: gravity
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
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
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

kubectl apply -f gravity-nats.yaml
```

### 13.3 部署 Gravity Dispatcher
```bash
cat > gravity-dispatcher.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gravity-dispatcher
  namespace: gravity
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

kubectl apply -f gravity-dispatcher.yaml
```

### 13.4 部署 Atomic
```bash
cat > gravity-atomic.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: atomic
  namespace: gravity
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

kubectl apply -f gravity-atomic.yaml
```

---

# 第六階段：驗證和測試

## 步驟 14: 完整驗證 (10.10.254.151 - Master Node)

### 14.1 檢查所有服務狀態
```bash
echo "🧪 檢查所有服務狀態..."

# 檢查 Gitea
echo "=== Gitea 服務 ==="
kubectl get pods -n gitea
kubectl get services -n gitea

# 檢查 Gravity
echo "=== Gravity 服務 ==="
kubectl get pods -n gravity
kubectl get services -n gravity

# 檢查 Harbor 可訪問性
echo "=== Harbor 連接測試 ==="
curl -k -I https://starlux.harbor.com
```

### 14.2 服務訪問信息
```bash
echo "🎉 所有服務部署完成！"
echo ""
echo "=== 服務訪問資訊 ==="
echo "Harbor:"
echo "- Web UI: https://starlux.harbor.com"
echo "- 登入: admin / Harbor12345"
echo ""
echo "Gitea:"
echo "- Web UI: http://10.10.254.151:30300"
echo "- SSH: ssh://10.10.254.151:30022"
echo ""
echo "Gravity:"
echo "- Dispatcher: http://10.10.254.151:30800"
echo "- NATS Monitor: kubectl port-forward -n gravity svc/nats-service 8222:8222"
echo ""
echo "下一步："
echo "1. 訪問 Gitea 並創建管理員帳號"
echo "2. 配置 Gravity 組件的具體業務邏輯"
echo "3. 根據需要部署 MSSQL Adapter"
```

---

# 完成檢查清單

## ✅ 完整重建檢查清單

### 清理階段
- [ ] Harbor VM 完全清理（容器、鏡像、目錄、套件）
- [ ] Master Node 清理 Harbor 相關配置
- [ ] Worker Node 1 清理 Harbor 相關配置
- [ ] Worker Node 2 清理 Harbor 相關配置

### Harbor 重建階段
- [ ] Harbor VM Docker 重新安裝
- [ ] SSL 憑證重新生成
- [ ] Harbor 重新安裝和配置
- [ ] 防火牆和 DNS 配置
- [ ] Harbor Web UI 可正常訪問

### 節點配置階段
- [ ] Master Node Docker 配置
- [ ] Worker Node 1 Docker 配置
- [ ] Worker Node 2 Docker 配置
- [ ] 所有節點可訪問 Harbor

### 鏡像分發階段
- [ ] Gravity 鏡像拉取到 Harbor VM
- [ ] 所有鏡像推送到 Harbor
- [ ] Master Node 從 Harbor 拉取鏡像
- [ ] Worker Node 1 從 Harbor 拉取鏡像
- [ ] Worker Node 2 從 Harbor 拉取鏡像

### 服務部署階段
- [ ] Gitea 成功部署
- [ ] NATS Server 成功部署
- [ ] Gravity Dispatcher 成功部署
- [ ] Atomic 服務成功部署
- [ ] 所有 Pod 運行正常

## 🎉 重建完成

完成所有步驟後，你將擁有：
1. **全新的 Harbor 環境** - 完全重建，統一使用 Docker
2. **功能正常的 Gravity 組件** - 所有鏡像從 Harbor 拉取
3. **簡單的 Gitea 環境** - 準備好手動創建帳號
4. **完整的測試驗證** - 確保所有組件正常工作

現在可以開始使用這個全新的環境了！