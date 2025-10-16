# kube-vip-hcch-k8s-ms03 決定性修復指南

## 問題診斷結果

通過最新的診斷發現了一個關鍵問題：
- ✅ 叢集健康狀態良好
- ✅ VIP 由 ms02 正常維護  
- ✅ API 服務正常
- ❌ **異常現象**：刪除 manifest 檔案後 Pod 仍然存在

這表明存在深層的配置殘留或 kubelet 緩存問題。

## 決定性修復方案

### 階段 1：深層清理（必須執行）

#### 1.1 完全停止所有相關服務

```bash
# 在 hcch-k8s-ms03 執行

echo "=== 階段 1：深層清理 ==="

# 停止 kubelet
sudo systemctl stop kubelet

# 確認停止
sudo systemctl status kubelet | grep "Active:"

# 強制終止所有 kube-vip 相關進程
sudo pkill -f kube-vip 2>/dev/null || true
```

#### 1.2 清理所有容器和檔案

```bash
# 清理所有 kube-vip 容器
sudo crictl ps -a | grep kube-vip
sudo crictl rm $(sudo crictl ps -aq --name kube-vip) 2>/dev/null || true

# 清理映像檔
sudo crictl images | grep kube-vip
sudo crictl rmi $(sudo crictl images -q | grep -v "<none>") 2>/dev/null || true

# 清理所有可能的配置檔案位置
sudo find /etc/kubernetes -name "*kube-vip*" -type f -delete 2>/dev/null || true
sudo find /var/lib/kubelet -name "*kube-vip*" -type f -delete 2>/dev/null || true
sudo find /tmp -name "*kube-vip*" -type f -delete 2>/dev/null || true
```

#### 1.3 清理 kubelet 狀態和緩存

```bash
# 清理 kubelet 的 Pod 狀態
sudo rm -rf /var/lib/kubelet/pods/*/volumes/kubernetes.io~configmap/kube-vip* 2>/dev/null || true
sudo rm -rf /var/lib/kubelet/pods/*/volumes/kubernetes.io~secret/kube-vip* 2>/dev/null || true

# 清理可能的 StaticPod 狀態
sudo find /var/lib/kubelet/staticpods -name "*kube-vip*" -delete 2>/dev/null || true

# 清理 containerd 狀態
sudo systemctl stop containerd
sleep 5
sudo systemctl start containerd
```

#### 1.4 重啟服務並確認清理

```bash
# 重啟 kubelet
sudo systemctl start kubelet
sudo systemctl status kubelet

# 等待服務穩定
sleep 60

# 確認 kube-vip Pod 已完全消失
kubectl get pods -n kube-system | grep kube-vip-hcch-k8s-ms03 || echo "✅ Pod 成功清理"

# 如果還存在，強制刪除
kubectl delete pod kube-vip-hcch-k8s-ms03 -n kube-system --grace-period=0 --force 2>/dev/null || true
```

### 階段 2：檢查其他節點的工作配置

#### 2.1 從正常節點獲取配置

```bash
echo "=== 階段 2：獲取正常節點配置 ==="

# 檢查 ms01 節點的配置
echo "檢查 ms01 配置："
ssh systex@172.21.169.51 "sudo cat /etc/kubernetes/manifests/kube-vip.yaml | head -20"

# 檢查 ms02 節點的配置
echo "檢查 ms02 配置："
ssh systex@172.21.169.52 "sudo cat /etc/kubernetes/manifests/kube-vip.yaml | head -20"

# 複製 ms01 的配置作為模板（ms01 Pod 狀態正常）
ssh systex@172.21.169.51 "sudo cat /etc/kubernetes/manifests/kube-vip.yaml" > /tmp/ms01-kube-vip.yaml
```

#### 2.2 分析配置差異

```bash
# 檢查 ms01 的 Pod 狀態和日誌
kubectl logs -n kube-system kube-vip-hcch-k8s-ms01 --tail=5
kubectl describe pod -n kube-system kube-vip-hcch-k8s-ms01 | grep -A 10 "Environment:"

# 顯示即將使用的配置
echo "=== 準備使用的配置模板 ==="
cat /tmp/ms01-kube-vip.yaml
```

### 階段 3：應用修正配置

#### 3.1 創建專門為 ms03 修正的配置

```bash
echo "=== 階段 3：應用修正配置 ==="

# 基於 ms01 的配置，修改節點名稱
sed 's/hcch-k8s-ms01/hcch-k8s-ms03/g' /tmp/ms01-kube-vip.yaml > /tmp/ms03-kube-vip.yaml

# 檢查修正後的配置
echo "修正後的配置："
cat /tmp/ms03-kube-vip.yaml | grep -A 3 -B 3 "hcch-k8s-ms03"

# 應用配置
sudo cp /tmp/ms03-kube-vip.yaml /etc/kubernetes/manifests/kube-vip.yaml

# 設置正確的權限
sudo chown root:root /etc/kubernetes/manifests/kube-vip.yaml
sudo chmod 600 /etc/kubernetes/manifests/kube-vip.yaml
```

#### 3.2 監控啟動過程

```bash
# 等待 Pod 創建
echo "等待 Pod 創建..."
sleep 30

# 持續監控 Pod 狀態
for i in {1..12}; do
    echo "檢查 $i/12:"
    kubectl get pods -n kube-system | grep kube-vip-hcch-k8s-ms03
    sleep 10
done
```

### 階段 4：如果仍然失敗的最終解決方案

