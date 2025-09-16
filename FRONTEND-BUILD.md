# 🎨 Yearning 前端构建指南

## 📋 概述

Yearning 使用 **Go embed** 技术将前端静态资源嵌入到后端二进制文件中，实现前后端一体化部署。

### 🏗️ 架构设计

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

## 🎯 前端技术栈

- **框架**: Vue 3.2.39
- **构建工具**: Vite 3.1.0
- **UI库**: Ant Design Vue 3.2.15
- **编程语言**: TypeScript
- **代码编辑器**: Monaco Editor
- **图表库**: @antv/g2

## 🚀 快速构建

### 方法1: 使用构建脚本 (推荐)

```bash
# 一键构建前端
./build-frontend.sh

# 构建完整应用
./build.sh
```

### 方法2: 手动构建

```bash
# 1. 克隆官方前端项目
mkdir -p ~/workspace
git clone -b next https://github.com/cookieY/gemini-next.git ~/workspace/yearning-frontend

# 2. 安装依赖
cd ~/workspace/yearning-frontend
npm install --legacy-peer-deps

# 3. 构建前端
npm run build

# 4. 复制到后端项目
rm -rf src/service/dist
cp -r ~/workspace/yearning-frontend/dist src/service/dist

# 5. 构建完整应用
./build.sh
```

## 📁 目录结构

```
Yearning/
├── src/service/
│   ├── dist/                    # 前端构建产物 (embed嵌入)
│   │   ├── index.html          # 主页面
│   │   └── assets/             # 静态资源
│   └── yearning.go             # embed配置
├── build-frontend.sh           # 前端构建脚本
└── build.sh                    # 完整构建脚本
```

## 🔧 embed 实现原理

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

## 🎛️ 开发模式

如需前端热重载开发，可以独立运行前端：

```bash
# 启动前端开发服务器
cd ~/workspace/yearning-frontend
npm run dev

# 前端会代理API请求到后端 (localhost:8000)
# 访问: http://localhost:5173
```

## 📦 生产部署

```bash
# 1. 构建
./build-frontend.sh
./build.sh

# 2. 部署单一二进制文件
scp Yearning user@server:/opt/yearning/
scp conf.toml user@server:/opt/yearning/

# 3. 服务器上运行
./Yearning install  # 初始化数据库
./Yearning run       # 启动服务
```

## 🔍 构建验证

```bash
# 检查嵌入的文件
go run -c "
package main
import (\"embed\"; \"fmt\"; \"io/fs\")
//go:embed src/service/dist/*
var files embed.FS
func main() {
    fs.WalkDir(files, \".\", func(path string, d fs.DirEntry, err error) error {
        if !d.IsDir() {
            info, _ := d.Info()
            fmt.Printf(\"%s (%d bytes)\\n\", path, info.Size())
        }
        return nil
    })
}
"

# 检查二进制文件大小
ls -lh Yearning
```

## ⚠️ 注意事项

1. **Node.js版本**: 建议使用 Node.js 16+
2. **依赖安装**: 使用 `--legacy-peer-deps` 解决依赖冲突
3. **构建顺序**: 必须先构建前端，再构建后端
4. **文件大小**: 嵌入前端后，二进制文件会增大约30-50MB
5. **更新前端**: 每次前端修改后需要重新构建整个应用

## 📚 相关链接

- [官方前端项目](https://github.com/cookieY/gemini-next)
- [Go embed文档](https://pkg.go.dev/embed)
- [Vite构建配置](https://vitejs.dev/config/)

---

🎉 **现在您已经掌握了Yearning的前后端一体化构建方式！**

