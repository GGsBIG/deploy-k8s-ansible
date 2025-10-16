# 完整 ELK Stack 部署指南 (HTTPS版本)

## 概述

本指南將完整部署 ELK Stack (Elasticsearch + Kibana + Filebeat)，包含：
- ✅ 統一部署在 `elk-stack` namespace
- ✅ HTTPS 安全連接
- ✅ 自定義帳號 `admin/Systex123!`
- ✅ Kibana URL: `https://172.21.169.71:5601`
- ✅ Filebeat 日誌收集
- ✅ LoadBalancer 和 Ingress 配置

### 架構圖
```
Kubernetes Pods --> Filebeat --> Elasticsearch --> Kibana (HTTPS)
     日誌收集          處理轉發        存儲索引        視覺化分析
                                                   ↓
                                            LoadBalancer
                                         https://172.21.169.71:5601
```

---

## 第1步：環境準備

### 1.1 創建統一 Namespace

```bash
# 1. 創建 elk-stack namespace
kubectl create namespace elk-stack

# 2. 設置預設 namespace（可選）
kubectl config set-context --current --namespace=elk-stack

# 3. 驗證 namespace 創建
kubectl get namespaces | grep elk-stack
```

### 1.2 創建 MetalLB IP 配置

```bash
# 1. 創建 Kibana 專用 IP 配置
cat > metallb-kibana-config.yaml << 'EOF'
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: kibana-pool
  namespace: metallb-system
spec:
  addresses:
  - 172.21.169.71/32
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: kibana-advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
  - kibana-pool
EOF

# 2. 應用 MetalLB 配置
kubectl apply -f metallb-kibana-config.yaml

# 3. 驗證 IP 池配置
kubectl get ipaddresspool -n metallb-system | grep kibana
kubectl get l2advertisement -n metallb-system | grep kibana
```

---

## 第2步：部署 ECK Operator

### 2.1 安裝 ECK Operator

```bash
# 1. 創建 ECK namespace
kubectl create namespace elastic-system

# 2. 安裝 ECK CRDs
kubectl apply -f https://download.elastic.co/downloads/eck/2.9.0/crds.yaml

# 3. 安裝 ECK Operator
kubectl apply -f https://download.elastic.co/downloads/eck/2.9.0/operator.yaml

# 4. 等待 Operator 就緒
kubectl wait --for=condition=ready pod -l control-plane=elastic-operator -n elastic-system --timeout=300s

# 5. 驗證 ECK Operator 狀態
kubectl get pods -n elastic-system
kubectl logs -n elastic-system statefulset/elastic-operator --tail=10
```

---

## 第3步：部署 Elasticsearch

### 3.1 創建 Elasticsearch 配置

