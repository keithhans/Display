import socket
import os
import argparse
from PIL import Image
import io

def preprocess_image(image_path, max_size=(3024, 4032), max_file_size=10*1024*1024):
    """预处理图片，确保符合iOS支持的格式和大小限制
    
    Args:
        image_path (str): 图片文件路径
        max_size (tuple): 最大图片尺寸 (宽, 高)
        max_file_size (int): 最大文件大小（字节）
    
    Returns:
        bytes: 处理后的图片数据
    """
    if not os.path.exists(image_path):
        raise FileNotFoundError(f"图片文件 {image_path} 不存在")

    with Image.open(image_path) as img:
        # 检查图片格式
        if img.format not in ['JPEG', 'JPG']:
            print(f'警告：输入图片格式为{img.format}，将转换为JPEG格式')

        # 转换为RGB模式
        if img.mode in ('RGBA', 'LA') or (img.mode == 'P' and 'transparency' in img.info):
            img = img.convert('RGB')
            print('已将图片转换为RGB模式')
        
        # 检查并调整图片尺寸
        width, height = img.size
        if width > max_size[0] or height > max_size[1]:
            ratio = min(max_size[0]/width, max_size[1]/height)
            new_size = (int(width * ratio), int(height * ratio))
            img = img.resize(new_size, Image.Resampling.LANCZOS)
            print(f'已将图片尺寸从 {width}x{height} 调整为 {new_size[0]}x{new_size[1]}')

        # 压缩图片
        quality = 95
        while True:
            img_byte_arr = io.BytesIO()
            img.save(img_byte_arr, format='JPEG', quality=quality, optimize=True)
            img_data = img_byte_arr.getvalue()
            
            if len(img_data) <= max_file_size or quality <= 30:
                break
                
            quality -= 5
            print(f'图片大小超出限制，降低质量到{quality}%重试...')

        print(f'最终图片大小: {len(img_data)/1024:.1f}KB, 质量: {quality}%')
        return img_data

def display(image_name, server_address='localhost', port=8080):
    """在iOS设备上显示指定的图片
    
    Args:
        image_name (str): 图片文件的路径
        server_address (str): 服务器地址，默认为localhost
        port (int): 服务器端口，默认为8080
    """
    try:
        # 预处理图片
        image_data = preprocess_image(image_name)
        
        # 创建TCP socket连接
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect((server_address, port))
        
        # 添加4字节的数据长度头
        data_length = len(image_data)
        length_header = data_length.to_bytes(4, byteorder='big')
        
        # 发送数据长度头和图片数据
        sock.sendall(length_header + image_data)
        
        # 等待服务器响应
        response = sock.recv(1024).decode('utf-8')
        if 'OK' in response:
            print(f"成功发送图片 {image_name} 到显示设备")
        else:
            print(f"发送图片失败: {response}")
            
        sock.close()
            
    except ConnectionRefusedError:
        print("无法连接到显示设备，请确保iOS应用正在运行且在同一网络中")
    except Exception as e:
        print(f"发生错误: {str(e)}")

def main():
    parser = argparse.ArgumentParser(description='在iOS设备上显示图片')
    parser.add_argument('image', help='要显示的图片文件路径')
    parser.add_argument('--server', default='localhost', help='服务器地址，默认为localhost')
    parser.add_argument('--port', type=int, default=8080, help='服务器端口，默认为8080')
    
    args = parser.parse_args()
    display(args.image, args.server, args.port)

if __name__ == '__main__':
    main()