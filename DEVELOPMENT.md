# Yearning 开发环境指南

本指南将帮助您快速搭建 Yearning SQL 审核平台的开发环境，支持前后端分离调试。

## 🚀 快速开始

### 前置要求

- Docker Desktop
- Docker Compose
- Git
- VS Code (推荐)

### 一键启动

```bash
# 克隆项目并进入目录
cd Yearning

# 启动完整开发环境
./dev-start.sh start
```

等待几分钟后，访问：
- 🌐 **完整应用**: http://localhost
- 🔧 **前端开发**: http://localhost:3000 (热重载)
- 🔌 **后端API**: http://localhost:8000
- 🗄️ **数据库**: localhost:3306

**默认账号**: `admin` / `Yearning_admin`

## 📁 项目结构

```
Yearning/
├── src/                    # 后端Go源码
├── frontend-dev/          # 前端开发目录 (需要手动添加)
├── docker-compose.dev.yml # 开发环境配置
├── dev-start.sh          # 开发环境管理脚本
├── Dockerfile.backend-dev # 后端开发容器
├── Dockerfile.frontend-dev # 前端开发容器
├── nginx-dev.conf        # Nginx代理配置
└── .vscode/              # VS Code调试配置
```

## 🛠️ 开发环境管理

### 启动脚本命令

```bash
./dev-start.sh start      # 启动完整环境
./dev-start.sh backend    # 仅启动后端
./dev-start.sh frontend   # 仅启动前端
./dev-start.sh stop       # 停止环境
./dev-start.sh restart    # 重启环境
./dev-start.sh logs       # 查看所有日志
./dev-start.sh logs backend-dev  # 查看后端日志
./dev-start.sh status     # 查看状态
./dev-start.sh exec backend-dev  # 进入后端容器
./dev-start.sh clean      # 清理环境
./dev-start.sh help       # 帮助信息
```

### 容器服务

| 服务名 | 端口 | 描述 |
|--------|------|------|
| mysql | 3306 | MySQL 5.7 数据库 |
| backend-dev | 8000, 2345 | Go后端服务 + 调试端口 |
| frontend-dev | 3000, 3001 | Vue前端 + 热重载端口 |
| nginx-proxy | 80 | Nginx反向代理 |

## 🔧 后端开发

### 技术栈
- **语言**: Go 1.21
- **框架**: Yee (类Gin)
- **ORM**: GORM
- **数据库**: MySQL 5.7

### 开发流程

1. **启动后端开发环境**:
   ```bash
   ./dev-start.sh backend
   ```

2. **VS Code调试**:
   - 按 `F5` 选择"远程调试 Yearning 后端"
   - 或在终端运行 `dlv debug --headless --listen=:2345 --api-version=2`

3. **热重载开发**:
   ```bash
   # 进入后端容器
   ./dev-start.sh exec backend-dev
   
   # 使用air进行热重载
   air
   ```

4. **查看日志**:
   ```bash
   ./dev-start.sh logs backend-dev
   ```

### API文档

后端API遵循RESTful设计:

- `GET /api/v2/fetch/userinfo` - 获取用户信息
- `POST /login` - 用户登录
- `GET /api/v2/dash/*` - 仪表板相关API
- `POST /api/v2/audit/order/*` - 审核工单API

### 配置文件

开发环境配置会自动生成在容器内的 `/app/conf.toml`，主要配置：

```toml
[Mysql]
Host = "mysql"
Port = "3306"
User = "yearning"
Password = "yearning123"
Db = "yearning"

[General]
SecretKey = "dev_secret_key_1234567890"
LogLevel = "debug"
Lang = "zh_CN"
```

## 🎨 前端开发

### 技术栈
- **框架**: Vue 3 + Vite
- **UI库**: Element Plus
- **状态管理**: Vuex
- **HTTP客户端**: Axios

### 前端代码