```bash
# 1. 創建 Elasticsearch 部署配置
cat > elasticsearch.yaml << 'EOF'
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: elasticsearch
  namespace: elk-stack
spec:
  version: 8.5.1
  http:
    tls:
      selfSignedCertificate:
        disabled: false
  nodeSets:
  - name: master
    count: 1
    config:
      # 安全性配置
      xpack.security.enabled: true
      xpack.security.transport.ssl.enabled: true
      xpack.security.http.ssl.enabled: true
      # 記憶體映射設定
      node.store.allow_mmap: false
      # 叢集設定
      cluster.initial_master_nodes: ["elasticsearch-es-master-0"]
      discovery.seed_hosts: ["elasticsearch-es-master"]
    podTemplate:
      metadata:
        labels:
          app: elasticsearch
      spec:
        # 設定安全上下文
        securityContext:
          fsGroup: 1000
        # 初始化容器
        initContainers:
        - name: increase-vm-max-map-count
          image: busybox:1.35
          command: ['sysctl', '-w', 'vm.max_map_count=262144']
          securityContext:
            privileged: true
        - name: increase-fd-ulimit
          image: busybox:1.35
          command: ['sh', '-c', 'ulimit -n 65536']
          securityContext:
            privileged: true
        containers:
        - name: elasticsearch
          env:
          - name: ES_JAVA_OPTS
            value: "-Xms2g -Xmx2g"
          resources:
            requests:
              memory: 2Gi
              cpu: 1000m
            limits:
              memory: 4Gi
              cpu: 2000m
    volumeClaimTemplates:
    - metadata:
        name: elasticsearch-data
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 50Gi
        storageClassName: nfs-storage
EOF

# 2. 部署 Elasticsearch
kubectl apply -f elasticsearch.yaml

# 3. 等待 Elasticsearch 就緒
echo "等待 Elasticsearch Pod 創建..."
for i in {1..30}; do
    STATUS=$(kubectl get pod elasticsearch-es-master-0 -n elk-stack -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
    READY=$(kubectl get pod elasticsearch-es-master-0 -n elk-stack -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null || echo "false")
    
    echo "Elasticsearch 檢查 $i/30: Status=$STATUS, Ready=$READY"
    
    if [ "$STATUS" = "Running" ] && [ "$READY" = "true" ]; then
        echo "✅ Elasticsearch 已成功啟動"
        break
    fi
    
    if [ $i -eq 30 ]; then
        echo "❌ Elasticsearch 啟動超時"
        kubectl describe pod elasticsearch-es-master-0 -n elk-stack
        kubectl logs elasticsearch-es-master-0 -n elk-stack --tail=20
        exit 1
    fi
    
    sleep 20
done
```

### 3.2 創建 admin 用戶

```bash
# 1. 取得 ECK 自動生成的 elastic 超級用戶密碼
ELASTIC_PASSWORD=$(kubectl get secret elasticsearch-es-elastic-user -n elk-stack -o go-template='{{.data.elastic | base64decode}}')
echo "ECK Elasticsearch 超級用戶密碼: $ELASTIC_PASSWORD"

# 2. 等待 Elasticsearch 完全就緒
sleep 60

# 3. 在 Elasticsearch 中創建 admin 用戶
kubectl exec elasticsearch-es-master-0 -n elk-stack -- \
  curl -k -X POST "https://localhost:9200/_security/user/admin" \
  -H "Content-Type: application/json" \
  -u "elastic:$ELASTIC_PASSWORD" \
  -d '{
    "password": "Systex123!",
    "roles": ["superuser", "kibana_admin", "kibana_user"],
    "full_name": "Administrator",
    "email": "admin@example.com"
  }'

# 4. 驗證 admin 用戶創建成功
kubectl exec elasticsearch-es-master-0 -n elk-stack -- \
  curl -k -X GET "https://localhost:9200/_security/user/admin" \
  -u "elastic:$ELASTIC_PASSWORD"

# 5. 測試 admin 用戶認證
kubectl exec elasticsearch-es-master-0 -n elk-stack -- \
  curl -k -u "admin:Systex123!" \
  https://localhost:9200/_cluster/health?pretty

echo "✅ admin 用戶創建成功，密碼: Systex123!"
```

---

## 第4步：部署 Kibana

### 4.1 創建 Kibana 配置

