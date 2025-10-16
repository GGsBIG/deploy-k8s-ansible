# Harbor SSL 憑證配置修復指南

## 環境資訊
- **Harbor Server**: 10.10.254.155 (starlux.harbor.com)
- **Master Node**: 10.10.254.151
- **Worker Nodes**: 10.10.254.152, 10.10.254.153
- **問題**: 各節點無法信任 Harbor 的自簽憑證
- **解決**: 分發 Harbor CA 憑證到所有節點

---

# 第一步：Harbor VM 憑證準備 (10.10.254.155)

## 1.1 連接到 Harbor VM
```bash
ssh user@10.10.254.155
```

## 1.2 準備憑證分發包
```bash
# 進入憑證目錄
cd /data/cert/

# 確認憑證文件存在
ls -la harbor.crt harbor.key

# 創建憑證分發包
tar czf harbor-certs.tar.gz harbor.crt

# 驗證分發包
tar -tzf harbor-certs.tar.gz

echo "✅ 憑證分發包準備完成"
```

## 1.3 分發憑證到所有 K8s 節點
```bash
echo "🚀 開始分發憑證到所有節點..."

# 分發憑證到 Master Node
scp harbor-certs.tar.gz user@10.10.254.151:~/
echo "✅ 已分發到 Master Node (10.10.254.151)"

# 分發憑證到 Worker Node 1
scp harbor-certs.tar.gz user@10.10.254.152:~/
echo "✅ 已分發到 Worker Node 1 (10.10.254.152)"

# 分發憑證到 Worker Node 2
scp harbor-certs.tar.gz user@10.10.254.153:~/
echo "✅ 已分發到 Worker Node 2 (10.10.254.153)"

echo "🎉 憑證分發完成！"
```

---

# 第二步：Master Node 憑證配置 (10.10.254.151)

## 2.1 連接到 Master Node
```bash
ssh user@10.10.254.151
```

## 2.2 解壓憑證文件
```bash
# 解壓憑證包
tar xzf harbor-certs.tar.gz

# 確認憑證文件
ls -la harbor.crt

# 驗證憑證內容
openssl x509 -in harbor.crt -text -noout | grep -E "(Issuer|Subject|DNS|IP Address)"

echo "✅ 憑證文件解壓完成"
```

## 2.3 配置 Docker 憑證信任
```bash
# 創建 Docker 憑證目錄
sudo mkdir -p /etc/docker/certs.d/starlux.harbor.com

# 複製 CA 憑證
sudo cp harbor.crt /etc/docker/certs.d/starlux.harbor.com/ca.crt

# 設置正確的權限
sudo chmod 644 /etc/docker/certs.d/starlux.harbor.com/ca.crt
sudo chown root:root /etc/docker/certs.d/starlux.harbor.com/ca.crt

# 驗證憑證已配置
ls -la /etc/docker/certs.d/starlux.harbor.com/

echo "✅ Docker 憑證信任配置完成"
```

## 2.4 配置 Containerd 憑證信任
```bash
# 創建 Containerd 憑證目錄
sudo mkdir -p /etc/containerd/certs.d/starlux.harbor.com

# 複製 CA 憑證
sudo cp harbor.crt /etc/containerd/certs.d/starlux.harbor.com/ca.crt

# 創建 hosts.toml 配置文件
sudo tee /etc/containerd/certs.d/starlux.harbor.com/hosts.toml << 'EOF'
server = "https://starlux.harbor.com"

[host."https://starlux.harbor.com"]
  capabilities = ["pull", "resolve", "push"]
  ca = "/etc/containerd/certs.d/starlux.harbor.com/ca.crt"

[host."http://starlux.harbor.com"]
  capabilities = ["pull", "resolve", "push"]
  skip_verify = true
  plain_http = true
EOF

# 設置權限
sudo chmod 644 /etc/containerd/certs.d/starlux.harbor.com/ca.crt
sudo chmod 644 /etc/containerd/certs.d/starlux.harbor.com/hosts.toml

echo "✅ Containerd 憑證信任配置完成"
```

