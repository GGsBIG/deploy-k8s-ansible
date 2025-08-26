# Kubernetes 集群套件版本清單

## 📋 概述
本文檔記錄了 Kubernetes 集群中部署的所有套件及其版本信息，包含核心組件、監控系統、日誌管理、追蹤工具和管理界面。

---

## 🚀 核心 Kubernetes 組件

| 套件名稱 | 版本 | 類型 | 描述 |
|---------|------|------|------|
| **Kubernetes** | v1.32.4 | 容器編排 | 包含 kubelet, kubeadm, kubectl |
| **containerd** | v2.1.3 | 容器運行時 | 容器運行時引擎 |
| **runc** | v1.3.0 | 容器運行時 | 低階容器運行時 |
| **CNI plugins** | v1.7.1 | 網絡插件 | 容器網絡接口插件 |
| **Calico CNI** | v3.29.4 / v3.30.2 | 網絡解決方案 | 網絡策略和路由 |
| **kube-vip** | 最新版本 | 高可用性 | 虛擬 IP 管理 |

---

## 🌐 Ingress 控制器

| 套件名稱 | 版本 | 服務 IP | 端口 | 描述 |
|---------|------|---------|------|------|
| **Nginx Ingress Controller** | v4.11.3 | 172.21.169.73 | 80/443 | HTTP/HTTPS 路由 |
| **Istio Control Plane** | 最新版本 | - | - | 服務網格控制平面 |
| **Istio Ingress Gateway** | 最新版本 | 172.21.169.72 | 80/443 | 服務網格入口 |

---

## 📊 監控系統

| 套件名稱 | 版本 | 服務 IP | 端口 | 描述 |
|---------|------|---------|------|------|
| **Prometheus Stack** | v61.1.1 | 172.21.169.75 | 9090 | 監控數據收集 |
| **Grafana** | v8.5.1 | 172.21.169.74 | 3000 | 監控視覺化儀表板 |
| **AlertManager** | 包含在 Prometheus Stack | - | 9093 | 告警管理 |
| **Node Exporter** | 包含在 Prometheus Stack | - | 9100 | 節點指標收集 |
| **Kube State Metrics** | 包含在 Prometheus Stack | - | 8080 | Kubernetes 資源指標 |

---

## 🔍 分散式追蹤

| 套件名稱 | 版本 | 服務 IP | 端口 | 描述 |
|---------|------|---------|------|------|
| **Jaeger Operator** | v1.57.0 | - | - | Jaeger 管理員 |
| **Jaeger All-in-One** | v1.57 | 172.21.169.82 | 16686 | 分散式追蹤 UI |
| **Jaeger Collector** | v1.57 | - | 14268/14250 | 追蹤數據收集器 |
| **Zipkin Endpoint** | v1.57 | - | 9411 | Zipkin 兼容端點 |

---

## 🕸️ 服務網格可觀測性

| 套件名稱 | 版本 | 服務 IP | 端口 | 描述 |
|---------|------|---------|------|------|
| **Kiali** | v1.86.0 | 172.21.169.77 | 20001 | 服務網格視覺化 |
| **Kiali Operator** | v1.86.0 | - | - | Kiali 管理員 |

---

## 📝 日誌管理 (ELK Stack)

| 套件名稱 | 版本 | 服務 IP | 端口 | 描述 |
|---------|------|---------|------|------|
| **Elasticsearch** | v8.5.1 | - | 9200 | 搜索和分析引擎 |
| **Kibana** | v8.5.1 | 172.21.169.71 | 5601 | 日誌搜索和視覺化 |
| **Filebeat** | v8.5.1 | - | - | 日誌收集器 |

---

## 🛠️ 管理工具

| 套件名稱 | 版本 | 服務 IP | 端口 | 描述 |
|---------|------|---------|------|------|
| **Kubernetes Dashboard** | v2.7.0 | 172.21.169.81 | 8443 | 集群管理界面 |
| **Swagger UI** | v5.9.0 | 172.21.169.79 | 8080 | API 文檔和測試 |

---

## 🔧 基礎設施組件

| 套件名稱 | 版本 | 描述 |
|---------|------|------|
| **MetalLB** | v0.13.12 | 負載均衡器 |
| **NFS Provisioner** | - | 動態持久化存儲 |
| **chrony** | 最新 | 時間同步服務 |