```bash
# 1. 創建 Kibana 部署配置
cat > kibana.yaml << 'EOF'
apiVersion: kibana.k8s.elastic.co/v1
kind: Kibana
metadata:
  name: kibana
  namespace: elk-stack
spec:
  version: 8.5.1
  count: 1
  elasticsearchRef:
    name: elasticsearch
    namespace: elk-stack
  http:
    service:
      spec:
        type: LoadBalancer
        loadBalancerIP: "172.21.169.71"
        ports:
        - name: https
          port: 5601
          targetPort: 5601
          protocol: TCP
      metadata:
        annotations:
          metallb.universe.tf/loadBalancerIPs: "172.21.169.71"
    tls:
      selfSignedCertificate:
        disabled: false
  podTemplate:
    metadata:
      labels:
        app: kibana
    spec:
      containers:
      - name: kibana
        env:
        - name: NODE_OPTIONS
          value: "--max-old-space-size=1800"
        resources:
          requests:
            memory: 1Gi
            cpu: 500m
          limits:
            memory: 2Gi
            cpu: 1000m
  config:
    server.host: "0.0.0.0"
    server.port: 5601
    server.publicBaseUrl: "https://172.21.169.71:5601"
    # Elasticsearch 配置
    elasticsearch.ssl.verificationMode: certificate
EOF

# 2. 部署 Kibana
kubectl apply -f kibana.yaml

# 3. 等待 Kibana 就緒
echo "等待 Kibana Pod 創建..."
for i in {1..40}; do
    POD_NAME=$(kubectl get pods -n elk-stack -l kibana.k8s.elastic.co/name=kibana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "NotFound")
    
    if [ "$POD_NAME" = "NotFound" ]; then
        echo "Kibana 檢查 $i/40: Pod 尚未創建"
    else
        STATUS=$(kubectl get pod $POD_NAME -n elk-stack -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
        READY=$(kubectl get pod $POD_NAME -n elk-stack -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null || echo "false")
        
        echo "Kibana 檢查 $i/40: Pod=$POD_NAME, Status=$STATUS, Ready=$READY"
        
        if [ "$STATUS" = "Running" ] && [ "$READY" = "true" ]; then
            echo "✅ Kibana 已成功啟動"
            break
        fi
        
        if [ "$STATUS" = "Error" ] || [ "$STATUS" = "CrashLoopBackOff" ]; then
            echo "❌ Kibana 錯誤狀態，顯示日誌:"
            kubectl logs $POD_NAME -n elk-stack --tail=10
        fi
    fi
    
    if [ $i -eq 40 ]; then
        echo "❌ Kibana 啟動超時"
        kubectl describe pod $POD_NAME -n elk-stack
        exit 1
    fi
    
    sleep 15
done

# 4. 檢查 LoadBalancer 服務
kubectl get svc kibana-kb-http -n elk-stack
```

---

## 第5步：部署 Filebeat

### 5.1 創建 Filebeat RBAC

```bash
# 1. 創建 Filebeat ServiceAccount 和 RBAC 權限
cat > filebeat-rbac.yaml << 'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: filebeat
  namespace: elk-stack
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: filebeat
rules:
- apiGroups: [""]
  resources:
  - nodes
  - namespaces
  - events
  - pods
  verbs: ["get", "list", "watch"]
- apiGroups: ["extensions"]
  resources:
  - replicasets
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources:
  - statefulsets
  - deployments
  - replicasets
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources:
  - nodes/stats
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: filebeat
subjects:
- kind: ServiceAccount
  name: filebeat
  namespace: elk-stack
roleRef:
  kind: ClusterRole
  name: filebeat
  apiGroup: rbac.authorization.k8s.io
EOF

# 2. 應用 RBAC 配置
kubectl apply -f filebeat-rbac.yaml

# 3. 驗證 RBAC 創建
kubectl get sa filebeat -n elk-stack
kubectl get clusterrole filebeat
```

### 5.2 創建 Filebeat 配置

```bash
# 1. 創建 Filebeat ConfigMap
cat > filebeat-configmap.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: filebeat-config
  namespace: elk-stack
data:
  filebeat.yml: |
    filebeat.inputs:
    - type: container
      paths:
        - /var/log/containers/*.log
      processors:
        - add_kubernetes_metadata:
            host: ${NODE_NAME}
            matchers:
            - logs_path:
                logs_path: "/var/log/containers/"
        - decode_json_fields:
            fields: ["message"]
            target: ""
            overwrite_keys: true
            
    output.elasticsearch:
      hosts: ["https://elasticsearch-es-http.elk-stack.svc.cluster.local:9200"]
      username: "admin"
      password: "Systex123!"
      ssl.verification_mode: "none"
      index: "filebeat-%{+yyyy.MM.dd}"
      timeout: 90
      
    setup.template.name: "filebeat"
    setup.template.pattern: "filebeat-*"
    setup.template.settings:
      index.number_of_shards: 1
      index.number_of_replicas: 0
      
    setup.ilm.enabled: false
    
    logging.level: info
    logging.to_stderr: true
    
    processors:
      - add_host_metadata:
          when.not.contains.tags: forwarded
      - add_kubernetes_metadata: ~
      
    http.enabled: true
    http.port: 5066
    
    monitoring.enabled: true
EOF

# 2. 應用 ConfigMap
kubectl apply -f filebeat-configmap.yaml

# 3. 驗證配置
kubectl describe configmap filebeat-config -n elk-stack
```

