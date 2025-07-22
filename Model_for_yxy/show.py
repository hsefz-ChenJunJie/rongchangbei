import gradio as gr
import os
import json
import torch
from ultralytics import YOLO
from PIL import Image
import numpy as np
from pathlib import Path

# 模型目录
cur_dir = Path(__file__).parent
MODEL_DIR = os.path.join(cur_dir, 'models')

# 获取所有可用的模型文件
def get_model_list():
    model_files = [f for f in os.listdir(MODEL_DIR) if f.endswith('.pt')]
    return model_files if model_files else ["best.pt"]

# 加载模型并进行预测
def predict_image(image, model_choice, conf_threshold):
    # 构建完整模型路径
    model_path = os.path.join(MODEL_DIR, model_choice)
    
    # 加载模型
    model = YOLO(model_path)
    
    # 进行预测
    results = model.predict(
        source=image,
        conf=conf_threshold,
        save=False,
        save_txt=False,
        save_conf=False
    )
    
    # 获取第一个结果（单张图片）
    result = results[0]
    
    # 获取带标注的图像
    plotted_img = result.plot()
    plotted_img = Image.fromarray(plotted_img[..., ::-1])  # BGR to RGB
    
    # 获取检测到的对象数量
    num_objects = len(result.boxes)
    
    # 获取详细的JSON结果
    json_data = json.loads(result.tojson())
    
    # 添加额外信息到JSON
    detailed_json = {
        "image_size": result.orig_shape,
        "detected_objects": num_objects,
        "detections": json_data
    }
    
    return plotted_img, num_objects, detailed_json

# 获取模型列表
available_models = get_model_list()
default_model = "best.pt" if "best.pt" in available_models else available_models[0]

# 创建Gradio界面
with gr.Blocks(title="YOLOv10 目标检测") as demo:
    gr.Markdown("# 🚀 YOLOv10 目标检测演示")
    gr.Markdown("上传图片并选择模型进行目标检测")
    
    with gr.Row():
        with gr.Column():
            image_input = gr.Image(type="pil", label="输入图片")
            model_dropdown = gr.Dropdown(
                choices=available_models,
                value=default_model,
                label="选择模型"
            )
            conf_slider = gr.Slider(
                minimum=0.0,
                maximum=1.0,
                value=0.25,
                step=0.01,
                label="置信度阈值"
            )
            submit_btn = gr.Button("开始检测", variant="primary")
        
        with gr.Column():
            image_output = gr.Image(type="pil", label="检测结果")
            count_output = gr.Number(label="检测到的对象数量")
            json_output = gr.JSON(label="检测详情")

    # 设置提交动作
    submit_btn.click(
        fn=predict_image,
        inputs=[image_input, model_dropdown, conf_slider],
        outputs=[image_output, count_output, json_output]
    )

    # 添加示例
    gr.Markdown("## 示例图片")
    gr.Examples(
        examples=[
            [os.path.join(cur_dir, "example1.jpg"), "yxy_v1.pt", 0.1]
        ],
        inputs=[image_input, model_dropdown, conf_slider],
        outputs=[image_output, count_output, json_output],
        fn=predict_image,
        cache_examples=False
    )

# 启动应用
if __name__ == "__main__":
    demo.launch()