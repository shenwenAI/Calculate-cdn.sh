// Cloudflare Workers 后端 - shenwenCDN 节点管理系统
// 部署地址: https://shenwencdn.578388.xyz

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;

    // CORS 处理
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    };

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    try {
      // 路由处理
      if (path === '/api/register' && request.method === 'POST') {
        return await handleRegister(request, env);
      } else if (path === '/api/nodes' && request.method === 'GET') {
        return await handleGetNodes(request, env);
      } else if (path === '/api/heartbeat' && request.method === 'POST') {
        return await handleHeartbeat(request, env);
      } else if (path === '/api/proxy' && request.method === 'POST') {
        return await handleProxy(request, env);
      } else if (path === '/' || path === '/index.html') {
        // 返回前端页面 (如果部署在同一域名下)
        return new Response(await getFrontendPage(), {
          headers: { ...corsHeaders, 'Content-Type': 'text/html' }
        });
      } else {
        return new Response(JSON.stringify({ error: 'Not Found' }), {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }
    } catch (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }
  }
};

// 处理节点注册
async function handleRegister(request, env) {
  const body = await request.json();
  const { ip, role, cpu_cores, memory_gb, has_gpu, location, port } = body;

  if (!ip || !role) {
    return new Response(JSON.stringify({ error: 'Missing required fields' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' }
    });
  }

  const nodeId = `${ip}:${port}`;
  const nodeData = {
    id: nodeId,
    ip,
    role, // 'hybrid', 'compute', 'cdn'
    cpu_cores: cpu_cores || 0,
    memory_gb: memory_gb || 0,
    has_gpu: has_gpu || false,
    location: location || 'Unknown',
    port: port || 8080,
    status: 'online',
    last_heartbeat: Date.now(),
    registered_at: Date.now()
  };

  // 存储到 KV
  await env.NODES_KV.put(`node:${nodeId}`, JSON.stringify(nodeData), { expirationTtl: 3600 }); // 1小时过期，需心跳续期

  console.log(`Node registered: ${nodeId}`);

  return new Response(JSON.stringify({
    success: true,
    message: 'Node registered successfully',
    nodeId: nodeId
  }), {
    headers: { 'Content-Type': 'application/json' }
  });
}

// 获取所有活跃节点
async function handleGetNodes(request, env) {
  const url = new URL(request.url);
  const roleFilter = url.searchParams.get('role'); // 可选：按角色过滤

  const nodes = [];
  const currentTime = Date.now();

  // 列出所有 node: 开头的 key
  let cursor = undefined;
  do {
    const list = await env.NODES_KV.list({ prefix: 'node:', cursor });
    
    for (const key of list.keys) {
      const data = await env.NODES_KV.get(key.name);
      if (data) {
        const node = JSON.parse(data);
        
        // 检查是否过期 (超过1小时未心跳)
        if (currentTime - node.last_heartbeat < 3600000) {
          if (!roleFilter || node.role === roleFilter) {
            nodes.push(node);
          }
        } else {
          // 清理过期节点
          await env.NODES_KV.delete(key.name);
        }
      }
    }
    cursor = list.cursor;
  } while (cursor);

  return new Response(JSON.stringify({
    success: true,
    count: nodes.length,
    nodes: nodes
  }), {
    headers: { 'Content-Type': 'application/json' }
  });
}

// 处理心跳
async function handleHeartbeat(request, env) {
  const body = await request.json();
  const { nodeId } = body;

  if (!nodeId) {
    return new Response(JSON.stringify({ error: 'Missing nodeId' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' }
    });
  }

  const existingData = await env.NODES_KV.get(`node:${nodeId}`);
  if (!existingData) {
    return new Response(JSON.stringify({ error: 'Node not found' }), {
      status: 404,
      headers: { 'Content-Type': 'application/json' }
    });
  }

  const node = JSON.parse(existingData);
  node.last_heartbeat = Date.now();
  node.status = 'online';

  await env.NODES_KV.put(`node:${nodeId}`, JSON.stringify(node), { expirationTtl: 3600 });

  return new Response(JSON.stringify({
    success: true,
    message: 'Heartbeat received'
  }), {
    headers: { 'Content-Type': 'application/json' }
  });
}

// 代理请求到最佳节点 (简单负载均衡)
async function handleProxy(request, env) {
  const body = await request.json();
  const { prompt, model } = body;

  // 获取所有 hybrid 或 compute 节点
  const allNodesRes = await handleGetNodes(request, env);
  const allNodesData = await allNodesRes.json();
  
  const availableNodes = allNodesData.nodes.filter(n => 
    n.role === 'hybrid' || n.role === 'compute'
  );

  if (availableNodes.length === 0) {
    return new Response(JSON.stringify({ error: 'No available compute nodes' }), {
      status: 503,
      headers: { 'Content-Type': 'application/json' }
    });
  }

  // 随机选择一个节点 (可扩展为基于延迟、负载等策略)
  const targetNode = availableNodes[Math.floor(Math.random() * availableNodes.length)];
  const targetUrl = `http://${targetNode.ip}:${targetNode.port}/completion`;

  try {
    const proxyRes = await fetch(targetUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ prompt, model })
    });

    const result = await proxyRes.json();
    return new Response(JSON.stringify({
      ...result,
      _meta: {
        served_by: targetNode.id,
        location: targetNode.location
      }
    }), {
      headers: { 'Content-Type': 'application/json' }
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: `Failed to reach node: ${error.message}` }), {
      status: 502,
      headers: { 'Content-Type': 'application/json' }
    });
  }
}