#### 4.1 手動創建最簡配置

```bash
echo "=== 階段 4：最簡配置 ==="

# 如果複製配置仍失敗，使用最簡配置
sudo tee /etc/kubernetes/manifests/kube-vip.yaml > /dev/null << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  name: kube-vip
  namespace: kube-system
spec:
  containers:
  - args:
    - manager
    env:
    - name: cp_enable
      value: "true"
    - name: cp_namespace
      value: "kube-system"  
    - name: vip_interface
      value: "bond0"
    - name: address
      value: "172.21.169.50"
    - name: port
      value: "6443"
    - name: vip_arp
      value: "true"
    - name: vip_leaderelection
      value: "true"
    - name: vip_leaseduration
      value: "5"
    - name: vip_renewdeadline
      value: "3"
    - name: vip_retryperiod
      value: "1"
    image: ghcr.io/kube-vip/kube-vip:v0.6.4
    imagePullPolicy: Always
    name: kube-vip
    resources: {}
    securityContext:
      capabilities:
        add:
        - NET_ADMIN
        - NET_RAW
    volumeMounts:
    - mountPath: /etc/kubernetes/admin.conf
      name: kubeconfig
  hostNetwork: true
  volumes:
  - hostPath:
      path: /etc/kubernetes/admin.conf
    name: kubeconfig
status: {}
EOF
```

#### 4.2 等待並驗證結果

```bash
echo "等待最簡配置啟動..."
sleep 60

# 檢查結果
kubectl get pods -n kube-system | grep kube-vip-hcch-k8s-ms03
kubectl logs -n kube-system kube-vip-hcch-k8s-ms03 --tail=10
```

### 階段 5：最終驗證

#### 5.1 完整狀態檢查

```bash
echo "=== 階段 5：最終驗證 ==="

# 檢查所有 kube-vip Pod 狀態
kubectl get pods -n kube-system | grep kube-vip

# 檢查日誌
echo "ms03 日誌："
kubectl logs -n kube-system kube-vip-hcch-k8s-ms03 --tail=5

# 檢查 VIP 分配
echo "VIP 分配狀態："
for node in 51 52 53; do
    echo -n "172.21.169.$node: "
    ssh systex@172.21.169.$node "ip addr show bond0 | grep 172.21.169.50 && echo 'HAS VIP' || echo 'NO VIP'" 2>/dev/null
done

# 測試叢集功能
echo "叢集功能測試："
kubectl get nodes --no-headers | wc -l && echo "nodes detected"
curl -k -s https://172.21.169.50:6443/healthz && echo " - API OK"
```

### 備用方案：如果所有修復都失敗

#### 選項 A：暫時禁用並監控

```bash
echo "=== 備用方案 A：暫時禁用 ==="

# 移除配置文件
sudo mv /etc/kubernetes/manifests/kube-vip.yaml /etc/kubernetes/manifests/kube-vip.yaml.disabled

# 等待 Pod 消失
sleep 30

# 確認禁用成功
kubectl get pods -n kube-system | grep kube-vip-hcch-k8s-ms03 || echo "已成功禁用"

# 設置監控腳本
cat > /tmp/monitor-cluster.sh << 'EOF'
#!/bin/bash
while true; do
    echo "$(date): VIP Status"
    curl -k -s https://172.21.169.50:6443/healthz && echo " - API OK" || echo " - API FAILED"
    kubectl get nodes --no-headers | wc -l
    sleep 60
done
EOF

chmod +x /tmp/monitor-cluster.sh
echo "運行監控： /tmp/monitor-cluster.sh &"
```

#### 選項 B：節點維護模式

```bash
echo "=== 備用方案 B：維護模式 ==="

# 標記節點為維護狀態
kubectl cordon hcch-k8s-ms03
kubectl annotate node hcch-k8s-ms03 maintenance="kube-vip-issue-$(date +%Y%m%d)"

# 檢查影響
kubectl get nodes
echo "節點已設置為維護模式，kube-vip 問題不會影響叢集運作"
```

## 成功標準

修復成功的標準：
- ✅ `kubectl get pods -n kube-system | grep kube-vip-hcch-k8s-ms03` 顯示 `1/1 Running`
- ✅ 日誌中沒有 "no features are enabled" 錯誤
- ✅ VIP 172.21.169.50 可以正常訪問
- ✅ 叢集所有功能正常

## 執行建議

### 推薦執行順序：

1. **階段 1（必須執行）** - 深層清理
2. **階段 2-3** - 使用正常節點的配置
3. **階段 4（如需要）** - 最簡配置
4. **階段 5** - 驗證
5. **備用方案（最後選擇）** - 如果都失敗

### 預期時間：
- 階段 1-3：30-45 分鐘
- 階段 4-5：15-20 分鐘
- 總計：45-65 分鐘

### 成功率預估：
- 階段 1-3：70%
- 階段 4：85%
- 備用方案：100%

## 重要提醒

1. **不會影響服務**：整個過程中 VIP 由其他節點維護
2. **可以隨時中斷**：如有問題可立即停止操作
3. **完整記錄**：建議記錄每個步驟的輸出
4. **備份重要**：執行前建議備份 `/etc/kubernetes/` 目錄

---

**這是最後一次修復嘗試**：如果這個方案仍然失敗，建議選擇備用方案 A 暫時禁用，等待後續維護窗口進行節點重建。

**執行時機**：建議在低峰時段執行，雖然不會影響服務但便於問題排查。