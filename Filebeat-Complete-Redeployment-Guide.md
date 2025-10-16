# Filebeat 完整重新部署指南

## 概述

本指南提供 Filebeat 在 ELK Stack 中的完整重新部署流程，包含清理舊配置、重新配置和驗證步驟。

### 環境資訊
- **Namespace**: `elk-stack`
- **Elasticsearch**: `elasticsearch-es-http.elk-stack.svc.cluster.local:9200`
- **認證**: admin / Systex123!
- **Kibana URL**: https://172.21.169.71:5601

---

## 第1步：完全清理現有 Filebeat

### 1.1 停止並刪除所有 Filebeat 資源

```bash
echo "=== 第1步：清理現有 Filebeat 配置 ==="

# 1. 刪除 DaemonSet（這會自動刪除所有 Pod）
kubectl delete daemonset filebeat -n elk-stack --ignore-not-found=true

# 2. 等待所有 Pod 完全終止
echo "等待 Filebeat Pod 終止..."
while kubectl get pods -l app=filebeat -n elk-stack --no-headers 2>/dev/null | grep -q .; do
    echo "等待 Pod 終止中..."
    sleep 5
done
echo "✅ 所有 Filebeat Pod 已終止"

# 3. 刪除 ConfigMap
kubectl delete configmap filebeat-config -n elk-stack --ignore-not-found=true

# 4. 清理可能存在的 Service 和其他資源
kubectl delete service filebeat -n elk-stack --ignore-not-found=true
kubectl delete servicemonitor filebeat -n elk-stack --ignore-not-found=true

# 5. 驗證清理完成
echo "驗證清理狀態:"
kubectl get pods,configmap,daemonset -l app=filebeat -n elk-stack
echo ""
```

### 1.2 清理 RBAC 資源（如需要重建）

```bash
# 如果需要重新創建 RBAC 權限
echo "清理 RBAC 資源:"
kubectl delete clusterrole filebeat --ignore-not-found=true
kubectl delete clusterrolebinding filebeat --ignore-not-found=true
kubectl delete serviceaccount filebeat -n elk-stack --ignore-not-found=true
echo "✅ RBAC 資源已清理"
```

---

## 第2步：重新創建 RBAC 權限

### 2.1 創建完整 RBAC 配置

```bash
echo "=== 第2步：重新創建 RBAC 權限 ==="

# 創建 RBAC 配置文件
cat > filebeat-rbac.yaml << 'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: filebeat
  namespace: elk-stack
  labels:
    app: filebeat
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: filebeat
  labels:
    app: filebeat
rules:
- apiGroups: [""]
  resources:
  - nodes
  - namespaces
  - events
  - pods
  - services
  - configmaps
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources:
  - nodes/stats
  verbs: ["get"]
- apiGroups: ["extensions"]
  resources:
  - replicasets
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources:
  - statefulsets
  - deployments
  - replicasets
  - daemonsets
  verbs: ["get", "list", "watch"]
- apiGroups: ["batch"]
  resources:
  - jobs
  - cronjobs
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: filebeat
  labels:
    app: filebeat
subjects:
- kind: ServiceAccount
  name: filebeat
  namespace: elk-stack
roleRef:
  kind: ClusterRole
  name: filebeat
  apiGroup: rbac.authorization.k8s.io
EOF

# 應用 RBAC 配置
kubectl apply -f filebeat-rbac.yaml

# 驗證 RBAC 創建
echo "驗證 RBAC 資源:"
kubectl get sa filebeat -n elk-stack
kubectl get clusterrole filebeat
kubectl get clusterrolebinding filebeat
echo "✅ RBAC 權限已重新創建"
echo ""
```

---

## 第3步：創建新的 Filebeat 配置

### 3.1 創建 Filebeat ConfigMap

