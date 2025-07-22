import tkinter as tk
from tkinter import ttk, filedialog, messagebox
import os
import re

class FileCreatorApp:
    def __init__(self, root):
        self.root = root
        self.root.title("批量创建空文件工具")
        self.root.geometry("500x400")
        self.root.resizable(True, True)
        
        # 变量初始化
        self.folder_path = tk.StringVar()
        self.file_type = tk.StringVar(value=".txt")
        self.file_prefix = tk.StringVar(value="")
        self.start_number = tk.StringVar(value="1")
        self.file_count = tk.StringVar(value="10")
        self.digit_width = tk.StringVar(value="6")
        self.file_suffix = tk.StringVar(value="")
        self.overwrite_mode = tk.StringVar(value="ask")  # ask/skip/overwrite
        
        # 创建界面组件
        self.create_widgets()
        
    def create_widgets(self):
        # 文件夹选择部分
        folder_frame = ttk.Frame(self.root, padding="10")
        folder_frame.pack(fill="x")
        
        ttk.Label(folder_frame, text="目标文件夹:").grid(row=0, column=0, sticky="w")
        ttk.Entry(folder_frame, textvariable=self.folder_path, width=40).grid(row=0, column=1, padx=5)
        ttk.Button(folder_frame, text="浏览...", command=self.browse_folder).grid(row=0, column=2)
        
        # 文件类型选择
        type_frame = ttk.Frame(self.root, padding="10")
        type_frame.pack(fill="x")
        
        ttk.Label(type_frame, text="文件类型:").grid(row=0, column=0, sticky="w")
        file_types = [".txt", ".bmp", ".jpg", ".png", ".log", ".csv", ".docx", ".xlsx"]
        ttk.Combobox(type_frame, textvariable=self.file_type, values=file_types, width=8).grid(row=0, column=1, sticky="w")
        
        # 命名设置
        naming_frame = ttk.LabelFrame(self.root, text="命名设置", padding="10")
        naming_frame.pack(fill="x", padx=10, pady=5)
        
        ttk.Label(naming_frame, text="前缀:").grid(row=0, column=0, sticky="w", pady=2)
        ttk.Entry(naming_frame, textvariable=self.file_prefix, width=10).grid(row=0, column=1, sticky="w", padx=5)
        
        ttk.Label(naming_frame, text="起始编号:").grid(row=0, column=2, sticky="w", padx=10, pady=2)
        ttk.Entry(naming_frame, textvariable=self.start_number, width=5).grid(row=0, column=3, sticky="w")
        
        ttk.Label(naming_frame, text="编号位数:").grid(row=0, column=4, sticky="w", padx=10, pady=2)
        ttk.Entry(naming_frame, textvariable=self.digit_width, width=5).grid(row=0, column=5, sticky="w")
        
        ttk.Label(naming_frame, text="后缀:").grid(row=0, column=6, sticky="w", padx=10, pady=2)
        ttk.Entry(naming_frame, textvariable=self.file_suffix, width=10).grid(row=0, column=7, sticky="w")
        
        ttk.Label(naming_frame, text="文件名示例:").grid(row=1, column=0, sticky="w", pady=5)
        self.example_label = ttk.Label(naming_frame, text=self.get_filename_example(), font=("Arial", 9))
        self.example_label.grid(row=1, column=1, columnspan=7, sticky="w", padx=5)
        
        # 绑定变量变化事件
        for var in [self.file_prefix, self.start_number, self.digit_width, self.file_suffix, self.file_type]:
            var.trace_add("write", self.update_example)
        
        # 文件数量设置
        count_frame = ttk.Frame(self.root, padding="10")
        count_frame.pack(fill="x")
        
        ttk.Label(count_frame, text="创建数量:").grid(row=0, column=0, sticky="w")
        ttk.Entry(count_frame, textvariable=self.file_count, width=10).grid(row=0, column=1, sticky="w", padx=5)
        
        # 覆盖模式设置
        mode_frame = ttk.Frame(self.root, padding="10")
        mode_frame.pack(fill="x")
        
        ttk.Label(mode_frame, text="同名文件处理:").grid(row=0, column=0, sticky="w")
        ttk.Radiobutton(mode_frame, text="询问", variable=self.overwrite_mode, value="ask").grid(row=0, column=1, sticky="w", padx=5)
        ttk.Radiobutton(mode_frame, text="跳过", variable=self.overwrite_mode, value="skip").grid(row=0, column=2, sticky="w", padx=5)
        ttk.Radiobutton(mode_frame, text="覆盖", variable=self.overwrite_mode, value="overwrite").grid(row=0, column=3, sticky="w", padx=5)
        
        # 操作按钮
        button_frame = ttk.Frame(self.root, padding="10")
        button_frame.pack(fill="x")
        
        ttk.Button(button_frame, text="创建文件", command=self.create_files).pack(side="right", padx=5)
        ttk.Button(button_frame, text="清空设置", command=self.reset_fields).pack(side="right", padx=5)
        
        # 状态栏
        self.status_var = tk.StringVar(value="就绪")
        status_bar = ttk.Label(self.root, textvariable=self.status_var, relief="sunken", anchor="w")
        status_bar.pack(side="bottom", fill="x")
    
    def browse_folder(self):
        folder = filedialog.askdirectory()
        if folder:
            self.folder_path.set(folder)
    
    def get_filename_example(self):
        try:
            num = int(self.start_number.get())
            width = int(self.digit_width.get())
            prefix = self.file_prefix.get()
            suffix = self.file_suffix.get()
            ext = self.file_type.get()
            return f"{prefix}{num:0{width}d}{suffix}{ext}"
        except:
            return "无效设置"
    
    def update_example(self, *args):
        self.example_label.config(text=self.get_filename_example())
    
    def reset_fields(self):
        self.file_prefix.set("")
        self.start_number.set("1")
        self.digit_width.set("6")
        self.file_suffix.set("")
        self.file_type.set(".txt")
        self.file_count.set("10")
        self.overwrite_mode.set("ask")
        self.status_var.set("设置已重置")
    
    def validate_inputs(self):
        # 验证文件夹
        folder = self.folder_path.get()
        if not folder or not os.path.isdir(folder):
            messagebox.showerror("错误", "请选择有效的目标文件夹")
            return False
        
        # 验证数字输入
        try:
            start_num = int(self.start_number.get())
            file_count = int(self.file_count.get())
            digit_width = int(self.digit_width.get())
            
            if start_num < 0 or file_count <= 0 or digit_width <= 0:
                raise ValueError
        except ValueError:
            messagebox.showerror("错误", "起始编号、创建数量、编号位数必须是正整数")
            return False
        
        # 验证文件扩展名
        ext = self.file_type.get()
        if not ext.startswith(".") or len(ext) < 2:
            messagebox.showerror("错误", "文件类型必须以点开头（如 .txt）")
            return False
        
        return True
    
    def create_files(self):
        if not self.validate_inputs():
            return
        
        folder = self.folder_path.get()
        prefix = self.file_prefix.get()
        suffix = self.file_suffix.get()
        ext = self.file_type.get()
        start_num = int(self.start_number.get())
        file_count = int(self.file_count.get())
        digit_width = int(self.digit_width.get())
        overwrite_mode = self.overwrite_mode.get()
        
        created_count = 0
        skipped_count = 0
        overwritten_count = 0
        
        for i in range(file_count):
            current_num = start_num + i
            filename = f"{prefix}{current_num:0{digit_width}d}{suffix}{ext}"
            filepath = os.path.join(folder, filename)
            
            # 检查文件是否存在
            if os.path.exists(filepath):
                if overwrite_mode == "skip":
                    skipped_count += 1
                    continue
                
                if overwrite_mode == "ask":
                    response = messagebox.askyesnocancel(
                        "文件已存在",
                        f"文件 '{filename}' 已存在。\n\n覆盖此文件？",
                        detail="点击'是'覆盖当前文件\n点击'否'跳过此文件\n点击'取消'中止操作"
                    )
                    
                    if response is None:  # 取消
                        break
                    elif not response:    # 跳过
                        skipped_count += 1
                        continue
                    # 否则继续执行覆盖
            
            # 创建文件
            try:
                with open(filepath, "w") as f:
                    pass  # 创建空文件
                
                if os.path.exists(filepath):
                    created_count += 1
                    if overwrite_mode == "ask" or overwrite_mode == "overwrite":
                        overwritten_count += 1
            except Exception as e:
                messagebox.showerror("错误", f"创建文件 '{filename}' 失败:\n{str(e)}")
                break
        
        # 显示结果
        result_msg = f"操作完成！\n\n创建文件: {created_count}"
        if skipped_count > 0:
            result_msg += f"\n跳过文件: {skipped_count}"
        if overwritten_count > 0:
            result_msg += f"\n覆盖文件: {overwritten_count}"
        
        self.status_var.set(result_msg)
        messagebox.showinfo("完成", result_msg)

if __name__ == "__main__":
    root = tk.Tk()
    app = FileCreatorApp(root)
    root.mainloop()