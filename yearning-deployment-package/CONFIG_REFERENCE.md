# Yearning 配置文件详细参考

**版本**: v20250917-72d84e6  
**适用环境**: Linux生产环境部署  
**文件位置**: `conf/yearning.conf`

---

## 📋 配置文件结构

Yearning使用TOML格式的配置文件，主要包含以下几个部分：
- `[Mysql]` - 数据库连接配置
- `[General]` - 系统通用配置  
- `[Oidc]` - 单点登录配置

---

## 🗄️ [Mysql] 数据库配置

### Db
```toml
Db = "yearning"
```
- **说明**: 数据库名称
- **类型**: 字符串
- **必填**: ✅ 是
- **示例**: `"yearning"`, `"Yearning"`, `"sql_audit"`
- **注意事项**: 
  - 必须与MySQL中实际创建的数据库名称完全一致
  - 区分大小写
  - 建议使用小写字母和下划线

### Host
```toml
Host = "127.0.0.1"
```
- **说明**: MySQL服务器地址
- **类型**: 字符串
- **必填**: ✅ 是
- **示例**: 
  - `"127.0.0.1"` - 本地数据库
  - `"10.10.106.42"` - 内网数据库
  - `"mysql.example.com"` - 域名访问
- **注意事项**:
  - 确保网络连通性
  - 防火墙端口开放
  - 如使用域名，确保DNS解析正常

### Port
```toml
Port = "3306"
```
- **说明**: MySQL服务端口
- **类型**: 字符串（注意是字符串格式）
- **必填**: ✅ 是
- **默认值**: `"3306"`
- **示例**: `"3306"`, `"13306"`, `"33060"`
- **注意事项**:
  - 端口号用引号包围
  - 确保端口未被其他服务占用
  - 防火墙需开放对应端口

### User
```toml
User = "root"
```
- **说明**: MySQL用户名
- **类型**: 字符串
- **必填**: ✅ 是
- **权限要求**: 
  - 对Yearning数据库有完全访问权限
  - 能够创建、修改、删除表结构
  - 建议创建专用用户而非直接使用root
- **示例**: `"root"`, `"yearning"`, `"sql_audit_user"`

### Password
```toml
Password = "your_password"
```
- **说明**: MySQL用户密码
- **类型**: 字符串
- **必填**: ✅ 是
- **支持格式**:
  - **明文密码**: `"ktvsky5166"`
  - **AES加密**: `"encrypted_base64_string"`
- **加密说明**:
  - 系统会自动尝试使用SecretKey解密
  - 解密失败则作为明文使用
  - 推荐生产环境使用加密密码
- **安全建议**:
  - 密码长度不少于8位
  - 包含大小写字母、数字、特殊字符
  - 定期更换密码

---

## ⚙️ [General] 系统配置

### SecretKey
```toml
SecretKey = "dbcjqheupqjsuwsm"
```
- **说明**: 系统加密密钥
- **类型**: 字符串
- **必填**: ✅ 是
- **长度要求**: 必须是16位字符
- **用途**:
  - JWT Token签名
  - 数据库密码加密/解密
  - 系统内部数据加密
- **安全要求**:
  - 🔴 **极其重要**: 泄露会导致系统安全风险
  - 生产环境必须使用强随机字符串
  - 不要使用默认值或简单字符串
- **示例**: `"a1b2c3d4e5f6g7h8"`, `"prod_key_16char"`

### Hours
```toml
Hours = 4
```
- **说明**: JWT Token有效期（小时）
- **类型**: 整数
- **必填**: ❌ 否
- **默认值**: 4
- **推荐值**: 
  - 开发环境: 8-24小时
  - 生产环境: 2-8小时
- **注意事项**: 值过大会降低安全性，过小会影响用户体验

