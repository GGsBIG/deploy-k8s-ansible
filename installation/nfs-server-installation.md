# NFS Server 安裝紀錄

## 概述
本文檔記錄在 Kubernetes 叢集中安裝 NFS Subdir External Provisioner 的完整步驟。

## 環境資訊
- **Kubernetes 叢集**：hcch-k8s
- **執行節點**：hcch-k8s-ms01
- **NFS 伺服器 IP**：172.21.169.51
- **NFS 共享路徑**：/NFS
- **安裝日期**：2025年7月30日
- **執行用戶**：systex

## 安裝步驟

### 1. 新增 Helm Repository

```bash
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
```

**輸出結果**：
```
"nfs-subdir-external-provisioner" already exists with the same configuration, skipping
```

### 2. 安裝 NFS Subdir External Provisioner

```bash
helm install nfs-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --namespace=nfs \
  --set nfs.server=172.21.169.51 \
  --set nfs.path=/NFS \
  --set storageClass.name=nfs-storage \
  --create-namespace
```

**安裝參數說明**：
- `nfs-provisioner`：Release 名稱
- `--namespace=nfs`：安裝到 nfs 命名空間
- `--set nfs.server=172.21.169.51`：NFS 伺服器的 IP 地址
- `--set nfs.path=/NFS`：NFS 伺服器上的共享路徑
- `--set storageClass.name=nfs-storage`：StorageClass 名稱
- `--create-namespace`：如果命名空間不存在則自動創建

**安裝輸出**：
```
NAME: nfs-provisioner
LAST DEPLOYED: Wed Jul 30 22:27:38 2025
NAMESPACE: nfs
STATUS: deployed
REVISION: 1
TEST SUITE: None
```

### 3. 驗證安裝結果

檢查所有 Pod 狀態：
```bash
kubectl get pods -A
```

**相關 Pod 狀態**：
```
NAMESPACE     NAME                                                              READY   STATUS    RESTARTS   AGE
nfs           nfs-provisioner-nfs-subdir-external-provisioner-796b7bdd6cw4mvw   1/1     Running   0          13s
```

## 安裝後的資源狀態

### Kubernetes 叢集概況
- **Total Pods**：29個（全部運行正常）
- **Master 節點**：3個（hcch-k8s-ms01, hcch-k8s-ms02, hcch-k8s-ms03）
- **Worker 節點**：2個（hcch-k8s-wk01, hcch-k8s-wk02）
- **網路插件**：Calico
- **負載平衡**：kube-vip

### 核心服務狀態
- ✅ etcd：3個實例運行中
- ✅ kube-apiserver：3個實例運行中
- ✅ kube-controller-manager：3個實例運行中
- ✅ kube-scheduler：3個實例運行中
- ✅ kube-proxy：5個實例運行中
- ✅ coredns：2個實例運行中
- ✅ calico-node：5個實例運行中
- ✅ kube-vip：3個實例運行中

## 後續驗證步驟

### 1. 檢查 StorageClass
```bash
kubectl get storageclass
```

預期結果應包含：
```
NAME          PROVISIONER                                     RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
nfs-storage   cluster.local/nfs-provisioner-nfs-subdir-external-provisioner   Delete          Immediate              true                   <age>
```

### 2. 檢查 NFS Provisioner 詳細資訊
```bash
kubectl describe pod -n nfs nfs-provisioner-nfs-subdir-external-provisioner-796b7bdd6cw4mvw
```

### 3. 測試 PVC 創建
```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-nfs-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: nfs-storage
  resources:
    requests:
      storage: 1Gi
EOF
```

### 4. 驗證 PVC 綁定
```bash
kubectl get pvc test-nfs-pvc
kubectl get pv
```

### 5. 清理測試資源
```bash
kubectl delete pvc test-nfs-pvc
```

## 配置文件

### Helm Values 等效 YAML
```yaml
nfs:
  server: 172.21.169.51
  path: /NFS

storageClass:
  name: nfs-storage
  defaultClass: false
  reclaimPolicy: Delete
  archiveOnDelete: true

image:
  repository: registry.k8s.io/sig-storage/nfs-subdir-external-provisioner
  tag: v4.0.2
  pullPolicy: IfNotPresent

replicaCount: 1

resources: {}

nodeSelector: {}

tolerations: []

affinity: {}
```

## 故障排除

### 常見問題

1. **Pod 無法啟動**
   - 檢查 NFS 伺服器是否可訪問：`ping 172.21.169.51`
   - 檢查 NFS 共享是否存在：`showmount -e 172.21.169.51`

2. **PVC 無法綁定**
   - 檢查 StorageClass 是否存在：`kubectl get sc`
   - 檢查 Provisioner Pod 日誌：`kubectl logs -n nfs <pod-name>`

3. **權限問題**
   - 確保 NFS 共享具有適當的讀寫權限
   - 檢查 NFS 伺服器的導出配置

### 重要注意事項

1. **NFS 伺服器依賴**：
   - 必須確保 172.21.169.51 上的 NFS 服務正常運行
   - NFS 共享路徑 `/NFS` 必須存在且具有適當權限

2. **網路要求**：
   - 所有 Kubernetes 節點必須能訪問 NFS 伺服器
   - 防火牆必須允許 NFS 相關端口（通常是 2049）

3. **高可用性**：
   - 目前僅有單一 Provisioner 實例
   - NFS 伺服器本身成為單點故障

## 下一步

✅ **已完成**：NFS Subdir External Provisioner 安裝

🔄 **進行中**：準備安裝 Nginx Ingress Controller（172.21.169.73）

📋 **待完成**：
1. Istio Ingress Gateway (172.21.169.72)
2. Prometheus (172.21.169.75)
3. Grafana (172.21.169.74)
4. 其他服務...

## 備註

- 此安裝使用的是 NFS Subdir External Provisioner，它會在 NFS 共享中為每個 PVC 創建子目錄
- StorageClass 設置為非默認，需要在 PVC 中明確指定 `storageClassName: nfs-storage`
- 所有透過此 Provisioner 創建的 PV 都會在刪除時自動清理對應的 NFS 目錄