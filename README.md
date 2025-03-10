# Display 图片显示器

## 项目概述
Display是一个基于iOS的图片显示应用，它允许你通过网络从Python客户端发送图片到iOS设备上进行实时显示。应用支持图片历史记录，可以通过水平滑动查看之前显示过的所有图片。

## 功能特点
- 通过TCP网络连接接收图片
- 实时显示接收到的图片
- 支持图片历史记录和浏览
- 水平滑动切换不同图片
- 自动适应屏幕大小的图片显示

## 环境要求

### iOS应用
- iOS 13.0 或更高版本
- 支持iPhone和iPad设备

### Python客户端
- Python 3.6 或更高版本
- 需要安装的Python包：
  - socket（标准库）
  - PIL（用于图片处理）

## 安装和使用

### iOS应用安装
1. 使用Xcode打开Display.xcodeproj项目文件
2. 选择目标设备或模拟器
3. 点击运行按钮或按Command+R进行编译和安装

### Python客户端使用
1. 确保iOS设备和运行Python客户端的电脑在同一网络下
2. 运行iOS应用，等待显示"等待接收图片..."提示
3. 使用Python客户端发送图片：
```python
from client import display

# 发送图片到iOS设备
display("图片路径.jpg", server_address="iOS设备IP地址")
```

## 支持的图片格式
- JPEG/JPG
- PNG
- GIF（静态）
- 其他iOS原生支持的图片格式

## 注意事项
- 确保iOS设备和Python客户端在同一局域网内
- iOS应用需要在接收图片前保持运行状态
- 建议发送适当大小的图片以确保传输效率

## 技术实现
- iOS端使用Network框架实现TCP服务器
- 使用UICollectionView实现图片历史记录的水平滚动显示
- Python客户端使用socket进行网络通信
- 实现了简单的图片传输协议，包含数据长度头和图片数据