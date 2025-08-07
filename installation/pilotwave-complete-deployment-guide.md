# PilotWave 完整建置手冊

## 目標
部署 PilotWave 服務到 Kubernetes 集群，通過 Istio Service Mesh 提供服務，並配置外部訪問地址 http://172.21.169.78

---

## 前置條件檢查

### 1. 確認 Istio 已安裝並運行
```bash
kubectl get pods -n istio-system
# 應該看到 istiod 和 istio-ingressgateway 運行中
```

### 2. 確認 NFS 存儲可用
```bash
kubectl get storageclass
# 應該看到 nfs-storage 存儲類
```

### 3. 確認 MetalLB 配置
```bash
kubectl get svc -n istio-system istio-ingressgateway
# 應該看到 EXTERNAL-IP: 172.21.169.72
```

---

## 步驟 1: 清理現有部署（如果存在）

```bash
# 刪除現有 PilotWave 資源
kubectl delete namespace pilotwave --force --grace-period=0

# 等待命名空間完全刪除
kubectl get ns | grep pilotwave || echo "命名空間已刪除"
```

---

## 步驟 2: 創建並配置命名空間

```bash
# 創建 pilotwave 命名空間
kubectl create namespace pilotwave

# 啟用 Istio 自動注入
kubectl label namespace pilotwave istio-injection=enabled

# 驗證命名空間配置
kubectl get namespace pilotwave --show-labels
```

---

## 步驟 3: 創建 RBAC 配置文件

創建 `pilotwave-rbac-fixed.yaml`:
```yaml
# ServiceAccount for PilotWave
apiVersion: v1
kind: ServiceAccount
metadata:
  name: pilotwave-sa
  namespace: pilotwave
  labels:
    app: pilotwave
---
# ClusterRoleBinding - 綁定集群管理員權限
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: pilotwave-cluster-admin
subjects:
- kind: ServiceAccount
  name: pilotwave-sa
  namespace: pilotwave
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
---
# RoleBinding - Namespace 級別權限
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pilotwave-namespace-admin
  namespace: pilotwave
subjects:
- kind: ServiceAccount
  name: pilotwave-sa
  namespace: pilotwave
roleRef:
  kind: ClusterRole
  name: admin
  apiGroup: rbac.authorization.k8s.io
```

應用 RBAC 配置：
```bash
kubectl apply -f pilotwave-rbac-fixed.yaml
```

---

## 步驟 4: 創建應用部署配置文件

創建 `pilotwave-app-fixed.yaml`:
```yaml
# PersistentVolumeClaim - 修復存儲類配置
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pilotwave-pvc
  namespace: pilotwave
  labels:
    app: pilotwave
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: "nfs-storage"
  resources:
    requests:
      storage: 10Gi
---
# Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pilotwave
  namespace: pilotwave
  labels:
    app: pilotwave
    version: v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pilotwave
      version: v1
  template:
    metadata:
      labels:
        app: pilotwave
        version: v1
      annotations:
        sidecar.istio.io/inject: "true"
        sidecar.istio.io/proxyCPU: "100m"
        sidecar.istio.io/proxyMemory: "128Mi"
    spec:
      serviceAccountName: pilotwave-sa
      containers:
        - name: pilotwave
          image: hb.k8sbridge.com/pilotwave/pilotwave:v1.5
          ports:
            - name: http
              containerPort: 22112
              protocol: TCP
          args:
            - "--service-port=22112"
            - "--grafana-host=10.10.7.230"
            - "--grafana-port=80"
            - "--grafana-token=**"
          env:
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
          volumeMounts:
            - name: pilotwave-storage
              mountPath: /data
          resources:
            requests:
              memory: "256Mi"
              cpu: "100m"
            limits:
              memory: "512Mi"
              cpu: "500m"
          readinessProbe:
            httpGet:
              path: /health
              port: 22112
            initialDelaySeconds: 30
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /health
              port: 22112
            initialDelaySeconds: 60
            periodSeconds: 30
      volumes:
        - name: pilotwave-storage
          persistentVolumeClaim:
            claimName: pilotwave-pvc
---
# Service
apiVersion: v1
kind: Service
metadata:
  name: pilotwave-svc
  namespace: pilotwave
  labels:
    app: pilotwave
    service: pilotwave
spec:
  type: ClusterIP
  ports:
    - name: http
      port: 80
      targetPort: 22112
      protocol: TCP
  selector:
    app: pilotwave
```