---

## 📦 系統套件

| 套件名稱 | 版本 | 描述 |
|---------|------|------|
| **jq** | 最新 | JSON 處理工具 |
| **curl** | 最新 | HTTP 客戶端 |
| **apt-transport-https** | 最新 | APT HTTPS 支援 |
| **ca-certificates** | 最新 | CA 證書 |
| **gpg** | 最新 | GPG 加密工具 |

---

## 🌍 網絡配置

| 配置項目 | 值 | 描述 |
|---------|---|------|
| **Pod CIDR** | 10.244.0.0/16 | Pod 網段 |
| **Service CIDR** | 10.96.0.0/16 | 服務網段 |
| **Control Plane Endpoint** | 10.10.7.216:6443 | 控制平面端點 |
| **kube-vip VIP** | 10.10.7.216 | 虛擬 IP 地址 |

---

## 📍 服務 IP 分配表

| 服務名稱 | IP 地址 | 端口 | 協議 | 用途 |
|---------|---------|------|------|------|
| **Nginx Ingress** | 172.21.169.73 | 80/443 | HTTP/HTTPS | 入口控制器 |
| **Istio Ingress** | 172.21.169.72 | 80/443 | HTTP/HTTPS | 服務網格入口 |
| **Prometheus** | 172.21.169.75 | 9090 | HTTP | 監控數據收集 |
| **Grafana** | 172.21.169.74 | 3000 | HTTP | 監控視覺化 |
| **Jaeger UI** | 172.21.169.82 | 16686 | HTTP | 分散式追蹤 |
| **Kiali** | 172.21.169.77 | 20001 | HTTP | 服務網格視覺化 |
| **Kibana** | 172.21.169.71 | 5601 | HTTP | 日誌搜索 |
| **K8s Dashboard** | 172.21.169.81 | 8443 | HTTPS | 集群管理 |
| **Swagger UI** | 172.21.169.79 | 8080 | HTTP | API 文檔 |

---

## 🔄 版本管理說明

### 固定版本
- 所有 Helm Chart 使用固定版本號確保部署一致性
- Kubernetes 組件版本已鎖定 (apt-mark hold)

### 動態版本
- **kube-vip**: 自動獲取 GitHub 最新 release
- **Istio**: 使用 istioctl 下載最新穩定版

### 存儲配置
- **StorageClass**: nfs-storage
- **存儲後端**: NFS Server
- **持久化卷**: ReadWriteOnce

---

## 📝 部署順序

1. **系統準備** → 時間同步、內核模組、網絡配置
2. **容器運行時** → containerd + runc + CNI
3. **Kubernetes 核心** → kubelet, kubeadm, kubectl
4. **kube-vip** → 高可用性虛擬 IP
5. **集群初始化** → kubeadm init + Calico CNI
6. **Ingress** → Nginx Ingress + Istio
7. **監控** → Prometheus + Grafana
8. **追蹤** → Jaeger + Kiali
9. **日誌** → Elasticsearch + Kibana + Filebeat
10. **管理工具** → Dashboard + Swagger UI

---

## 🏷️ 標籤和註解

### Helm Repository
- `ingress-nginx`: https://kubernetes.github.io/ingress-nginx
- `prometheus-community`: https://prometheus-community.github.io/helm-charts
- `grafana`: https://grafana.github.io/helm-charts
- `kiali`: https://kiali.org/helm-charts
- `elastic`: https://helm.elastic.co

### 重要註解
- `metallb.universe.tf/loadBalancerIPs`: MetalLB IP 分配
- `prometheus.io/scrape`: Prometheus 自動發現
- `istio-injection=enabled`: Istio Sidecar 注入

---

## 📚 相關文檔

- [Kubernetes 官方文檔](https://kubernetes.io/docs/)
- [Istio 文檔](https://istio.io/latest/docs/)
- [Prometheus 文檔](https://prometheus.io/docs/)
- [Grafana 文檔](https://grafana.com/docs/)
- [Jaeger 文檔](https://www.jaegertracing.io/docs/)
- [Elastic Stack 文檔](https://www.elastic.co/guide/)

---

**最後更新**: 2025-08-21  
**集群名稱**: ETTTT  
**環境**: 生產環境  
**節點數量**: 6 個 (3 Master + 3 Worker)