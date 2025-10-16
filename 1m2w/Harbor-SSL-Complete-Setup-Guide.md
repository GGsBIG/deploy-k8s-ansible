# Harbor SSL 憑證安裝完整指南

## 環境資訊
- **Harbor Server**: 10.10.254.155
- **Domain**: starlux.harbor.com
- **Master Node**: 10.10.254.151
- **Worker Nodes**: 10.10.254.152, 10.10.254.153
- **使用 HTTPS**: 443 端口
- **容器運行時**: Containerd + Podman

---

# 第一階段：Harbor VM 建置 (10.10.254.155)

## 步驟 1: 基礎系統準備

### 1.1 連接到 Harbor VM
```bash
ssh user@10.10.254.155
```

### 1.2 系統更新和基礎套件安裝
```bash
# 更新系統
sudo apt update && sudo apt upgrade -y

# 安裝必要套件
sudo apt install -y curl wget vim net-tools openssl ca-certificates \
    apt-transport-https gnupg lsb-release
```

### 1.3 安裝 Docker 和 Docker Compose
```bash
# 移除舊版本
sudo apt remove -y docker docker-engine docker.io containerd runc

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
newgrp docker

# 安裝 Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# 驗證安裝
docker --version
docker-compose --version
```

## 步驟 2: 生成 SSL 憑證

### 2.1 創建憑證工作目錄
```bash
# 創建工作目錄
mkdir -p ~/harbor-cert && cd ~/harbor-cert
```

### 2.2 生成 SSL 憑證
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

echo "憑證生成完成！"
```

### 2.3 配置憑證目錄
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
```

## 步驟 3: 下載和配置 Harbor

### 3.1 下載 Harbor
```bash
# 進入安裝目錄
cd /opt
sudo wget https://github.com/goharbor/harbor/releases/download/v2.9.0/harbor-offline-installer-v2.9.0.tgz

# 解壓縮
sudo tar xzf harbor-offline-installer-v2.9.0.tgz
sudo chown -R $USER:$USER harbor
cd harbor
```

### 3.2 配置 Harbor
```bash
# 複製配置模板
cp harbor.yml.tmpl harbor.yml

# 編輯配置文件
vim harbor.yml
```

**Harbor 配置內容 (harbor.yml):**
```yaml
# 主機名設定
hostname: starlux.harbor.com

# HTTP 配置 (可選，用於重定向到 HTTPS)
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

# 其他配置保持默認
```

### 3.3 安裝 Harbor
```bash
# 執行預安裝腳本
sudo ./prepare

# 安裝 Harbor
sudo ./install.sh

# 等待安裝完成，檢查容器狀態
docker-compose ps
```

## 步驟 4: 配置 Harbor VM 的憑證信任

### 4.1 配置 Containerd 憑證信任
```bash
# 創建 containerd 憑證目錄
sudo mkdir -p /etc/containerd/certs.d/starlux.harbor.com
sudo mkdir -p /etc/containerd/certs.d/10.10.254.155

# 複製 CA 憑證
sudo cp /data/cert/harbor.crt /etc/containerd/certs.d/starlux.harbor.com/ca.crt
sudo cp /data/cert/harbor.crt /etc/containerd/certs.d/10.10.254.155/ca.crt

# 創建域名 hosts.toml 配置
sudo tee /etc/containerd/certs.d/starlux.harbor.com/hosts.toml << 'EOF'
server = "https://starlux.harbor.com"

[host."https://starlux.harbor.com"]
  ca = "/etc/containerd/certs.d/starlux.harbor.com/ca.crt"
EOF

# 創建 IP hosts.toml 配置
sudo tee /etc/containerd/certs.d/10.10.254.155/hosts.toml << 'EOF'
server = "https://10.10.254.155"

[host."https://10.10.254.155"]
  ca = "/etc/containerd/certs.d/10.10.254.155/ca.crt"
EOF
```

