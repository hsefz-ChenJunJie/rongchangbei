import os
import shutil
import re
import sys

def move_and_rename_jpg_files(source_dir, target_dir):
    # 确保目标文件夹存在（使用绝对路径）
    try:
        os.makedirs(target_dir, exist_ok=True)
    except PermissionError:
        print(f"错误：没有权限在 {target_dir} 创建文件夹")
        print("请尝试以下解决方案：")
        print("1. 选择当前用户有写入权限的目录（如桌面或文档）")
        print("2. 以管理员身份运行脚本")
        print("3. 修改目标文件夹路径")
        sys.exit(1)
    
    # 获取源目录中所有JPG/JPEG文件
    jpg_files = [
        f for f in os.listdir(source_dir) 
        if os.path.isfile(os.path.join(source_dir, f)) and 
        f.lower().endswith(('.jpg', '.jpeg'))
    ]
    
    if not jpg_files:
        print(f"在 {source_dir} 中没有找到JPG/JPEG文件")
        return
    
    # 按文件名排序（可选，如果需要按创建时间排序请使用下一行）
    jpg_files.sort()
    # 按修改时间排序: jpg_files.sort(key=lambda f: os.path.getmtime(os.path.join(source_dir, f)))
    
    # 获取目标目录现有文件的最大编号
    existing_files = os.listdir(target_dir)
    max_num = 0
    for file in existing_files:
        match = re.match(r'^(\d{6})\.jpg$', file, re.IGNORECASE)
        if match:
            num = int(match.group(1))
            if num > max_num:
                max_num = num
    
    # 计数器从最大编号+1开始
    count = max_num + 1
    
    # 移动并重命名文件
    for filename in jpg_files:
        source_path = os.path.join(source_dir, filename)
        
        # 生成新文件名（6位数字编号）
        new_filename = f"{count:06d}.jpg"
        target_path = os.path.join(target_dir, new_filename)
        
        # 移动并重命名文件
        shutil.move(source_path, target_path)
        print(f"移动文件: {filename} -> {new_filename}")
        
        count += 1

if __name__ == "__main__":
    # 获取当前脚本所在目录
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    # 配置源文件夹和目标文件夹路径（使用绝对路径）
    source_directory = os.path.join(script_dir, R"C:\Users\CJKIM\Desktop\dataset_for_yxy\Derivative_cropped")  # 源文件夹
    target_directory = os.path.join(script_dir, R"C:\Users\CJKIM\Desktop\dataset_for_yxy\Derivative_cropped_numbered")      # 目标文件夹
    
    # 如果源文件夹不存在则创建（示例）
    os.makedirs(source_directory, exist_ok=True)
    
    print(f"源文件夹: {source_directory}")
    print(f"目标文件夹: {target_directory}")
    print("开始处理...")
    
    move_and_rename_jpg_files(source_directory, target_directory)
    print("\n操作完成！")