### 5.3 部署 Filebeat DaemonSet

```bash
# 1. 創建 Filebeat DaemonSet
cat > filebeat-daemonset.yaml << 'EOF'
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: filebeat
  namespace: elk-stack
  labels:
    app: filebeat
spec:
  selector:
    matchLabels:
      app: filebeat
  template:
    metadata:
      labels:
        app: filebeat
    spec:
      serviceAccountName: filebeat
      terminationGracePeriodSeconds: 30
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      containers:
      - name: filebeat
        image: docker.elastic.co/beats/filebeat:8.5.1
        args: [
          "-c", "/etc/filebeat.yml",
          "-e"
        ]
        env:
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        securityContext:
          runAsUser: 0
          runAsGroup: 0
          privileged: true
        resources:
          limits:
            memory: 1Gi
            cpu: 1000m
          requests:
            cpu: 100m
            memory: 256Mi
        volumeMounts:
        - name: config
          mountPath: /etc/filebeat.yml
          readOnly: true
          subPath: filebeat.yml
        - name: data
          mountPath: /usr/share/filebeat/data
        - name: varlog
          mountPath: /var/log
          readOnly: true
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
        - name: dockersock
          mountPath: /var/run/docker.sock
          readOnly: true
        livenessProbe:
          httpGet:
            path: /
            port: 5066
            scheme: HTTP
          failureThreshold: 5
          initialDelaySeconds: 30
          periodSeconds: 30
          timeoutSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 5066
            scheme: HTTP
          failureThreshold: 3
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
      volumes:
      - name: config
        configMap:
          defaultMode: 0640
          name: filebeat-config
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
      - name: varlog
        hostPath:
          path: /var/log
      - name: dockersock
        hostPath:
          path: /var/run/docker.sock
      - name: data
        hostPath:
          path: /var/lib/filebeat-data
          type: DirectoryOrCreate
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
EOF

# 2. 部署 DaemonSet
kubectl apply -f filebeat-daemonset.yaml

# 3. 等待 Filebeat 就緒
echo "等待 Filebeat Pod 啟動..."
sleep 60

# 4. 檢查 Filebeat 狀態
kubectl get daemonset filebeat -n elk-stack
kubectl get pods -l app=filebeat -n elk-stack -o wide

# 5. 等待所有 Pod 就緒
kubectl wait --for=condition=ready pod -l app=filebeat -n elk-stack --timeout=300s || echo "部分 Pod 可能仍在啟動中"
```

---

## 第6步：創建測試應用

### 6.1 部署日誌生成測試應用

