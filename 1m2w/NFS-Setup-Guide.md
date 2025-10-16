# NFS Storage 完整建置指南

使用 nfs-subdir-external-provisioner 為 Kubernetes 集群建置 NFS 動態存儲

## 環境資訊

- **Master 節點**: 10.10.254.151
- **Worker 節點**: 10.10.254.152, 10.10.254.153
- **SSH 用戶**: user
- **密碼**: 1qaz@WSX
- **NFS 共享目錄**: /mnt/nfs_share

## 建置步驟

### 步驟 1: 在 Master 節點建立 NFS 服務器

```bash
# SSH 到 Master 節點
ssh user@10.10.254.151

# 安裝 NFS 服務器
sudo apt update
sudo apt install -y nfs-kernel-server

# 建立 NFS 共享目錄
sudo mkdir -p /mnt/nfs_share
sudo chown nobody:nogroup /mnt/nfs_share
sudo chmod 777 /mnt/nfs_share

# 配置 NFS 導出
echo '/mnt/nfs_share 10.10.254.0/24(rw,sync,no_subtree_check,no_root_squash)' | sudo tee -a /etc/exports

# 套用 NFS 配置
sudo exportfs -ra
sudo systemctl enable nfs-kernel-server
sudo systemctl restart nfs-kernel-server

# 檢查 NFS 服務狀態
sudo systemctl status nfs-kernel-server
sudo exportfs -v
```

### 步驟 2: 在所有節點安裝 NFS 客戶端

```bash
# 在 Master 節點
sudo apt install -y nfs-common

# 在 Worker 節點 1
ssh user@10.10.254.152 "sudo apt update && sudo apt install -y nfs-common"

# 在 Worker 節點 2
ssh user@10.10.254.153 "sudo apt update && sudo apt install -y nfs-common"
```

### 步驟 3: 測試 NFS 掛載（可選，但建議）

```bash
# 在 Worker 節點測試掛載
ssh user@10.10.254.152 "
sudo mkdir -p /mnt/test
sudo mount -t nfs 10.10.254.151:/mnt/nfs_share /mnt/test
echo 'test file' | sudo tee /mnt/test/test.txt
ls -la /mnt/test/
sudo umount /mnt/test
sudo rmdir /mnt/test
"

# 在 Master 確認檔案存在
ssh user@10.10.254.151 "ls -la /mnt/nfs_share/"
```

### 步驟 4: 添加 Helm Repository

```bash
# 在 Master 節點執行
ssh user@10.10.254.151

# 添加 nfs-subdir-external-provisioner helm repo
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm repo update
```

### 步驟 5: 建立 NFS namespace

```bash
kubectl create namespace nfs
```

### 步驟 6: 安裝 NFS Provisioner

```bash
helm install nfs-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --namespace=nfs \
  --set nfs.server=10.10.254.151 \
  --set nfs.path=/mnt/nfs_share \
  --set storageClass.name=nfs-storage \
  --set storageClass.defaultClass=true
```

### 步驟 7: 驗證安裝

```bash
# 檢查 Pod 狀態
kubectl get pods -n nfs

# 檢查 StorageClass
kubectl get storageclass

# 等待 Pod 啟動完成
kubectl wait --for=condition=Ready pod -l app=nfs-subdir-external-provisioner -n nfs --timeout=120s
```

### 步驟 8: 測試 NFS Storage

```bash
# 建立測試 PVC
kubectl apply -f - << 'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-nfs-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: nfs-storage
  resources:
    requests:
      storage: 1Gi
EOF

# 建立測試 Pod
kubectl apply -f - << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: test-nfs-pod
spec:
  containers:
  - name: test-container
    image: busybox
    command: ['sleep', '3600']
    volumeMounts:
    - name: nfs-storage
      mountPath: /data
  volumes:
  - name: nfs-storage
    persistentVolumeClaim:
      claimName: test-nfs-pvc
EOF
```

### 步驟 9: 驗證 NFS 功能

```bash
# 等待 Pod 啟動
kubectl wait --for=condition=Ready pod/test-nfs-pod --timeout=60s

# 在 Pod 中寫入檔案
kubectl exec test-nfs-pod -- sh -c "echo 'Hello NFS Storage' > /data/test.txt"

# 讀取檔案
kubectl exec test-nfs-pod -- cat /data/test.txt

# 在 Master 節點確認檔案存在
ssh user@10.10.254.151 "find /mnt/nfs_share -name 'test.txt' -exec cat {} \;"
```

### 步驟 10: 清理測試資源（可選）

```bash
kubectl delete pod test-nfs-pod
kubectl delete pvc test-nfs-pvc
```

## 使用範例

### 建立 PVC

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-app-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: nfs-storage
  resources:
    requests:
      storage: 5Gi
```

### 在 Pod 中使用 PVC

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: data
      mountPath: /usr/share/nginx/html
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: my-app-pvc
```

## 驗證命令

### 檢查 NFS 服務狀態
```bash
# 在 Master 節點檢查 NFS 服務
ssh user@10.10.254.151 "
sudo systemctl status nfs-kernel-server
sudo exportfs -v
df -h /mnt/nfs_share
"
```

### 檢查 Kubernetes StorageClass
```bash
kubectl get storageclass
kubectl get pods -n nfs
kubectl describe storageclass nfs-storage
```

### 檢查 PVC 和 PV
```bash
kubectl get pvc
kubectl get pv
```

## 疑難排解

### NFS 服務無法啟動
```bash
# 檢查 NFS 服務日誌
sudo journalctl -u nfs-kernel-server

# 檢查防火牆設定
sudo ufw status
sudo ufw allow from 10.10.254.0/24 to any port nfs
```

### Pod 無法掛載 NFS
```bash
# 檢查 NFS Provisioner 日誌
kubectl logs -n nfs deployment/nfs-provisioner-nfs-subdir-external-provisioner

# 檢查節點是否可以掛載 NFS
ssh user@10.10.254.152 "showmount -e 10.10.254.151"
```

### PVC 卡在 Pending 狀態
```bash
# 檢查 PVC 詳細資訊
kubectl describe pvc <pvc-name>

# 檢查 StorageClass
kubectl describe storageclass nfs-storage
```

## 重要注意事項

1. **權限設定**: NFS 目錄權限設為 777 以避免權限問題
2. **網路安全**: NFS 僅允許內部網路存取 (10.10.254.0/24)
3. **備份**: 定期備份 /mnt/nfs_share 目錄
4. **監控**: 定期檢查 NFS 服務和磁碟空間使用量
5. **效能**: NFS 適合小到中等規模的應用，大規模應用建議使用其他存儲方案

## 版本資訊

- **NFS Server**: nfs-kernel-server (Ubuntu package)
- **NFS Provisioner**: nfs-subdir-external-provisioner (latest)
- **Kubernetes**: v1.32.4
- **Helm**: v3.x