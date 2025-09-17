<div align="center">

<h1 style="border-bottom: none">
    <b><a href="https://next.yearning.io">Yearning</a></b><br />
</h1>
</div>

A robust, locally deployed platform designed for seamless SQL detection and query auditing, tailored specifically for DBAs and developers. Focused on privacy and efficiency, it provides an intuitive and secure environment for MYSQL auditing.

---
[![OSCS Status](https://www.oscs1024.com/platform/badge/cookieY/Yearning.svg?size=small)](https://www.murphysec.com/dr/nDuoncnUbuFMdrZsh7)
![Platform Support](https://img.shields.io/badge/-x86_x64%20ARM%20Supports%20%E2%86%92-rgb(84,56,255)?style=flat-square&logoColor=white&logo=linux)
[![][github-license-shield]][github-license-link]
![GitHub top language](https://img.shields.io/github/languages/top/cookieY/Yearning?color=369eff&label=golang&labelColor=black&logo=golang&logoColor=white&style=flat-square)
[![][github-forks-shield]][github-forks-link]
[![][github-stars-shield]][github-stars-link]
[![Downloads](https://img.shields.io/github/downloads/cookieY/Yearning/total?labelColor=black&logo=download&logoColor=white&style=flat-square)](https://github.com/cookieY/Yearning/releases/latest)

English | [简体中文](README.zh-CN.md) | [日本語](README.ja-JP.md)

## ✨ Features

- **AI Assistant**: Our AI assistant offers real-time SQL optimization suggestions, enhancing SQL performance. It also supports text-to-SQL conversion, allowing users to input natural language and receive optimized SQL statements.

- **SQL Audit**: Create SQL audit tickets with approval workflows and automated syntax checks. Validate SQL statements for correctness, security, and compliance. Rollback statements are automatically generated for DDL/DML operations, with a comprehensive history log for traceability.

- **Query Audit**: Audit user queries, restrict data sources and databases, and anonymize sensitive fields. Query records are saved for future reference.

- **Check Rules**: Our automated syntax checker supports a wide range of check rules, suitable for most automatic checking scenarios.

- **Privacy Focused**: Yearning is a locally deployable, open-source solution that ensures the security of your database and SQL statements. It includes encryption mechanisms to protect sensitive data, ensuring it remains secure even if unauthorized access occurs.

- **RBAC (Role-Based Access Control)**: Create and manage roles with specific permissions, restricting access to query work orders, auditing functions, and other sensitive operations based on user roles.

> [!TIP]
> For more detailed information, visit our [Yearning Guide](https://next.yearning.io)

## 🚀 Quick Start

### Production Deployment (Recommended) ⭐

Download the [latest release](https://github.com/cookieY/Yearning/releases/latest) and use binary deployment for optimal performance.

**Version**: v20250917-72d84e6
**Build Time**: 2025-09-17T04:26:26Z
**Git Commit**: 72d84e66453fb9f94d22da4608e4d785374351a8

```bash
# 1. Download and extract deployment package
wget https://github.com/cookieY/Yearning/releases/download/v20250917/yearning-deployment-package.tar.gz
tar -xzf yearning-deployment-package.tar.gz
cd yearning-deployment-package

# 2. Extract Linux binary package
tar -xzf yearning-v20250917-72d84e6-linux-amd64.tar.gz
cd yearning-v20250917-72d84e6-linux-amd64

# 3. Create configuration directory and file
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
RpcAddr = "127.0.0.1:50001"
LogLevel = "info"
Lang = "zh_CN"

[Oidc]
Enable = false
EOF

# 4. Edit configuration file
vim conf/yearning.conf

# 5. Initialize database
./yearning install

# 6. Start service
./yearning run --config conf/yearning.conf
```

#### macOS Development Environment

```bash
# Extract macOS binary package
tar -xzf yearning-v20250917-72d84e6-darwin-arm64.tar.gz
cd yearning-v20250917-72d84e6-darwin-arm64

# Or use quick test script
chmod +x quick-mac-test.sh
./quick-mac-test.sh
```

### Alternative Deployment Methods

#### Automated Script Deployment

```bash
# Download and extract deployment package
wget https://github.com/cookieY/Yearning/releases/download/v20250917/yearning-deployment-package.tar.gz
tar -xzf yearning-deployment-package.tar.gz
cd yearning-deployment-package

# Run automated deployment script
chmod +x deploy-production.sh
./deploy-production.sh
```

#### Docker Deployment
[![][docker-release-shield]][docker-release-link]
[![][docker-size-shield]][docker-size-link]
[![][docker-pulls-shield]][docker-pulls-link]

```bash
# Use production Docker Compose
docker-compose -f docker-compose.production.yml up -d
```

### Build from Source

```bash
# 1. Build integrated application (Frontend + Backend)
./build.sh

# 2. Configure database
cp conf.toml.template conf.toml
# Edit conf.toml to set MySQL connection

# 3. Initialize database
./Yearning install

# 4. Start service
./Yearning run
```

## 📦 System Requirements

### Production Environment (Recommended)
- **Operating System**: Linux (CentOS 7+/Ubuntu 18.04+)
- **Database**: MySQL 5.7 (Production Standard)
- **Memory**: Minimum 2GB, Recommended 4GB+
- **Disk**: Minimum 10GB available space

### Development/Test Environment
- **Operating System**: macOS (Apple Silicon) or Linux
- **Database**: MySQL 5.7+ or Docker
- **Memory**: Minimum 1GB

## ⚙️ Configuration

### Core Configuration Items

```toml
[Mysql]
Db = "yearning"
Host = "127.0.0.1"  # Production MySQL address
Port = "3306"
Password = "your_encrypted_password"  # Use AES encrypted password
User = "yearning"

[General]
SecretKey = "your_16_char_key_here"  # Must be 16 characters
RpcAddr = "127.0.0.1:50001"         # Juno RPC service address
LogLevel = "info"                    # Use info for production
Lang = "zh_CN"

[Oidc]
Enable = false  # Enable OIDC as needed
```

### Password Encryption

Yearning uses AES encryption to store database passwords, the key must be 16 characters:

```bash
# Use deploy-production.sh script to automatically generate encrypted passwords
echo "Please use deploy-production.sh script to automatically generate encrypted passwords"
```

## 🗄️ Database Initialization

### MySQL 5.7 Production Configuration

```sql
-- Create database and user
CREATE DATABASE yearning CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'yearning'@'%' IDENTIFIED BY 'your_password';
GRANT ALL PRIVILEGES ON yearning.* TO 'yearning'@'%';
FLUSH PRIVILEGES;

-- If accessing from Docker containers
GRANT ALL PRIVILEGES ON yearning.* TO 'yearning'@'172.%.%.%';
```

### Audit Rules Optimization

Default audit rules may be too strict, recommended adjustments:

```sql
-- Connect to Yearning database, update audit rules
UPDATE core_rules
SET audit_role = JSON_SET(
  audit_role,
  '$.DMLSelect', true,      -- Allow SELECT statements
  '$.DMLWhere', true,       -- Allow WHERE clauses
  '$.DMLOrder', true,       -- Allow ORDER BY
  '$.DMLAllowLimitSTMT', true  -- Allow LIMIT statements
)
WHERE id = 1;
```

Common audit rule descriptions:
- `DMLSelect`: Controls whether SELECT statements are allowed
- `DMLWhere`: Controls whether WHERE conditions are required
- `DMLOrder`: Controls whether ORDER BY is allowed
- `MaxAffectRows`: Maximum affected rows limit

### Juno SQL Detection Service

Yearning integrates Juno service for SQL detection and optimization:

```bash
# Start Juno service (Docker method)
docker run -d \
  --name juno \
  -p 50001:50001 \
  cookiey/juno:latest

# Verify Juno service
curl http://localhost:50001/health
```

## 🤖 AI Assistance

Our AI Assistant leverages a large language model to provide SQL optimization suggestions and text-to-SQL conversion. Whether using default or custom prompts, the AI Assistant enhances SQL performance by optimizing statements and converting natural language inputs into SQL queries.

![Text to SQL](img/text2sql.jpg)

## 🔖 Automated SQL Checker

The automated SQL checker evaluates SQL statements based on predefined rules and syntax. It ensures compliance with specific coding standards, best practices, and security requirements, providing a robust validation layer.

![SQL Audit](img/audit.png)

## 💡 SQL Syntax Highlighting and Auto-completion

Enhance your query writing efficiency with SQL syntax highlighting and auto-completion features. These features help visually distinguish different components of SQL queries (keywords, table names, column names, operators, etc.), making it easier to read and understand query structure.

![SQL Query](img/query.png)

## ⏺️ Order/Query Records

Our platform supports auditing of user orders and query statements. This feature allows you to track and record all query operations, including data source, database, and sensitive field handling, ensuring query operations comply with regulations and providing traceability for query history.

![Order/Query Records](img/record.png)

## 🔧 Troubleshooting

### Common Issues

#### Port Conflicts
If you encounter port occupation, manually specify available ports:
```bash
# Check port occupation
lsof -i:8000  # Check port 8000
lsof -i:8080  # Check port 8080

# Start with other ports (e.g., 8082)
./yearning run --port 8082 --config conf/yearning.conf
```

#### MySQL Connection Issues
Support multiple MySQL connection methods:
```bash
# 1. Local MySQL (requires root password)
mysql -u root -p

# 2. Remote MySQL (recommended for test environment)
mysql -h <remote_ip> -P <port> -u <user> -p

# 3. Docker MySQL
docker run -d --name mysql-test -e MYSQL_ROOT_PASSWORD=test123 -p 3307:3306 mysql:5.7
```

#### Strict Audit Rules
```sql
-- Relax audit rules
UPDATE core_rules
SET audit_role = JSON_SET(audit_role, '$.DMLSelect', true)
WHERE id = 1;
```

#### Permission Configuration Errors
```sql
-- Check user permission configuration
SELECT username, `group` FROM core_graineds WHERE username = 'admin';
SELECT permissions FROM core_role_groups WHERE group_id = '<group_id>';
```

## 🛠️ Recommended Tools

- [Spug - Open Source Lightweight Automation Operations Platform](https://github.com/openspug/spug)

## ☎️ Contact

For inquiries, please contact us at: henry@yearning.io

## 📋 License

Yearning is licensed under the AGPL license. See [LICENSE](LICENSE) for details.

2024 © Henry Yee

---

Experience a smooth, secure, and efficient approach to SQL auditing and optimization with Yearning.


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