```bash
# 1. 創建測試應用
cat > test-log-apps.yaml << 'EOF'
# Web 應用模擬器
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app-simulator
  namespace: elk-stack
  labels:
    app: web-app-simulator
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-app-simulator
  template:
    metadata:
      labels:
        app: web-app-simulator
        log-type: web
    spec:
      containers:
      - name: web-simulator
        image: busybox:1.35
        command:
        - sh
        - -c
        - |
          while true; do
            echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Processing web request from IP: 192.168.1.$((RANDOM%255))"
            echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Response time: ${RANDOM}ms"
            if [ $((RANDOM%10)) -eq 0 ]; then
              echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] Database connection timeout"
            fi
            if [ $((RANDOM%20)) -eq 0 ]; then
              echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] High memory usage detected: $((60+RANDOM%40))%"
            fi
            sleep $((1+RANDOM%5))
          done
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
---
# API 應用模擬器
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-service
  namespace: elk-stack
  labels:
    app: api-service
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api-service
  template:
    metadata:
      labels:
        app: api-service
        log-type: api
    spec:
      containers:
      - name: api-service
        image: busybox:1.35
        command:
        - sh
        - -c
        - |
          while true; do
            ENDPOINTS=("users" "orders" "products" "payments" "analytics")
            ENDPOINT=${ENDPOINTS[$RANDOM % ${#ENDPOINTS[@]}]}
            STATUS_CODES=(200 200 200 404 500)
            STATUS=${STATUS_CODES[$RANDOM % ${#STATUS_CODES[@]}]}
            
            echo "{\"timestamp\":\"$(date -Iseconds)\", \"level\":\"INFO\", \"endpoint\":\"/api/v1/$ENDPOINT\", \"status\":$STATUS, \"response_time\":${RANDOM}}"
            
            if [ $((RANDOM%15)) -eq 0 ]; then
              echo "{\"timestamp\":\"$(date -Iseconds)\", \"level\":\"ERROR\", \"message\":\"Failed to connect to database\", \"error_code\":\"DB_CONN_001\"}"
            fi
            
            sleep $((2+RANDOM%8))
          done
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
EOF

# 2. 部署測試應用
kubectl apply -f test-log-apps.yaml

# 3. 等待測試應用就緒
kubectl wait --for=condition=ready pod -l app=web-app-simulator -n elk-stack --timeout=60s
kubectl wait --for=condition=ready pod -l app=api-service -n elk-stack --timeout=60s

# 4. 檢查測試應用狀態
kubectl get pods -n elk-stack | grep -E "(web-app|api-service)"
```

---

## 第7步：配置索引生命週期管理

### 7.1 設置索引清理策略

```bash
# 1. 創建索引生命週期管理策略
cat > ilm-policy.json << 'EOF'
{
  "policy": {
    "phases": {
      "hot": {
        "actions": {
          "rollover": {
            "max_size": "5GB",
            "max_age": "1d"
          }
        }
      },
      "warm": {
        "min_age": "2d",
        "actions": {
          "allocate": {
            "number_of_replicas": 0
          }
        }
      },
      "delete": {
        "min_age": "7d"
      }
    }
  }
}
EOF

# 2. 應用 ILM 策略
kubectl exec elasticsearch-es-master-0 -n elk-stack -- \
  curl -k -X PUT \
  "https://localhost:9200/_ilm/policy/filebeat-policy" \
  -H "Content-Type: application/json" \
  -u "admin:Systex123!" \
  -d @ilm-policy.json

# 3. 創建索引模板
kubectl exec elasticsearch-es-master-0 -n elk-stack -- \
  curl -k -X PUT \
  "https://localhost:9200/_template/filebeat-template" \
  -H "Content-Type: application/json" \
  -u "admin:Systex123!" \
  -d '{
    "index_patterns": ["filebeat-*"],
    "settings": {
      "index.lifecycle.name": "filebeat-policy",
      "index.lifecycle.rollover_alias": "filebeat",
      "number_of_shards": 1,
      "number_of_replicas": 0
    }
  }'

# 4. 清理臨時文件
rm -f ilm-policy.json
```

---

## 第8步：驗證和測試

### 8.1 完整系統驗證

