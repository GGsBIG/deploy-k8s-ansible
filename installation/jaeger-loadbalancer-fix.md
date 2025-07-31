# Jaeger LoadBalancer 服務修復指南

## 問題診斷

✅ **正常狀態**：
- Jaeger 實例狀態：`Running`
- Jaeger Pod 狀態：`1/1 Running`
- LoadBalancer IP 已分配：`172.21.169.82`

❌ **問題現象**：
- UI 端點 (16686) 無法訪問：`Connection refused`
- 收集器端點 (14268) 無法訪問：`Connection refused`
- 管理端點 (14269) 可以訪問 ✅

**根本原因**：LoadBalancer 服務的選擇器與實際 Pod 標籤不匹配

---

## 修復步驟

### 步驟 1：檢查 Pod 實際標籤

```bash
echo "=== 檢查 Jaeger Pod 的實際標籤 ==="
kubectl get pods -n observability jaeger-production-66c7b4986b-lpn64 --show-labels

echo "=== 檢查 Jaeger 相關的所有 Pod 標籤 ==="
kubectl get pods -n observability -l app=jaeger --show-labels
```

### 步驟 2：檢查自動創建的服務

```bash
echo "=== 檢查 Jaeger Operator 自動創建的服務 ==="
kubectl get svc -n observability | grep jaeger

echo "=== 檢查自動創建服務的詳細信息 ==="
kubectl describe svc -n observability | grep -A 10 -B 5 jaeger
```

### 步驟 3：修復 LoadBalancer 服務選擇器

根據實際情況選擇以下方案之一：


#### 方案 B：重新創建正確的 LoadBalancer 服務

```bash
echo "=== 刪除現有的 LoadBalancer 服務 ==="
kubectl delete svc jaeger-external -n observability

echo "=== 創建修正的 LoadBalancer 服務 ==="
cat > jaeger-loadbalancer-fixed.yaml << 'EOF'
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
    app.kubernetes.io/name: jaeger-production
    app.kubernetes.io/component: all-in-one
EOF

kubectl apply -f jaeger-loadbalancer-fixed.yaml
```


```bash
echo "=== 檢查是否有自動創建的 ClusterIP 服務 ==="
kubectl get svc -n observability -o wide

# 如果存在 jaeger-production-query 服務，將其改為 LoadBalancer
if kubectl get svc jaeger-production-query -n observability &>/dev/null; then
    echo "找到自動創建的服務 jaeger-production-query，將其改為 LoadBalancer"
    
    kubectl patch svc jaeger-production-query -n observability -p '{
      "spec": {
        "type": "LoadBalancer",
        "loadBalancerIP": "172.21.169.82"
      }
    }'
    
    kubectl annotate svc jaeger-production-query -n observability metallb.universe.tf/loadBalancerIPs="172.21.169.82"
    
    echo "已將 jaeger-production-query 服務改為 LoadBalancer"
    
    # 刪除多餘的外部服務
    kubectl delete svc jaeger-external -n observability || true
else
    echo "未找到自動創建的服務，使用方案 B"
fi
```

### 步驟 4：等待並驗證服務

```bash
echo "=== 等待 LoadBalancer IP 分配 ==="
sleep 10

echo "=== 檢查服務狀態 ==="
kubectl get svc -n observability | grep -E "(LoadBalancer|jaeger)"

echo "=== 檢查端點狀態 ==="
kubectl get endpoints -n observability | grep jaeger
```

### 步驟 5：測試連通性

```bash
echo "=== 測試所有端點連通性 ==="

echo "測試 Jaeger UI (16686)..."
curl -I http://172.21.169.82:16686

echo "測試收集器 HTTP (14268)..."
curl -I http://172.21.169.82:14268

echo "測試 Zipkin (9411)..."
curl -I http://172.21.169.82:9411

echo "測試管理端點 (14269)..."
curl -s http://172.21.169.82:14269/metrics | head -3

echo "測試 API..."
curl -s http://172.21.169.82:16686/api/services
```