### RpcAddr
```toml
RpcAddr = ""
```
- **说明**: Juno SQL检测服务地址
- **类型**: 字符串
- **必填**: ❌ 否
- **配置选项**:
  - **空字符串** `""`: 使用内置SQL检测引擎（🔥推荐）
  - **外部服务**: `"127.0.0.1:50001"`, `"juno:50001"`
- **部署模式对比**:

| 配置值 | 部署模式 | 优势 | 适用场景 |
|--------|---------|------|----------|
| `""` | 单体部署 | 简单、稳定、易维护 | 中小型团队、快速部署 |
| `"host:port"` | 微服务部署 | 性能更好、功能完整 | 大型生产环境 |

- **推荐设置**: 生产环境建议使用 `""` 以获得最佳稳定性

### LogLevel
```toml
LogLevel = "info"
```
- **说明**: 日志级别
- **类型**: 字符串
- **必填**: ❌ 否
- **默认值**: `"info"`
- **可选值**:
  - `"debug"`: 详细调试信息（开发环境）
  - `"info"`: 一般信息（🔥生产推荐）
  - `"warn"`: 警告信息
  - `"error"`: 仅错误信息
- **环境建议**:
  - 开发/测试: `"debug"`
  - 生产环境: `"info"` 或 `"warn"`

### Lang
```toml
Lang = "zh_CN"
```
- **说明**: 系统界面语言
- **类型**: 字符串
- **必填**: ❌ 否
- **默认值**: `"en_US"`
- **可选值**:
  - `"zh_CN"`: 简体中文
  - `"en_US"`: 英文
- **注意事项**: 影响Web界面显示语言和错误提示语言

---

## 🔐 [Oidc] 单点登录配置

> **说明**: OIDC（OpenID Connect）用于企业级单点登录集成

### Enable
```toml
Enable = false
```
- **说明**: 是否启用OIDC登录
- **类型**: 布尔值
- **默认值**: `false`
- **用途**: 与企业IdP（如Keycloak、Azure AD）集成

### ClientId
```toml
ClientId = "yearning"
```
- **说明**: OIDC客户端ID
- **类型**: 字符串
- **必填**: 仅在Enable=true时
- **获取方式**: 从IdP提供商获取

### ClientSecret
```toml
ClientSecret = "your_client_secret"
```
- **说明**: OIDC客户端密钥
- **类型**: 字符串
- **必填**: 仅在Enable=true时
- **安全要求**: 
  - 保密存储
  - 定期轮换
  - 不要提交到版本控制

### Scope
```toml
Scope = "openid profile"
```
- **说明**: OIDC权限范围
- **类型**: 字符串
- **常用值**: `"openid profile email"`

### AuthUrl
```toml
AuthUrl = "https://keycloak.xxx.ca/auth/realms/master/protocol/openid-connect/auth"
```
- **说明**: OIDC认证端点
- **类型**: 字符串（URL）
- **获取方式**: 从IdP配置中获取

### TokenUrl
```toml
TokenUrl = "https://keycloak.xxx.ca/auth/realms/master/protocol/openid-connect/token"
```
- **说明**: OIDC令牌端点
- **类型**: 字符串（URL）
- **获取方式**: 从IdP配置中获取

### UserUrl
```toml
UserUrl = "https://keycloak.xxx.ca/auth/realms/master/protocol/openid-connect/userinfo"
```
- **说明**: OIDC用户信息端点
- **类型**: 字符串（URL）
- **获取方式**: 从IdP配置中获取

### RedirectUrL
```toml
RedirectUrL = "http://127.0.0.1:8000/oidc/_token-login"
```
- **说明**: OIDC回调地址
- **类型**: 字符串（URL）
- **格式**: `http(s)://your-domain:port/oidc/_token-login`
- **注意事项**: 
  - 必须与IdP中配置的回调地址完全一致
  - 使用实际的Yearning访问地址

### 用户字段映射

#### UserNameKey
```toml
UserNameKey = "preferred_username"
```
- **说明**: OIDC用户名字段映射
- **默认值**: `"preferred_username"`