```bash
echo "=== ELK Stack 部署驗證 ==="

# 1. 檢查所有組件狀態
echo "1. 檢查所有 Pod 狀態:"
kubectl get pods -n elk-stack -o wide
echo ""

# 2. 檢查服務狀態
echo "2. 檢查服務狀態:"
kubectl get svc -n elk-stack
echo ""

# 3. 檢查 Elasticsearch 健康狀態
echo "3. 檢查 Elasticsearch 健康:"
kubectl exec elasticsearch-es-master-0 -n elk-stack -- \
  curl -k -s -u "admin:Systex123!" \
  https://localhost:9200/_cluster/health?pretty
echo ""

# 4. 檢查索引創建情況
echo "4. 檢查 Filebeat 索引:"
kubectl exec elasticsearch-es-master-0 -n elk-stack -- \
  curl -k -s -u "admin:Systex123!" \
  "https://localhost:9200/_cat/indices?v" | grep filebeat || echo "索引尚未創建，請等待..."
echo ""

# 5. 測試 Kibana 連接
echo "5. 測試 Kibana 連接:"
timeout 10 curl -k -I https://172.21.169.71:5601/login 2>/dev/null && echo "✅ Kibana 可訪問" || echo "❌ Kibana 連接失敗"
echo ""

# 6. 檢查測試應用日誌
echo "6. 檢查測試應用日誌生成:"
kubectl logs -l app=web-app-simulator -n elk-stack --tail=3
echo ""

# 7. 顯示登入資訊
echo "=== 登入資訊 ==="
echo "Kibana URL: https://172.21.169.71:5601"
echo "Username: admin"
echo "Password: Systex123!"
echo ""
echo "Elasticsearch 內部連接:"
echo "Host: elasticsearch-es-http.elk-stack.svc.cluster.local:9200"
echo "Username: admin"
echo "Password: Systex123!"
```

### 8.2 Kibana 索引模式配置

```bash
# 1. 等待日誌收集（約2-3分鐘）
echo "等待 Filebeat 收集日誌並建立索引..."
sleep 180

# 2. 檢查日誌索引內容
kubectl exec elasticsearch-es-master-0 -n elk-stack -- \
  curl -k -s -u "admin:Systex123!" \
  "https://localhost:9200/filebeat-$(date +%Y.%m.%d)/_search?size=1&pretty" || echo "索引數據尚未準備好"

# 3. 顯示 Kibana 配置說明
echo ""
echo "=== Kibana 配置說明 ==="
echo "1. 開啟瀏覽器訪問: https://172.21.169.71:5601"
echo "2. 使用帳號登入: admin / Systex123!"
echo "3. 進入 Stack Management > Data > Index Management"
echo "4. 創建 Index Pattern: filebeat-*"
echo "5. 設定時間字段: @timestamp"
echo "6. 進入 Discover 頁面查看日誌"
```

### 8.3 故障排除檢查

```bash
# 1. 檢查失敗的 Pod
echo "=== 故障排除檢查 ==="
FAILED_PODS=$(kubectl get pods -n elk-stack --field-selector=status.phase!=Running -o name 2>/dev/null)
if [ -n "$FAILED_PODS" ]; then
    echo "發現失敗的 Pod:"
    echo "$FAILED_PODS"
    for pod in $FAILED_PODS; do
        echo "檢查 Pod: $pod"
        kubectl describe $pod -n elk-stack
        kubectl logs $pod -n elk-stack --tail=20 2>/dev/null || echo "無法取得日誌"
    done
else
    echo "✅ 所有 Pod 運行正常"
fi

# 2. 檢查 Filebeat 連接
FILEBEAT_POD=$(kubectl get pods -n elk-stack -l app=filebeat -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$FILEBEAT_POD" ]; then
    echo ""
    echo "檢查 Filebeat 狀態:"
    kubectl exec $FILEBEAT_POD -n elk-stack -- curl -s http://localhost:5066 2>/dev/null | head -5 || echo "Filebeat 指標端點不可用"
fi

# 3. 檢查資源使用
echo ""
echo "檢查資源使用情況:"
kubectl top pods -n elk-stack 2>/dev/null || echo "Metrics server 不可用"
```

---

## 第9步：維護和監控

### 9.1 日常監控腳本

