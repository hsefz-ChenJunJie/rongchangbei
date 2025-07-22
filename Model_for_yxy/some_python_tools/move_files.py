import os
import shutil
import re
import sys
import tkinter as tk
from tkinter import ttk, filedialog, messagebox
from PIL import Image, ImageTk
import threading

class FileTransferApp:
    def __init__(self, root):
        self.root = root
        self.root.title("文件转移与重命名工具")
        self.root.geometry("850x650")
        self.root.resizable(True, True)
        
        # 设置应用图标
        try:
            self.root.iconbitmap(default=self.resource_path("icon.ico"))
        except:
            pass
        
        # 创建样式
        self.style = ttk.Style()
        self.style.configure("TFrame", background="#f0f0f0")
        self.style.configure("Header.TLabel", background="#2c3e50", foreground="white", font=("Arial", 14, "bold"))
        self.style.configure("TButton", font=("Arial", 10), padding=5)
        self.style.configure("TProgressbar", thickness=20)
        
        # 创建主框架
        self.main_frame = ttk.Frame(root)
        self.main_frame.pack(fill=tk.BOTH, expand=True, padx=20, pady=20)
        
        # 创建标题
        self.header = ttk.Label(self.main_frame, text="文件转移与重命名工具", style="Header.TLabel")
        self.header.pack(fill=tk.X, pady=(0, 20))
        
        # 创建配置面板
        self.config_frame = ttk.LabelFrame(self.main_frame, text="配置选项")
        self.config_frame.pack(fill=tk.X, pady=10)
        
        # 源目录选择
        ttk.Label(self.config_frame, text="源目录:").grid(row=0, column=0, sticky=tk.W, padx=5, pady=5)
        self.source_entry = ttk.Entry(self.config_frame, width=50)
        self.source_entry.grid(row=0, column=1, padx=5, pady=5)
        ttk.Button(self.config_frame, text="浏览...", command=self.browse_source).grid(row=0, column=2, padx=5, pady=5)
        
        # 目标目录选择
        ttk.Label(self.config_frame, text="目标目录:").grid(row=1, column=0, sticky=tk.W, padx=5, pady=5)
        self.target_entry = ttk.Entry(self.config_frame, width=50)
        self.target_entry.grid(row=1, column=1, padx=5, pady=5)
        ttk.Button(self.config_frame, text="浏览...", command=self.browse_target).grid(row=1, column=2, padx=5, pady=5)
        
        # 文件类型
        ttk.Label(self.config_frame, text="文件类型:").grid(row=2, column=0, sticky=tk.W, padx=5, pady=5)
        self.file_types_var = tk.StringVar(value=".jpg, .jpeg, .png, .gif, .bmp, .tiff")
        self.file_types_entry = ttk.Entry(self.config_frame, textvariable=self.file_types_var, width=50)
        self.file_types_entry.grid(row=2, column=1, padx=5, pady=5)
        ttk.Label(self.config_frame, text="(用逗号分隔)").grid(row=2, column=2, sticky=tk.W, padx=5, pady=5)
        
        # 编号格式
        ttk.Label(self.config_frame, text="编号格式:").grid(row=3, column=0, sticky=tk.W, padx=5, pady=5)
        self.format_var = tk.StringVar(value="{number:06d}{ext}")
        self.format_entry = ttk.Entry(self.config_frame, textvariable=self.format_var, width=50)
        self.format_entry.grid(row=3, column=1, padx=5, pady=5)
        ttk.Label(self.config_frame, text="(可用变量: {number}, {ext}, {name})").grid(row=3, column=2, sticky=tk.W, padx=5, pady=5)
        
        # 排序方式
        ttk.Label(self.config_frame, text="排序方式:").grid(row=4, column=0, sticky=tk.W, padx=5, pady=5)
        self.sort_var = tk.StringVar(value="filename")
        sort_options = ["文件名", "修改时间", "创建时间", "文件大小"]
        self.sort_combobox = ttk.Combobox(self.config_frame, textvariable=self.sort_var, 
                                        values=sort_options, state="readonly", width=20)
        self.sort_combobox.current(0)
        self.sort_combobox.grid(row=4, column=1, sticky=tk.W, padx=5, pady=5)
        
        # 起始编号
        ttk.Label(self.config_frame, text="起始编号:").grid(row=5, column=0, sticky=tk.W, padx=5, pady=5)
        self.start_num_var = tk.IntVar(value=1)
        self.start_num_spinbox = ttk.Spinbox(self.config_frame, from_=1, to=1000000, 
                                           textvariable=self.start_num_var, width=10)
        self.start_num_spinbox.grid(row=5, column=1, sticky=tk.W, padx=5, pady=5)
        
        # 操作按钮
        self.button_frame = ttk.Frame(self.main_frame)
        self.button_frame.pack(fill=tk.X, pady=20)
        
        self.start_button = ttk.Button(self.button_frame, text="开始处理", command=self.start_processing, 
                                     style="Accent.TButton")
        self.start_button.pack(side=tk.LEFT, padx=5)
        
        self.stop_button = ttk.Button(self.button_frame, text="停止", command=self.stop_processing, 
                                    state=tk.DISABLED)
        self.stop_button.pack(side=tk.LEFT, padx=5)
        
        ttk.Button(self.button_frame, text="打开目标文件夹", command=self.open_target_folder).pack(side=tk.RIGHT, padx=5)
        ttk.Button(self.button_frame, text="打开源文件夹", command=self.open_source_folder).pack(side=tk.RIGHT, padx=5)
        
        # 进度条
        self.progress_frame = ttk.Frame(self.main_frame)
        self.progress_frame.pack(fill=tk.X, pady=10)
        
        self.progress_label = ttk.Label(self.progress_frame, text="准备就绪")
        self.progress_label.pack(fill=tk.X, pady=(0, 5))
        
        self.progress_var = tk.DoubleVar()
        self.progress_bar = ttk.Progressbar(self.progress_frame, variable=self.progress_var, 
                                           mode="determinate", length=600)
        self.progress_bar.pack(fill=tk.X)
        
        # 日志区域
        self.log_frame = ttk.LabelFrame(self.main_frame, text="操作日志")
        self.log_frame.pack(fill=tk.BOTH, expand=True, pady=10)
        
        self.log_text = tk.Text(self.log_frame, height=10, wrap=tk.WORD)
        self.log_text.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)
        
        self.log_scroll = ttk.Scrollbar(self.log_text, command=self.log_text.yview)
        self.log_scroll.pack(side=tk.RIGHT, fill=tk.Y)
        self.log_text.config(yscrollcommand=self.log_scroll.set)
        
        # 状态栏
        self.status_var = tk.StringVar(value="就绪")
        self.status_bar = ttk.Label(root, textvariable=self.status_var, relief=tk.SUNKEN, anchor=tk.W)
        self.status_bar.pack(side=tk.BOTTOM, fill=tk.X)
        
        # 设置初始值
        self.source_entry.insert(0, os.path.join(os.path.expanduser("~"), "Desktop", "source_files"))
        self.target_entry.insert(0, os.path.join(os.path.expanduser("~"), "Desktop", "renamed_files"))
        
        # 处理控制变量
        self.is_processing = False
        self.stop_requested = False
        
        # 创建自定义样式
        self.style.configure("Accent.TButton", background="#3498db", foreground="white")
        self.style.map("Accent.TButton", background=[("active", "#2980b9")])
        
        # 添加示例文本
        self.log_text.insert(tk.END, "欢迎使用文件转移与重命名工具！\n")
        self.log_text.insert(tk.END, "请配置源目录、目标目录和文件类型，然后点击'开始处理'按钮。\n\n")
        self.log_text.insert(tk.END, "提示：\n")
        self.log_text.insert(tk.END, "- 文件类型可以输入多个扩展名，用逗号分隔（如 .jpg, .png, .gif）\n")
        self.log_text.insert(tk.END, "- 编号格式中可用变量：{number}（编号）, {ext}（扩展名）, {name}（原始文件名）\n")
        self.log_text.insert(tk.END, "- 示例格式：'IMG_{number:04d}{ext}' 会生成类似 'IMG_0001.jpg' 的文件名\n")
    
    def resource_path(self, relative_path):
        """获取资源的绝对路径"""
        try:
            base_path = sys._MEIPASS
        except Exception:
            base_path = os.path.abspath(".")
        return os.path.join(base_path, relative_path)
    
    def browse_source(self):
        """浏览源目录"""
        directory = filedialog.askdirectory(title="选择源目录")
        if directory:
            self.source_entry.delete(0, tk.END)
            self.source_entry.insert(0, directory)
    
    def browse_target(self):
        """浏览目标目录"""
        directory = filedialog.askdirectory(title="选择目标目录")
        if directory:
            self.target_entry.delete(0, tk.END)
            self.target_entry.insert(0, directory)
    
    def open_source_folder(self):
        """打开源文件夹"""
        source_dir = self.source_entry.get()
        if os.path.exists(source_dir):
            os.startfile(source_dir)
        else:
            messagebox.showwarning("目录不存在", f"源目录不存在:\n{source_dir}")
    
    def open_target_folder(self):
        """打开目标文件夹"""
        target_dir = self.target_entry.get()
        if os.path.exists(target_dir):
            os.startfile(target_dir)
        else:
            messagebox.showwarning("目录不存在", f"目标目录不存在:\n{target_dir}")
    
    def log_message(self, message):
        """在日志区域显示消息"""
        self.log_text.insert(tk.END, message + "\n")
        self.log_text.see(tk.END)
        self.status_var.set(message)
        self.root.update_idletasks()
    
    def start_processing(self):
        """开始处理文件"""
        if self.is_processing:
            return
            
        # 获取配置参数
        source_dir = self.source_entry.get()
        target_dir = self.target_entry.get()
        file_types = [ext.strip().lower() for ext in self.file_types_var.get().split(",") if ext.strip()]
        format_str = self.format_var.get()
        sort_option = self.sort_combobox.current()
        start_num = self.start_num_var.get()
        
        # 验证输入
        if not source_dir:
            messagebox.showerror("错误", "请选择源目录")
            return
        if not target_dir:
            messagebox.showerror("错误", "请选择目标目录")
            return
        if not file_types:
            messagebox.showerror("错误", "请至少指定一种文件类型")
            return
        if not format_str:
            messagebox.showerror("错误", "请输入编号格式")
            return
            
        # 创建目标目录
        try:
            os.makedirs(target_dir, exist_ok=True)
        except Exception as e:
            messagebox.showerror("错误", f"无法创建目标目录:\n{str(e)}")
            return
            
        # 禁用按钮，启用停止按钮
        self.start_button.config(state=tk.DISABLED)
        self.stop_button.config(state=tk.NORMAL)
        self.is_processing = True
        self.stop_requested = False
        
        # 在日志中显示配置信息
        self.log_message("="*50)
        self.log_message(f"开始处理文件...")
        self.log_message(f"源目录: {source_dir}")
        self.log_message(f"目标目录: {target_dir}")
        self.log_message(f"文件类型: {', '.join(file_types)}")
        self.log_message(f"编号格式: {format_str}")
        self.log_message(f"排序方式: {self.sort_combobox.get()}")
        self.log_message(f"起始编号: {start_num}")
        self.log_message("="*50)
        
        # 在新线程中处理文件
        processing_thread = threading.Thread(
            target=self.move_and_rename_files,
            args=(source_dir, target_dir, file_types, format_str, sort_option, start_num)
        )
        processing_thread.daemon = True
        processing_thread.start()
    
    def stop_processing(self):
        """停止处理文件"""
        if self.is_processing:
            self.stop_requested = True
            self.log_message("正在停止处理...")
            self.stop_button.config(state=tk.DISABLED)
    
    def move_and_rename_files(self, source_dir, target_dir, file_types, format_str, sort_option, start_num):
        """移动并重命名文件"""
        try:
            # 确保目标文件夹存在
            os.makedirs(target_dir, exist_ok=True)
            
            # 获取源目录中所有指定类型的文件
            all_files = [
                f for f in os.listdir(source_dir) 
                if os.path.isfile(os.path.join(source_dir, f))
            ]
            
            # 过滤出指定类型的文件
            file_list = [
                f for f in all_files
                if any(f.lower().endswith(ext) for ext in file_types)
            ]
            
            if not file_list:
                self.log_message(f"在 {source_dir} 中没有找到符合条件的文件")
                self.processing_completed()
                return
            
            self.log_message(f"找到 {len(file_list)} 个符合条件的文件")
            
            # 根据选择的排序方式进行排序
            if sort_option == 0:  # 文件名
                file_list.sort()
            elif sort_option == 1:  # 修改时间
                file_list.sort(key=lambda f: os.path.getmtime(os.path.join(source_dir, f)))
            elif sort_option == 2:  # 创建时间
                file_list.sort(key=lambda f: os.path.getctime(os.path.join(source_dir, f)))
            elif sort_option == 3:  # 文件大小
                file_list.sort(key=lambda f: os.path.getsize(os.path.join(source_dir, f)))
            
            # 获取目标目录现有文件的最大编号
            max_num = 0
            for file in os.listdir(target_dir):
                try:
                    # 尝试从文件名中提取数字部分
                    num_part = re.search(r'\d+', file)
                    if num_part:
                        num = int(num_part.group())
                        if num > max_num:
                            max_num = num
                except:
                    continue
            
            # 起始编号取最大值和用户设置值中的较大者
            count = max(max_num + 1, start_num)
            
            # 设置进度条
            total_files = len(file_list)
            self.progress_var.set(0)
            self.progress_bar["maximum"] = total_files
            
            # 移动并重命名文件
            processed_files = 0
            for filename in file_list:
                if self.stop_requested:
                    self.log_message("处理已停止")
                    break
                    
                source_path = os.path.join(source_dir, filename)
                
                # 获取文件扩展名
                name, ext = os.path.splitext(filename)
                
                # 生成新文件名
                try:
                    # 替换格式字符串中的变量
                    new_filename = format_str
                    new_filename = new_filename.replace("{number}", str(count))
                    new_filename = new_filename.replace("{ext}", ext)
                    new_filename = new_filename.replace("{name}", name)
                    
                    # 处理格式字符串中的格式化部分（如 {number:04d}）
                    if "{number:" in new_filename:
                        format_match = re.search(r'\{number:(\d+)d\}', new_filename)
                        if format_match:
                            digits = int(format_match.group(1))
                            formatted_num = f"{count:0{digits}d}"
                            new_filename = re.sub(r'\{number:\d+d\}', formatted_num, new_filename)
                    
                    # 确保文件名合法
                    new_filename = re.sub(r'[<>:"/\\|?*]', '_', new_filename)
                except Exception as e:
                    self.log_message(f"错误: 生成文件名时出错 - {str(e)}")
                    continue
                
                target_path = os.path.join(target_dir, new_filename)
                
                # 移动并重命名文件
                try:
                    shutil.move(source_path, target_path)
                    self.log_message(f"移动文件: {filename} -> {new_filename}")
                    count += 1
                    processed_files += 1
                    
                    # 更新进度
                    self.progress_var.set(processed_files)
                    self.progress_label.config(text=f"处理中: {processed_files}/{total_files} ({processed_files/total_files*100:.1f}%)")
                    self.root.update_idletasks()
                    
                except Exception as e:
                    self.log_message(f"错误: 移动文件 {filename} 失败 - {str(e)}")
            
            self.log_message(f"处理完成! 共处理 {processed_files} 个文件")
            
        except Exception as e:
            self.log_message(f"处理过程中发生错误: {str(e)}")
            messagebox.showerror("错误", f"处理过程中发生错误:\n{str(e)}")
        finally:
            self.processing_completed()
    
    def processing_completed(self):
        """处理完成后清理"""
        self.is_processing = False
        self.stop_requested = False
        self.start_button.config(state=tk.NORMAL)
        self.stop_button.config(state=tk.DISABLED)
        self.progress_label.config(text="处理完成")
        self.status_var.set("就绪")

def main():
    root = tk.Tk()
    app = FileTransferApp(root)
    root.mainloop()

if __name__ == "__main__":
    main()