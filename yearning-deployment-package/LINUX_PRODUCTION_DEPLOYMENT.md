# Yearning Linux生产环境部署指南

**适用对象**: 运维工程师、系统管理员
**部署方式**: 二进制部署（推荐）
**版本**: v20250917-72d84e6

## 🎯 快速部署（5分钟上线）

### 第一步：系统准备

```bash
# 检查系统环境
uname -a                    # 确认Linux系统
free -h                     # 确认内存≥2GB
df -h                       # 确认磁盘≥10GB

# 检查MySQL服务
systemctl status mysql
# 或
systemctl status mariadb
```

### 第二步：下载部署包

```bash
# 创建部署目录
sudo mkdir -p /opt/yearning
cd /opt/yearning

# 下载最新版本
wget https://github.com/cookieY/Yearning/releases/download/v20250917/yearning-deployment-package.tar.gz

# 解压部署包
tar -xzf yearning-deployment-package.tar.gz
cd yearning-deployment-package

# 解压Linux生产环境二进制包
tar -xzf yearning-v20250917-72d84e6-linux-amd64.tar.gz
cd yearning-v20250917-72d84e6-linux-amd64
```

### 第三步：配置服务

```bash
# 创建配置目录
mkdir -p conf

# 创建生产环境配置
cat > conf/yearning.conf << 'EOF'
[Mysql]
Db = "yearning"
Host = "127.0.0.1"          # 修改为您的MySQL地址
Port = "3306"               # 修改为您的MySQL端口
Password = "YOUR_PASSWORD"  # 修改为您的MySQL密码
User = "yearning"           # 修改为您的MySQL用户

[General]
SecretKey = "prod_secret_16c"  # 必须是16位字符，生产环境请修改
RpcAddr = "127.0.0.1:50001"    # Juno服务地址
LogLevel = "info"              # 生产环境建议使用info
Lang = "zh_CN"

[Oidc]
Enable = false
EOF

# 编辑配置文件
vim conf/yearning.conf
```

### 第四步：数据库初始化

```bash
# 连接MySQL创建数据库和用户
mysql -u root -p << 'EOF'
CREATE DATABASE yearning CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'yearning'@'%' IDENTIFIED BY 'YOUR_PASSWORD';
GRANT ALL PRIVILEGES ON yearning.* TO 'yearning'@'%';
FLUSH PRIVILEGES;
EXIT;
EOF

# 初始化Yearning数据库
./yearning install
```

### 第五步：启动服务

```bash
# 检查可用端口
lsof -i:8000 || echo "端口8000可用"

# 启动Yearning服务
./yearning run --config conf/yearning.conf

# 后台启动（推荐）
nohup ./yearning run --config conf/yearning.conf > logs/yearning.log 2>&1 &
```

### 第六步：验证部署

```bash
# 检查服务状态
curl http://localhost:8000 || echo "服务启动失败"

# 查看日志
tail -f logs/yearning.log
```

## 🚀 生产环境优化

### 系统服务配置

```bash
# 创建systemd服务文件
sudo tee /etc/systemd/system/yearning.service > /dev/null << 'EOF'
[Unit]
Description=Yearning SQL Audit Platform
After=network.target mysql.service

[Service]
Type=simple
User=yearning
Group=yearning
WorkingDirectory=/opt/yearning/yearning-deployment-package/yearning-v20250917-72d84e6-linux-amd64
ExecStart=/opt/yearning/yearning-deployment-package/yearning-v20250917-72d84e6-linux-amd64/yearning run --config conf/yearning.conf
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# 创建yearning用户
sudo useradd -r -s /bin/false yearning

# 设置目录权限
sudo chown -R yearning:yearning /opt/yearning

# 启用并启动服务
sudo systemctl daemon-reload
sudo systemctl enable yearning
sudo systemctl start yearning
sudo systemctl status yearning
```

### 防火墙配置

```bash
# CentOS/RHEL (firewalld)
sudo firewall-cmd --permanent --add-port=8000/tcp
sudo firewall-cmd --permanent --add-port=50001/tcp  # Juno服务
sudo firewall-cmd --reload

# Ubuntu (ufw)
sudo ufw allow 8000/tcp
sudo ufw allow 50001/tcp

# 验证端口
sudo netstat -tulpn | grep :8000
```

### Nginx反向代理

```bash
# 安装Nginx
sudo yum install nginx -y    # CentOS/RHEL
# 或
sudo apt install nginx -y    # Ubuntu/Debian

# 配置反向代理
sudo tee /etc/nginx/conf.d/yearning.conf > /dev/null << 'EOF'
server {
    listen 80;
    server_name yearning.yourcompany.com;

    client_max_body_size 50M;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

# 测试配置并重启
sudo nginx -t
sudo systemctl restart nginx
```

## 🔧 Juno SQL检测服务

Juno提供高级SQL检测和优化功能，强烈建议生产环境启用：

```bash
# 使用Docker启动Juno服务
docker run -d \
  --name juno \
  --restart=always \
  -p 50001:50001 \
  cookiey/juno:latest

# 验证Juno服务
curl http://localhost:50001/health

# 设置Juno开机启动
sudo systemctl enable docker
```

## 📊 监控和维护

### 日志管理

```bash
# 查看实时日志
sudo journalctl -u yearning -f

# 查看应用日志
tail -f /opt/yearning/yearning-deployment-package/yearning-v20250917-72d84e6-linux-amd64/logs/yearning.log

# 配置日志轮转
sudo tee /etc/logrotate.d/yearning > /dev/null << 'EOF'
/opt/yearning/yearning-deployment-package/yearning-v20250917-72d84e6-linux-amd64/logs/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 yearning yearning
    postrotate
        systemctl reload yearning
    endscript
}
EOF
```

