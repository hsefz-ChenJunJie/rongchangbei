import cv2
import numpy as np
import os
import random
from tqdm import tqdm

def augment_images(input_dir, output_dir, num_augmentations=5):
    """
    对输入目录中的每张图片进行多种数据增强操作
    :param input_dir: 输入图片目录
    :param output_dir: 输出图片目录
    :param num_augmentations: 每张图片生成的增强版本数量
    """
    # 创建输出目录
    os.makedirs(output_dir, exist_ok=True)
    
    # 获取所有图片文件
    image_files = [f for f in os.listdir(input_dir) 
                  if f.lower().endswith(('.png', '.jpg', '.jpeg', '.bmp'))]
    
    print(f"找到 {len(image_files)} 张图片，每张生成 {num_augmentations} 个增强版本...")
    
    for img_file in tqdm(image_files, desc="处理图片"):
        img_path = os.path.join(input_dir, img_file)
        img = cv2.imread(img_path)
        
        if img is None:
            continue
            
        height, width = img.shape[:2]
        base_name = os.path.splitext(img_file)[0]
        
        # 保存原始图片
        cv2.imwrite(os.path.join(output_dir, f"{base_name}_original.jpg"), img)
        
        for i in range(num_augmentations):
            # 随机选择增强操作组合
            aug_img = img.copy()
            
            # 随机旋转 (-30到30度)
            if random.random() > 0.3:
                angle = random.uniform(-30, 30)
                M = cv2.getRotationMatrix2D((width/2, height/2), angle, 1.0)
                aug_img = cv2.warpAffine(aug_img, M, (width, height), 
                                        borderMode=cv2.BORDER_REFLECT)
            
            # 随机平移 (±15%)
            if random.random() > 0.3:
                tx = random.uniform(-0.15, 0.15) * width
                ty = random.uniform(-0.15, 0.15) * height
                M = np.float32([[1, 0, tx], [0, 1, ty]])
                aug_img = cv2.warpAffine(aug_img, M, (width, height),
                                        borderMode=cv2.BORDER_REFLECT)
            
            # 随机缩放 (0.8到1.2倍)
            if random.random() > 0.5:
                scale = random.uniform(0.8, 1.2)
                aug_img = cv2.resize(aug_img, None, fx=scale, fy=scale)
                # 裁剪回原始尺寸
                new_h, new_w = aug_img.shape[:2]
                y0 = max(0, (new_h - height) // 2)
                x0 = max(0, (new_w - width) // 2)
                aug_img = aug_img[y0:y0+height, x0:x0+width]
            
            # 随机添加滤镜
            if random.random() > 0.4:
                filter_type = random.choice(['grayscale', 'sepia', 'warm', 'cool'])
                if filter_type == 'grayscale':
                    aug_img = cv2.cvtColor(aug_img, cv2.COLOR_BGR2GRAY)
                    aug_img = cv2.cvtColor(aug_img, cv2.COLOR_GRAY2BGR)
                elif filter_type == 'sepia':
                    sepia_filter = np.array([[0.272, 0.534, 0.131],
                                           [0.349, 0.686, 0.168],
                                           [0.393, 0.769, 0.189]])
                    aug_img = cv2.transform(aug_img, sepia_filter)
                    aug_img = np.clip(aug_img, 0, 255).astype(np.uint8)
                elif filter_type == 'warm':
                    aug_img[:, :, 0] = np.clip(aug_img[:, :, 0] * 0.9, 0, 255)
                    aug_img[:, :, 2] = np.clip(aug_img[:, :, 2] * 1.1, 0, 255)
                elif filter_type == 'cool':
                    aug_img[:, :, 0] = np.clip(aug_img[:, :, 0] * 1.1, 0, 255)
                    aug_img[:, :, 2] = np.clip(aug_img[:, :, 2] * 0.9, 0, 255)
            
            # 随机添加噪声
            if random.random() > 0.5:
                noise_type = random.choice(['gaussian', 'salt_pepper'])
                if noise_type == 'gaussian':
                    mean = 0
                    sigma = random.uniform(1, 25)
                    gauss = np.random.normal(mean, sigma, aug_img.shape).astype(np.uint8)
                    aug_img = cv2.add(aug_img, gauss)
                elif noise_type == 'salt_pepper':
                    amount = random.uniform(0.001, 0.01)
                    # 椒盐噪声
                    num_salt = np.ceil(amount * aug_img.size * 0.5)
                    num_pepper = np.ceil(amount * aug_img.size * 0.5)
                    
                    # 添加盐噪声
                    coords = [np.random.randint(0, i-1, int(num_salt)) for i in aug_img.shape]
                    aug_img[coords[0], coords[1], :] = 255
                    
                    # 添加椒噪声
                    coords = [np.random.randint(0, i-1, int(num_pepper)) for i in aug_img.shape]
                    aug_img[coords[0], coords[1], :] = 0
            
            # 随机调整亮度和对比度
            if random.random() > 0.4:
                alpha = random.uniform(0.7, 1.3)  # 对比度 (1.0-3.0)
                beta = random.randint(-40, 40)    # 亮度 (-50-50)
                aug_img = cv2.convertScaleAbs(aug_img, alpha=alpha, beta=beta)
            
            # 保存增强后的图片
            output_path = os.path.join(output_dir, f"{base_name}_aug_{i+1}.jpg")
            cv2.imwrite(output_path, aug_img)

if __name__ == "__main__":
    # 配置路径
    input_directory = R"C:\Users\CJKIM\Desktop\dataset_for_yxy\Original_Numbered"  # 替换为你的训练集路径
    output_directory = R"C:\Users\CJKIM\Desktop\dataset_for_yxy\Derivative"     # 替换为输出路径
    
    # 每张图片生成5个增强版本
    augment_images(input_directory, output_directory, num_augmentations=3)
    
    print("数据增强完成！")