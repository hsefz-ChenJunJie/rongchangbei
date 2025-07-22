from ultralytics import YOLO
from ultralytics import settings
import os
from pathlib import Path
import shutil

cur_dir = Path(__file__).parent

model_dir = os.path.join(cur_dir, 'models')

cwd = os.getcwd()

# Default model name and yaml file
model_name = 'yxy_v1.1.pt'
yaml_name = 'lovely_yxy_original/lovely_yxy_original.yaml'
dataset_dir = 'lovely_yxy_original'

# Default training parameters
epochs = 50
imgsz = 640

# Load a model
settings.update({'datasets_dir': os.path.join(cur_dir, dataset_dir)})
model = YOLO(os.path.join(model_dir, model_name))

# Train the model
model.train(data=os.path.join(cur_dir, yaml_name), epochs=epochs, imgsz=imgsz)

if os.path.exists(os.path.join(cur_dir, 'runs')):
    shutil.rmtree(os.path.join(cur_dir, 'runs'))
shutil.copytree(os.path.join(cwd, 'runs'), os.path.join(cur_dir, 'runs'))
