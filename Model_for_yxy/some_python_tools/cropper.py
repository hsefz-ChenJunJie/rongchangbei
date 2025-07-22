import sys
import os
import cv2
import numpy as np
from PyQt5.QtWidgets import (QApplication, QMainWindow, QPushButton, 
                             QFileDialog, QLabel, QVBoxLayout, QWidget,
                             QScrollArea, QSizePolicy, QMessageBox)
from PyQt5.QtGui import QImage, QPixmap, QPainter, QPen, QColor
from PyQt5.QtCore import Qt, QPoint

class ImageViewer(QLabel):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setSizePolicy(QSizePolicy.Ignored, QSizePolicy.Ignored)
        self.setAlignment(Qt.AlignCenter)
        self.setMouseTracking(True)
        self.crop_size = 100
        self.crop_pos = QPoint(0, 0)
        self.original_image = None
        self.scale_factor = 1.0
        self.min_crop_size = 20
        self.output_folder = ""  # 新增：存储输出文件夹路径

    def load_image(self, image_path):
        self.original_image = cv2.imread(image_path)
        if self.original_image is not None:
            h, w, _ = self.original_image.shape
            min_dim = min(h, w)
            self.crop_size = min_dim
            self.crop_pos = QPoint(w//2, h//2)
            self.scale_factor = 1.0
            self.update_display()

    def update_display(self):
        if self.original_image is None:
            return
            
        display_img = self.original_image.copy()
        # Draw crop rectangle
        x = int(self.crop_pos.x() - self.crop_size//2)
        y = int(self.crop_pos.y() - self.crop_size//2)
        cv2.rectangle(display_img, 
                     (x, y), 
                     (x + self.crop_size, y + self.crop_size), 
                     (0, 255, 0), 2)
        
        # Convert to QImage
        h, w, ch = display_img.shape
        bytes_per_line = ch * w
        q_img = QImage(display_img.data, w, h, bytes_per_line, QImage.Format_RGB888).rgbSwapped()
        self.setPixmap(QPixmap.fromImage(q_img))

    def mouseMoveEvent(self, event):
        if self.original_image is None:
            return
            
        # Update crop position to follow mouse
        img_pos = self.mapToImage(event.pos())
        if img_pos:
            self.crop_pos = img_pos
            self.clamp_crop_position()
            self.update_display()

    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton:
            # 左键点击直接裁剪
            self.crop_and_save()
        if event.button() == Qt.RightButton:
            self.move_to_next_image()

    def wheelEvent(self, event):
        if self.original_image is None:
            return
            
        # Zoom crop size
        delta = event.angleDelta().y() / 120
        new_size = self.crop_size + int(delta * 10)
        new_size = max(self.min_crop_size, min(new_size, min(self.original_image.shape[:2])))
        
        if new_size != self.crop_size:
            self.crop_size = new_size
            self.clamp_crop_position()
            self.update_display()

    def clamp_crop_position(self):
        if self.original_image is None:
            return
            
        h, w, _ = self.original_image.shape
        half_size = self.crop_size // 2
        
        x = max(half_size, min(self.crop_pos.x(), w - half_size))
        y = max(half_size, min(self.crop_pos.y(), h - half_size))
        self.crop_pos = QPoint(x, y)

    def mapToImage(self, pos):
        if not self.pixmap():
            return None
            
        pixmap_size = self.pixmap().size()
        label_size = self.size()
        
        # Calculate scaling
        scale_x = pixmap_size.width() / label_size.width()
        scale_y = pixmap_size.height() / label_size.height()
        
        # Calculate offset
        offset_x = (label_size.width() - pixmap_size.width()) / 2
        offset_y = (label_size.height() - pixmap_size.height()) / 2
        
        # Map to image coordinates
        img_x = (pos.x() - offset_x) * scale_x
        img_y = (pos.y() - offset_y) * scale_y
        
        if 0 <= img_x < pixmap_size.width() and 0 <= img_y < pixmap_size.height():
            return QPoint(int(img_x), int(img_y))
        return None

    def crop_and_save(self):
        if self.original_image is None:
            return
            
        # Calculate crop area
        x = int(self.crop_pos.x() - self.crop_size//2)
        y = int(self.crop_pos.y() - self.crop_size//2)
        
        # Perform crop
        cropped = self.original_image[y:y+self.crop_size, x:x+self.crop_size]
        
        # Save to output folder
        global current_image_index, image_files, output_folder
        if current_image_index < len(image_files):
            orig_path = image_files[current_image_index]
            filename = os.path.basename(orig_path)
            
            # 确保输出文件夹存在
            if not os.path.exists(output_folder):
                os.makedirs(output_folder)
            
            # 保存到输出文件夹
            save_path = os.path.join(output_folder, filename)
            cv2.imwrite(save_path, cropped)
            print(f"Saved cropped image to: {save_path}")
            self.move_to_next_image()
            
    def move_to_next_image(self):
        # Move to next image
        global current_image_index, image_files
        if current_image_index < len(image_files):
            current_image_index += 1
            if current_image_index < len(image_files):
                self.load_image(image_files[current_image_index])
            else:
                print("Finished processing all images")
                QMessageBox.information(self, "完成", "所有图片已处理完成！")

class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Square Cropper")
        self.setGeometry(100, 100, 800, 600)
        
        # Central widget and layout
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        layout = QVBoxLayout(central_widget)
        
        # Open folder button
        self.btn_open = QPushButton("打开文件夹")
        self.btn_open.clicked.connect(self.open_folder)
        layout.addWidget(self.btn_open)
        
        # Image viewer with scroll area
        self.scroll_area = QScrollArea()
        self.scroll_area.setWidgetResizable(True)
        self.image_viewer = ImageViewer()
        self.scroll_area.setWidget(self.image_viewer)
        layout.addWidget(self.scroll_area)

    def open_folder(self):
        global image_files, current_image_index, output_folder
        folder = QFileDialog.getExistingDirectory(self, "选择图片文件夹")
        if folder:
            # 创建输出文件夹
            output_folder = os.path.join(folder, "cropped")
            
            # 获取所有图片文件
            image_files = []
            for ext in ["*.png", "*.jpg", "*.jpeg"]:
                image_files.extend([os.path.join(folder, f) for f in os.listdir(folder) 
                                  if f.lower().endswith(ext.split("*")[-1])])
            
            if image_files:
                current_image_index = 0
                self.image_viewer.load_image(image_files[current_image_index])
            else:
                QMessageBox.warning(self, "无图片", "所选文件夹中没有找到图片文件！")

# Global variables
image_files = []
current_image_index = 0
output_folder = ""  # 新增：存储输出文件夹路径

if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = MainWindow()
    window.show()
    sys.exit(app.exec_())