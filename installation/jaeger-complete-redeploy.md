# Jaeger 完整重新部署指南

## 🧹 第一步：完整清理現有資源

```bash
echo "=== 開始完整清理 Jaeger 相關資源 ==="

# 1. 刪除 Jaeger 實例
kubectl delete jaeger --all -n observability

# 2. 刪除 Elasticsearch
helm uninstall elasticsearch-jaeger -n observability

# 3. 等待資源清理
echo "等待資源清理..."
sleep 30

# 4. 強制刪除殘留的 Pod（如果有）
kubectl delete pods --all -n observability --force --grace-period=0 || true

# 5. 清理 PVC（如果有）
kubectl delete pvc --all -n observability || true

# 6. 檢查是否還有殘留資源
kubectl get all -n observability

echo "=== 清理完成 ==="
```

## 🚀 第二步：使用內存存儲重新部署（推薦）

### 2.1 創建簡化的 Jaeger 實例

```bash
echo "=== 開始部署內存存儲版本的 Jaeger ==="

cat > jaeger-memory-production.yaml << 'EOF'
apiVersion: jaegertracing.io/v1
kind: Jaeger
metadata:
  name: jaeger-production
  namespace: observability
spec:
  strategy: allInOne
  allInOne:
    image: jaegertracing/all-in-one:1.57
    resources:
      requests:
        cpu: 300m
        memory: 512Mi
      limits:
        cpu: 1000m
        memory: 1Gi
    options:
      memory:
        max-traces: 100000
      query:
        base-path: /
      collector:
        zipkin:
          host-port: ":9411"
  storage:
    type: memory
EOF

kubectl apply -f jaeger-memory-production.yaml
```

### 2.2 等待 Jaeger Pod 啟動

```bash
echo "等待 Jaeger Pod 啟動..."
kubectl wait --for=condition=ready pod -l app=jaeger -n observability --timeout=120s

echo "檢查 Pod 狀態："
kubectl get pods -n observability

echo "檢查服務："
kubectl get svc -n observability
```

### 2.3 創建 LoadBalancer 服務

```bash
cat > jaeger-loadbalancer-service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: jaeger-external
  namespace: observability
  annotations:
    metallb.universe.tf/loadBalancerIPs: "172.21.169.82"
spec:
  type: LoadBalancer
  loadBalancerIP: "172.21.169.82"
  ports:
  - name: query-http
    port: 16686
    targetPort: 16686
    protocol: TCP
  - name: collector-grpc
    port: 14250
    targetPort: 14250
    protocol: TCP
  - name: collector-http
    port: 14268
    targetPort: 14268
    protocol: TCP
  - name: zipkin
    port: 9411
    targetPort: 9411
    protocol: TCP
  - name: admin
    port: 14269
    targetPort: 14269
    protocol: TCP
  selector:
    app: jaeger
    app.kubernetes.io/component: all-in-one
    app.kubernetes.io/instance: jaeger-production
EOF

kubectl apply -f jaeger-loadbalancer-service.yaml
```

### 2.4 等待 LoadBalancer IP 分配

```bash
echo "等待 LoadBalancer IP 分配..."
kubectl wait --for=jsonpath='{.status.loadBalancer.ingress[0].ip}' service/jaeger-external -n observability --timeout=60s

echo "檢查 LoadBalancer 狀態："
kubectl get svc jaeger-external -n observability
```

## ✅ 第三步：驗證部署

### 3.1 檢查所有資源狀態

```bash
echo "=== 驗證 Jaeger 部署狀態 ==="

echo "1. Pod 狀態："
kubectl get pods -n observability

echo "2. 服務狀態："
kubectl get svc -n observability

echo "3. LoadBalancer IP："
kubectl get svc jaeger-external -n observability -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
echo
```

### 3.2 測試連通性

```bash
echo "=== 測試連通性 ==="

echo "測試 Jaeger UI..."
curl -I http://172.21.169.82:16686

echo "測試收集器 HTTP 端點..."
curl -I http://172.21.169.82:14268

echo "測試 Zipkin 端點..."
curl -I http://172.21.169.82:9411

echo "測試管理端點..."
curl -s http://172.21.169.82:14269/metrics | head -5
```

### 3.3 檢查 Jaeger UI

```bash
echo "=== Jaeger UI 訪問信息 ==="
echo "瀏覽器訪問: http://172.21.169.82:16686"
echo "API 端點: http://172.21.169.82:16686/api/services"

# 測試 API
curl -s http://172.21.169.82:16686/api/services | head -10
```

## 🔗 第四步：配置 Istio 整合

### 4.1 更新 Istio 配置

```bash
echo "=== 配置 Istio 與 Jaeger 整合 ==="

cat > istio-jaeger-tracing.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: istio
  namespace: istio-system
data:
  mesh: |
    defaultConfig:
      proxyStatsMatcher:
        inclusionRegexps:
        - ".*outlier_detection.*"
        - ".*circuit_breakers.*"
        - ".*upstream_rq_retry.*"
        - ".*_cx_.*"
      tracing:
        zipkin:
          address: jaeger-production-collector.observability.svc.cluster.local:9411
    defaultProviders:
      tracing:
      - jaeger
    extensionProviders:
    - name: jaeger
      zipkin:
        service: jaeger-production-collector.observability.svc.cluster.local
        port: 9411
EOF

kubectl apply -f istio-jaeger-tracing.yaml
```

### 4.2 重啟 Istio 控制平面