前端使用官方仓库 [Yearning-gemini](https://github.com/cookieY/Yearning-gemini/)：
- **自动获取**: Docker构建时自动克隆最新代码
- **技术栈**: Vue 2 + TypeScript + Element UI
- **无需手动配置**: 开发环境自动处理

2. **启动前端开发**:
   ```bash
   ./dev-start.sh frontend
   ```

3. **访问前端**:
   - 开发服务器: http://localhost:3000
   - 生产代理: http://localhost

### 前端开发特性

- ✅ **热重载**: 代码修改自动刷新
- ✅ **API代理**: 自动代理到后端服务
- ✅ **ES6+支持**: 现代JavaScript特性
- ✅ **Vue DevTools**: 浏览器调试工具

### 构建部署

```bash
# 进入前端容器
./dev-start.sh exec frontend-dev

# 构建生产版本
npm run build

# 构建文件会输出到 ../src/service/dist
```

## 🗄️ 数据库管理

### 连接信息

```
Host: localhost
Port: 3306
Username: yearning
Password: yearning123
Database: yearning
```

### 常用操作

```bash
# 进入MySQL容器
./dev-start.sh exec mysql

# 连接数据库
mysql -u yearning -pyearning123 yearning

# 重置数据库
docker-compose -f docker-compose.dev.yml exec backend-dev go run . install
```

### 数据库表结构

主要表包括：
- `core_accounts` - 用户账号
- `core_sql_orders` - SQL工单
- `core_query_orders` - 查询工单
- `core_data_sources` - 数据源配置
- `core_role_groups` - 角色权限

## 🔍 调试技巧

### 1. Go后端调试

**VS Code调试** (推荐):
1. 确保后端服务运行在调试模式
2. 在VS Code中按 `F5`
3. 选择"远程调试 Yearning 后端"
4. 设置断点开始调试

**命令行调试**:
```bash
# 进入容器
./dev-start.sh exec backend-dev

# 启动调试器
dlv debug --headless --listen=:2345 --api-version=2 . -- run --port 8000

# 在另一个终端连接
dlv connect localhost:2345
```

### 2. 前端调试

- **浏览器DevTools**: F12 开发者工具
- **Vue DevTools**: 浏览器扩展
- **网络面板**: 查看API请求
- **控制台**: 查看错误和日志

### 3. 日志查看

```bash
# 查看所有服务日志
./dev-start.sh logs

# 查看特定服务日志
./dev-start.sh logs backend-dev
./dev-start.sh logs frontend-dev
./dev-start.sh logs mysql

# 实时跟踪日志
docker-compose -f docker-compose.dev.yml logs -f backend-dev
```

## 🚨 常见问题

### 1. 端口冲突

**症状**: 启动失败，提示端口被占用

**解决**:
```bash
# 检查端口使用
./dev-start.sh status

# 停止冲突的服务
sudo lsof -ti:8000 | xargs kill -9

# 或修改 docker-compose.dev.yml 中的端口映射
```

### 2. 数据库连接失败

**症状**: 后端无法连接MySQL

**解决**:
```bash
# 检查MySQL容器状态
docker-compose -f docker-compose.dev.yml ps mysql

# 查看MySQL日志
./dev-start.sh logs mysql

# 重启MySQL
docker-compose -f docker-compose.dev.yml restart mysql
```

### 3. 前端资源加载失败

**症状**: 页面空白或资源404

**解决**:
```bash
# 重新构建前端
./dev-start.sh exec frontend-dev npm run build

# 检查Nginx配置
./dev-start.sh logs nginx-proxy

# 重启前端服务
docker-compose -f docker-compose.dev.yml restart frontend-dev
```

### 4. Go模块下载失败

**症状**: 构建时依赖下载失败

**解决**:
```bash
# 设置Go代理
export GOPROXY=https://goproxy.cn,direct

# 清理模块缓存
go clean -modcache

# 重新下载依赖
go mod download
```

## 🔄 版本控制

### Git忽略文件

确保 `.gitignore` 包含：

```gitignore
# 开发环境文件
/frontend-dev/node_modules
/frontend-dev/dist
*.log
conf.toml

# Docker数据
/mysql-data
```

### 分支管理

- `main`: 主分支，稳定版本
- `develop`: 开发分支
- `feature/*`: 功能分支
- `hotfix/*`: 热修复分支

## 📚 参考资源

- [Yearning 官方文档](https://next.yearning.io)
- [Go官方文档](https://golang.org/doc/)
- [Vue.js官方文档](https://vuejs.org)
- [Element Plus文档](https://element-plus.org)
- [Docker文档](https://docs.docker.com)

## 🤝 贡献指南

1. Fork项目
2. 创建功能分支
3. 提交代码
4. 创建Pull Request

---

**Happy Coding! 🎉**

如遇问题，请查看日志或提交Issue。
