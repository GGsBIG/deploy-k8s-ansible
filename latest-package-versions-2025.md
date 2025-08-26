# Kubernetes 集群套件最新版本清單 (2025年8月)

## 📋 概述
本文檔記錄了 2025年8月最新的 Kubernetes 集群套件版本信息，包含當前使用版本與最新可用版本的對比。

---

## 🚀 核心 Kubernetes 組件

| 套件名稱 | 當前版本 | **最新版本 (2025)** | 升級建議 |
|---------|---------|-------------------|---------|
| **Kubernetes** | v1.32.4 | **v1.33.4** | ✅ 可升級 |
| **containerd** | v2.1.3 | **v2.1.4** | ✅ 可升級 |
| **runc** | v1.3.0 | **v1.3.0** | ✅ 最新 |
| **CNI plugins** | v1.7.1 | **v1.7.1** | ✅ 最新 |
| **Calico CNI** | v3.29.4 / v3.30.2 | **v3.30.2** | ✅ 最新 |
| **kube-vip** | 最新版本 | **最新版本** | ✅ 最新 |

### 🔍 詳細說明
- **Kubernetes v1.33.4**: 2025年8月12日發布，支持到2026年6月28日
- **Kubernetes v1.34**: 預計2025年8月27日發布
- **containerd v2.1.4**: 修復多項安全漏洞和錯誤

---

## 🌐 Ingress 控制器

| 套件名稱 | 當前版本 | **最新版本 (2025)** | 服務 IP | 升級建議 |
|---------|---------|-------------------|---------|---------|
| **Nginx Ingress Controller** | v4.11.3 | **v4.13.1** | 172.21.169.73 | ⚠️ 建議升級 |
| **Istio Control Plane** | 最新版本 | **v1.27.0** | - | ✅ 最新 |
| **Istio Ingress Gateway** | 最新版本 | **v1.27.0** | 172.21.169.72 | ✅ 最新 |

### 🔍 詳細說明
- **Nginx Ingress v4.13.1**: 支援 Kubernetes v1.33.3，包含安全更新
- **Istio v1.27.0**: 2025年8月11日發布，支援 Gateway API Inference Extension

---

## 📊 監控系統

| 套件名稱 | 當前版本 | **最新版本 (2025)** | 服務 IP | 升級建議 |
|---------|---------|-------------------|---------|---------|
| **Prometheus Stack** | v61.1.1 | **v76.4.0** | 172.21.169.75 | ⚠️ 重要升級 |
| **Grafana** | v8.5.1 | **v9.3.2+** | 172.21.169.74 | ⚠️ 重要升級 |
| **AlertManager** | 包含在 Stack | **最新 (Stack)** | - | ⚠️ 跟隨 Stack |
| **Node Exporter** | 包含在 Stack | **最新 (Stack)** | - | ⚠️ 跟隨 Stack |

### 🔍 詳細說明
- **kube-prometheus-stack v76.4.0**: 包含重要安全更新和新功能
- **Grafana**: 建議升級到最新版本以獲得更好的性能和安全性

---

## 🔍 分散式追蹤

| 套件名稱 | 當前版本 | **最新版本 (2025)** | 服務 IP | 升級建議 |
|---------|---------|-------------------|---------|---------|
| **Jaeger Operator** | v1.57.0 | **v1.65.0** | - | ⚠️ 建議升級 |
| **Jaeger All-in-One** | v1.57 | **v2.0.0** | 172.21.169.82 | 🚨 重大版本升級 |

### 🔍 詳細說明
- **Jaeger v2.0.0**: 基於 OpenTelemetry Collector，架構重大變更
- **重要**: Jaeger v1 生命週期結束時間為 2025年12月31日
- **建議**: 計劃遷移到 Jaeger v2 或 OpenTelemetry Operator

---

## 🕸️ 服務網格可觀測性

| 套件名稱 | 當前版本 | **最新版本 (2025)** | 服務 IP | 升級建議 |
|---------|---------|-------------------|---------|---------|
| **Kiali** | v1.86.0 | **v1.86.0+** | 172.21.169.77 | ✅ 檢查更新 |
| **Kiali Operator** | v1.86.0 | **v1.86.0+** | - | ✅ 檢查更新 |

### 🔍 詳細說明
- **Kiali**: 2025年4月25日有最新 Sprint 發布
- **建議**: 檢查 Helm repository 獲取最新版本

---

## 📝 日誌管理 (ELK Stack)

| 套件名稱 | 當前版本 | **最新版本 (2025)** | 服務 IP | 升級建議 |
|---------|---------|-------------------|---------|---------|
| **Elasticsearch** | v8.5.1 | **v8.5.1** | - | ⚠️ 使用 ECK |
| **Kibana** | v8.5.1 | **v8.5.1** | 172.21.169.71 | ⚠️ 使用 ECK |
| **Filebeat** | v8.5.1 | **v8.5.1** | - | ⚠️ 使用 ECK |

