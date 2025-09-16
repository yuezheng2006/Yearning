# 📦 Yearning 构建总结

## 🎯 核心改进

✅ **前后端一体化**: 使用Go embed将Vue3前端嵌入到单一二进制文件  
✅ **官方前端**: 集成了官方gemini-next项目 (Vue3 + Vite)  
✅ **构建脚本**: 自动化前端构建和后端编译流程  
✅ **文档完善**: 提供详细的构建和部署文档  

## 🚀 快速使用

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

## 📁 文件结构

```
├── build.sh                # 完整构建脚本 (前端+后端)
├── build-frontend.sh       # 前端构建脚本  
├── src/service/dist/        # 前端构建产物 (embed嵌入)
├── FRONTEND-BUILD.md        # 前端构建详细文档
└── Yearning                 # 单一二进制文件 (包含前端)
```

## 🔧 技术实现

- **Go Embed**: 编译时将前端资源嵌入二进制文件
- **Vue3 + Vite**: 现代化前端技术栈  
- **一体化部署**: 无需单独前端服务器
- **开发模式**: 支持前端热重载开发

## 📚 相关文档

- [FRONTEND-BUILD.md](FRONTEND-BUILD.md) - 详细构建指南
- [DEVELOPMENT.md](DEVELOPMENT.md) - 开发环境配置  
- [DEPLOY.md](DEPLOY.md) - 生产环境部署

---

🎉 **Yearning现在支持现代化的前后端一体化构建和部署！**