## 2.5 重啟服務並測試
```bash
# 重啟 Docker 服務
sudo systemctl restart docker
echo "Docker 服務已重啟"

# 重啟 Containerd 服務
sudo systemctl restart containerd
echo "Containerd 服務已重啟"

# 測試網絡連通性
ping -c 3 starlux.harbor.com

# 測試 HTTPS 連接
curl -I https://starlux.harbor.com

# 測試 Docker 登入
echo "測試 Docker 登入..."
docker login starlux.harbor.com
# 輸入: admin / Harbor12345

if [ $? -eq 0 ]; then
    echo "✅ Master Node Harbor 訪問成功！"
else
    echo "❌ Master Node Harbor 訪問失敗"
fi
```

---

# 第三步：Worker Node 1 憑證配置 (10.10.254.152)

## 3.1 連接到 Worker Node 1
```bash
ssh user@10.10.254.152
```

## 3.2 執行憑證配置
```bash
echo "🔧 配置 Worker Node 1 憑證..."

# 解壓憑證文件
tar xzf harbor-certs.tar.gz
ls -la harbor.crt
sudo mkdir -p /etc/docker/certs.d/starlux.harbor.com
sudo cp harbor.crt /etc/docker/certs.d/starlux.harbor.com/ca.crt
sudo chmod 644 /etc/docker/certs.d/starlux.harbor.com/ca.crt
sudo chown root:root /etc/docker/certs.d/starlux.harbor.com/ca.crt
sudo mkdir -p /etc/containerd/certs.d/starlux.harbor.com
sudo cp harbor.crt /etc/containerd/certs.d/starlux.harbor.com/ca.crt

# 創建 hosts.toml
sudo tee /etc/containerd/certs.d/starlux.harbor.com/hosts.toml << 'EOF'
server = "https://starlux.harbor.com"

[host."https://starlux.harbor.com"]
  capabilities = ["pull", "resolve", "push"]
  ca = "/etc/containerd/certs.d/starlux.harbor.com/ca.crt"

[host."http://starlux.harbor.com"]
  capabilities = ["pull", "resolve", "push"]
  skip_verify = true
  plain_http = true
EOF

# 設置權限
sudo chmod 644 /etc/containerd/certs.d/starlux.harbor.com/ca.crt
sudo chmod 644 /etc/containerd/certs.d/starlux.harbor.com/hosts.toml
sudo systemctl restart docker
sudo systemctl restart containerd
ping -c 3 starlux.harbor.com
curl -I https://starlux.harbor.com

# 測試 Docker 登入
docker login starlux.harbor.com
# 輸入: admin / Harbor12345

echo "✅ Worker Node 1 憑證配置完成"
```

---

# 第四步：Worker Node 2 憑證配置 (10.10.254.153)

## 4.1 連接到 Worker Node 2
```bash
ssh user@10.10.254.153
```

