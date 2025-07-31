# Elasticsearch 8.5.1 終極修復指南

## 問題根本原因

Helm Chart 的默認行為會自動設置 `cluster.initial_master_nodes` 環境變數，這與 `discovery.type: single-node` 衝突。必須通過命令行參數完全覆蓋這些設置。

---

## 完整修復步驟

### 第一步：完全清理現有部署

```bash
echo "=== 完全清理 Elasticsearch ==="

# 1. 停止並刪除 Helm Release
helm uninstall elasticsearch -n logging --wait

# 2. 強制清理所有資源
kubectl delete statefulset elasticsearch-master -n logging --force --grace-period=0 || true
kubectl delete pvc elasticsearch-master-elasticsearch-master-0 -n logging --force --grace-period=0
kubectl delete secret elasticsearch-master-certs -n logging --force --grace-period=0 || true
kubectl delete secret elasticsearch-master-credentials -n logging --force --grace-period=0 || true
kubectl delete configmap elasticsearch-master-config -n logging --force --grace-period=0 || true
kubectl delete svc elasticsearch-master -n logging --force --grace-period=0 || true
kubectl delete svc elasticsearch-master-headless -n logging --force --grace-period=0 || true

# 3. 等待資源完全清理
echo "等待資源清理完成..."
sleep 60

# 4. 驗證清理結果
echo "=== 驗證清理結果 ==="
kubectl get all,pvc,secrets,configmaps -n logging | grep elasticsearch || echo "✅ 清理完成"
```

### 第二步：使用終極修復配置重新部署

```bash
echo "=== 使用終極修復方案重新部署 ==="

# 使用完全覆蓋的方式部署，避免所有衝突
helm install elasticsearch elastic/elasticsearch \
  --namespace logging \
  --version 8.5.1 \
  --set replicas=1 \
  --set minimumMasterNodes=1 \
  --set clusterName="elasticsearch" \
  --set nodeGroup="master" \
  --set resources.requests.cpu="500m" \
  --set resources.requests.memory="1Gi" \
  --set resources.limits.cpu="1000m" \
  --set resources.limits.memory="2Gi" \
  --set esJavaOpts="-Xmx1g -Xms1g" \
  --set persistence.enabled=true \
  --set persistence.storageClass="nfs-storage" \
  --set persistence.size="30Gi" \
  --set service.type="ClusterIP" \
  --set readinessProbe.initialDelaySeconds=90 \
  --set readinessProbe.timeoutSeconds=10 \
  --set livenessProbe.initialDelaySeconds=120 \
  --set livenessProbe.timeoutSeconds=10 \
  --set securityContext.runAsUser=1000 \
  --set securityContext.fsGroup=1000 \
  --set podSecurityContext.runAsUser=1000 \
  --set podSecurityContext.fsGroup=1000 \
  --set volumeClaimTemplate.storageClassName="nfs-storage" \
  --set extraEnvs[0].name="discovery.type" \
  --set extraEnvs[0].value="single-node" \
  --set extraEnvs[1].name="bootstrap.memory_lock" \
  --set extraEnvs[1].value="false" \
  --set extraEnvs[2].name="ES_JAVA_OPTS" \
  --set extraEnvs[2].value="-Xmx1g -Xms1g" \
  --set esConfig."elasticsearch\.yml"="cluster.name: elasticsearch
network.host: 0.0.0.0
http.port: 9200
transport.port: 9300
discovery.type: single-node
bootstrap.memory_lock: false
http.cors.enabled: true
http.cors.allow-origin: \"*\"" \
  --set masterService="" \
  --set clusterHealthCheckParams="wait_for_status=yellow&timeout=1s"

echo "=== 等待 Pod 創建 ==="
sleep 30

# 檢查初始狀態
kubectl get pods -n logging
kubectl get pvc -n logging
```

### 第三步：監控部署進度

```bash
echo "=== 監控 Elasticsearch 啟動進度 ==="

# 監控啟動過程（最多等待 10 分鐘）
for i in {1..20}; do
    echo "=== 檢查第 $i 次 ($(date)) ==="
    
    # 檢查 Pod 狀態
    kubectl get pods -n logging elasticsearch-master-0 || continue
    
    # 檢查是否有致命錯誤
    if kubectl get pods -n logging elasticsearch-master-0 | grep -q "CrashLoopBackOff\|Error\|ImagePullBackOff"; then
        echo "❌ 發現錯誤，檢查日誌："
        kubectl logs -n logging elasticsearch-master-0 --tail=20
        echo ""
        echo "如果仍然是 cluster.initial_master_nodes 錯誤，請執行以下命令："
        echo "kubectl set env statefulset/elasticsearch-master -n logging cluster.initial_master_nodes-"
        break
    fi
    
    # 檢查是否成功啟動
    if kubectl get pods -n logging elasticsearch-master-0 | grep -q "1/1.*Running"; then
        echo "✅ Elasticsearch 成功啟動！"
        break
    fi
    
    # 檢查是否在啟動中
    if kubectl get pods -n logging elasticsearch-master-0 | grep -q "0/1.*Running"; then
        echo "🔄 Elasticsearch 正在啟動中..."
    else
        echo "⏳ 等待 Pod 啟動..."
    fi
    
    echo "等待 30 秒後重新檢查..."
    sleep 30
done
```