### 4.2 配置 Docker/Podman 憑證信任
```bash
# 創建 containers 憑證目錄
sudo mkdir -p /etc/containers/certs.d/starlux.harbor.com
sudo mkdir -p /etc/containers/certs.d/10.10.254.155

# 複製 CA 憑證
sudo cp /data/cert/harbor.crt /etc/containers/certs.d/starlux.harbor.com/ca.crt
sudo cp /data/cert/harbor.crt /etc/containers/certs.d/10.10.254.155/ca.crt

# 設置權限
sudo chmod 644 /etc/containerd/certs.d/*/ca.crt
sudo chmod 644 /etc/containers/certs.d/*/ca.crt
```

### 4.3 安裝和配置 Podman
```bash
# 安裝 Podman
sudo apt update
sudo apt install -y podman

# 驗證 Podman 安裝
podman --version
```

## 步驟 5: 配置防火牆和網絡

### 5.1 配置防火牆
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
```

### 5.2 配置 DNS (hosts 文件)
```bash
# 編輯 hosts 文件
sudo vim /etc/hosts

# 添加以下行
10.10.254.155    starlux.harbor.com
```

---

# 第二階段：所有節點 DNS 配置

## 步驟 6: 配置所有節點的 DNS 解析

在**所有節點** (10.10.254.155, 10.10.254.151, 10.10.254.152, 10.10.254.153) 執行：

```bash
# 編輯 hosts 文件
sudo vim /etc/hosts

# 添加以下行
10.10.254.155    starlux.harbor.com
```

## 步驟 7: 驗證 DNS 解析

在每個節點執行：
```bash
# 測試域名解析
ping -c 3 starlux.harbor.com

# 測試 HTTPS 連接
curl -k -I https://starlux.harbor.com

# 應該返回 Harbor 的 HTTPS 響應
```

---

# 第三階段：分發憑證到所有節點

## 步驟 8: 從 Harbor VM 複製憑證到所有節點

### 8.1 準備憑證文件
```bash
# 在 Harbor VM (10.10.254.155) 上
cd /data/cert/

# 創建憑證分發包
tar czf harbor-certs.tar.gz harbor.crt
```

### 8.2 分發憑證到 Master Node (10.10.254.151)
```bash
# 從 Harbor VM 執行
scp harbor-certs.tar.gz user@10.10.254.151:~/

# 或者手動複製憑證內容
cat /data/cert/harbor.crt
# 複製輸出內容到其他節點
```

### 8.3 分發憑證到 Worker Nodes
```bash
# 分發到 Worker Node 1
scp harbor-certs.tar.gz user@10.10.254.152:~/

# 分發到 Worker Node 2  
scp harbor-certs.tar.gz user@10.10.254.153:~/
```

---

# 第四階段：Master Node 配置 (10.10.254.151)

## 步驟 9: Master Node 憑證配置

### 9.1 連接到 Master Node
```bash
ssh user@10.10.254.151
```

### 9.2 安裝必要套件
```bash
# 更新系統
sudo apt update && sudo apt upgrade -y

# 安裝 containerd 和 podman
sudo apt install -y containerd podman

# 啟動服務
sudo systemctl start containerd
sudo systemctl enable containerd
```

### 9.3 解壓和配置憑證
```bash
# 解壓憑證文件
tar xzf harbor-certs.tar.gz

# 創建 containerd 憑證目錄
sudo mkdir -p /etc/containerd/certs.d/starlux.harbor.com
sudo mkdir -p /etc/containerd/certs.d/10.10.254.155

# 複製 CA 憑證
sudo cp harbor.crt /etc/containerd/certs.d/starlux.harbor.com/ca.crt
sudo cp harbor.crt /etc/containerd/certs.d/10.10.254.155/ca.crt

# 創建域名 hosts.toml 配置
sudo tee /etc/containerd/certs.d/starlux.harbor.com/hosts.toml << 'EOF'
server = "https://starlux.harbor.com"

[host."https://starlux.harbor.com"]
  ca = "/etc/containerd/certs.d/starlux.harbor.com/ca.crt"
EOF

# 創建 IP hosts.toml 配置
sudo tee /etc/containerd/certs.d/10.10.254.155/hosts.toml << 'EOF'
server = "https://10.10.254.155"

[host."https://10.10.254.155"]
  ca = "/etc/containerd/certs.d/10.10.254.155/ca.crt"