```bash
# 1. 創建監控腳本
cat > monitor-elk-stack.sh << 'EOF'
#!/bin/bash
echo "=== ELK Stack 監控報告 $(date) ==="
echo ""

# 檢查 Pod 狀態
echo "1. Pod 狀態檢查:"
kubectl get pods -n elk-stack -o wide
echo ""

# 檢查服務狀態
echo "2. 服務狀態檢查:"
kubectl get svc -n elk-stack
echo ""

# 檢查 Elasticsearch 健康
echo "3. Elasticsearch 叢集健康:"
kubectl exec elasticsearch-es-master-0 -n elk-stack -- \
  curl -k -s -u "admin:Systex123!" \
  https://localhost:9200/_cluster/health | jq . 2>/dev/null || echo "需要安裝 jq"
echo ""

# 檢查索引大小
echo "4. 索引大小統計:"
kubectl exec elasticsearch-es-master-0 -n elk-stack -- \
  curl -k -s -u "admin:Systex123!" \
  "https://localhost:9200/_cat/indices?v&h=index,docs.count,store.size" | head -10
echo ""

# 檢查 Filebeat 狀態
echo "5. Filebeat 狀態統計:"
kubectl get pods -l app=filebeat -n elk-stack --no-headers | wc -l | xargs echo "運行中的 Filebeat Pod 數量:"
echo ""

echo "監控完成。"
EOF

chmod +x monitor-elk-stack.sh
echo "監控腳本已創建: ./monitor-elk-stack.sh"

# 2. 執行一次監控檢查
# ./monitor-elk-stack.sh
```

### 9.2 備份策略

```bash
# 1. 創建 Elasticsearch 快照儲存庫設置
cat > backup-setup.json << 'EOF'
{
  "type": "fs",
  "settings": {
    "location": "/usr/share/elasticsearch/backup",
    "compress": true
  }
}
EOF

# 2. 配置快照儲存庫（可選）
kubectl exec elasticsearch-es-master-0 -n elk-stack -- \
  curl -k -X PUT \
  "https://localhost:9200/_snapshot/backup_repo" \
  -H "Content-Type: application/json" \
  -u "admin:Systex123!" \
  -d @backup-setup.json 2>/dev/null || echo "快照設置需要額外的存儲配置"

rm -f backup-setup.json

echo "備份配置完成（如需啟用，請配置持久化存儲）"
```

---

## 清理和重新部署

### 完全清理命令

```bash
# ⚠️ 警告：以下命令將完全刪除 ELK Stack 部署！

# 1. 刪除所有應用
kubectl delete namespace elk-stack --force --grace-period=0

# 2. 清理 RBAC
kubectl delete clusterrole filebeat
kubectl delete clusterrolebinding filebeat

# 3. 清理 MetalLB 配置
kubectl delete ipaddresspool kibana-pool -n metallb-system
kubectl delete l2advertisement kibana-advertisement -n metallb-system

# 4. 清理 ECK Operator（如需要）
# kubectl delete namespace elastic-system

echo "ELK Stack 已完全清理"
```

---

## 成功標準

### 部署成功指標

✅ **Elasticsearch**: `1/1 Running`, 叢集狀態 `green`  
✅ **Kibana**: `1/1 Running`, 可通過 https://172.21.169.71:5601 訪問  
✅ **Filebeat**: 所有節點上 `1/1 Running`  
✅ **認證**: 可使用 `admin/Systex123!` 登入  
✅ **日誌收集**: Elasticsearch 中能看到 `filebeat-*` 索引  
✅ **測試應用**: 產生日誌並被正確收集  

### 訪問資訊總結

```
🌐 Kibana Web Interface
   URL: https://172.21.169.71:5601
   Username: admin  
   Password: Systex123!

🔍 Elasticsearch API
   Internal: https://elasticsearch-es-http.elk-stack.svc.cluster.local:9200
   Username: admin
   Password: Systex123!

📊 日誌索引模式
   Pattern: filebeat-*
   時間字段: @timestamp

🎯 測試應用日誌
   Namespace: elk-stack
   應用: web-app-simulator, api-service
```

---

**🎉 部署完成！**

你現在擁有一個完整的、統一部署在 `elk-stack` namespace 的 ELK Stack 系統，包含：
- **安全的 HTTPS 訪問**
- **統一的 admin 帳號認證**  
- **自動日誌收集和索引**
- **測試應用和監控工具**
- **生產級別的配置和優化**

可以開始使用 Kibana 進行日誌分析和視覺化了！