#### RealNameKey
```toml
RealNameKey = "name"
```
- **说明**: OIDC真实姓名字段映射
- **默认值**: `"name"`

#### EmailKey
```toml
EmailKey = "email"
```
- **说明**: OIDC邮箱字段映射
- **默认值**: `"email"`

#### SessionKey
```toml
SessionKey = "session_state"
```
- **说明**: OIDC会话标识字段映射
- **默认值**: `"session_state"`

---

## 📝 完整配置示例

### 基础配置（推荐）
```toml
[Mysql]
Db = "yearning"
Host = "127.0.0.1"
Port = "3306"
Password = "strong_password_123"
User = "yearning"

[General]
SecretKey = "your_16char_key!"  # 必须修改
Hours = 4
RpcAddr = ""                    # 使用内置引擎
LogLevel = "info"
Lang = "zh_CN"

[Oidc]
Enable = false
```

### 企业环境配置
```toml
[Mysql]
Db = "yearning_prod"
Host = "mysql.internal.com"
Port = "3306"
Password = "encrypted_password_base64"
User = "yearning_user"

[General]
SecretKey = "prod_secret_16chr"  # 生产环境密钥
Hours = 2                        # 短期有效期
RpcAddr = ""                     # 稳定的内置引擎
LogLevel = "warn"                # 减少日志量
Lang = "zh_CN"

[Oidc]
Enable = true
ClientId = "yearning-prod"
ClientSecret = "oidc_client_secret"
Scope = "openid profile email"
AuthUrl = "https://sso.company.com/auth"
TokenUrl = "https://sso.company.com/token"
UserUrl = "https://sso.company.com/userinfo"
RedirectUrL = "https://yearning.company.com/oidc/_token-login"
UserNameKey = "preferred_username"
RealNameKey = "name"
EmailKey = "email"
SessionKey = "session_state"
```

---

## ⚠️ 安全最佳实践

### 🔒 密钥安全
1. **SecretKey**: 使用强随机16位字符串
2. **密码加密**: 生产环境建议加密存储数据库密码
3. **权限最小化**: 创建专用数据库用户，避免使用root
4. **定期轮换**: 定期更换密钥和密码

### 🌐 网络安全
1. **内网部署**: 数据库尽量部署在内网
2. **防火墙**: 只开放必要的端口
3. **SSL/TLS**: 生产环境启用HTTPS
4. **访问控制**: 配置适当的网络访问策略

### 📊 监控建议
1. **日志监控**: 监控错误日志和异常访问
2. **性能监控**: 监控数据库连接和响应时间
3. **安全审计**: 定期检查用户权限和操作日志
4. **备份策略**: 定期备份配置文件和数据库

---

## 🔧 故障排除

### 常见配置错误

| 错误现象 | 可能原因 | 解决方案 |
|---------|---------|----------|
| 数据库连接失败 | Host/Port/密码错误 | 检查数据库配置和网络连通性 |
| "juno client is nil" | RpcAddr配置错误 | 设置 `RpcAddr = ""` |
| JWT验证失败 | SecretKey错误 | 检查SecretKey长度和字符 |
| 界面显示异常 | Lang配置错误 | 使用 `"zh_CN"` 或 `"en_US"` |
| OIDC登录失败 | 回调地址不匹配 | 检查RedirectUrL配置 |

### 配置验证命令
```bash
# 测试数据库连接
mysql -h 127.0.0.1 -P 3306 -u yearning -p

# 检查配置文件语法
cat conf/yearning.conf | grep -v "^#" | grep -v "^$"

# 启动时检查日志
./yearning run --config conf/yearning.conf
```

---

## 📞 技术支持

- **文档**: 参考 `LINUX_PRODUCTION_DEPLOYMENT.md`
- **问题排查**: 查看应用日志和错误信息
- **配置生成**: 可使用脚本自动生成基础配置

---

**最后更新**: 2025-09-17  
**文档版本**: v1.0  
**维护者**: Yearning Team