EOF
```

### 9.4 配置 Podman 憑證信任
```bash
# 創建 containers 憑證目錄
sudo mkdir -p /etc/containers/certs.d/starlux.harbor.com
sudo mkdir -p /etc/containers/certs.d/10.10.254.155

# 複製 CA 憑證
sudo cp harbor.crt /etc/containers/certs.d/starlux.harbor.com/ca.crt
sudo cp harbor.crt /etc/containers/certs.d/10.10.254.155/ca.crt

# 用戶級別配置
mkdir -p ~/.config/containers/certs.d/starlux.harbor.com
mkdir -p ~/.config/containers/certs.d/10.10.254.155
cp harbor.crt ~/.config/containers/certs.d/starlux.harbor.com/ca.crt
cp harbor.crt ~/.config/containers/certs.d/10.10.254.155/ca.crt

# 設置權限
sudo chmod 644 /etc/containerd/certs.d/*/ca.crt
sudo chmod 644 /etc/containers/certs.d/*/ca.crt
chmod 644 ~/.config/containers/certs.d/*/ca.crt
```

### 9.5 重啟服務
```bash
# 重啟 containerd 服務
sudo systemctl restart containerd

# 驗證服務狀態
sudo systemctl status containerd
```

---

# 第五階段：Worker Node 1 配置 (10.10.254.152)

## 步驟 10: Worker Node 1 憑證配置

### 10.1 連接到 Worker Node 1
```bash
ssh user@10.10.254.152
```

### 10.2 重複 Master Node 的配置步驟
```bash
# 更新系統和安裝套件
sudo apt update && sudo apt upgrade -y
sudo apt install -y containerd podman
sudo systemctl start containerd
sudo systemctl enable containerd

# 解壓憑證
tar xzf harbor-certs.tar.gz

# 配置 containerd 憑證
sudo mkdir -p /etc/containerd/certs.d/starlux.harbor.com
sudo mkdir -p /etc/containerd/certs.d/10.10.254.155
sudo cp harbor.crt /etc/containerd/certs.d/starlux.harbor.com/ca.crt
sudo cp harbor.crt /etc/containerd/certs.d/10.10.254.155/ca.crt

# 創建 hosts.toml 配置
sudo tee /etc/containerd/certs.d/starlux.harbor.com/hosts.toml << 'EOF'
server = "https://starlux.harbor.com"

[host."https://starlux.harbor.com"]
  ca = "/etc/containerd/certs.d/starlux.harbor.com/ca.crt"
EOF

sudo tee /etc/containerd/certs.d/10.10.254.155/hosts.toml << 'EOF'
server = "https://10.10.254.155"

[host."https://10.10.254.155"]
  ca = "/etc/containerd/certs.d/10.10.254.155/ca.crt"
EOF

# 配置 Podman 憑證
sudo mkdir -p /etc/containers/certs.d/starlux.harbor.com
sudo mkdir -p /etc/containers/certs.d/10.10.254.155
sudo cp harbor.crt /etc/containers/certs.d/starlux.harbor.com/ca.crt
sudo cp harbor.crt /etc/containers/certs.d/10.10.254.155/ca.crt

# 用戶級別配置
mkdir -p ~/.config/containers/certs.d/starlux.harbor.com
mkdir -p ~/.config/containers/certs.d/10.10.254.155
cp harbor.crt ~/.config/containers/certs.d/starlux.harbor.com/ca.crt
cp harbor.crt ~/.config/containers/certs.d/10.10.254.155/ca.crt

# 設置權限
sudo chmod 644 /etc/containerd/certs.d/*/ca.crt
sudo chmod 644 /etc/containers/certs.d/*/ca.crt
chmod 644 ~/.config/containers/certs.d/*/ca.crt

# 重啟服務
sudo systemctl restart containerd
```

---

# 第六階段：Worker Node 2 配置 (10.10.254.153)

## 步驟 11: Worker Node 2 憑證配置

### 11.1 連接到 Worker Node 2
```bash
ssh user@10.10.254.153
```

### 11.2 重複相同的配置步驟
```bash
# 更新系統和安裝套件
sudo apt update && sudo apt upgrade -y
sudo apt install -y containerd podman
sudo systemctl start containerd
sudo systemctl enable containerd