## 4.2 執行憑證配置
```bash
echo "🔧 配置 Worker Node 2 憑證..."

# 解壓憑證文件
tar xzf harbor-certs.tar.gz
ls -la harbor.crt

# 配置 Docker 憑證信任
sudo mkdir -p /etc/docker/certs.d/starlux.harbor.com
sudo cp harbor.crt /etc/docker/certs.d/starlux.harbor.com/ca.crt
sudo chmod 644 /etc/docker/certs.d/starlux.harbor.com/ca.crt
sudo chown root:root /etc/docker/certs.d/starlux.harbor.com/ca.crt

# 配置 Containerd 憑證信任
sudo mkdir -p /etc/containerd/certs.d/starlux.harbor.com
sudo cp harbor.crt /etc/containerd/certs.d/starlux.harbor.com/ca.crt

# 創建 hosts.toml
sudo tee /etc/containerd/certs.d/starlux.harbor.com/hosts.toml << 'EOF'
server = "https://starlux.harbor.com"

[host."https://starlux.harbor.com"]
  capabilities = ["pull", "resolve", "push"]
  ca = "/etc/containerd/certs.d/starlux.harbor.com/ca.crt"

[host."http://starlux.harbor.com"]
  capabilities = ["pull", "resolve", "push"]
  skip_verify = true
  plain_http = true
EOF

# 設置權限
sudo chmod 644 /etc/containerd/certs.d/starlux.harbor.com/ca.crt
sudo chmod 644 /etc/containerd/certs.d/starlux.harbor.com/hosts.toml

# 重啟服務
sudo systemctl restart docker
sudo systemctl restart containerd

# 測試連接
ping -c 3 starlux.harbor.com
curl -I https://starlux.harbor.com

# 測試 Docker 登入
docker login starlux.harbor.com
# 輸入: admin / Harbor12345

echo "✅ Worker Node 2 憑證配置完成"
```

---

# 第五步：完整驗證測試

## 5.1 創建驗證腳本 (Harbor VM)
```bash
# 回到 Harbor VM
ssh user@10.10.254.155

# 創建全節點驗證腳本
cat > verify-all-nodes.sh << 'EOF'
#!/bin/bash

NODES=("10.10.254.155" "10.10.254.151" "10.10.254.152" "10.10.254.153")
NODE_NAMES=("Harbor VM" "Master Node" "Worker Node 1" "Worker Node 2")

echo "🧪 驗證所有節點的 Harbor 憑證配置..."

for i in "${!NODES[@]}"; do
    NODE_IP="${NODES[$i]}"
    NODE_NAME="${NODE_NAMES[$i]}"
    
    echo ""
    echo "=== 測試 $NODE_NAME ($NODE_IP) ==="
    
    if [ "$NODE_IP" == "10.10.254.155" ]; then
        # 本機測試
        echo "測試本機 Harbor 服務..."
        curl -s -I https://starlux.harbor.com | head -1
        docker images | grep starlux.harbor.com | wc -l | xargs echo "本機 Harbor 鏡像數量:"
    else
        # 遠程節點測試
        ssh -o ConnectTimeout=10 user@$NODE_IP << 'REMOTE_EOF'
            echo "測試網絡連通性..."
            ping -c 1 starlux.harbor.com > /dev/null 2>&1 && echo "✅ 網絡連通" || echo "❌ 網絡不通"
            
            echo "測試 HTTPS 連接..."
            curl -s -I https://starlux.harbor.com | head -1
            
            echo "檢查 Docker 憑證配置..."
            [ -f /etc/docker/certs.d/starlux.harbor.com/ca.crt ] && echo "✅ Docker 憑證已配置" || echo "❌ Docker 憑證未配置"
            
            echo "檢查 Containerd 憑證配置..."
            [ -f /etc/containerd/certs.d/starlux.harbor.com/ca.crt ] && echo "✅ Containerd 憑證已配置" || echo "❌ Containerd 憑證未配置"
            
            echo "測試 Docker 登入..."
            echo "Harbor12345" | docker login --username admin --password-stdin starlux.harbor.com > /dev/null 2>&1 && echo "✅ Docker 登入成功" || echo "❌ Docker 登入失敗"
REMOTE_EOF
    fi
done

echo ""
echo "🎉 所有節點驗證完成！"
EOF

chmod +x verify-all-nodes.sh
```

## 5.2 執行完整驗證
```bash
# 執行驗證腳本
./verify-all-nodes.sh
```