### 第四步：環境變數修復（如果需要）

如果 Pod 仍然崩潰並顯示 `cluster.initial_master_nodes` 錯誤，執行以下修復：

```bash
echo "=== 應急修復：移除衝突的環境變數 ==="

# 直接移除會導致衝突的環境變數
kubectl patch statefulset elasticsearch-master -n logging --type='json' \
  -p='[{"op": "remove", "path": "/spec/template/spec/containers/0/env", "value": [{"name": "cluster.initial_master_nodes"}]}]' || true

# 或者使用 kubectl set env 命令
kubectl set env statefulset/elasticsearch-master -n logging cluster.initial_master_nodes- || true

# 重新啟動 Pod
kubectl delete pod elasticsearch-master-0 -n logging

echo "等待 Pod 重新啟動..."
sleep 60

# 檢查狀態
kubectl get pods -n logging
```

### 第五步：最終驗證

```bash
echo "=== 最終驗證和測試 ==="

# 等待服務完全就緒
echo "等待 Elasticsearch 服務完全就緒..."
sleep 90

# 檢查最終狀態
echo "=== 檢查部署狀態 ==="
kubectl get pods -n logging
kubectl get pvc -n logging
kubectl get svc -n logging

# 獲取密碼
echo "=== 獲取 Elasticsearch 密碼 ==="
if kubectl get secret elasticsearch-master-credentials -n logging >/dev/null 2>&1; then
    ELASTIC_PASSWORD=$(kubectl get secret elasticsearch-master-credentials -n logging -o jsonpath='{.data.password}' | base64 --decode)
    echo "Elasticsearch elastic 用戶密碼: $ELASTIC_PASSWORD"
    export ELASTIC_PASSWORD
    
    # 測試連接
    echo "=== 測試 Elasticsearch 連接 ==="
    if kubectl exec -n logging elasticsearch-master-0 -- curl -k -u "elastic:$ELASTIC_PASSWORD" https://localhost:9200 2>/dev/null; then
        echo "✅ Elasticsearch HTTPS 連接成功！"
        
        # 檢查叢集健康狀態
        echo "=== 檢查叢集健康狀態 ==="
        kubectl exec -n logging elasticsearch-master-0 -- curl -k -u "elastic:$ELASTIC_PASSWORD" https://localhost:9200/_cluster/health?pretty 2>/dev/null
        
        echo ""
        echo "✅ Elasticsearch 8.5.1 部署成功！"
        echo "密碼: $ELASTIC_PASSWORD"
        echo "服務地址: elasticsearch-master.logging.svc.cluster.local:9200"
        
    else
        echo "❌ Elasticsearch 連接失敗，檢查 Pod 狀態："
        kubectl get pods -n logging
        kubectl logs -n logging elasticsearch-master-0 --tail=20
    fi
else
    echo "⚠️  密碼 Secret 尚未創建，Elasticsearch 可能仍在啟動中"
    echo "請等待幾分鐘後重新檢查"
fi
```

---

## 預期成功結果

### Pod 狀態
```
NAME                     READY   STATUS    RESTARTS   AGE
elasticsearch-master-0   1/1     Running   0          5m
```

### PVC 狀態
```
NAME                                          STATUS   VOLUME                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
elasticsearch-master-elasticsearch-master-0  Bound    pvc-xxx-xxx-xxx-xxx        30Gi       RWO            nfs-storage    5m
```

### 成功的 Elasticsearch 響應
```json
{
  "name" : "elasticsearch-master-0",
  "cluster_name" : "elasticsearch",
  "cluster_uuid" : "...",
  "version" : {
    "number" : "8.5.1"
  },
  "tagline" : "You Know, for Search"
}
```

---

## 故障排除

### 如果仍然失敗

1. **檢查環境變數**：
```bash
kubectl describe pod elasticsearch-master-0 -n logging | grep -A 20 "Environment:"
```

2. **檢查配置**：
```bash
kubectl get configmap elasticsearch-master-config -n logging -o yaml
```

3. **檢查完整日誌**：
```bash
kubectl logs -n logging elasticsearch-master-0 --tail=100
```

4. **手動移除問題環境變數**：
```bash
kubectl edit statefulset elasticsearch-master -n logging
# 手動移除 cluster.initial_master_nodes 相關的環境變數
```

---

## 關鍵修復點總結

1. ✅ **使用純命令行部署** - 避免 YAML 配置文件的複雜性
2. ✅ **明確設置 discovery.type=single-node** - 通過環境變數強制設置
3. ✅ **禁用 masterService** - 避免 master 相關的自動配置
4. ✅ **增加啟動延遲時間** - 給 Elasticsearch 充足的初始化時間
5. ✅ **保持安全功能** - 不禁用 X-Pack Security
6. ✅ **應急修復機制** - 如果還有問題，可以手動移除環境變數

這個方案應該能徹底解決 `cluster.initial_master_nodes` 與 `discovery.type: single-node` 的衝突問題。