```bash
echo "重啟 Istio 控制平面..."
kubectl rollout restart deployment/istiod -n istio-system

echo "等待 Istio 重啟完成..."
kubectl wait --for=condition=available deployment/istiod -n istio-system --timeout=120s

echo "Istio 重啟完成！"
```

## 🧪 第五步：部署測試應用驗證追蹤

### 5.1 創建測試應用

```bash
echo "=== 部署測試應用 ==="

cat > jaeger-test-apps.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: productpage
  namespace: default
  labels:
    app: productpage
    version: v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: productpage
      version: v1
  template:
    metadata:
      labels:
        app: productpage
        version: v1
    spec:
      containers:
      - name: productpage
        image: nginx:1.21
        ports:
        - containerPort: 80
        env:
        - name: SERVICE_NAME
          value: "productpage"
---
apiVersion: v1
kind: Service
metadata:
  name: productpage
  namespace: default
  labels:
    app: productpage
spec:
  ports:
  - port: 9080
    targetPort: 80
    name: http
  selector:
    app: productpage
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: details
  namespace: default
  labels:
    app: details
    version: v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: details
      version: v1
  template:
    metadata:
      labels:
        app: details
        version: v1
    spec:
      containers:
      - name: details
        image: httpd:2.4
        ports:
        - containerPort: 80
        env:
        - name: SERVICE_NAME
          value: "details"
---
apiVersion: v1
kind: Service
metadata:
  name: details
  namespace: default
  labels:
    app: details
spec:
  ports:
  - port: 9080
    targetPort: 80
    name: http
  selector:
    app: details
EOF

kubectl apply -f jaeger-test-apps.yaml
```

### 5.2 為 default 命名空間啟用 Istio 注入

```bash
echo "為 default 命名空間啟用 Istio sidecar 注入..."
kubectl label namespace default istio-injection=enabled --overwrite

echo "重啟應用以注入 sidecar..."
kubectl rollout restart deployment/productpage -n default
kubectl rollout restart deployment/details -n default

echo "等待應用重啟..."
kubectl wait --for=condition=ready pod -l app=productpage -n default --timeout=60s
kubectl wait --for=condition=ready pod -l app=details -n default --timeout=60s
```

### 5.3 生成測試流量

```bash
echo "=== 生成測試流量 ==="

# 等待 sidecar 就緒
sleep 10

echo "生成測試請求..."
for i in {1..20}; do
  echo "發送請求 $i..."
  kubectl exec -n default deployment/productpage -- curl -s details:9080/ > /dev/null
  sleep 1
done

echo "測試流量生成完成！"
```

### 5.4 檢查追蹤數據

```bash
echo "=== 檢查追蹤數據 ==="

echo "等待追蹤數據傳輸..."
sleep 10

echo "檢查 Jaeger 中的服務："
curl -s http://172.21.169.82:16686/api/services | jq -r '.data[]' 2>/dev/null || curl -s http://172.21.169.82:16686/api/services

echo ""
echo "在瀏覽器中訪問 Jaeger UI："
echo "URL: http://172.21.169.82:16686"
echo "查找服務: productpage, details, istio-proxy"
```

## 🚨 故障排除

### 如果 LoadBalancer IP 未分配

```bash
echo "=== 檢查 MetalLB 狀態 ==="
kubectl get pods -n metallb-system
kubectl logs -n metallb-system deployment/controller --tail=10

echo "=== 檢查 IP 地址池 ==="
kubectl get ipaddresspool jaeger-pool -n metallb-system
kubectl describe ipaddresspool jaeger-pool -n metallb-system
```

### 如果 Pod 無法啟動

```bash
echo "=== 檢查 Pod 詳細狀態 ==="
kubectl describe pod -n observability $(kubectl get pods -n observability -l app=jaeger -o jsonpath='{.items[0].metadata.name}')

echo "=== 檢查 Pod 日誌 ==="
kubectl logs -n observability -l app=jaeger --tail=20
```

### 如果追蹤數據不顯示

```bash
echo "=== 檢查 Istio sidecar 注入 ==="
kubectl get pods -n default -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'

echo "=== 檢查 Istio 配置 ==="
kubectl get configmap istio -n istio-system -o yaml | grep -A 10 -B 5 jaeger
```

## 🧹 清理命令（如果需要重新開始）

```bash
echo "=== 完整清理所有資源 ==="

# 刪除測試應用
kubectl delete -f jaeger-test-apps.yaml || true

# 刪除 Jaeger 資源
kubectl delete jaeger --all -n observability
kubectl delete svc jaeger-external -n observability || true

# 清理配置文件
rm -f jaeger-*.yaml istio-*.yaml

# 移除 Istio 注入標籤
kubectl label namespace default istio-injection-

echo "清理完成！"
```

## 📋 執行總結

### 成功指標：
- ✅ Jaeger Pod 狀態為 `1/1 Running`
- ✅ LoadBalancer 服務分配到 `172.21.169.82`
- ✅ 可以訪問 `http://172.21.169.82:16686`
- ✅ 測試應用產生追蹤數據
- ✅ Jaeger UI 中可以看到服務和追蹤

### 關鍵配置：
- **存儲類型**: 內存存儲（重啟後數據會丟失）
- **部署策略**: allInOne（單一容器包含所有組件）
- **資源配置**: 1 CPU, 1GB 內存
- **端口映射**: 16686 (UI), 14268 (HTTP), 9411 (Zipkin)

### 注意事項：
- 內存存儲適合測試和開發環境
- 生產環境建議使用持久化存儲
- 定期監控資源使用情況
- 可根據負載調整資源限制