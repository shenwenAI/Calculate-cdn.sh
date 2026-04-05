# Calculate-cdn.sh

公网 IP 检测与 CDN 测试工具 / Public IP Detection & CDN Testing Tool

## 项目结构 / Project Structure

```
├── install.sh          # 本地安装脚本（公网 IP 检测）
├── worker/             # Cloudflare Worker CDN 后端
│   ├── index.js        # Worker 入口文件
│   └── wrangler.toml   # Wrangler 配置文件
└── pages/              # Cloudflare Pages 前端
    └── index.html      # 前端页面
```

## Cloudflare Worker 后端 / Worker Backend

Worker 提供以下 API 端点：

| 端点 / Endpoint | 说明 / Description |
|---|---|
| `GET /api/ip` | 返回客户端 IP、地理位置、CDN 节点信息（JSON） |
| `GET /api/ip/simple` | 仅返回客户端 IP（纯文本） |
| `GET /api/cdn-test` | CDN 延迟测试端点（JSON） |
| `GET /api/trace` | 连接跟踪信息（文本，类似 /cdn-cgi/trace） |

### 部署 Worker / Deploy Worker

1. 安装 Wrangler CLI：
   ```bash
   npm install -g wrangler
   ```

2. 登录 Cloudflare：
   ```bash
   wrangler login
   ```

3. 部署：
   ```bash
   cd worker
   wrangler deploy
   ```

部署完成后会得到一个 Worker URL，例如：`https://calculate-cdn-worker.<your-subdomain>.workers.dev`

### API 响应示例 / API Response Example

`GET /api/ip`
```json
{
  "ip": "1.2.3.4",
  "ip_version": "IPv4",
  "location": {
    "country": "US",
    "region": "California",
    "city": "San Francisco",
    "timezone": "America/Los_Angeles"
  },
  "cdn": {
    "colo": "SJC",
    "asn": 13335,
    "as_organization": "Cloudflare, Inc.",
    "http_protocol": "HTTP/2",
    "tls_version": "TLSv1.3"
  }
}
```

## Cloudflare Pages 前端 / CF Pages Frontend

`pages/index.html` 是一个双语（中/英）Web 界面，用于展示 IP 检测和 CDN 测试结果。

### 部署 Pages / Deploy Pages

1. 在 Cloudflare Dashboard 中创建 Pages 项目
2. 连接 GitHub 仓库或直接上传 `pages/` 目录
3. 设置构建输出目录为 `pages`
4. 部署后在页面中填入 Worker API 地址即可使用

### 功能 / Features

- 🌐 检测客户端公网 IP 地址
- 📍 显示地理位置信息（国家、城市、时区等）
- ⚡ 显示 CDN 节点信息（数据中心、ASN、运营商）
- 📊 测量到 CDN 节点的往返延迟
- 🌍 支持中文/英文切换

## 本地脚本 / Local Script

```bash
bash install.sh
```

运行后会检测本机所有网卡的公网 IP 地址，支持 IPv4 和 IPv6。