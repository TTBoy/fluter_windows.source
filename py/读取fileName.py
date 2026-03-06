import os
import json
import pandas as pd
import tkinter as tk
from tkinter import filedialog

def select_excel_file():
    """打开文件选择器选择Excel文件"""
    root = tk.Tk()
    root.withdraw()  # 隐藏主窗口
    file_path = filedialog.askopenfilename(
        title="选择Excel文件",
        filetypes=[("Excel文件", "*.xlsx *.xls"), ("所有文件", "*.*")]
    )
    return file_path

def extract_filenames(excel_path):
    """从Excel中提取文件名（带筛选条件）并添加.png后缀"""
    try:
        # 读取需要的列：A列（image_1）、C列（text_image_domain）、I列（图片维度）
        df = pd.read_excel(excel_path, usecols=['text_md5', 'text_image_domain', '图片维度'])
        
        # 应用筛选条件
        filtered_df = df[
            (df['text_image_domain'] == "单实例推理") & 
            (df['图片维度'] == "选合格")
        ]
        
        # 提取文件名并过滤空值，添加.png后缀
        filenames = [
            os.path.basename(path)  # 添加.png后缀
            for path in filtered_df['text_md5'].dropna() 
            if isinstance(path, str)
        ]
        
        return filenames
    except KeyError as e:
        print(f"错误：Excel文件中缺少必要的列 - {e}")
        return []
    except Exception as e:
        print(f"处理Excel时出错: {e}")
        return []

def save_to_json(filenames, output_path="filenames.json"):
    """将文件名列表保存为JSON文件"""
    data = {"fileNames": filenames}
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=4, ensure_ascii=False)
    return os.path.abspath(output_path)

def main():
    # 步骤1：选择Excel文件
    excel_path = select_excel_file()
    if not excel_path:
        print("未选择文件，程序退出")
        return
    
    # 步骤2：提取文件名（带筛选）并添加.png后缀
    filenames = extract_filenames(excel_path)
    if not filenames:
        print("未找到符合条件的文件名")
        return
    
    # 步骤3：保存为JSON
    output_path = save_to_json(filenames)
    print(f"已成功导出 {len(filenames)} 个文件名到: {output_path}")
    print(f"筛选条件：text_image_domain='单实例推理' 且 图片维度='选合格'")
    print(f"所有文件名已添加.png后缀")

if __name__ == "__main__":
    main()