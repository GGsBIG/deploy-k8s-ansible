# Prometheus LoadBalancer 問題修復指南

## 問題描述
在安裝 Prometheus 時遇到 LoadBalancer IP (172.21.169.75) 無法訪問的問題，curl 返回 "No route to host" 錯誤。

## 問題分析

### 現象
```bash
systex@hcch-k8s-ms01:~$ curl http://172.21.169.75:9090
curl: (7) Failed to connect to 172.21.169.75 port 9090: No route to host
```

### 檢查結果
```bash
# 檢查 Prometheus 服務 - 只有 ClusterIP 類型
systex@hcch-k8s-ms01:~$ kubectl get svc -n monitoring | grep prometheus
prometheus-kube-prometheus-alertmanager   ClusterIP   10.96.252.26    <none>        9093/TCP,8080/TCP
prometheus-kube-prometheus-operator       ClusterIP   10.96.255.158   <none>        443/TCP
prometheus-kube-prometheus-prometheus     ClusterIP   10.96.4.48      <none>        9090/TCP,8080/TCP
prometheus-kube-state-metrics             ClusterIP   10.96.215.11    <none>        8080/TCP
prometheus-operated                       ClusterIP   None            <none>        9090/TCP
prometheus-prometheus-node-exporter       ClusterIP   10.96.198.126   <none>        9100/TCP
```

### 根本原因
1. **配置錯誤**: 原始的 `prometheus-values.yaml` 中使用了錯誤的配置結構
2. **服務類型**: Prometheus 服務創建為 ClusterIP 而不是 LoadBalancer
3. **IP 未分配**: MetalLB 沒有為 Prometheus 分配 172.21.169.75 IP

## 修復方法

### 方法一：手動創建 LoadBalancer 服務（推薦 - 快速修復）

#### 1. 創建 LoadBalancer 服務
```bash
cat > prometheus-loadbalancer.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: prometheus-external
  namespace: monitoring
  annotations:
    metallb.universe.tf/loadBalancerIPs: "172.21.169.75"
spec:
  type: LoadBalancer
  loadBalancerIP: "172.21.169.75"
  ports:
  - name: web
    port: 9090
    targetPort: 9090
    protocol: TCP
  selector:
    app.kubernetes.io/name: prometheus
    app.kubernetes.io/instance: prometheus-kube-prometheus-prometheus
EOF

kubectl apply -f prometheus-loadbalancer.yaml
```

#### 2. 驗證修復結果
```bash
# 檢查新服務
kubectl get svc -n monitoring prometheus-external

# 等待 IP 分配
kubectl wait --for=condition=ready service/prometheus-external -n monitoring --timeout=60s

# 測試訪問
curl -I http://172.21.169.75:9090
```

#### 預期結果
```bash
systex@hcch-k8s-ms01:~$ kubectl get svc -n monitoring prometheus-external
NAME                  TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)          AGE
prometheus-external   LoadBalancer   10.96.xxx.xxx   172.21.169.75   9090:xxxxx/TCP   30s

systex@hcch-k8s-ms01:~$ curl -I http://172.21.169.75:9090
HTTP/1.1 200 OK
Content-Type: text/html; charset=utf-8
```

### 方法二：重新安裝 Prometheus（完整修復）

#### 1. 卸載現有安裝
```bash
helm uninstall prometheus -n monitoring
```

