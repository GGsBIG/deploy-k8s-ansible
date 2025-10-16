# Gitea Helm 簡單部署指南

## 前置準備
```bash
# 在主節點 10.10.254.151 上執行
helm repo add gitea-charts https://dl.gitea.com/charts/
helm repo update
```

## 部署 Gitea
```bash
# 創建 gitea namespace
kubectl create namespace gitea

# 使用 Helm 部署 Gitea
helm install gitea gitea-charts/gitea \
  --namespace gitea \
  --set service.http.type=NodePort \
  --set service.http.nodePort=30000
```

## 驗證部署
```bash
# 檢查 Pod 狀態
kubectl get pods -n gitea

# 檢查 Service
kubectl get svc -n gitea

# 等待 Pod 運行正常後訪問
# 瀏覽器訪問: http://10.10.254.151:30000
```

## 故障排除
```bash
# 如果 Pod 無法啟動，檢查 logs
kubectl logs -n gitea deployment/gitea

# 檢查所有資源
kubectl get all -n gitea
```

完成後即可通過 http://10.10.254.151:30000 訪問 Gitea