應用應用配置：
```bash
kubectl apply -f pilotwave-app-fixed.yaml
```

---

## 步驟 5: 創建 Istio 網絡配置文件

創建 `pilotwave-istio-network.yaml`:
```yaml
# Gateway - 配置入口網關
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: pilotwave-gateway
  namespace: pilotwave
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "172.21.169.78"
    - "pilotwave.local"
---
# VirtualService - 配置路由規則
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: pilotwave-vs
  namespace: pilotwave
spec:
  hosts:
  - "172.21.169.78"
  - "pilotwave.local"
  gateways:
  - pilotwave-gateway
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: pilotwave-svc.pilotwave.svc.cluster.local
        port:
          number: 80
    timeout: 60s
    retries:
      attempts: 3
      perTryTimeout: 20s
      retryOn: 5xx,reset,connect-failure,refused-stream
---
# DestinationRule - 配置流量策略
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: pilotwave-dr
  namespace: pilotwave
spec:
  host: pilotwave-svc.pilotwave.svc.cluster.local
  trafficPolicy:
    loadBalancer:
      simple: LEAST_CONN
    connectionPool:
      tcp:
        maxConnections: 100
        connectTimeout: 30s
      http:
        http1MaxPendingRequests: 50
        http2MaxRequests: 100
        maxRequestsPerConnection: 10
        maxRetries: 3
        idleTimeout: 90s
    outlierDetection:
      consecutiveGatewayErrors: 3
      consecutive5xxErrors: 3
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
      minHealthPercent: 30
```

---

## 步驟 6: 配置 MetalLB IP 地址

創建 `pilotwave-loadbalancer.yaml`:
```yaml
# LoadBalancer Service for PilotWave
apiVersion: v1
kind: Service
metadata:
  name: pilotwave-loadbalancer
  namespace: pilotwave
  labels:
    app: pilotwave
    service: loadbalancer
  annotations:
    metallb.universe.tf/loadBalancerIPs: "172.21.169.78"
spec:
  type: LoadBalancer
  loadBalancerIP: "172.21.169.78"
  ports:
    - name: http
      port: 80
      targetPort: 22112
      protocol: TCP
  selector:
    app: pilotwave
```

---

## 步驟 7: 執行完整部署

```bash
echo "=== 開始部署 PilotWave ==="

# 1. 應用 RBAC 配置
echo "應用 RBAC 配置..."
kubectl apply -f pilotwave-rbac-fixed.yaml

# 2. 等待 ServiceAccount 創建
sleep 10

# 3. 應用應用部署
echo "部署 PilotWave 應用..."
kubectl apply -f pilotwave-app-fixed.yaml

# 4. 等待 PVC 綁定
echo "等待 PVC 綁定..."
sleep 30

# 5. 檢查 PVC 狀態
kubectl get pvc -n pilotwave

# 6. 等待 Pod 啟動
echo "等待 Pod 啟動..."
kubectl wait --for=condition=Ready pod -l app=pilotwave -n pilotwave --timeout=300s

# 7. 應用 Istio 網絡配置
echo "配置 Istio 網絡..."
kubectl apply -f pilotwave-istio-network.yaml

# 8. 應用 LoadBalancer 配置
echo "配置 LoadBalancer..."
kubectl apply -f pilotwave-loadbalancer.yaml

echo "=== 部署完成 ==="
```

---

## 步驟 8: 驗證部署狀態