// 简单的前端页面 (如果直接访问 Worker 域名)
async function getFrontendPage() {
  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <title>shenwenCDN 节点网络</title>
  <style>body{font-family:Arial,sans-serif;margin:40px;background:#f5f5f5}.container{max-width:1200px;margin:0 auto;background:white;padding:30px;border-radius:8px;box-shadow:0 2px 10px rgba(0,0,0,0.1)}h1{color:#333;text-align:center}.stats{display:flex;justify-content:space-around;margin:30px 0}.stat-card{background:#f8f9fa;padding:20px;border-radius:8px;text-align:center;min-width:150px}.stat-number{font-size:2em;color:#007bff;font-weight:bold}.node-list{margin-top:30px}.node-item{background:#fff;border:1px solid #ddd;padding:15px;margin:10px 0;border-radius:6px;display:flex;justify-content:space-between;align-items:center}.badge{padding:4px 8px;border-radius:4px;font-size:0.8em;color:white}.badge-hybrid{background:#28a745}.badge-compute{background:#17a2b8}.badge-cdn{background:#ffc107;color:#333}.status-online{color:#28a745}.loading{text-align:center;padding:40px}</style>
</head>
<body>
  <div class="container">
    <h1>🌐 shenwenCDN 全球节点网络</h1>
    <div id="loading" class="loading">正在加载节点数据...</div>
    <div id="content" style="display:none">
      <div class="stats">
        <div class="stat-card"><div class="stat-number" id="total-nodes">0</div><div>总节点数</div></div>
        <div class="stat-card"><div class="stat-number" id="hybrid-nodes">0</div><div>混合节点</div></div>
        <div class="stat-card"><div class="stat-number" id="compute-nodes">0</div><div>计算节点</div></div>
        <div class="stat-card"><div class="stat-number" id="cdn-nodes">0</div><div>CDN节点</div></div>
      </div>
      <h2>活跃节点列表</h2>
      <div id="node-list" class="node-list"></div>
    </div>
  </div>
  <script>
    async function loadNodes() {
      try {
        const res = await fetch('/api/nodes');
        const data = await res.json();
        document.getElementById('loading').style.display = 'none';
        document.getElementById('content').style.display = 'block';
        
        const nodes = data.nodes;
        document.getElementById('total-nodes').textContent = nodes.length;
        document.getElementById('hybrid-nodes').textContent = nodes.filter(n => n.role === 'hybrid').length;
        document.getElementById('compute-nodes').textContent = nodes.filter(n => n.role === 'compute').length;
        document.getElementById('cdn-nodes').textContent = nodes.filter(n => n.role === 'cdn').length;
        
        const listEl = document.getElementById('node-list');
        if (nodes.length === 0) {
          listEl.innerHTML = '<p style="text-align:center;color:#666">暂无活跃节点，运行安装脚本创建第一个节点吧！</p>';
          return;
        }
        
        nodes.forEach(node => {
          const item = document.createElement('div');
          item.className = 'node-item';
          item.innerHTML = \`
            <div>
              <strong>\${node.ip}:\${node.port}</strong>
              <span class="badge badge-\${node.role}">\${node.role.toUpperCase()}</span>
              <span style="margin-left:10px">\${node.location}</span>
            </div>
            <div class="status-online">● 在线</div>
          \`;
          listEl.appendChild(item);
        });
      } catch (err) {
        document.getElementById('loading').innerHTML = '加载失败: ' + err.message;
      }
    }
    loadNodes();
    setInterval(loadNodes, 30000); // 每30秒刷新
  </script>
</body>
</html>`;
}
