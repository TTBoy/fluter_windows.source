import sys
import torch
from PIL import Image
from transformers import CLIPProcessor, CLIPModel
import torchvision.transforms as T
from torchvision import models
import numpy as np
from sklearn.metrics.pairwise import cosine_similarity
from sklearn.decomposition import PCA
from sklearn.cluster import KMeans
import os
import torch.nn as nn
from collections import defaultdict
import imagehash
from concurrent.futures import ThreadPoolExecutor
import pytesseract
import difflib
import argparse
import json 

# 获取当前脚本所在的目录 (即 dist 文件夹)
script_dir = os.path.dirname(os.path.abspath(__file__))
# 拼接 Tesseract-OCR 可执行文件的路径
tesseract_path = os.path.join(script_dir, 'Tesseract-OCR', 'tesseract.exe')

# 检查文件是否存在，如果存在则使用，否则回退到原来的硬编码路径并打印警告
if os.path.exists(tesseract_path):
    pytesseract.pytesseract.tesseract_cmd = tesseract_path
    tessdata_dir = os.path.join(script_dir, 'Tesseract-OCR', 'tessdata')
    os.environ['TESSDATA_PREFIX'] = tessdata_dir
else:
    print(f"警告：在相对路径 '{tesseract_path}' 中未找到 Tesseract。将使用默认的绝对路径。")
    pytesseract.pytesseract.tesseract_cmd = r"D:\STware\Tesseract-OCR\tesseract.exe"
# --- 修改结束 ---

# ------------------------------ 模型加载 ------------------------------
try:
    clip_model = CLIPModel.from_pretrained("openai/clip-vit-base-patch16", local_files_only=True)
    clip_processor = CLIPProcessor.from_pretrained("openai/clip-vit-base-patch16", local_files_only=True)
except Exception as e:
    print("Warning: CLIP 模型加载失败，将尝试在线下载", e)
    clip_model = CLIPModel.from_pretrained("openai/clip-vit-base-patch16")
    clip_processor = CLIPProcessor.from_pretrained("openai/clip-vit-base-patch16")

try:
    resnet_model = models.resnet50(pretrained=True)
except Exception as e:
    print("Warning: ResNet50 模型加载失败，使用无预训练模型", e)
    resnet_model = models.resnet50(pretrained=False)
resnet_model.eval()

# ------------------------------ 特征提取 ------------------------------
def extract_clip_features(image):
    inputs = clip_processor(images=image, return_tensors="pt", padding=True)
    with torch.no_grad():
        features = clip_model.get_image_features(**inputs)
    return features.squeeze().cpu().numpy()

def extract_resnet_features(image):
    transform = T.Compose([
        T.Resize(256), T.CenterCrop(224),
        T.ToTensor(),
        T.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
    ])
    image = transform(image).unsqueeze(0)
    with torch.no_grad():
        features = nn.Sequential(*list(resnet_model.children())[:-1])(image)
    return features.squeeze().cpu().numpy()

# ------------------------------ 哈希过滤 ------------------------------
def hash_check(path1, path2, phash_threshold):
    img1, img2 = Image.open(path1), Image.open(path2)
    h1, h2 = imagehash.phash(img1), imagehash.phash(img2)
    diff = abs(h1 - h2)
    # print(f"Hash 距离 {os.path.basename(path1)} vs {os.path.basename(path2)}: {diff}")
    return diff <= phash_threshold

# ------------------------------ OCR 文本相似度 ------------------------------
def text_similarity(img1, img2):
    try:
        text1 = pytesseract.image_to_string(img1, lang='chi_sim')
        text2 = pytesseract.image_to_string(img2, lang='chi_sim')
        ratio = difflib.SequenceMatcher(None, text1, text2).ratio()
        return ratio
    except Exception as e:
        print("OCR 识别失败:", e)
        return 0.0

# ------------------------------ 配对比较函数 ------------------------------
def compare_pair(path1, path2, features_dict, clip_threshold, resnet_threshold, phash_threshold, text_similarity_threshold):
    if not hash_check(path1, path2, phash_threshold): return None
    clip_sim = cosine_similarity(features_dict[path1]["clip"], features_dict[path2]["clip"])[0][0]
    resnet_sim = cosine_similarity(features_dict[path1]["resnet"], features_dict[path2]["resnet"])[0][0]
    if clip_sim > clip_threshold and resnet_sim > resnet_threshold:
        img1 = Image.open(path1).convert("RGB")
        img2 = Image.open(path2).convert("RGB")
        sim_text = text_similarity(img1, img2)
        if sim_text < text_similarity_threshold:
          return None  #  OCR 也必须满足
        # print(f"  🔤 OCR 文本相似: {os.path.basename(path1)} vs {os.path.basename(path2)} -> 相似度 {sim_text:.2%}")
        return (path2, clip_sim, resnet_sim, sim_text)
    return None