#### 2. 創建正確的配置文件
```bash
cat > prometheus-values-fixed.yaml << 'EOF'
prometheus:
  prometheusSpec:
    resources:
      requests:
        memory: 1Gi
        cpu: 500m
      limits:
        memory: 2Gi
        cpu: 1000m
    
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: nfs-storage
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 50Gi
    
    retention: 30d
    retentionSize: 45GB
    
    externalUrl: http://172.21.169.75:9090
    
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
    ruleSelectorNilUsesHelmValues: false

  # 正確的服務配置位置
  service:
    type: LoadBalancer
    loadBalancerIP: "172.21.169.75"
    annotations:
      metallb.universe.tf/loadBalancerIPs: "172.21.169.75"
    port: 9090

alertmanager:
  enabled: true
  alertmanagerSpec:
    resources:
      requests:
        memory: 256Mi
        cpu: 100m
      limits:
        memory: 512Mi
        cpu: 200m
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: nfs-storage
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 5Gi

grafana:
  enabled: false

nodeExporter:
  enabled: true

kubeStateMetrics:
  enabled: true

defaultRules:
  create: true

rbac:
  create: true
EOF
```

#### 3. 重新安裝
```bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values prometheus-values-fixed.yaml \
  --version 61.1.1
```

## 配置差異對比

### 原始配置（錯誤）
```yaml
# ❌ 錯誤：server 不是 kube-prometheus-stack 的正確配置項
server:
  service:
    type: LoadBalancer
    loadBalancerIP: "172.21.169.75"
    annotations:
      metallb.universe.tf/loadBalancerIPs: "172.21.169.75"
    port: 9090
```

### 修正配置（正確）
```yaml
# ✅ 正確：prometheus.service 是正確的配置項
prometheus:
  service:
    type: LoadBalancer
    loadBalancerIP: "172.21.169.75"
    annotations:
      metallb.universe.tf/loadBalancerIPs: "172.21.169.75"
    port: 9090
```

## 診斷步驟

如果修復後仍有問題，執行以下診斷：

```bash
# 1. 檢查 Prometheus Pod 狀態
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus

# 2. 檢查 LoadBalancer 服務
kubectl describe svc -n monitoring prometheus-external

# 3. 檢查 MetalLB 事件
kubectl get events -n metallb-system --sort-by='.lastTimestamp' | grep prometheus

# 4. 檢查 Prometheus Pod 日誌
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus -c prometheus --tail=20

# 5. 測試端口連通性
nc -zv 172.21.169.75 9090
```

## 驗證清單

完成修復後，確認以下項目：

- [ ] LoadBalancer 服務已創建：`kubectl get svc -n monitoring prometheus-external`
- [ ] IP 已分配：服務的 EXTERNAL-IP 顯示為 172.21.169.75
- [ ] Prometheus 可訪問：`curl -I http://172.21.169.75:9090` 返回 HTTP 200
- [ ] Web UI 可用：瀏覽器訪問 http://172.21.169.75:9090
- [ ] Nginx Ingress 可用：`curl -H "Host: prometheus.172.21.169.73.nip.io" http://172.21.169.73`

## 後續步驟

1. **測試 Prometheus 功能**：
   - 訪問 http://172.21.169.75:9090
   - 檢查 Status > Targets 頁面確認監控目標
   - 執行簡單查詢，例如 `up`

2. **更新文檔**：
   - 將正確的配置更新到 `complete-services-installation-guide.md`
   - 確保未來安裝使用正確的配置

3. **準備下一步**：
   - Prometheus 正常運行後，可以繼續安裝 Grafana
   - Grafana 會使用 Prometheus 作為數據源

## 經驗教訓

1. **Chart 配置差異**：不同的 Helm Chart 有不同的配置結構，需要參考官方文檔
2. **服務發現**：kube-prometheus-stack 使用 Prometheus Operator，配置方式與普通 Prometheus Chart 不同
3. **快速修復**：當 Helm values 配置有問題時，手動創建所需資源是快速解決方案
4. **驗證重要性**：每個步驟完成後都應該驗證結果，及早發現問題

## 相關文件
- `prometheus-loadbalancer.yaml` - LoadBalancer 服務配置
- `prometheus-values-fixed.yaml` - 修正後的 Helm values
- `prometheus-ingress.yaml` - Nginx Ingress 配置
- `metallb-prometheus-config.yaml` - MetalLB IP 池配置