```bash
echo "=== 第3步：創建新的 Filebeat 配置 ==="

# 創建經過優化的 Filebeat 配置
cat > filebeat-config.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: filebeat-config
  namespace: elk-stack
  labels:
    app: filebeat
data:
  filebeat.yml: |-
    # Filebeat 輸入配置（適用於 containerd）
    filebeat.inputs:
    - type: container
      paths:
        - /var/log/containers/*.log
      # 排除系統 Pod 日誌以減少噪音
      exclude_lines: ['^\\s*$']
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
            add_error_key: true
        # 過濾不需要的 namespace（可選）
        - drop_event:
            when:
              or:
                - equals:
                    kubernetes.namespace: kube-system
                - equals:
                    kubernetes.namespace: kube-public
    
    # Elasticsearch 輸出配置
    output.elasticsearch:
      hosts: ["https://elasticsearch-es-http.elk-stack.svc.cluster.local:9200"]
      username: "admin"
      password: "Systex123!"
      ssl:
        verification_mode: none
        certificate_authorities: []
      # 使用日期索引模式
      index: "filebeat-%{+yyyy.MM.dd}"
      # 批量處理優化
      bulk_max_size: 1000
      worker: 2
      timeout: 30s
    
    # 模板配置
    setup.template.name: "filebeat"
    setup.template.pattern: "filebeat-*"
    setup.template.settings:
      index:
        number_of_shards: 1
        number_of_replicas: 0
    
    # 禁用 ILM 以簡化索引管理
    setup.ilm.enabled: false
    
    # 處理器配置
    processors:
      - add_host_metadata:
          when.not.contains.tags: forwarded
      - add_kubernetes_metadata: ~
    
    # 日誌配置
    logging.level: info
    logging.to_stderr: true
    logging.to_files: false
    
    # 監控端點配置
    http:
      enabled: true
      host: "0.0.0.0"
      port: 5066
    
    # 監控配置
    monitoring:
      enabled: true
      elasticsearch:
        hosts: ["https://elasticsearch-es-http.elk-stack.svc.cluster.local:9200"]
        username: "admin"
        password: "Systex123!"
        ssl.verification_mode: none
EOF

# 應用 ConfigMap
kubectl apply -f filebeat-config.yaml

# 驗證 ConfigMap 創建
kubectl describe configmap filebeat-config -n elk-stack
echo "✅ Filebeat 配置已創建"
echo ""
```

---

## 第4步：部署 Filebeat DaemonSet

### 4.1 創建 Filebeat DaemonSet

```bash
echo "=== 第4步：部署 Filebeat DaemonSet ==="

# 創建優化的 DaemonSet 配置
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
      containers:
      - name: filebeat
        image: docker.elastic.co/beats/filebeat:8.5.1
        args: ["-c", "/etc/filebeat.yml", "-e"]
        env:
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        securityContext:
          runAsUser: 0
          capabilities:
            add:
              - SYS_ADMIN
        resources:
          limits:
            memory: 1Gi
            cpu: 1000m
          requests:
            cpu: 100m
            memory: 256Mi
        # 健康檢查配置
        livenessProbe:
          exec:
            command:
            - sh
            - -c
            - 'curl -s http://localhost:5066 > /dev/null || exit 1'
          initialDelaySeconds: 120
          periodSeconds: 30
          timeoutSeconds: 10
          failureThreshold: 5
        readinessProbe:
          exec:
            command:
            - sh
            - -c
            - 'curl -s http://localhost:5066 > /dev/null || exit 1'
          initialDelaySeconds: 60
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
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
        - name: varlibcontainers
          mountPath: /var/log/containers
          readOnly: true
        - name: varlibpods
          mountPath: /var/log/pods
          readOnly: true
      volumes:
      - name: config
        configMap:
          defaultMode: 0640
          name: filebeat-config
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibcontainers
        hostPath:
          path: /var/log/containers
      - name: varlibpods
        hostPath:
          path: /var/log/pods
      - name: data
        hostPath:
          path: /var/lib/filebeat-data
          type: DirectoryOrCreate
      tolerations:
      - operator: Exists
        effect: NoSchedule
      - operator: Exists
        effect: NoExecute
EOF

# 部署 DaemonSet
kubectl apply -f filebeat-daemonset.yaml

echo "✅ Filebeat DaemonSet 已部署"
echo ""
```

---

## 第5步：驗證部署狀態

### 5.1 檢查 Pod 啟動狀態