### 🔍 詳細說明
- **重要變更**: Elastic 官方 Helm Charts 已停止維護
- **建議**: 遷移到 ECK (Elastic Cloud on Kubernetes) 部署方式
- **ECK Chart**: 使用 `eck-stack` Helm Chart 進行部署

---

## 🛠️ 管理工具

| 套件名稱 | 當前版本 | **最新版本 (2025)** | 服務 IP | 升級建議 |
|---------|---------|-------------------|---------|---------|
| **Kubernetes Dashboard** | v2.7.0 | **v7.13.0** | 172.21.169.81 | ⚠️ 重要升級 |
| **Swagger UI** | v5.9.0 | **v5.25.4** | 172.21.169.79 | ⚠️ 建議升級 |

### 🔍 詳細說明
- **Dashboard v7.13.0**: 新架構使用 Kong Gateway，單容器部署
- **Swagger UI v5.25.4**: 支援 OpenAPI 3.1.x 規範

---

## 🔧 基礎設施組件

| 套件名稱 | 當前版本 | **最新版本 (2025)** | 升級建議 |
|---------|---------|-------------------|---------|
| **MetalLB** | v0.13.12 | **v0.15.2** | ⚠️ 重要升級 |
| **NFS Provisioner** | - | **檢查中** | ✅ 檢查更新 |

### 🔍 詳細說明
- **MetalLB v0.15.2**: 基於 distroless 映像，降低攻擊面
- **新功能**: LoadBalancerClass 支援、Layer2Service 狀態監控

---

## 📊 版本對比總結

### 🚨 需要重大升級的組件
1. **Prometheus Stack**: v61.1.1 → v76.4.0 (重要安全更新)
2. **Kubernetes Dashboard**: v2.7.0 → v7.13.0 (架構變更)
3. **Jaeger**: v1.57 → v2.0.0 (架構重大變更)
4. **MetalLB**: v0.13.12 → v0.15.2 (安全改進)

### ⚠️ 建議升級的組件
1. **Nginx Ingress**: v4.11.3 → v4.13.1
2. **Grafana**: v8.5.1 → v9.3.2+
3. **Swagger UI**: v5.9.0 → v5.25.4
4. **Kubernetes**: v1.32.4 → v1.33.4

### ✅ 已為最新版本
1. **runc**: v1.3.0
2. **CNI plugins**: v1.7.1
3. **Calico CNI**: v3.30.2
4. **Istio**: v1.27.0

---

## 🛠️ 升級計劃建議

### 第一階段：基礎設施 (優先級：高)
1. **MetalLB**: v0.13.12 → v0.15.2
2. **Kubernetes**: v1.32.4 → v1.33.4
3. **containerd**: v2.1.3 → v2.1.4

### 第二階段：監控系統 (優先級：高)
1. **Prometheus Stack**: v61.1.1 → v76.4.0
2. **Grafana**: v8.5.1 → v9.3.2+

### 第三階段：Ingress 和管理工具 (優先級：中)
1. **Nginx Ingress**: v4.11.3 → v4.13.1
2. **Kubernetes Dashboard**: v2.7.0 → v7.13.0
3. **Swagger UI**: v5.9.0 → v5.25.4

### 第四階段：專案遷移 (優先級：中-長期)
1. **ELK Stack**: 遷移到 ECK 部署方式
2. **Jaeger**: 規劃 v1 → v2 遷移 (2025年底前)

---

## ⚠️ 重要注意事項

### 🚨 生命週期警告
- **Jaeger v1**: 2025年12月31日停止支援
- **Red Hat Jaeger Operator**: 2025年11月3日從 catalog 移除

### 🔄 部署方式變更
- **Elastic Stack**: 建議使用 ECK Operator 而非傳統 Helm Charts
- **Jaeger v2**: 使用 OpenTelemetry Operator 部署

### 🛡️ 安全考量
- **MetalLB v0.15.2**: 使用 distroless 映像提升安全性
- **Prometheus Stack v76.4.0**: 包含重要安全修復
- **containerd v2.1.4**: 修復 CVE-2025-47290 漏洞

---

## 📚 升級資源

### 官方文檔
- [Kubernetes Release Notes](https://kubernetes.io/releases/)
- [Istio Upgrade Guide](https://istio.io/latest/docs/setup/upgrade/)
- [Prometheus Operator Upgrade](https://github.com/prometheus-operator/prometheus-operator)
- [ECK Documentation](https://www.elastic.co/guide/en/cloud-on-k8s/current/)

### Helm Repository 更新指令
```bash
# 更新所有 Helm Repository
helm repo update

# 檢查可用更新
helm list -A
helm search repo <chart-name> --versions
```

---

**最後更新**: 2025-08-21  
**資料來源**: 官方 GitHub Releases, Helm Charts, Docker Hub  
**下次檢查**: 2025-09-21