# 解壓憑證
tar xzf harbor-certs.tar.gz

# 配置 containerd 憑證
sudo mkdir -p /etc/containerd/certs.d/starlux.harbor.com
sudo mkdir -p /etc/containerd/certs.d/10.10.254.155
sudo cp harbor.crt /etc/containerd/certs.d/starlux.harbor.com/ca.crt
sudo cp harbor.crt /etc/containerd/certs.d/10.10.254.155/ca.crt

# 創建 hosts.toml 配置
sudo tee /etc/containerd/certs.d/starlux.harbor.com/hosts.toml << 'EOF'
server = "https://starlux.harbor.com"

[host."https://starlux.harbor.com"]
  ca = "/etc/containerd/certs.d/starlux.harbor.com/ca.crt"
EOF

sudo tee /etc/containerd/certs.d/10.10.254.155/hosts.toml << 'EOF'
server = "https://10.10.254.155"

[host."https://10.10.254.155"]
  ca = "/etc/containerd/certs.d/10.10.254.155/ca.crt"
EOF

# 配置 Podman 憑證
sudo mkdir -p /etc/containers/certs.d/starlux.harbor.com
sudo mkdir -p /etc/containers/certs.d/10.10.254.155
sudo cp harbor.crt /etc/containers/certs.d/starlux.harbor.com/ca.crt
sudo cp harbor.crt /etc/containers/certs.d/10.10.254.155/ca.crt

# 用戶級別配置
mkdir -p ~/.config/containers/certs.d/starlux.harbor.com
mkdir -p ~/.config/containers/certs.d/10.10.254.155
cp harbor.crt ~/.config/containers/certs.d/starlux.harbor.com/ca.crt
cp harbor.crt ~/.config/containers/certs.d/10.10.254.155/ca.crt

