# Yearning SQL审计平台 - 生产环境部署指南

## 概览

Yearning是一个基于Go语言开发的MySQL SQL审计和查询平台，专为DBA和开发者设计，提供本地部署的隐私安全解决方案。

**版本**: v20250917-72d84e6
**构建时间**: 2025-09-17T04:26:26Z
**Git提交**: 72d84e66453fb9f94d22da4608e4d785374351a8

## 系统要求

### 生产环境（推荐）
- **操作系统**: Linux (推荐 CentOS 7+/Ubuntu 18.04+)
- **数据库**: MySQL 5.7 (生产环境标准)
- **内存**: 最低 2GB，推荐 4GB+
- **磁盘**: 最低 10GB 可用空间

### 开发/测试环境
- **操作系统**: macOS (Apple Silicon) 或 Linux
- **数据库**: MySQL 5.7+ 或 Docker
- **内存**: 最低 1GB

## 部署包内容

```
yearning-deployment-package/
├── README.md                                          # 完整部署指南
├── LINUX_PRODUCTION_DEPLOYMENT.md                    # Linux生产环境专用指南 ⭐ 运维必看
├── yearning-v20250917-72d84e6-linux-amd64.tar.gz    # Linux生产环境二进制包 ⭐ 推荐
├── yearning-v20250917-72d84e6-linux-amd64.zip       # Linux生产环境二进制包(ZIP格式)
├── yearning-v20250917-72d84e6-darwin-arm64.tar.gz   # macOS开发环境二进制包
├── yearning-v20250917-72d84e6-darwin-arm64.zip      # macOS开发环境二进制包(ZIP格式)
├── deploy-production.sh                               # 自动化部署脚本
├── quick-mac-test.sh                                 # macOS快速测试脚本
├── docker-compose.production.yml                     # Docker部署配置
└── init-database.sql                                 # 数据库初始化脚本
```

## 🚀 快速部署

### 方式一：二进制部署（推荐）⭐

二进制部署具有**性能优异、资源占用低、部署简单**等优势，是生产环境的最佳选择。

#### Linux生产环境 🐧

> 📋 **运维同学专用指南**: [LINUX_PRODUCTION_DEPLOYMENT.md](LINUX_PRODUCTION_DEPLOYMENT.md)
>
> 包含完整的生产环境部署流程、系统服务配置、监控维护、故障排除等运维必备内容。

**快速启动**：
```bash
# 1. 下载并解压
wget https://github.com/your-repo/yearning/releases/download/v20250917/yearning-deployment-package.tar.gz
tar -xzf yearning-deployment-package.tar.gz && cd yearning-deployment-package
tar -xzf yearning-v20250917-72d84e6-linux-amd64.tar.gz && cd yearning-v20250917-72d84e6-linux-amd64

# 2. 配置和启动（详细步骤见Linux生产环境指南）
mkdir -p conf && vim conf/yearning.conf  # 配置数据库连接
./yearning install                        # 初始化数据库
./yearning run --config conf/yearning.conf  # 启动服务
```

#### macOS开发环境

```bash
# 解压macOS二进制包
tar -xzf yearning-v20250917-72d84e6-darwin-arm64.tar.gz
cd yearning-v20250917-72d84e6-darwin-arm64

# 或者使用快速测试脚本
chmod +x quick-mac-test.sh
./quick-mac-test.sh
```

### 方式二：自动化脚本部署

```bash
# 下载并解压部署包
wget https://github.com/your-repo/yearning/releases/download/v20250917/yearning-deployment-package.tar.gz
tar -xzf yearning-deployment-package.tar.gz
cd yearning-deployment-package

# 运行自动化部署脚本
chmod +x deploy-production.sh
./deploy-production.sh
```

### 方式三：Docker部署

```bash
# 使用生产环境Docker Compose
docker-compose -f docker-compose.production.yml up -d
```

## ⚙️ 配置说明

### 核心配置项

```toml
[Mysql]
Db = "yearning"
Host = "127.0.0.1"  # 生产环境MySQL地址
Port = "3306"
Password = "your_encrypted_password"  # 使用AES加密的密码
User = "yearning"

[General]
SecretKey = "your_16_char_key_here"  # 必须是16位字符
RpcAddr = "127.0.0.1:50001"         # Juno RPC服务地址
LogLevel = "info"                    # 生产环境使用info
Lang = "zh_CN"

[Oidc]
Enable = false  # 根据需要启用OIDC
```

