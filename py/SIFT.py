import cv2
import numpy as np
import os
import json
import argparse
from collections import defaultdict

def extract_sift_features(image_path):
    """提取图像的SIFT特征"""
    img = cv2.imread(image_path)
    if img is None:
        return None, None
        
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    sift = cv2.SIFT_create()
    keypoints, descriptors = sift.detectAndCompute(gray, None)
    return keypoints, descriptors

def match_images(desc1, desc2, ratio_thresh=0.75):
    """匹配两幅图像的SIFT特征"""
    if desc1 is None or desc2 is None:
        return 0
        
    # FLANN参数
    FLANN_INDEX_KDTREE = 1
    index_params = dict(algorithm=FLANN_INDEX_KDTREE, trees=5)
    search_params = dict(checks=50)
    
    flann = cv2.FlannBasedMatcher(index_params, search_params)
    matches = flann.knnMatch(desc1, desc2, k=2)
    
    # 应用Lowe's ratio test筛选好的匹配
    good_matches = []
    for m, n in matches:
        if m.distance < ratio_thresh * n.distance:
            good_matches.append(m)
            
    return len(good_matches)

def find_similar_images(folder_path, match_threshold=30, ratio_thresh=0.75):
    """查找文件夹中相似的图片并进行分组"""
    # 获取所有图片文件
    image_files = [f for f in os.listdir(folder_path) 
                  if f.lower().endswith(('.png', '.jpg', '.jpeg', '.bmp', '.tiff'))]
    
    # 提取所有图片的特征
    image_features = {}
    for img_file in image_files:
        img_path = os.path.join(folder_path, img_file)
        kp, desc = extract_sift_features(img_path)
        image_features[img_file] = desc
    
    # 创建相似图片组
    groups = []
    processed = set()
    
    # 遍历所有图片对进行比较
    for i, img1 in enumerate(image_files):
        if img1 in processed:
            continue
            
        # 创建新组
        current_group = [img1]
        processed.add(img1)
        
        # 查找与当前图片相似的图片
        for j, img2 in enumerate(image_files):
            if i == j or img2 in processed:
                continue
                
            desc1 = image_features[img1]
            desc2 = image_features[img2]
            matches_count = match_images(desc1, desc2, ratio_thresh)
            
            if matches_count >= match_threshold:
                current_group.append(img2)
                processed.add(img2)
        
        groups.append(current_group)
    
    return groups

def main():
    parser = argparse.ArgumentParser(description='Group similar images in a folder using SIFT algorithm')
    parser.add_argument('folder', help='Path to the folder containing images')
    parser.add_argument('--threshold', type=int, default=30, 
                       help='Minimum number of matches to consider images similar (default: 30)')
    parser.add_argument('--ratio', type=float, default=0.75,
                       help='Lowe\'s ratio test threshold (default: 0.75, lower for higher precision)')
    
    args = parser.parse_args()
    
    if not os.path.isdir(args.folder):
        print(f"Error: The path '{args.folder}' is not a valid directory.")
        return
    
    # 查找相似图片组
    similar_groups = find_similar_images(args.folder, args.threshold, args.ratio)
    
    # 过滤：只保留包含两张或以上图片的分组
    filtered_groups = [group for group in similar_groups if len(group) >= 2]
    
    # 输出JSON格式结果
    print(json.dumps(filtered_groups, indent=2))

if __name__ == "__main__":
    main()