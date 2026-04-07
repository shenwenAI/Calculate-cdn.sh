# shenwenCDN - 全球分布式 AI 推理与内容分发网络

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Cloudflare Workers](https://img.shields.io/badge/Cloudflare-Workers-orange)](https://workers.cloudflare.com/)
[![AI Model](https://img.shields.io/badge/AI-shenwen--coderV2-blue)](https://huggingface.co/shenwenAI)

## 🌟 项目简介

shenwenCDN 是一个智能分布式 AI 推理网络，通过自动检测服务器的网络环境（公网/内网）和硬件性能（CPU/GPU/内存），智能分配节点角色，构建全球化的 AI 推理加速网络。

### 核心特性

- **智能角色分配**：根据公网 IP 和硬件配置自动分配节点角色（混合/计算/CDN）
- **极速模型下载**：自动测试 HuggingFace 和镜像站速度，选择最优源
- **自适应编译**：检测 GPU 并优先编译 CUDA 版本，失败自动回退 CPU
- **多语言支持**：中英文双语界面
- **实时监控面板**：基于 Cloudflare Workers + Pages 的全球节点监控
- **自动心跳注册**：节点自动注册到中央网络并定期发送心跳

## 🏗️ 系统架构

```
┌─────────────────────────────────────────────────────────────┐
│                    Cloudflare Workers                        │
│              (中央注册中心 & API 代理)                        │
│           https://shenwencdn.578388.xyz                     │
└────────────────────┬────────────────────────────────────────┘
                     │
        ┌────────────┼────────────┐
        │            │            │
   ┌────▼────┐  ┌───▼────┐  ┌───▼────┐
   │ 混合节点 │  │计算节点 │  │ CDN 节点 │
   │Hybrid   │  │Compute │  │CDN Proxy│
   │公网 + 算力│  │内网 + 算力│  │公网 + 弱算力│
   └─────────┘  └────────┘  └─────────┘
```

### 节点角色说明

| 角色 | 公网 IP | 硬件要求 | 功能 |
|------|---------|----------|------|
| **混合节点 (Hybrid)** | ✅ 有 | RAM>8G 且 (CPU>4 核 或 有 GPU) | 运行 swllm.cpp 提供 API 服务 + CDN 转发 |
| **计算节点 (Compute)** | ❌ 无 | RAM>8G 且 (CPU>4 核 或 有 GPU) | 仅在内网运行 API，供其他节点代理 |
| **CDN 节点 (CDN Proxy)** | ✅ 有 | 不限 | 不运行模型，专门做流量分发和模型缓存 |
| **无** | ❌ 无 | 不满足算力要求 | 不安装任何组件 |

## 🚀 快速开始

### 一键安装

```bash
# 下载安装脚本
wget https://raw.githubusercontent.com/shenwenAI/swllm.cpp/main/install.sh

# 添加执行权限
chmod +x install.sh

# 运行安装（需要 sudo 权限）
sudo ./install.sh
```

### 安装流程

1. **语言选择**：选择中文或英文界面
2. **公网 IP 检测**：自动检测是否有公网 IP
3. **硬件检测**：检测 CPU 核心数、内存大小、GPU
4. **角色分配**：根据检测结果自动分配节点角色
5. **依赖安装**：自动安装 git、cmake、build-essential 等
6. **编译程序**：克隆 swllm.cpp 并编译（支持 CUDA 加速）
7. **下载模型**：自动选择最快的源下载 shenwen-coderV2 模型
8. **注册节点**：将节点信息注册到 Cloudflare Workers 网络
9. **启动服务**：根据角色启动相应的服务

### 管理服务

安装完成后，使用管理脚本控制服务：

```bash
cd /opt/swllm.cpp

# 启动服务
sudo ./swllm-manager.sh start

# 查看状态
sudo ./swllm-manager.sh status

# 停止服务
sudo ./swllm-manager.sh stop

# 重启服务
sudo ./swllm-manager.sh restart
```

## 📁 项目结构

```
swllm.cpp/
├── worker/                 # Cloudflare Workers 后端代码
│   ├── index.js           # Workers 主程序
│   └── wrangler.toml      # Workers 配置文件
├── web/                    # 前端监控页面
│   └── index.html         # 节点监控网页
├── install.sh             # 自动化安装脚本
└── README.md              # 项目文档
```

## 🔧 部署指南

### 1. 部署 Cloudflare Workers

#### 方法一：使用 Wrangler CLI（推荐）

```bash
# 安装 Wrangler
npm install -g wrangler

# 登录 Cloudflare
wrangler login

# 进入 worker 目录
cd worker

# 创建 KV 命名空间
wrangler kv:namespace create "NODES_KV"
# 记录返回的 ID

# 修改 wrangler.toml 中的 KV ID
# 然后部署
wrangler deploy
```

#### 方法二：Cloudflare Dashboard

1. 访问 [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. 进入 Workers & Pages → Create Application
3. 选择 "Deploy from Git" 或直接粘贴 `worker/index.js` 代码
4. 创建 KV 命名空间并绑定到 Worker
5. 设置路由：`shenwencdn.578388.xyz/*`

### 2. 部署前端页面

#### 使用 Cloudflare Pages

```bash
# 进入 web 目录
cd web

# 使用 Wrangler 部署
wrangler pages deploy . --project-name=shenwencdn-web
```

或直接在 Cloudflare Dashboard 中：
1. Pages → Create Project → Connect to Git
2. 选择仓库的 `web/` 目录
3. 部署即可

### 3. 配置自定义域名（可选）

在 Cloudflare Dashboard 中为 Workers 或 Pages 绑定自定义域名：
- 进入 Workers/Pages 设置
- Custom Domains → Add Custom Domain
- 输入你的域名（如 `shenwencdn.578388.xyz`）

## 🌐 API 接口

### 节点注册

```bash
POST https://shenwencdn.578388.xyz/api/register
Content-Type: application/json

{
  "ip": "1.2.3.4",
  "role": "hybrid",
  "cpu_cores": 8,
  "memory_gb": 16,
  "has_gpu": true,
  "location": "CN",
  "port": 8080
}
```

### 查询节点列表

```bash
GET https://shenwencdn.578388.xyz/api/nodes
# 可选参数：?role=hybrid （按角色过滤）
```

### 发送心跳

```bash
POST https://shenwencdn.578388.xyz/api/heartbeat
Content-Type: application/json

{
  "nodeId": "1.2.3.4:8080"
}
```

### 代理推理请求

```bash
POST https://shenwencdn.578388.xyz/api/proxy
Content-Type: application/json

{
  "prompt": "Write a function to...",
  "model": "shenwen-coderV2"
}
```

## 🖥️ 监控面板

访问 [https://shenwencdn.578388.xyz](https://shenwencdn.578388.xyz) 查看：

- 📊 实时统计：总节点数、混合节点、计算节点、CDN 节点数量
- 🌍 节点列表：IP 地址、角色、地理位置、硬件配置
- 🔄 自动刷新：每 30 秒更新一次节点状态

## ⚙️ 高级配置

### 修改 Workers 地址

如果使用了自定义域名，需要修改 `install.sh` 中的 `WORKER_URL`：

```bash
WORKER_URL="https://your-custom-domain.com"
```

### 手动指定模型下载源

```bash
# 在 install.sh 中修改 MODEL_URL
MODEL_URL="https://huggingface.co/..."  # 原始站
# 或
MODEL_URL="https://hf-mirror.com/..."   # 镜像站
```

### 调整心跳间隔

编辑 `/opt/swllm.cpp/heartbeat.sh`：

```bash
sleep 300  # 改为需要的秒数（默认 5 分钟）
```

## 🛠️ 故障排查

### 节点注册失败

检查网络连接：
```bash
curl -X POST https://shenwencdn.578388.xyz/api/register \
  -H "Content-Type: application/json" \
  -d '{"ip":"test","role":"cdn"}'
```

### 编译 CUDA 失败

确保已安装 NVIDIA 驱动和 CUDA Toolkit：
```bash
nvidia-smi  # 检查 GPU
nvcc --version  # 检查 CUDA
```

### 模型下载慢

安装脚本会自动选择最快的源，也可以手动指定：
```bash
# 使用镜像站
export MODEL_URL="https://hf-mirror.com/..."
```

## 📊 性能基准

| 配置 | 推理速度 (tokens/s) | 适用场景 |
|------|-------------------|----------|
| CPU 8 核 + 16GB | ~5-8 | 低并发、开发测试 |
| CPU 16 核 + 32GB | ~10-15 | 中等并发 |
| GPU RTX 3060 + 12GB | ~30-50 | 高并发、生产环境 |
| GPU RTX 4090 + 24GB | ~80-120 | 超高并发 |

## 🤝 贡献指南

欢迎提交 Issue 和 Pull Request！

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

模型文件请遵循 [shenwenAI](https://huggingface.co/shenwenAI) 对应的开源协议。

## 🔗 相关链接

- [swllm.cpp 仓库](https://github.com/shenwenAI/swllm.cpp)
- [shenwen-coderV2 模型](https://huggingface.co/shenwenAI/shenwen-coderV2-GGUF)
- [Cloudflare Workers 文档](https://developers.cloudflare.com/workers/)
- [HuggingFace Mirror](https://hf-mirror.com/)

## 📞 联系方式

- 项目主页：https://github.com/shenwenAI/swllm.cpp
- 问题反馈：https://github.com/shenwenAI/swllm.cpp/issues

---

**Built with ❤️ by shenwenAI Team**