# 設置權限
sudo chmod 644 /etc/containerd/certs.d/*/ca.crt
sudo chmod 644 /etc/containers/certs.d/*/ca.crt
chmod 644 ~/.config/containers/certs.d/*/ca.crt

# 重啟服務
sudo systemctl restart containerd
```

---

# 第七階段：Harbor 項目創建和測試

## 步驟 12: 創建 Harbor 項目

### 12.1 訪問 Harbor Web UI
在瀏覽器中訪問：`https://starlux.harbor.com`

### 12.2 登入 Harbor
- 用戶名: `admin`
- 密碼: `Harbor12345`

### 12.3 創建項目
1. 點擊 "NEW PROJECT"
2. 項目名稱: `library`
3. 訪問級別: 選擇 "Public"
4. 點擊 "OK" 創建項目

---

# 第八階段：完整測試驗證

## 步驟 13: Harbor VM 測試 (10.10.254.155)

```bash
# 在 Harbor VM 上測試
ssh user@10.10.254.155

# 登入 Harbor (使用域名)
podman login starlux.harbor.com
# 輸入: admin / Harbor12345

# 登入 Harbor (使用 IP)
podman login 10.10.254.155
# 輸入: admin / Harbor12345

# 拉取測試鏡像
podman pull busybox:latest

# 標記並推送鏡像 (域名)
podman tag busybox:latest starlux.harbor.com/library/busybox-harbor:latest
podman push starlux.harbor.com/library/busybox-harbor:latest

# 標記並推送鏡像 (IP)
podman tag busybox:latest 10.10.254.155/library/busybox-ip:latest
podman push 10.10.254.155/library/busybox-ip:latest

echo "Harbor VM 測試成功！"
```

## 步驟 14: Master Node 測試 (10.10.254.151)

```bash
# 連接到 Master Node
ssh user@10.10.254.151

# 登入 Harbor (域名測試)
podman login starlux.harbor.com
# 輸入: admin / Harbor12345

# 拉取 Harbor VM 推送的鏡像
podman pull starlux.harbor.com/library/busybox-harbor:latest

# 推送自己的測試鏡像
podman pull nginx:latest
podman tag nginx:latest starlux.harbor.com/library/nginx-master:latest
podman push starlux.harbor.com/library/nginx-master:latest

# 測試運行容器
podman run --rm starlux.harbor.com/library/busybox-harbor:latest echo "Master Node 測試成功！"

# IP 方式測試
podman login 10.10.254.155
podman pull 10.10.254.155/library/busybox-ip:latest
podman tag nginx:latest 10.10.254.155/library/nginx-master-ip:latest
podman push 10.10.254.155/library/nginx-master-ip:latest

echo "Master Node 所有測試成功！"
```

## 步驟 15: Worker Node 1 測試 (10.10.254.152)

```bash
# 連接到 Worker Node 1
ssh user@10.10.254.152

# 登入 Harbor
podman login starlux.harbor.com

# 拉取其他節點推送的鏡像
podman pull starlux.harbor.com/library/busybox-harbor:latest
podman pull starlux.harbor.com/library/nginx-master:latest

# 推送自己的測試鏡像
podman pull alpine:latest
podman tag alpine:latest starlux.harbor.com/library/alpine-worker1:latest
podman push starlux.harbor.com/library/alpine-worker1:latest

# 運行測試
podman run --rm starlux.harbor.com/library/nginx-master:latest nginx -v

# IP 測試
podman login 10.10.254.155
podman pull 10.10.254.155/library/nginx-master-ip:latest
podman tag alpine:latest 10.10.254.155/library/alpine-worker1-ip:latest
podman push 10.10.254.155/library/alpine-worker1-ip:latest

echo "Worker Node 1 所有測試成功！"
```

## 步驟 16: Worker Node 2 測試 (10.10.254.153)

```bash
# 連接到 Worker Node 2
ssh user@10.10.254.153

# 登入 Harbor
podman login starlux.harbor.com

# 拉取所有節點的鏡像
podman pull starlux.harbor.com/library/busybox-harbor:latest
podman pull starlux.harbor.com/library/nginx-master:latest
podman pull starlux.harbor.com/library/alpine-worker1:latest

# 推送自己的測試鏡像
podman pull ubuntu:latest
podman tag ubuntu:latest starlux.harbor.com/library/ubuntu-worker2:latest
podman push starlux.harbor.com/library/ubuntu-worker2:latest

# 運行測試
podman run --rm starlux.harbor.com/library/alpine-worker1:latest echo "Cross-node pull 測試成功！"

# IP 測試
podman login 10.10.254.155
podman pull 10.10.254.155/library/alpine-worker1-ip:latest
podman tag ubuntu:latest 10.10.254.155/library/ubuntu-worker2-ip:latest
podman push 10.10.254.155/library/ubuntu-worker2-ip:latest

echo "Worker Node 2 所有測試成功！"
```

## 步驟 17: 最終交叉驗證測試

### 17.1 在所有節點驗證所有鏡像
```bash
# 在每個節點執行
for node in 10.10.254.155 10.10.254.151 10.10.254.152 10.10.254.153; do
    echo "測試節點: $node"
    ssh user@$node "podman pull starlux.harbor.com/library/ubuntu-worker2:latest && echo '節點 $node 測試成功'"
done
```

### 17.2 驗證 Harbor Web UI 中的鏡像
訪問 `https://starlux.harbor.com`，在 `library` 項目中應該看到所有推送的鏡像：
- busybox-harbor:latest
- busybox-ip:latest  
- nginx-master:latest
- nginx-master-ip:latest
- alpine-worker1:latest
- alpine-worker1-ip:latest
- ubuntu-worker2:latest
- ubuntu-worker2-ip:latest

---

# 故障排除指南

## 問題 1: SSL 憑證驗證失敗

### 診斷步驟:
```bash
# 檢查憑證有效期
openssl x509 -in /data/cert/harbor.crt -noout -dates

# 檢查憑證 SAN
openssl x509 -in /data/cert/harbor.crt -noout -text | grep -A 10 "Subject Alternative Name"

# 測試 SSL 連接
openssl s_client -connect starlux.harbor.com:443 -verify_return_error
```

### 解決方案:
```bash
# 重新生成憑證 (如果 SAN 不正確)
cd ~/harbor-cert
# 修改 openssl.cnf 文件中的 alt_names 部分
# 重新生成憑證並重新配置
```

## 問題 2: Podman 無法登入 Harbor

### 診斷步驟:
```bash
# 檢查憑證路徑
ls -la /etc/containers/certs.d/starlux.harbor.com/
ls -la ~/.config/containers/certs.d/starlux.harbor.com/

# 檢查憑證內容
openssl x509 -in ~/.config/containers/certs.d/starlux.harbor.com/ca.crt -noout -text

# 測試連接
podman login --get-login starlux.harbor.com
```

### 解決方案:
```bash
# 重新複製憑證
sudo cp /data/cert/harbor.crt /etc/containers/certs.d/starlux.harbor.com/ca.crt
cp /data/cert/harbor.crt ~/.config/containers/certs.d/starlux.harbor.com/ca.crt

# 清除登入快取
rm -rf ~/.config/containers/auth.json
```

## 問題 3: Containerd 無法拉取鏡像

### 診斷步驟:
```bash
# 檢查 containerd 配置
sudo cat /etc/containerd/certs.d/starlux.harbor.com/hosts.toml

# 檢查 containerd 服務
sudo systemctl status containerd
sudo journalctl -u containerd -f
```

### 解決方案:
```bash
# 重啟 containerd 服務
sudo systemctl restart containerd

# 使用 crictl 測試 (如果可用)
sudo crictl pull starlux.harbor.com/library/busybox:latest
```

---

# 維護指南

## 定期維護任務

### 1. 憑證更新 (每年或憑證到期前)
```bash
# 檢查憑證到期時間
openssl x509 -in /data/cert/harbor.crt -noout -dates

# 重新生成憑證 (重複步驟 2.2)
cd ~/harbor-cert
openssl req -x509 -nodes -newkey rsa:4096 \
  -keyout harbor.key \
  -out harbor.crt \
  -days 3650 \
  -config openssl.cnf \
  -extensions v3_req

# 更新憑證並重啟 Harbor
sudo cp harbor.crt harbor.key /data/cert/
cd /opt/harbor
sudo docker-compose restart
```

### 2. Harbor 備份
```bash
# 備份 Harbor 數據
sudo tar czf harbor-backup-$(date +%Y%m%d).tar.gz /data /opt/harbor/harbor.yml

# 備份憑證
sudo tar czf harbor-certs-backup-$(date +%Y%m%d).tar.gz /data/cert/
```

### 3. 系統監控
```bash
# 檢查 Harbor 服務狀態
cd /opt/harbor
sudo docker-compose ps

# 檢查磁盤使用
df -h /data
sudo du -sh /data/*

# 檢查網絡連接
sudo netstat -tlnp | grep :443
```

---

# 成功部署檢查清單

## ✅ 部署完成檢查清單

- [ ] Harbor VM (10.10.254.155) SSL 憑證生成完成
- [ ] Harbor 安裝並配置 HTTPS
- [ ] Harbor Web UI 可通過 https://starlux.harbor.com 訪問
- [ ] 所有節點 DNS 配置完成
- [ ] 所有節點 containerd 憑證配置完成
- [ ] 所有節點 podman 憑證配置完成
- [ ] Harbor VM 測試 push/pull 成功
- [ ] Master Node (10.10.254.151) 測試成功
- [ ] Worker Node 1 (10.10.254.152) 測試成功
- [ ] Worker Node 2 (10.10.254.153) 測試成功
- [ ] 跨節點鏡像拉取測試成功
- [ ] 域名和 IP 兩種方式都測試成功

## 🚀 部署成功標誌

當所有檢查項目都完成時，您的 Harbor SSL 私有鏡像倉庫就已經成功部署完成！

**最終訪問方式:**
- **Web UI**: https://starlux.harbor.com
- **Container Registry**: starlux.harbor.com 或 10.10.254.155
- **管理員登入**: admin / Harbor12345
- **支援 SSL/TLS**: ✅ 是
- **支援域名和 IP 訪問**: ✅ 是

**已完成功能:**
- ✅ 所有節點可通過域名和 IP 訪問 Harbor
- ✅ SSL 憑證驗證正常
- ✅ Podman push/pull 正常
- ✅ Containerd 信任配置正常
- ✅ 跨節點鏡像共享正常

您的 Harbor 私有倉庫現在已經可以投入生產使用！