### 密码加密

Yearning使用AES加密存储数据库密码，密钥必须是16位字符：

```bash
# 生成加密密码的示例代码在部署脚本中包含
echo "请使用deploy-production.sh脚本自动生成加密密码"
```

## 🗄️ 数据库初始化

### MySQL 5.7 生产环境配置

```sql
-- 创建数据库和用户
CREATE DATABASE yearning CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'yearning'@'%' IDENTIFIED BY 'your_password';
GRANT ALL PRIVILEGES ON yearning.* TO 'yearning'@'%';
FLUSH PRIVILEGES;

-- 如果需要从Docker容器访问
GRANT ALL PRIVILEGES ON yearning.* TO 'yearning'@'172.%.%.%';
```

### 审核规则优化

默认审核规则可能过于严格，建议调整：

```sql
-- 连接到Yearning数据库，更新审核规则
UPDATE core_rules
SET audit_role = JSON_SET(
  audit_role,
  '$.DMLSelect', true,      -- 允许SELECT语句
  '$.DMLWhere', true,       -- 允许WHERE子句
  '$.DMLOrder', true,       -- 允许ORDER BY
  '$.DMLAllowLimitSTMT', true  -- 允许LIMIT语句
)
WHERE id = 1;
```

常见审核规则说明：
- `DMLSelect`: 控制是否允许SELECT语句
- `DMLWhere`: 控制是否必须有WHERE条件
- `DMLOrder`: 控制是否允许ORDER BY
- `MaxAffectRows`: 最大影响行数限制

### Juno SQL检测服务

Yearning集成Juno服务进行SQL检测和优化：

```bash
# 启动Juno服务（Docker方式）
docker run -d \
  --name juno \
  -p 50001:50001 \
  cookiey/juno:latest

# 验证Juno服务
curl http://localhost:50001/health
```

## 🔧 故障排除

### 常见问题

#### 端口冲突问题
如果遇到端口占用，手动指定可用端口：
```bash
# 检查端口占用
lsof -i:8000  # 检查8000端口
lsof -i:8080  # 检查8080端口

# 使用其他端口启动（如8082）
./yearning run --port 8082 --config conf/yearning.conf
```

#### MySQL连接问题
支持多种MySQL连接方式：
```bash
# 1. 本地MySQL（需要root密码）
mysql -u root -p

# 2. 远程MySQL（推荐测试环境）
mysql -h <remote_ip> -P <port> -u <user> -p

# 3. Docker MySQL
docker run -d --name mysql-test -e MYSQL_ROOT_PASSWORD=test123 -p 3307:3306 mysql:5.7
```

#### 审核规则过严
```sql
-- 放宽审核规则
UPDATE core_rules
SET audit_role = JSON_SET(audit_role, '$.DMLSelect', true)
WHERE id = 1;
```

#### 权限配置错误
```sql
-- 检查用户权限配置
SELECT username, `group` FROM core_graineds WHERE username = 'admin';
SELECT permissions FROM core_role_groups WHERE group_id = '<group_id>';
```

### 端口可用性检查
```bash
# 查找可用端口
for port in 8080 8081 8082 8083 8084; do
  if ! lsof -i:$port > /dev/null 2>&1; then
    echo "端口 $port 可用"
    break
  fi
done
```

### MySQL连接验证
```bash
# 测试数据库连接
mysql -h <host> -P <port> -u <user> -p<password> -e "SELECT 1;"

# 检查用户权限
mysql -h <host> -P <port> -u <user> -p<password> -e "SHOW GRANTS;"
```

## 🎯 部署检查清单

### 环境检查
- [ ] 操作系统：Linux/macOS 确认
- [ ] Go版本：1.21+ （如果需要编译）
- [ ] MySQL版本：5.7+ 确认
- [ ] 内存：最低2GB可用
- [ ] 磁盘：最低10GB可用空间

### 端口检查
```bash
# 检查常用端口是否被占用
lsof -i:8000  # Yearning默认端口
lsof -i:8080  # 备用端口
lsof -i:8082  # 备用端口
lsof -i:3306  # MySQL端口
lsof -i:50001 # Juno RPC端口
```

