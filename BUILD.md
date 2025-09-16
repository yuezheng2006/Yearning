# 📦 Yearning 构建指南

## 🎯 快速开始

```bash
# 一键构建（前端+后端）
./build.sh

# 配置数据库
cp conf.toml.template conf.toml

# 初始化并启动  
./Yearning install
./Yearning run
```

访问: http://localhost:8000

## 🏗️ 架构特点

✅ **前后端一体化**: 使用Go embed将Vue3前端嵌入到单一二进制文件  
✅ **官方前端**: 集成gemini-next项目 (Vue3 + Vite)  
✅ **智能构建**: 自动检测并按需构建前端  
✅ **单文件部署**: 无需单独前端服务器  

```
┌─────────────────────────────────────────┐
│        单一Go二进制文件                 │
│  ┌─────────────────────────────────────┐ │
│  │     前端静态资源 (embed)            │ │  ← 编译时嵌入
│  │     Vue3 + Vite (gemini-next)      │ │
│  └─────────────────────────────────────┘ │
│           后端API服务                   │
│           MySQL连接                     │
└─────────────────────────────────────────┘
```

## 📁 文件结构

```
Yearning/
├── build.sh                # 完整构建脚本 (前端+后端)
├── build-frontend.sh       # 前端构建脚本  
├── frontend/               # 前端源码 (gemini-next)
├── src/service/dist/       # 前端构建产物 (embed嵌入)
└── Yearning                # 单一二进制文件 (包含前端)
```

## 🔧 构建脚本

### build.sh - 主构建脚本
- 自动检测前端是否需要构建
- 支持交叉编译 (macOS → Linux)
- 提供构建统计信息
- 智能检测操作系统平台

### build-frontend.sh - 前端构建脚本
- 使用本地 `frontend/` 目录
- 支持 Vue3 + Vite 项目
- 自动安装依赖 (yarn/npm)
- 构建产物复制到 `src/service/dist/`

## 🎨 前端技术栈

- **框架**: Vue 3.2.39
- **构建工具**: Vite 3.1.0
- **UI库**: Ant Design Vue 3.2.15
- **编程语言**: TypeScript
- **代码编辑器**: Monaco Editor
- **图表库**: @antv/g2

## 🔄 二次开发

### 开发流程

```bash
# 1. 克隆项目 (前端代码已包含)
git clone <your-repo>
cd Yearning

# 2. 前端开发模式 (可选)
cd frontend
npm run dev  # 启动开发服务器，支持热更新
cd ..

# 3. 构建前端 (修改后必须)
./build-frontend.sh

# 4. 构建后端一体化应用
./build.sh

# 5. 部署
./Yearning install  # 首次安装
./Yearning run      # 启动服务
```

### 开发注意事项
- 前端修改后必须重新运行 `./build-frontend.sh` 构建
- 前端构建完成后需要运行 `./build.sh` 重新编译后端
- 最终部署的是包含前端资源的单个二进制文件

## 🔍 embed 实现原理

### Go代码实现

```go
// src/service/yearning.go
package service

import "embed"

//go:embed dist/*
var f embed.FS

//go:embed dist/index.html
var html string

func StartYearning(port string) {
    e := yee.New()
    // 将嵌入的文件系统挂载到 /front 路径
    e.Pack("/front", f, "dist")
    
    // 根路径返回主页
    e.GET("/", func(c yee.Context) error {
        return c.HTML(http.StatusOK, html)
    })
    // ...
}
```

### 访问路径

- **主页**: `http://localhost:8000/`
- **前端应用**: `http://localhost:8000/front/`
- **API接口**: `http://localhost:8000/api/`

## 📦 生产部署

### 方式1: 二进制部署 (推荐)

```bash
# 1. 构建
./build.sh

# 2. 部署到服务器
scp Yearning conf.toml user@server:/opt/yearning/

# 3. 配置数据库 (编辑 conf.toml)
[Mysql]
Host = "你的MySQL地址"
Port = "3306"
User = "yearning"
Password = "你的密码"
Db = "yearning"

# 4. 初始化并启动
./Yearning install  # 初始化数据库
./Yearning run       # 启动服务
```

### 方式2: Docker部署

```bash
# 1. 启动
docker-compose -f docker-compose.prod.yml up -d

# 2. 初始化数据库
docker-compose -f docker-compose.prod.yml exec yearning ./Yearning install
```

### 默认账号
- 用户名: `admin`
- 密码: `Yearning_admin`
- 地址: `http://你的服务器:8000`

## ⚠️ 注意事项

1. **Node.js版本**: 建议使用 Node.js 16+
2. **依赖安装**: 使用 `--legacy-peer-deps` 解决依赖冲突
3. **构建顺序**: 必须先构建前端，再构建后端
4. **文件大小**: 嵌入前端后，二进制文件约30MB
5. **更新前端**: 每次前端修改后需要重新构建整个应用

## 📚 相关链接

- [官方前端项目](https://github.com/cookieY/gemini-next)
- [Go embed文档](https://pkg.go.dev/embed)
- [Vite构建配置](https://vitejs.dev/config/)

---

🎉 **Yearning现在支持现代化的前后端一体化构建和部署！**
