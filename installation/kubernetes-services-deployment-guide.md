# Kubernetes Services Deployment Guide

## 概述
本指南說明在 Kubernetes 叢集上部署各種服務的建議順序和配置，確保 IP 地址永久綁定到網卡且重開機後不會變動。

## IP 地址分配
- NFS: 172.21.169.91
- Kibana: 172.21.169.71 (HTTPS)
- Istio Ingress: 172.21.169.72
- Nginx Ingress: 172.21.169.73
- Grafana: 172.21.169.74 (HTTP)
- Prometheus: 172.21.169.75 (HTTP)
- Kiali: 172.21.169.77 (HTTP)
- PilotWave: 172.21.169.78 (HTTP)
- Swagger UI: 172.21.169.79 (HTTP)
- K8s Dashboard: 172.21.169.81 (HTTP)
- Jaeger UI: 172.21.169.82 (HTTP)

## 部署優先順序

### 第一階段：基礎設施服務
**優先級：最高**

1. **NFS Server (172.21.169.91)**
   - 目的：提供持久化儲存
   - 原因：所有需要持久化資料的服務都依賴此服務
   - 部署前置條件：無
   - 預計部署時間：30分鐘

### 第二階段：Ingress 控制器
**優先級：高**

2. **Nginx Ingress Controller (172.21.169.73)**
   - 目的：提供 HTTP/HTTPS 路由和負載平衡
   - 原因：大部分 Web 應用需要通過 Ingress 暴露服務
   - 部署前置條件：Kubernetes 叢集就緒
   - 預計部署時間：20分鐘

3. **Istio Ingress Gateway (172.21.169.72)**
   - 目的：提供服務網格入口點
   - 原因：微服務架構和進階流量管理需求
   - 部署前置條件：Istio Control Plane 安裝完成
   - 預計部署時間：45分鐘

### 第三階段：監控和可觀測性
**優先級：高**

4. **Prometheus (172.21.169.75)**
   - 目的：指標收集和監控
   - 原因：所有監控解決方案的基礎
   - 部署前置條件：NFS, Nginx Ingress
   - 預計部署時間：30分鐘

5. **Grafana (172.21.169.74)**
   - 目的：監控儀表板和視覺化
   - 原因：依賴 Prometheus 作為資料源
   - 部署前置條件：Prometheus, NFS
   - 預計部署時間：25分鐘

6. **Jaeger UI (172.21.169.82)**
   - 目的：分散式追蹤
   - 原因：微服務追蹤和效能分析
   - 部署前置條件：NFS, Nginx Ingress
   - 預計部署時間：35分鐘

### 第四階段：服務網格管理
**優先級：中**

7. **Kiali (172.21.169.77)**
   - 目的：Istio 服務網格視覺化
   - 原因：依賴 Istio 和 Prometheus
   - 部署前置條件：Istio, Prometheus, Jaeger
   - 預計部署時間：25分鐘

### 第五階段：日誌管理
**優先級：中**

8. **Kibana (172.21.169.71)**
   - 目的：日誌搜尋和視覺化
   - 原因：需要 Elasticsearch 後端
   - 部署前置條件：Elasticsearch, NFS, Nginx Ingress
   - 預計部署時間：40分鐘

### 第六階段：管理和開發工具
**優先級：中低**

9. **Kubernetes Dashboard (172.21.169.81)**
   - 目的：Kubernetes 叢集管理界面
   - 原因：叢集管理和監控
   - 部署前置條件：Nginx Ingress
   - 預計部署時間：20分鐘

10. **Swagger UI (172.21.169.79)**
    - 目的：API 文件和測試界面
    - 原因：開發和API管理
    - 部署前置條件：Nginx Ingress
    - 預計部署時間：15分鐘

### 第七階段：應用服務
**優先級：低**

11. **PilotWave (172.21.169.78)**
    - 目的：應用程式服務
    - 原因：業務邏輯應用
    - 部署前置條件：所有基礎設施服務就緒
    - 預計部署時間：取決於應用複雜度

## IP 地址永久綁定配置

### 使用 MetalLB 進行 LoadBalancer IP 分配

1. **安裝 MetalLB**
```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml
```

2. **配置 IP 地址池**
```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: production-pool
  namespace: metallb-system
spec:
  addresses:
  - 172.21.169.71-172.21.169.91
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: production-advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
  - production-pool
```

### 服務配置範例

```yaml
apiVersion: v1
kind: Service
metadata:
  name: grafana-service
  annotations:
    metallb.universe.tf/loadBalancerIPs: 172.21.169.74
spec:
  type: LoadBalancer
  loadBalancerIP: 172.21.169.74
  ports:
  - port: 80
    targetPort: 3000
  selector:
    app: grafana
```

## 網路配置注意事項

1. **防火牆規則**：確保所有指定的 IP 地址在防火牆中開放相應端口
2. **DNS 記錄**：建議為每個服務配置 DNS 記錄
3. **SSL/TLS**：HTTPS 服務需要配置適當的憑證
4. **備份策略**：NFS 和資料庫服務需要定期備份

## 驗證步驟

每個服務部署完成後，執行以下驗證：

1. 檢查 Pod 狀態：`kubectl get pods -n <namespace>`
2. 檢查 Service 狀態：`kubectl get svc -n <namespace>`
3. 檢查 IP 地址分配：`kubectl get svc -o wide`
4. 測試服務連通性：`curl -I http://<service-ip>:<port>`

## 總預計部署時間

- **第一階段**：30分鐘
- **第二階段**：65分鐘
- **第三階段**：90分鐘
- **第四階段**：25分鐘
- **第五階段**：40分鐘
- **第六階段**：35分鐘
- **第七階段**：變動

**總計：約 4-5 小時**（不包含第七階段應用服務）

## 故障排除

1. **IP 地址衝突**：確保指定的 IP 地址未被其他設備使用
2. **服務無法訪問**：檢查 NetworkPolicy 和防火牆規則
3. **持久化儲存問題**：驗證 NFS 服務和 PV/PVC 配置
4. **Ingress 路由問題**：檢查 Ingress 規則和 DNS 解析

## 建議

1. 建議在測試環境先進行完整部署測試
2. 每個階段完成後進行功能驗證再進入下一階段
3. 建立監控告警確保服務可用性
4. 定期備份配置檔案和資料