```bash
echo "=== 第5步：驗證 Filebeat 部署 ==="

# 等待 Pod 啟動
echo "等待 Filebeat Pod 啟動（最多5分鐘）..."
for i in {1..30}; do
    READY_PODS=$(kubectl get pods -l app=filebeat -n elk-stack --no-headers 2>/dev/null | grep "1/1.*Running" | wc -l)
    TOTAL_PODS=$(kubectl get pods -l app=filebeat -n elk-stack --no-headers 2>/dev/null | wc -l)
    
    echo "檢查 $i/30: $READY_PODS/$TOTAL_PODS Pod 就緒"
    
    if [ "$READY_PODS" -gt 0 ] && [ "$READY_PODS" -eq "$TOTAL_PODS" ]; then
        echo "✅ 所有 Filebeat Pod 已就緒"
        break
    fi
    
    if [ $i -eq 30 ]; then
        echo "⚠️  部分 Pod 可能仍在啟動中，請檢查詳細狀態"
    fi
    
    sleep 10
done

# 顯示 Pod 狀態
echo ""
echo "當前 Filebeat Pod 狀態:"
kubectl get pods -l app=filebeat -n elk-stack -o wide
echo ""
```

### 5.2 檢查 Pod 詳細狀態

```bash
echo "檢查 Pod 詳細狀態:"
kubectl describe pods -l app=filebeat -n elk-stack | grep -A 10 -B 5 "Conditions:\|Ready:\|Events:" | head -20
echo ""

# 檢查最新日誌
echo "檢查 Filebeat 日誌:"
kubectl logs -l app=filebeat -n elk-stack --tail=10
echo ""
```

### 5.3 測試健康檢查端點

```bash
echo "測試 Filebeat 健康檢查:"
FILEBEAT_POD=$(kubectl get pods -l app=filebeat -n elk-stack -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$FILEBEAT_POD" ]; then
    echo "測試 Pod: $FILEBEAT_POD"
    kubectl exec $FILEBEAT_POD -n elk-stack -- curl -s http://localhost:5066/ | head -5 || echo "健康檢查端點暫時不可用"
else
    echo "找不到 Filebeat Pod"
fi
echo ""
```

---

## 第6步：驗證日誌收集

### 6.1 檢查 Elasticsearch 連接

```bash
echo "=== 第6步：驗證日誌收集功能 ==="

# 檢查 Filebeat 連接到 Elasticsearch
echo "檢查 Elasticsearch 連接:"
kubectl exec elasticsearch-es-master-0 -n elk-stack -- \
  curl -k -s -u "admin:Systex123!" \
  https://localhost:9200/_cluster/health?pretty | head -10
echo ""
```

### 6.2 等待並檢查索引創建

```bash
echo "等待日誌收集和索引創建（180秒）..."
sleep 180

# 檢查 Filebeat 索引
echo "檢查 Filebeat 索引:"
kubectl exec elasticsearch-es-master-0 -n elk-stack -- \
  curl -k -s -u "admin:Systex123!" \
  "https://localhost:9200/_cat/indices?v" | grep filebeat | head -5
echo ""

# 檢查今日索引文檔數量
echo "檢查今日索引文檔數量:"
kubectl exec elasticsearch-es-master-0 -n elk-stack -- \
  curl -k -s -u "admin:Systex123!" \
  "https://localhost:9200/filebeat-$(date +%Y.%m.%d)/_count" 2>/dev/null | jq '.count' 2>/dev/null || echo "索引數據準備中..."
echo ""
```

### 6.3 測試日誌搜尋

```bash
echo "測試日誌搜尋功能:"

# 搜尋最近5分鐘的日誌
kubectl exec elasticsearch-es-master-0 -n elk-stack -- \
  curl -k -s -u "admin:Systex123!" \
  "https://localhost:9200/filebeat-$(date +%Y.%m.%d)/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "range": {
        "@timestamp": {
          "gte": "now-5m"
        }
      }
    },
    "size": 1,
    "sort": [{"@timestamp": {"order": "desc"}}]
  }' | jq '.hits.total.value' 2>/dev/null || echo "搜尋測試執行中..."
echo ""
```

---

## 第7步：部署測試應用（可選）

### 7.1 部署日誌生成測試應用