```bash
# 檢查所有資源狀態
echo "=== 檢查部署狀態 ==="

# 檢查 Pod 狀態
echo "Pod 狀態:"
kubectl get pods -n pilotwave -o wide

# 檢查 Service 狀態
echo "Service 狀態:"
kubectl get svc -n pilotwave

# 檢查 PVC 狀態
echo "PVC 狀態:"
kubectl get pvc -n pilotwave

# 檢查 Istio 資源
echo "Istio 資源:"
kubectl get gateway,virtualservice,destinationrule -n pilotwave

# 檢查 ServiceAccount 和權限
echo "RBAC 配置:"
kubectl get sa -n pilotwave
kubectl get clusterrolebinding | grep pilotwave
kubectl get rolebinding -n pilotwave

# 檢查 LoadBalancer IP
echo "LoadBalancer 狀態:"
kubectl get svc pilotwave-loadbalancer -n pilotwave
```

---

## 步驟 9: 測試服務連接

```bash
# 1. 測試內部連接
echo "=== 測試內部連接 ==="
kubectl exec -n pilotwave deployment/pilotwave -c pilotwave -- curl -I http://localhost:22112/health

# 2. 測試 Service 連接
echo "=== 測試 Service 連接 ==="
kubectl run -i --tty --rm debug --image=busybox --restart=Never -- wget -qO- http://pilotwave-svc.pilotwave.svc.cluster.local/health

# 3. 測試 LoadBalancer 連接
echo "=== 測試 LoadBalancer 連接 ==="
curl -I http://172.21.169.78/health

# 4. 測試完整頁面
echo "=== 測試完整頁面 ==="
curl -s http://172.21.169.78 | head -10
```

---

## 步驟 10: 故障排除

### 如果 Pod 仍然 Pending

```bash
# 檢查 PVC 綁定問題
kubectl describe pvc pilotwave-pvc -n pilotwave

# 檢查存儲類
kubectl get storageclass nfs-storage -o yaml

# 檢查 NFS Provisioner
kubectl logs -n nfs -l app=nfs-subdir-external-provisioner

# 手動創建 PV（如果需要）
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pilotwave-pv-manual
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: nfs-storage
  nfs:
    path: /NFS/pilotwave-data
    server: 172.21.169.51
EOF
```

### 如果 LoadBalancer IP 未分配

```bash
# 檢查 MetalLB 配置
kubectl get configmap -n metallb-system

# 檢查 IP 池
kubectl describe ipaddresspool -n metallb-system

# 驗證 IP 範圍包含 172.21.169.78
kubectl get ipaddresspool -n metallb-system -o yaml
```

### 如果服務無法訪問

```bash
# 檢查 Istio 代理狀態
istioctl proxy-status

# 檢查 Istio 配置
istioctl analyze -n pilotwave

# 檢查 Pod 日誌
kubectl logs -n pilotwave deployment/pilotwave -c pilotwave
kubectl logs -n pilotwave deployment/pilotwave -c istio-proxy

# 檢查網絡連接
kubectl exec -n pilotwave deployment/pilotwave -c pilotwave -- netstat -tlnp
```

---

## 訪問信息

部署成功後，您可以通過以下方式訪問 PilotWave：

### 直接 LoadBalancer 訪問
- **主要訪問地址**: http://172.21.169.78
- **健康檢查**: http://172.21.169.78/health

### 通過 Istio Gateway 訪問
- **Istio Gateway**: http://172.21.169.72 (需要 Host header: 172.21.169.78)

### 內部訪問
- **Service DNS**: http://pilotwave-svc.pilotwave.svc.cluster.local

---

## 監控和管理

### 在 Kiali 中查看服務網格
```bash
# 訪問 Kiali 界面
echo "Kiali: http://172.21.169.77:20001"
```

### 在 Grafana 中監控指標
```bash
# 訪問 Grafana 界面
echo "Grafana: http://172.21.169.74"
```

### 在 Jaeger 中查看追蹤
```bash
# 訪問 Jaeger 界面
echo "Jaeger: http://172.21.169.82:16686"
```

---

## 清理部署

如果需要完全清理 PilotWave 部署：

```bash
# 刪除所有 PilotWave 資源
kubectl delete namespace pilotwave --force --grace-period=0

# 刪除 ClusterRoleBinding
kubectl delete clusterrolebinding pilotwave-cluster-admin

# 等待資源清理完成
kubectl get ns | grep pilotwave || echo "清理完成"
```

---

**部署完成後，請訪問 http://172.21.169.78 確認 PilotWave 服務正常運行。**