### 健康检查脚本

```bash
# 创建健康检查脚本
sudo tee /opt/yearning/health-check.sh > /dev/null << 'EOF'
#!/bin/bash
HEALTH_URL="http://localhost:8000"
LOG_FILE="/var/log/yearning-health.log"

if curl -f -s $HEALTH_URL > /dev/null; then
    echo "$(date): Yearning服务正常" >> $LOG_FILE
else
    echo "$(date): Yearning服务异常，尝试重启" >> $LOG_FILE
    systemctl restart yearning
fi
EOF

sudo chmod +x /opt/yearning/health-check.sh

# 添加到crontab（每5分钟检查一次）
echo "*/5 * * * * /opt/yearning/health-check.sh" | sudo crontab -
```

### 性能监控

```bash
# 监控进程资源使用
ps aux | grep yearning

# 监控端口状态
ss -tulpn | grep :8000

# 监控磁盘使用
du -sh /opt/yearning

# MySQL连接数监控
mysql -u root -p -e "SHOW PROCESSLIST;" | grep yearning | wc -l
```

## ⚠️ 故障排除

### 常见问题

#### 1. 端口被占用
```bash
# 查找占用进程
sudo lsof -i:8000

# 停止占用进程
sudo kill -9 <PID>

# 或使用其他端口
./yearning run --port 8082 --config conf/yearning.conf
```

#### 2. MySQL连接失败
```bash
# 检查MySQL服务
systemctl status mysql

# 测试连接
mysql -h 127.0.0.1 -P 3306 -u yearning -p

# 检查防火墙
sudo iptables -L | grep 3306
```

#### 3. 权限问题
```bash
# 检查文件权限
ls -la /opt/yearning

# 修复权限
sudo chown -R yearning:yearning /opt/yearning
sudo chmod +x /opt/yearning/yearning-deployment-package/yearning-v20250917-72d84e6-linux-amd64/yearning
```

#### 4. 内存不足
```bash
# 检查内存使用
free -h

# 检查进程内存
pmap -x $(pgrep yearning)

# 调整MySQL配置
sudo vim /etc/mysql/mysql.conf.d/mysqld.cnf
# 添加或修改：
# innodb_buffer_pool_size = 512M  # 根据可用内存调整
```

## 🔐 安全加固

### 数据库安全

```bash
# 限制MySQL用户访问
mysql -u root -p << 'EOF'
-- 删除默认权限，仅允许特定IP访问
DROP USER 'yearning'@'%';
CREATE USER 'yearning'@'127.0.0.1' IDENTIFIED BY 'STRONG_PASSWORD';
GRANT ALL PRIVILEGES ON yearning.* TO 'yearning'@'127.0.0.1';
FLUSH PRIVILEGES;
EOF
```

### 系统安全

```bash
# 禁用yearning用户登录
sudo usermod -s /sbin/nologin yearning

# 设置文件权限
sudo chmod 600 /opt/yearning/yearning-deployment-package/yearning-v20250917-72d84e6-linux-amd64/conf/yearning.conf
sudo chmod 755 /opt/yearning/yearning-deployment-package/yearning-v20250917-72d84e6-linux-amd64/yearning
```

## 📈 备份策略

```bash
# 创建备份脚本
sudo tee /opt/yearning/backup.sh > /dev/null << 'EOF'
#!/bin/bash
BACKUP_DIR="/backup/yearning"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# 备份数据库
mysqldump -u yearning -p yearning > $BACKUP_DIR/yearning_db_$DATE.sql

# 备份配置文件
cp -r /opt/yearning/yearning-deployment-package/yearning-v20250917-72d84e6-linux-amd64/conf $BACKUP_DIR/conf_$DATE

# 删除30天前的备份
find $BACKUP_DIR -name "*.sql" -mtime +30 -delete
find $BACKUP_DIR -name "conf_*" -mtime +30 -exec rm -rf {} \;

echo "$(date): 备份完成" >> /var/log/yearning-backup.log
EOF

sudo chmod +x /opt/yearning/backup.sh

# 添加到每日备份计划
echo "0 2 * * * /opt/yearning/backup.sh" | sudo crontab -
```

## ✅ 部署验证清单

- [ ] **系统环境**：Linux系统，内存≥2GB，磁盘≥10GB
- [ ] **MySQL服务**：MySQL 5.7+运行正常
- [ ] **网络端口**：8000和50001端口可用
- [ ] **二进制文件**：yearning可执行，权限正确
- [ ] **配置文件**：数据库连接信息正确
- [ ] **数据库初始化**：install命令执行成功
- [ ] **服务启动**：yearning进程运行正常
- [ ] **Web访问**：http://localhost:8000 可访问
- [ ] **登录测试**：admin/Yearning_admin 登录成功
- [ ] **系统服务**：systemd服务配置完成
- [ ] **防火墙**：必要端口已开放
- [ ] **Juno服务**：SQL检测功能正常（可选）
- [ ] **日志轮转**：日志管理配置完成
- [ ] **健康检查**：监控脚本运行正常
- [ ] **备份策略**：备份脚本配置完成

## 🎯 生产环境访问

**Web界面**: http://your-server:8000
**默认账号**: admin
**默认密码**: Yearning_admin

⚠️ **首次登录后请立即修改admin密码！**

---

**部署完成时间**: ___________
**运维负责人**: ___________
**验收人员**: ___________