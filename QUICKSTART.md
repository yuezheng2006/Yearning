# 🚀 Yearning 开发环境快速启动

## 1分钟启动指南

### Step 1: 检查环境
```bash
# 确保Docker运行
docker --version
docker-compose --version
```

### Step 2: 启动开发环境
```bash
# 一键启动所有服务
./dev-start.sh start
```

### Step 3: 等待启动完成
```
等待2-3分钟，直到看到:
✅ MySQL数据库启动
✅ 后端API服务启动  
✅ 前端开发服务器启动
✅ Nginx代理启动
```

### Step 4: 访问应用
- **完整应用**: http://localhost
- **前端开发**: http://localhost:3000
- **后端API**: http://localhost:8000

### Step 5: 登录测试
```
用户名: admin
密码: Yearning_admin
```

## 🛠️ 开发命令

```bash
# 查看服务状态
./dev-start.sh status

# 查看日志  
./dev-start.sh logs

# 停止服务
./dev-start.sh stop

# 重启服务
./dev-start.sh restart

# 仅启动后端
./dev-start.sh backend

# 进入后端容器
./dev-start.sh exec backend-dev
```

## 🔧 VS Code调试

1. 打开项目
2. 按 `F5`
3. 选择 "远程调试 Yearning 后端"
4. 设置断点开始调试

## 📁 添加前端代码

```bash
# 克隆前端仓库到开发目录
git clone https://github.com/cookieY/Yearning-gemini.git frontend-dev

# 或复制现有前端代码到 frontend-dev/ 目录
```

## 🚨 遇到问题？

1. **端口冲突**: 停止占用端口的服务
2. **服务启动失败**: 检查 `./dev-start.sh logs`
3. **数据库连接失败**: 等待MySQL完全启动
4. **前端页面空白**: 确保前端代码在 `frontend-dev/` 目录

详细文档请查看 [DEVELOPMENT.md](DEVELOPMENT.md)

---

**开始愉快的开发之旅! 🎉**