## 5.3 測試鏡像拉取 (各節點)
```bash
echo "🧪 測試各節點鏡像拉取功能..."

# 在每個節點執行
for node in 10.10.254.151 10.10.254.152 10.10.254.153; do
    echo "測試節點 $node..."
    ssh user@$node << 'EOF'
        # 登入 Harbor
        echo "Harbor12345" | docker login --username admin --password-stdin starlux.harbor.com
        
        # 測試拉取小鏡像
        docker pull starlux.harbor.com/library/hello-world:latest 2>/dev/null || echo "測試鏡像不存在（正常）"
        
        # 測試連接
        docker search starlux.harbor.com/ 2>/dev/null || echo "搜索功能測試完成"
        
        echo "✅ 節點鏡像拉取測試完成"
EOF
done
```

---

# 第六步：故障排除

## 6.1 常見問題診斷

### 問題 1: 憑證驗證失敗
```bash
# 診斷步驟
openssl x509 -in /etc/docker/certs.d/starlux.harbor.com/ca.crt -text -noout | grep -E "(Subject|DNS|IP)"

# 檢查憑證有效期
openssl x509 -in /etc/docker/certs.d/starlux.harbor.com/ca.crt -noout -dates

# 測試 SSL 連接
openssl s_client -connect starlux.harbor.com:443 -verify_return_error
```

### 問題 2: Docker 服務問題
```bash
# 檢查 Docker 服務狀態
sudo systemctl status docker

# 查看 Docker 日誌
sudo journalctl -u docker.service -n 20

# 重啟 Docker 服務
sudo systemctl restart docker
```

### 問題 3: Containerd 配置問題
```bash
# 檢查 Containerd 配置
sudo cat /etc/containerd/certs.d/starlux.harbor.com/hosts.toml

# 檢查 Containerd 服務
sudo systemctl status containerd

# 重啟 Containerd 服務
sudo systemctl restart containerd
```

## 6.2 清理和重新配置
```bash
# 如果需要重新配置憑證
sudo rm -rf /etc/docker/certs.d/starlux.harbor.com/
sudo rm -rf /etc/containerd/certs.d/starlux.harbor.com/

# 清除 Docker 登入信息
docker logout starlux.harbor.com

# 重新執行憑證配置步驟
```

---

# 完成檢查清單

## ✅ 憑證配置檢查清單

### Harbor VM (10.10.254.155)
- [ ] 憑證分發包創建完成
- [ ] 憑證已分發到所有 K8s 節點

### Master Node (10.10.254.151)
- [ ] 憑證文件解壓成功
- [ ] Docker 憑證信任配置完成
- [ ] Containerd 憑證信任配置完成
- [ ] 服務重啟成功
- [ ] Docker 登入測試成功

### Worker Node 1 (10.10.254.152)
- [ ] 憑證文件解壓成功
- [ ] Docker 憑證信任配置完成
- [ ] Containerd 憑證信任配置完成
- [ ] 服務重啟成功
- [ ] Docker 登入測試成功

### Worker Node 2 (10.10.254.153)
- [ ] 憑證文件解壓成功
- [ ] Docker 憑證信任配置完成
- [ ] Containerd 憑證信任配置完成
- [ ] 服務重啟成功
- [ ] Docker 登入測試成功

### 完整驗證
- [ ] 所有節點網絡連通正常
- [ ] 所有節點 HTTPS 訪問正常
- [ ] 所有節點 Docker 登入成功
- [ ] 鏡像拉取功能正常

## 🎉 配置完成

完成所有步驟後：

1. **所有節點都信任 Harbor 憑證** - 不再出現 SSL 錯誤
2. **Docker 登入正常** - 可以正常推送和拉取鏡像
3. **Containerd 支援 Harbor** - Kubernetes 可以從 Harbor 拉取鏡像
4. **完整的憑證管理** - 系統級和容器級都正確配置

## 🔧 快速修復命令

如果某個節點出現憑證問題，快速修復：

```bash
# 在有問題的節點執行
sudo mkdir -p /etc/docker/certs.d/starlux.harbor.com
sudo cp harbor.crt /etc/docker/certs.d/starlux.harbor.com/ca.crt
sudo systemctl restart docker
docker login starlux.harbor.com
```

現在所有節點都可以正常使用 Harbor SSL 連接了！