```bash
echo "=== 第7步：部署測試應用生成日誌 ==="

# 創建測試應用
cat > test-app.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: log-generator
  namespace: elk-stack
  labels:
    app: log-generator
spec:
  replicas: 1
  selector:
    matchLabels:
      app: log-generator
  template:
    metadata:
      labels:
        app: log-generator
    spec:
      containers:
      - name: log-generator
        image: busybox:1.35
        command:
        - sh
        - -c
        - |
          while true; do
            echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Test log message from log-generator"
            echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Processing request ID: $RANDOM"
            if [ $((RANDOM%10)) -eq 0 ]; then
              echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] Simulated error condition"
            fi
            if [ $((RANDOM%15)) -eq 0 ]; then
              echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] Warning: High resource usage detected"
            fi
            sleep $((3+RANDOM%7))
          done
        resources:
          requests:
            memory: "32Mi"
            cpu: "25m"
          limits:
            memory: "64Mi"
            cpu: "50m"
EOF

# 部署測試應用
kubectl apply -f test-app.yaml

# 等待測試應用就緒
kubectl wait --for=condition=ready pod -l app=log-generator -n elk-stack --timeout=60s

echo "✅ 測試應用已部署"
echo ""

# 檢查測試應用日誌
echo "測試應用日誌樣本:"
kubectl logs -l app=log-generator -n elk-stack --tail=3
echo ""
```

### 7.2 驗證測試應用日誌收集

```bash
echo "等待測試應用日誌被收集（120秒）..."
sleep 120

# 搜尋測試應用日誌
echo "搜尋測試應用日誌:"
kubectl exec elasticsearch-es-master-0 -n elk-stack -- \
  curl -k -s -u "admin:Systex123!" \
  "https://localhost:9200/filebeat-$(date +%Y.%m.%d)/_search?q=kubernetes.labels.app:log-generator&size=1&pretty" | head -20
echo ""
```

---

## 第8步：最終驗證和報告

### 8.1 完整系統狀態檢查

```bash
echo "=== 第8步：最終驗證報告 ==="

echo "1. 所有 ELK Stack 組件狀態:"
kubectl get pods -n elk-stack -o wide
echo ""

echo "2. Filebeat DaemonSet 狀態:"
kubectl get daemonset filebeat -n elk-stack
echo ""

echo "3. Elasticsearch 叢集健康:"
kubectl exec elasticsearch-es-master-0 -n elk-stack -- \
  curl -k -s -u "admin:Systex123!" \
  https://localhost:9200/_cluster/health | jq '.status, .number_of_nodes, .active_primary_shards' 2>/dev/null || echo "健康檢查執行中..."
echo ""

echo "4. Filebeat 索引統計:"
kubectl exec elasticsearch-es-master-0 -n elk-stack -- \
  curl -k -s -u "admin:Systex123!" \
  "https://localhost:9200/_cat/indices?v" | grep filebeat | wc -l | xargs echo "Filebeat 索引數量:"
echo ""
```

### 8.2 性能監控

```bash
echo "5. 系統資源使用:"
kubectl top pods -n elk-stack 2>/dev/null | grep filebeat || echo "Metrics server 不可用"
echo ""

echo "6. Filebeat 處理統計:"
FILEBEAT_POD=$(kubectl get pods -l app=filebeat -n elk-stack -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$FILEBEAT_POD" ]; then
    kubectl logs $FILEBEAT_POD -n elk-stack --tail=5 | grep -i "events\|monitoring" | tail -2
fi
echo ""
```

---

## 第9步：Kibana 訪問和配置

### 9.1 Kibana 連接測試

```bash
echo "=== 第9步：Kibana 配置指引 ==="

echo "1. Kibana 連接測試:"
timeout 10 curl -k -I https://172.21.169.71:5601/login 2>/dev/null && echo "✅ Kibana 可訪問" || echo "❌ Kibana 連接失敗"
echo ""

echo "2. 訪問資訊:"
echo "🌐 Kibana URL: https://172.21.169.71:5601"
echo "👤 Username: admin"
echo "🔑 Password: Systex123!"
echo ""

echo "3. 索引模式配置:"
echo "- 進入 Stack Management > Data > Index Management"
echo "- 創建 Index Pattern: filebeat-*"
echo "- 選擇時間字段: @timestamp"
echo "- 進入 Discover 頁面開始分析日誌"
echo ""
```

