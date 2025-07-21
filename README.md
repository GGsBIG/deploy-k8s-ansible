# Kubernetes Cluster Deployment

自動化部署 Kubernetes 高可用叢集的 Ansible 腳本

## 叢集架構

- **VIP**: 10.10.7.236 (kube-vip)
- **Master Nodes**: 
  - master-01: 10.10.7.230
  - master-02: 10.10.7.231  
  - master-03: 10.10.7.232
- **Worker Nodes**:
  - worker-01: 10.10.7.233
  - worker-02: 10.10.7.234

## 部署階段

### Stage 1: 系統設定 (01-system-setup.yml)
- 設定台灣時區
- 安裝與設定 chrony 時間同步
- 關閉 swap
- 載入 kernel 模組
- 設定 sysctl 參數

### Stage 2: 容器運行時 (02-container-runtime.yml)
- 安裝 containerd
- 安裝 runc
- 安裝 CNI plugins
- 設定 containerd 與 crictl

### Stage 3: Kubernetes 安裝 (03-kubernetes-install.yml)
- 新增 Kubernetes APT repository
- 安裝 kubelet, kubeadm, kubectl
- 鎖定套件版本

### Stage 4: Kube-VIP 設定 (04-kube-vip-setup.yml)
- 設定 kube-vip manifest
- 準備高可用性 API Server

### Stage 5: 叢集初始化 (05-cluster-init.yml)
- 使用 kubeadm 初始化第一個 master
- 產生 join token
- 設定 kubeconfig

### Stage 6: 網路設定 (06-network-setup.yml)
- 部署 Calico CNI
- 等待網路組件就緒

### Stage 7: 加入 Master 節點 (07-join-masters.yml)
- 其他 master 節點加入叢集
- 設定各節點的 kubeconfig

### Stage 8: 加入 Worker 節點 (08-join-workers.yml)
- Worker 節點加入叢集
- 驗證節點狀態

### Stage 9: 完成設定 (09-finalize-cluster.yml)
- 為 worker 節點加上標籤
- 檢查叢集狀態
- 產生叢集資訊

## 使用方式

### 完整部署
```bash
./deploy.sh
# 或
./deploy.sh --full
```

### 執行特定階段
```bash
./deploy.sh --stage 1    # 執行第 1 階段
./deploy.sh --stage 5    # 執行第 5 階段
```

### 使用 site.yml 一次執行所有階段
```bash
./deploy.sh --site
```

### 列出所有階段
```bash
./deploy.sh --list
```

### 顯示說明
```bash
./deploy.sh --help
```

## 檔案結構

```
├── inventory.ini              # Ansible 主機清單
├── site.yml                   # 主要編排 playbook
├── deploy.sh                  # 部署腳本
├── templates/
│   └── init-config.yaml.j2    # kubeadm 設定範本
└── playbooks/
    ├── 01-system-setup.yml
    ├── 02-container-runtime.yml
    ├── 03-kubernetes-install.yml
    ├── 04-kube-vip-setup.yml
    ├── 05-cluster-init.yml
    ├── 06-network-setup.yml
    ├── 07-join-masters.yml
    ├── 08-join-workers.yml
    └── 09-finalize-cluster.yml
```

## 前置需求

1. **Ansible 安裝**
   - macOS: `brew install ansible`
   - Linux: `sudo apt install ansible`

2. **SSH 連線**
   - 確保能以 root 身份 SSH 連線到所有節點
   - 或設定 sudo 免密碼

3. **系統需求**
   - Ubuntu 20.04/22.04
   - 最少 2GB RAM
   - 最少 2 CPU cores

## 部署後操作

1. **取得 kubeconfig**
   ```bash
   scp root@10.10.7.230:/etc/kubernetes/admin.conf ~/.kube/config
   ```

2. **驗證叢集**
   ```bash
   kubectl get nodes
   kubectl get pods -A
   ```

3. **安裝額外組件**
   - Ingress Controller
   - Storage Classes
   - Monitoring (Prometheus/Grafana)
   - Logging (ELK Stack)

## 故障排除

- 檢查特定階段的日誌
- 重新執行失敗的階段
- 驗證網路連線與 SSH 權限
- 確認系統資源充足

## 版本資訊

- Kubernetes: 1.32.4
- Containerd: 1.7.27
- Calico: 3.29.4
- kube-vip: 最新版本