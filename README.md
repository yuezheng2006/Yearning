<div align="center">

<h1 style="border-bottom: none">
    <b><a href="https://next.yearning.io">Yearning</a></b><br />
</h1>
</div>

一个强大的本地部署SQL审计和查询平台，专为DBA和开发者设计，提供无缝的SQL检测和审计功能。专注于隐私和效率，为MySQL审计提供直观安全的环境。

---
[![OSCS Status](https://www.oscs1024.com/platform/badge/cookieY/Yearning.svg?size=small)](https://www.murphysec.com/dr/nDuoncnUbuFMdrZsh7)
![Platform Support](https://img.shields.io/badge/-x86_x64%20ARM%20支持%20%E2%86%92-rgb(84,56,255)?style=flat-square&logoColor=white&logo=linux)
[![][github-license-shield]][github-license-link]
![GitHub top language](https://img.shields.io/github/languages/top/cookieY/Yearning?color=369eff&label=golang&labelColor=black&logo=golang&logoColor=white&style=flat-square)
[![][github-forks-shield]][github-forks-link]
[![][github-stars-shield]][github-stars-link]
[![Downloads](https://img.shields.io/github/downloads/cookieY/Yearning/total?labelColor=black&logo=download&logoColor=white&style=flat-square)](https://github.com/cookieY/Yearning/releases/latest)

[English](README.en.md) | 简体中文 | [日本語](README.ja-JP.md)

## ✨ 功能特性

- **AI智能助手**: 我们的AI助手提供实时SQL优化建议，提升SQL性能。同时支持自然语言转SQL功能，用户可以输入自然语言并获得优化的SQL语句。

- **SQL审核**: 创建带有审批流程和自动语法检查的SQL审核工单。验证SQL语句的正确性、安全性和合规性。为DDL/DML操作自动生成回滚语句，并提供完整的历史日志以便追溯。

- **查询审计**: 审计用户查询，限制数据源和数据库访问，对敏感字段进行匿名化。查询记录被保存以备将来参考。

- **检查规则**: 我们的自动语法检查器支持广泛的检查规则，适用于大多数自动检查场景。

- **隐私保护**: Yearning是一个本地可部署的开源解决方案，确保您的数据库和SQL语句的安全性。它包含加密机制来保护敏感数据，即使发生未经授权的访问也能确保数据安全。

- **RBAC(基于角色的访问控制)**: 创建和管理具有特定权限的角色，根据用户角色限制对查询工单、审计功能和其他敏感操作的访问。

> [!TIP]
> 更多详细信息，请访问 [Yearning 使用指南](https://next.yearning.io)

## 🚀 快速开始

### 生产环境部署 (推荐) ⭐

获取定制版本并使用二进制部署以获得最佳性能。本版本包含Juno问题修复和生产环境优化。

**版本**: v20250917-72d84e6
**构建时间**: 2025-09-17T04:26:26Z
**Git提交**: 72d84e66453fb9f94d22da4608e4d785374351a8

```bash
# 1. 克隆仓库获取部署包
git clone https://github.com/yuezheng2006/Yearning.git
cd Yearning/yearning-deployment-package

# 2. 解压Linux二进制包
tar -xzf yearning-v20250917-72d84e6-linux-amd64.tar.gz
cd yearning-v20250917-72d84e6-linux-amd64

# 3. 创建配置目录和文件
mkdir -p conf
cat > conf/yearning.conf << 'EOF'
[Mysql]
Db = "yearning"
Host = "127.0.0.1"
Port = "3306"
Password = "your_password"
User = "yearning"

[General]
SecretKey = "your_16_char_key_"
RpcAddr = ""              # 留空使用内置Juno引擎(推荐)
LogLevel = "info"
Lang = "zh_CN"

[Oidc]
Enable = false
EOF

# 4. 编辑配置文件
vim conf/yearning.conf

# 5. 初始化数据库
./yearning install

# 6. 启动服务
./yearning run --config conf/yearning.conf
```

#### macOS 开发环境

```bash
# 解压macOS二进制包
tar -xzf yearning-v20250917-72d84e6-darwin-arm64.tar.gz
cd yearning-v20250917-72d84e6-darwin-arm64

# 或者使用快速测试脚本
chmod +x quick-mac-test.sh
./quick-mac-test.sh
```

### 其他部署方式

#### 自动化脚本部署

```bash
# 克隆仓库获取部署包
git clone https://github.com/yuezheng2006/Yearning.git
cd Yearning/yearning-deployment-package

# 运行自动化部署脚本
chmod +x deploy-production.sh
./deploy-production.sh
```

#### Docker 部署
[![][docker-release-shield]][docker-release-link]
[![][docker-size-shield]][docker-size-link]
[![][docker-pulls-shield]][docker-pulls-link]

```bash
# 使用生产环境Docker Compose
docker-compose -f docker-compose.production.yml up -d
```

### 从源码构建

```bash
# 1. 构建集成应用(前端+后端)
./build.sh

# 2. 配置数据库
cp conf.toml.template conf.toml
# 编辑conf.toml设置MySQL连接

# 3. 初始化数据库
./Yearning install

# 4. 启动服务
./Yearning run
```

## 📦 系统要求

### 生产环境 (推荐)
- **操作系统**: Linux (CentOS 7+/Ubuntu 18.04+)
- **数据库**: MySQL 5.7 (生产环境标准)
- **内存**: 最低2GB，推荐4GB+
- **磁盘**: 最低10GB可用空间

### 开发/测试环境
- **操作系统**: macOS (Apple Silicon) 或 Linux
- **数据库**: MySQL 5.7+ 或 Docker
- **内存**: 最低1GB

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
RpcAddr = ""                         # 留空使用内置Juno引擎(推荐)
LogLevel = "info"                    # 生产环境使用info
Lang = "zh_CN"

[Oidc]
Enable = false  # 根据需要启用OIDC
```

### 密码加密

Yearning使用AES加密存储数据库密码，密钥必须是16位字符：

```bash
# 使用deploy-production.sh脚本自动生成加密密码
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

### 内置Juno引擎

本版本包含完整的内置Juno引擎，无需外部服务：

```bash
# 推荐配置：使用内置引擎
RpcAddr = ""  # 留空自动使用内置引擎

# 可选：如果需要外部Juno服务
docker run -d \
  --name juno \
  -p 50001:50001 \
  cookiey/juno:latest

# 验证Juno服务
curl http://localhost:50001/health
```

## 🤖 AI智能助手

我们的AI助手利用大型语言模型提供SQL优化建议和文本转SQL功能。无论使用默认提示还是自定义提示，AI助手都能通过优化语句和将自然语言输入转换为SQL查询来提升SQL性能。

![文本转SQL](img/text2sql.jpg)

## 🔖 自动SQL检查器

自动SQL检查器基于预定义规则和语法评估SQL语句。它确保符合特定编码标准、最佳实践和安全要求，提供强大的验证层。

![SQL审核](img/audit.png)

## 💡 SQL语法高亮和自动补全

通过SQL语法高亮和自动补全功能提升您的查询编写效率。这些功能有助于直观地区分SQL查询的不同组件（关键字、表名、列名、操作符等），使查询结构更容易阅读和理解。

![SQL查询](img/query.png)

## ⏺️ 工单/查询记录

我们的平台支持对用户工单和查询语句进行审计。此功能允许您跟踪和记录所有查询操作，包括数据源、数据库和敏感字段处理，确保查询操作符合规定并为查询历史提供可追溯性。

![工单/查询记录](img/record.png)

## 🔧 故障排除

### 常见问题

#### 端口冲突
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

## 🛠️ 推荐工具

- [Spug - 开源轻量自动化运维平台](https://github.com/openspug/spug)

## ☎️ 联系方式

如有疑问，请联系我们：henry@yearning.io

## 📋 许可证

Yearning遵循AGPL许可证。详情请见 [LICENSE](LICENSE)。

2024 © Henry Yee

---

使用Yearning体验流畅、安全、高效的SQL审计和优化方法。


[docker-pulls-link]: https://hub.docker.com/r/yeelabs/yearning
[docker-pulls-shield]: https://img.shields.io/docker/pulls/yeelabs/yearning?color=45cc11&labelColor=black&style=flat-square
[docker-release-link]: https://hub.docker.com/r/yeelabs/yearning
[docker-release-shield]: https://img.shields.io/docker/v/yeelabs/yearning?color=369eff&label=docker&labelColor=black&logo=docker&logoColor=white&style=flat-square
[docker-size-link]: https://hub.docker.com/r/yeelabs/yearning
[docker-size-shield]: https://img.shields.io/docker/image-size/yeelabs/yearning?color=369eff&labelColor=black&style=flat-square
[github-forks-shield]: https://img.shields.io/github/forks/cookieY/Yearning?color=8ae8ff&labelColor=black&style=flat-square
[github-forks-link]: https://github.com/cookieY/Yearning/network/members
[github-stars-link]: https://github.com/cookieY/Yearning/network/stargazers
[github-stars-shield]: https://img.shields.io/github/stars/cookieY/Yearning?color=ffcb47&labelColor=black&style=flat-square
[github-license-link]: https://github.com/cookieY/Yearning/blob/main/LICENSE
[github-license-shield]: https://img.shields.io/badge/AGPL%203.0-white?labelColor=black&style=flat-square