# ------------------------------ 主函数 ------------------------------
def find_similar_images(image_folder, clip_threshold=0.9, resnet_threshold=0.9, min_group_size=2, phash_threshold=30, text_similarity_threshold=0.8, cluster_threshold=200, thread_count=8):
    image_paths = [
        os.path.join(image_folder, f)
        for f in os.listdir(image_folder)
        if f.lower().endswith(('jpg','jpeg','png'))
    ]
    pil_images = [Image.open(p).convert("RGB") for p in image_paths]

    inputs = clip_processor(images=pil_images, return_tensors="pt", padding=True)
    with torch.no_grad():
        clip_feats = clip_model.get_image_features(**inputs).cpu().numpy()
    clip_features = {p: feat for p, feat in zip(image_paths, clip_feats)}

    clip_matrix = np.array([clip_features[p] for p in image_paths])
    if len(image_paths) > cluster_threshold:
        print("进行预聚类...", file=sys.stderr)
        reduced = PCA(n_components=50).fit_transform(clip_matrix)
        labels = KMeans(n_clusters=min(len(image_paths) // 20, 50), random_state=42).fit_predict(reduced)
        image_paths = [p for _, p in sorted(zip(labels, image_paths))]

    transform = T.Compose([
        T.Resize(256), T.CenterCrop(224),
        T.ToTensor(),
        T.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
    ])
    batch_tensor = torch.stack([transform(img) for img in pil_images])
    with torch.no_grad():
        resnet_feats = nn.Sequential(*list(resnet_model.children())[:-1])(batch_tensor)
    resnet_features = {p: feat.squeeze().cpu().numpy() for p, feat in zip(image_paths, resnet_feats)}

    features_dict = {
        p: {
            "clip": clip_features[p].reshape(1, -1),
            "resnet": resnet_features[p].reshape(1, -1)
        } for p in image_paths
    }

    groups, visited = [], set()

    for i, path1 in enumerate(image_paths):
        if path1 in visited: continue
        group = [path1]
        visited.add(path1)

        with ThreadPoolExecutor(max_workers=thread_count) as executor:
            futures = [executor.submit(compare_pair, path1, path2, features_dict, clip_threshold, resnet_threshold, phash_threshold, text_similarity_threshold)
                       for path2 in image_paths[i+1:] if path2 not in visited]
        for future in futures:
            result = future.result()
            if result:
                path2, clip_sim, resnet_sim, sim_text = result
                group.append(path2)
                visited.add(path2)

        if len(group) >= min_group_size:
            groups.append(sorted(group))

    return groups

# ------------------------------ 运行入口 ------------------------------
if __name__ == "__main__":
    # 设置命令行参数解析
    parser = argparse.ArgumentParser(description='查找相似图片')
    parser.add_argument('folder', type=str, help='图片文件夹路径')
    parser.add_argument('--clip_threshold', type=float, default=0.85, help='CLIP相似度阈值')
    parser.add_argument('--resnet_threshold', type=float, default=0.85, help='ResNet相似度阈值')
    parser.add_argument('--phash_threshold', type=int, default=30, help='感知哈希阈值')
    parser.add_argument('--text_threshold', type=float, default=0.7, help='文本相似度阈值')
    parser.add_argument('--cluster_threshold', type=int, default=200, help='预聚类阈值')
    parser.add_argument('--threads', type=int, default=8, help='线程数')
    
    args = parser.parse_args()
    
    if not os.path.isdir(args.folder):
        print(f"错误: '{args.folder}' 不是一个有效的文件夹路径", file=sys.stderr)
        exit(1)

    groups = find_similar_images(
        args.folder,
        clip_threshold=args.clip_threshold,
        resnet_threshold=args.resnet_threshold,
        min_group_size=2,
        phash_threshold=args.phash_threshold,
        text_similarity_threshold=args.text_threshold,
        cluster_threshold=args.cluster_threshold,
        thread_count=args.threads
    )

    # 将结果转换为JSON格式，只包含文件名
    result = [
        [os.path.basename(img_path) for img_path in group]
        for group in groups
    ]
    
    # 输出JSON格式的结果
    print(json.dumps(result, ensure_ascii=False))

#使用方法
#python script.py "C:\Users\EDY\Desktop\img\新建文件夹 (13)"
#python script.py /path/to/image/folder --clip_threshold 0.85 --resnet_threshold 0.85 --phash_threshold 30 --text_threshold 0.7 --cluster_threshold 200 --threads 8