### 数据库准备
- [ ] MySQL服务正在运行
- [ ] 数据库连接信息准备就绪
- [ ] 数据库用户权限确认（CREATE, ALTER, INSERT, UPDATE, DELETE, SELECT）
- [ ] 如果使用远程数据库，网络连通性确认

### 部署后验证
- [ ] Web界面可以访问
- [ ] 用户可以正常登录（admin/Yearning_admin）
- [ ] 数据源配置可以查看和编辑
- [ ] 数据库连接测试成功
- [ ] 能够创建DML工单
- [ ] 能够创建DDL工单
- [ ] 工单审批流程正常

## 🚀 生产环境管理

### 系统服务配置

```bash
# 创建systemd服务文件
sudo tee /etc/systemd/system/yearning.service > /dev/null <<EOF
[Unit]
Description=Yearning SQL Audit Platform
After=network.target mysql.service

[Service]
Type=simple
User=yearning
Group=yearning
WorkingDirectory=/opt/yearning
ExecStart=/opt/yearning/yearning run --config /opt/yearning/conf/yearning.conf
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# 启用并启动服务
sudo systemctl daemon-reload
sudo systemctl enable yearning
sudo systemctl start yearning
sudo systemctl status yearning
```

### 防火墙配置

```bash
# 开放必要端口
sudo firewall-cmd --permanent --add-port=8000/tcp  # Yearning Web界面
sudo firewall-cmd --permanent --add-port=50001/tcp # Juno RPC服务
sudo firewall-cmd --reload
```

### 反向代理（Nginx）

```nginx
server {
    listen 80;
    server_name yearning.yourcompany.com;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 日志管理

```bash
# 查看应用日志
tail -f logs/yearning.log

# 系统服务日志
sudo journalctl -u yearning -f
```

## ⚡ 性能优化

### 数据库优化

```sql
-- MySQL 5.7 推荐配置
[mysqld]
innodb_buffer_pool_size = 1G
innodb_log_file_size = 256M
max_connections = 1000
query_cache_size = 64M
```

### 应用优化

```toml
# yearning.conf 性能相关配置
[General]
LogLevel = "info"        # 生产环境避免debug级别
MaxOpenConns = 100       # 数据库连接池大小
MaxIdleConns = 10        # 空闲连接数
```

### 监控和健康检查

```bash
# 检查服务状态
systemctl status yearning

# 检查端口监听
netstat -tulpn | grep :8000

# 检查进程资源使用
ps aux | grep yearning

# API健康检查
curl -f http://localhost:8000/api/v1/health || echo "Service unhealthy"
```

## 📝 更新升级

### 二进制更新

```bash
# 1. 停止服务
sudo systemctl stop yearning

# 2. 备份当前版本
cp yearning yearning.backup

# 3. 替换二进制文件
wget https://github.com/your-repo/yearning/releases/download/latest/yearning-linux-amd64.tar.gz
tar -xzf yearning-linux-amd64.tar.gz
cp yearning-*/yearning .

# 4. 重启服务
sudo systemctl start yearning
```

### 数据库迁移

```bash
# 运行数据库迁移
./yearning migrate --config conf/yearning.conf
```

## ✅ 部署成功标准

**部署成功的标志**：
1. Web界面正常访问
2. 用户能够登录并看到仪表板
3. 能够创建和执行SQL工单
4. 审批流程运行正常
5. 数据库操作日志正常记录

**可以开始生产使用的标志**：
1. 所有基础功能验证通过
2. 安全配置已完成
3. 监控和备份已就位
4. 团队培训已完成
5. 应急预案已制定

## 📞 技术支持

- **官方文档**: https://next.yearning.io
- **GitHub仓库**: https://github.com/cookieY/Yearning
- **问题反馈**: https://github.com/cookieY/Yearning/issues
- **社区讨论**: https://github.com/cookieY/Yearning/discussions

## 📄 许可证

Yearning遵循AGPL 3.0开源许可证。

---

**构建信息**
- 版本: v20250917-72d84e6
- 构建时间: 2025-09-17T04:26:26Z
- Go版本: go1.24.1
- 支持平台: Linux AMD64, macOS ARM64