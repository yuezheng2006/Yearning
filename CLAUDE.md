# Claude AI Assistant Configuration for Yearning

## 项目概览
Yearning是一个基于Go语言开发的MySQL SQL审计和查询平台，专为DBA和开发者设计，提供本地部署的隐私安全解决方案。

## 项目信息
- **项目名称**: Yearning SQL审计平台
- **主要语言**: Go (版本 1.21+)
- **框架**: 自定义Web框架(cookieY/yee)
- **数据库**: MySQL (使用GORM)
- **前端**: 独立前端项目(不在此仓库)

## 核心架构
```
Yearning/
├── main.go                 # 应用入口点
├── cmd/                    # CLI命令处理
├── src/
│   ├── apis/              # API层 - REST接口定义
│   ├── handler/           # 业务逻辑处理层
│   │   ├── common/        # 公共处理逻辑
│   │   ├── fetch/         # AI功能处理
│   │   ├── login/         # 认证授权
│   │   ├── manage/        # 管理功能
│   │   ├── order/         # 工单处理
│   │   └── personal/      # 个人相关
│   ├── model/             # 数据模型和数据库操作
│   ├── lib/               # 公共库
│   ├── router/            # 路由配置
│   └── service/           # 后台服务
└── migration/             # 数据库迁移脚本
```

## 关键依赖
- **Web框架**: github.com/cookieY/yee v0.5.2
- **数据库**: gorm.io/gorm v1.25.12 + MySQL驱动
- **AI集成**: github.com/sashabaranov/go-openai v1.36.1
- **身份验证**: github.com/golang-jwt/jwt v3.2.2
- **CLI**: github.com/gookit/gcli/v3 v3.2.3

## 开发规范

### 代码组织
- 遵循Go标准项目布局
- 业务逻辑在`/src/handler/`目录下按模块组织
- 数据模型统一在`/src/model/`
- 公共工具在`/src/lib/`

### 常用命令
```bash
# 初始化数据库
./Yearning install

# 启动服务
./Yearning run

# 获取帮助
./Yearning --help

# 开发调试
go run main.go run --config conf.toml

# 构建
go build -o Yearning main.go

# 测试
go test ./...
```

### 配置文件
- 主配置文件: `conf.toml` (基于`conf.toml.template`)
- 包含数据库连接、安全密钥、OIDC等配置

## 开发注意事项

### 数据库相关
- 使用GORM作为ORM
- 数据库迁移脚本在`/migration/`目录
- 模型定义在`/src/model/modal.go`

### 国际化
- 支持中文(zh_CN)和英文(en_US)
- 国际化文件在`/src/i18n/`

### AI功能
- 集成OpenAI API用于SQL优化和自然语言转SQL
- 相关代码在`/src/handler/fetch/ai.go`

### 消息推送
- 支持钉钉(DingTalk)和飞书(Feishu)Webhook通知
- 智能类型检测，根据URL自动识别平台
- 飞书支持交互式卡片，包含可点击按钮
- 工单状态变化实时推送通知
- 相关代码在`/src/lib/pusher/ding.go`

### 安全特性
- JWT认证
- RBAC权限控制
- 数据库密码加密存储
- LDAP集成支持

## 测试和部署
- 支持Docker部署
- 提供Docker Compose配置
- 自动化构建支持多架构(x86_64, ARM)

## 许可证
AGPL 3.0 - 开源但需要开放源代码

---
配置时间: 2025-09-08
Claude版本: Sonnet 4