### 9.2 常用搜尋範例

```bash
echo "4. 常用 Kibana 搜尋範例:"
echo "- 所有錯誤日誌: message:ERROR"
echo "- 特定應用日誌: kubernetes.labels.app:log-generator"
echo "- 特定命名空間: kubernetes.namespace:elk-stack"
echo "- 時間範圍: @timestamp:[now-1h TO now]"
echo ""
```

---

## 第10步：清理測試資源（可選）

### 10.1 清理測試應用

```bash
echo "=== 第10步：清理測試資源（可選） ==="

read -p "是否要清理測試應用？ (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    kubectl delete deployment log-generator -n elk-stack
    echo "✅ 測試應用已清理"
else
    echo "保留測試應用以供持續日誌生成"
fi
```

### 10.2 清理配置文件

```bash
echo ""
echo "清理部署配置文件:"
rm -f filebeat-rbac.yaml filebeat-config.yaml filebeat-daemonset.yaml test-app.yaml
echo "✅ 配置文件已清理"
```

---

## 故障排除指南

### 常見問題和解決方案

#### 1. Pod 狀態異常
```bash
# 檢查 Pod 詳細狀態
kubectl describe pods -l app=filebeat -n elk-stack

# 檢查 Pod 日誌
kubectl logs -l app=filebeat -n elk-stack --previous
```

#### 2. 健康檢查失敗
```bash
# 檢查端口是否可用
kubectl exec $(kubectl get pods -l app=filebeat -n elk-stack -o jsonpath='{.items[0].metadata.name}') -n elk-stack -- netstat -tlnp | grep 5066
```

#### 3. 日誌收集異常
```bash
# 檢查 Elasticsearch 連接
kubectl exec $(kubectl get pods -l app=filebeat -n elk-stack -o jsonpath='{.items[0].metadata.name}') -n elk-stack -- curl -k -u "admin:Systex123!" https://elasticsearch-es-http.elk-stack.svc.cluster.local:9200/_cluster/health
```

#### 4. 權限問題
```bash
# 重新創建 RBAC
kubectl delete clusterrole filebeat
kubectl delete clusterrolebinding filebeat
kubectl delete sa filebeat -n elk-stack
# 然後重新執行第2步
```

---

## 成功驗證標準

### ✅ **部署成功指標**

- **Pod 狀態**: 所有 Filebeat Pod 為 `1/1 Running`
- **健康檢查**: HTTP 端點 5066 可訪問
- **Elasticsearch 連接**: 成功連接並認證
- **索引創建**: 出現 `filebeat-YYYY.MM.DD` 格式索引
- **日誌收集**: 能在索引中搜尋到容器日誌
- **Kibana 顯示**: 在 Discover 頁面能看到日誌數據

### 📊 **性能指標**

- **處理延遲**: 日誌從生成到索引 < 30秒
- **資源使用**: CPU < 500m, Memory < 512Mi（每個 Pod）
- **索引速率**: 穩定增長，無明顯停滯
- **錯誤率**: 日誌中無持續的連接或處理錯誤

---

## 維護建議

### 日常監控命令

```bash
# 創建日常監控腳本
cat > check-filebeat.sh << 'EOF'
#!/bin/bash
echo "=== Filebeat 日常檢查 $(date) ==="
echo "Pod 狀態:"
kubectl get pods -l app=filebeat -n elk-stack
echo ""
echo "最新日誌:"
kubectl logs -l app=filebeat -n elk-stack --tail=3
echo ""
echo "索引統計:"
kubectl exec elasticsearch-es-master-0 -n elk-stack -- curl -k -s -u "admin:Systex123!" "https://localhost:9200/_cat/indices?v" | grep filebeat | tail -3
EOF

chmod +x check-filebeat.sh
echo "監控腳本已創建: ./check-filebeat.sh"
```

**🎉 Filebeat 重新部署完成！**

您現在擁有一個完全重新部署、配置優化的 Filebeat 系統，能夠穩定收集 Kubernetes 容器日誌並發送到 Elasticsearch 進行索引和分析。