# import json
# import mysql.connector
# import tkinter as tk
# from tkinter import filedialog, messagebox, ttk
# import os
# from datetime import datetime
# import threading
# import re

# # 数据库连接配置
# DB_CONFIG = {
#     'host': '10.1.5.175',
#     'user': 'yang',
#     'password': 'yjz147',
#     'database': 'imageqawork'
# }

# # 难度映射字典
# DIFFICULTY_MAP = {
#     "简单": 0,
#     "中等": 1
#     # 可以根据需要添加更多难度级别映射
# }

# # 固定时间戳
# FIXED_TIMESTAMP = "2025-08-27 09:30:00"

# def select_json_file():
#     """打开文件选择器选择JSON文件"""
#     root = tk.Tk()
#     root.withdraw()  # 隐藏主窗口
#     file_path = filedialog.askopenfilename(
#         title="选择JSON文件",
#         filetypes=[("JSON文件", "*.json"), ("所有文件", "*.*")]
#     )
#     root.destroy()
#     return file_path

# def parse_options(options_text):
#     """解析选项文本，返回选项列表"""
#     options = []
#     # 使用正则表达式匹配选项格式（A. 内容）
#     pattern = r'([A-D])\.\s*([^\n]+)'
#     matches = re.findall(pattern, options_text)
    
#     for match in matches:
#         option_letter, option_text = match
#         options.append({
#             'letter': option_letter,
#             'text': option_text.strip()
#         })
    
#     return options

# def process_json_data(json_data):
#     """处理JSON数据，转换为数据库插入格式"""
#     processed_data = []
    
#     for item in json_data:
#         # 提取文件名（去掉路径）
#         file_name = os.path.basename(item["image_1"])
        
#         # 构建path字段
#         path = f"img/single_instance_reasoning（单实例推理）/{file_name}"
        
#         # 转换难度
#         difficulty = DIFFICULTY_MAP.get(item["text_QA_diff"], 0)  # 默认值为0
        
#         # 解析选项
#         options = parse_options(item["text_opinion"])
        
#         # 获取正确答案
#         correct_answer = item.get("text_correct_answer", "")
        
#         # 构建插入数据
#         processed_item = {
#             'fileName': file_name,
#             'category': 'single_instance_reasoning（单实例推理）',
#             'collector_type': item["text_image_type"],
#             'question_direction': item["text_QA_direction"],
#             'difficulty': difficulty,
#             'path': path,
#             'state': 0,
#             'created_at': FIXED_TIMESTAMP,
#             'updated_at': FIXED_TIMESTAMP,
#             'originatorID': 1,
#             'checkImageListID': None,
#             'workID': None,
#             'question': item["text_question"],
#             'options': options,
#             'correct_answer': correct_answer
#         }
        
#         processed_data.append(processed_item)
    
#     return processed_data

# def import_to_database(data, progress_callback=None):
#     """将数据导入数据库"""
#     try:
#         # 连接数据库
#         conn = mysql.connector.connect(**DB_CONFIG)
#         cursor = conn.cursor()
        
#         # 准备SQL语句
#         image_sql = """
#         INSERT INTO image 
#         (fileName, category, collector_type, question_direction, difficulty, path, 
#          state, created_at, updated_at, originatorID, checkImageListID, workID)
#         VALUES 
#         (%(fileName)s, %(category)s, %(collector_type)s, %(question_direction)s, %(difficulty)s, %(path)s,
#          %(state)s, %(created_at)s, %(updated_at)s, %(originatorID)s, %(checkImageListID)s, %(workID)s)
#         """
        
#         question_sql = """
#         INSERT INTO question 
#         (questionText, imageID, rightAnswerID, explanation, textCOT)
#         VALUES 
#         (%(questionText)s, %(imageID)s, %(rightAnswerID)s, %(explanation)s, %(textCOT)s)
#         """
        
#         answer_sql = """
#         INSERT INTO answer 
#         (answerText, questionID)
#         VALUES 
#         (%(answerText)s, %(questionID)s)
#         """
        
#         # 逐条插入数据并更新进度
#         total = len(data)
#         for i, item in enumerate(data):
#             # 1. 首先插入image表
#             image_data = {k: v for k, v in item.items() if k not in ['question', 'options', 'correct_answer']}
#             cursor.execute(image_sql, image_data)
#             image_id = cursor.lastrowid
            
#             # 2. 插入question表（暂时不设置rightAnswerID）
#             question_data = {
#                 'questionText': item['question'],
#                 'imageID': image_id,
#                 'rightAnswerID': None,  # 稍后更新
#                 'explanation': None,
#                 'textCOT': None
#             }
#             cursor.execute(question_sql, question_data)
#             question_id = cursor.lastrowid
            
#             # 3. 插入答案选项并记录正确答案的ID
#             correct_answer_id = None
#             for option in item['options']:
#                 answer_data = {
#                     'answerText': f"{option['letter']}. {option['text']}",
#                     'questionID': question_id
#                 }
#                 cursor.execute(answer_sql, answer_data)
#                 answer_id = cursor.lastrowid
                
#                 # 检查是否是正确答案
#                 if option['letter'] == item['correct_answer']:
#                     correct_answer_id = answer_id
            
#             # 4. 更新question表中的rightAnswerID
#             if correct_answer_id:
#                 update_sql = "UPDATE question SET rightAnswerID = %s WHERE questionID = %s"
#                 cursor.execute(update_sql, (correct_answer_id, question_id))
            
#             if progress_callback:
#                 progress_callback(i + 1, total)
        
#         # 提交事务
#         conn.commit()
        
#         # 关闭连接
#         cursor.close()
#         conn.close()
        
#         return True, f"成功导入 {total} 条数据"
        
#     except Exception as e:
#         # 发生错误时回滚
#         if 'conn' in locals() and conn.is_connected():
#             conn.rollback()
#         return False, f"导入失败: {str(e)}"

# def create_progress_window():
#     """创建进度显示窗口"""
#     root = tk.Tk()
#     root.title("数据导入进度")
#     root.geometry("400x150")
    
#     # 进度标签
#     label = tk.Label(root, text="正在导入数据...")
#     label.pack(pady=10)
    
#     # 进度条
#     progress = ttk.Progressbar(root, orient="horizontal", length=300, mode="determinate")
#     progress.pack(pady=10)
    
#     # 进度百分比
#     percent_label = tk.Label(root, text="0%")
#     percent_label.pack()
    
#     return root, progress, label, percent_label

# def update_progress(progress, percent_label, value, total):
#     """更新进度条和百分比标签"""
#     progress["value"] = (value / total) * 100
#     percent_label.config(text=f"{int((value / total) * 100)}%")
#     progress.update_idletasks()

# def main():
#     # 选择JSON文件
#     json_file_path = select_json_file()
#     if not json_file_path:
#         messagebox.showinfo("信息", "未选择文件，程序退出")
#         return
    
#     try:
#         # 读取JSON文件
#         with open(json_file_path, 'r', encoding='utf-8') as f:
#             json_data = json.load(f)
        
#         # 处理数据
#         processed_data = process_json_data(json_data)
        
#         # 创建进度窗口
#         progress_window, progress_bar, status_label, percent_label = create_progress_window()
        
#         # 在单独线程中执行数据库导入
#         def import_thread():
#             success, message = import_to_database(
#                 processed_data, 
#                 lambda current, total: update_progress(progress_bar, percent_label, current, total)
#             )
            
#             # 关闭进度窗口
#             progress_window.after(0, progress_window.destroy)
            
#             # 显示结果
#             if success:
#                 messagebox.showinfo("成功", message)
#             else:
#                 messagebox.showerror("错误", message)
        
#         # 启动导入线程
#         thread = threading.Thread(target=import_thread)
#         thread.daemon = True
#         thread.start()
        
#         # 显示进度窗口
#         progress_window.mainloop()
        
#     except Exception as e:
#         messagebox.showerror("错误", f"处理文件时出错: {str(e)}")

# if __name__ == "__main__":
#     main()

import json
import mysql.connector
import tkinter as tk
from tkinter import filedialog, messagebox
import os
from datetime import datetime
import re
import sys

# 数据库连接配置
DB_CONFIG = {
    'host': '10.1.5.175',
    'user': 'user',
    'password': 'yjz147',
    'database': 'imageqawork'
}

# 难度映射字典
DIFFICULTY_MAP = {
    "简单": 0,
    "中等": 1
    # 可以根据需要添加更多难度级别映射
}

# 固定时间戳
FIXED_TIMESTAMP = "2025-08-27 09:30:00"

def select_json_file():
    """打开文件选择器选择JSON文件"""
    root = tk.Tk()
    root.withdraw()  # 隐藏主窗口
    file_path = filedialog.askopenfilename(
        title="选择JSON文件",
        filetypes=[("JSON文件", "*.json"), ("所有文件", "*.*")]
    )
    root.destroy()
    return file_path

def parse_options(options_text):
    """解析选项文本，返回选项列表（去除字母前缀）"""
    options = []
    # 使用正则表达式匹配选项格式（A. 内容）
    pattern = r'([A-D])\.\s*([^\n]+)'
    matches = re.findall(pattern, options_text)
    
    for match in matches:
        option_letter, option_text = match
        options.append({
            'letter': option_letter,
            'text': option_text.strip()  # 只保留选项内容，不包含字母
        })
    
    return options

def process_json_data(json_data):
    """处理JSON数据，转换为数据库插入格式"""
    processed_data = []
    
    for item in json_data:
        # 提取文件名（去掉路径）
        file_name = os.path.basename(item["image_1"])
        
        # 构建path字段
        path = f"img/single_instance_reasoning（单实例推理）/{file_name}"
        
        # 转换难度
        difficulty = DIFFICULTY_MAP.get(item["text_QA_diff"], 0)  # 默认值为0
        
        # 解析选项
        options = parse_options(item["text_opinion"])
        
        # 获取正确答案
        correct_answer = item.get("text_answer", "")  # 注意：这里应该是text_answer而不是text_correct_answer
        
        # 构建插入数据
        processed_item = {
            'fileName': file_name,
            'category': 'single_instance_reasoning（单实例推理）',
            'collector_type': item["text_image_type"],
            'question_direction': item["text_QA_direction"],
            'difficulty': difficulty,
            'path': path,
            'state': 0,
            'created_at': FIXED_TIMESTAMP,
            'updated_at': FIXED_TIMESTAMP,
            'originatorID': 1,
            'checkImageListID': None,
            'workID': None,
            'question': item["text_question"],
            'options': options,
            'correct_answer': correct_answer,
            'explanation': item.get("text_COT", "")  # 添加解释字段
        }
        
        processed_data.append(processed_item)
    
    return processed_data

def print_progress_bar(current, total, bar_length=50):
    """在控制台打印进度条"""
    percent = float(current) * 100 / total
    arrow = '-' * int(percent/100 * bar_length - 1) + '>'
    spaces = ' ' * (bar_length - len(arrow))
    
    print(f'\r进度: [{arrow}{spaces}] {current}/{total} ({percent:.2f}%)', end='', flush=True)
    
    if current == total:
        print()  # 完成后换行

def import_to_database(data):
    """将数据导入数据库"""
    try:
        # 连接数据库
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor()
        
        # 准备SQL语句
        image_sql = """
        INSERT INTO image 
        (fileName, category, collector_type, question_direction, difficulty, path, 
         state, created_at, updated_at, originatorID, checkImageListID, workID)
        VALUES 
        (%(fileName)s, %(category)s, %(collector_type)s, %(question_direction)s, %(difficulty)s, %(path)s,
         %(state)s, %(created_at)s, %(updated_at)s, %(originatorID)s, %(checkImageListID)s, %(workID)s)
        """
        
        question_sql = """
        INSERT INTO question 
        (questionText, imageID, rightAnswerID, explanation, textCOT)
        VALUES 
        (%(questionText)s, %(imageID)s, %(rightAnswerID)s, %(explanation)s, %(textCOT)s)
        """
        
        answer_sql = """
        INSERT INTO answer 
        (answerText, questionID)
        VALUES 
        (%(answerText)s, %(questionID)s)
        """
        
        # 逐条插入数据并更新进度
        total = len(data)
        print(f"开始导入 {total} 条数据...")
        
        for i, item in enumerate(data):
            # 1. 首先插入image表
            image_data = {k: v for k, v in item.items() if k not in ['question', 'options', 'correct_answer', 'explanation']}
            cursor.execute(image_sql, image_data)
            image_id = cursor.lastrowid
            
            # 2. 插入question表（暂时不设置rightAnswerID）
            question_data = {
                'questionText': item['question'],
                'imageID': image_id,
                'rightAnswerID': None,  # 稍后更新
                'explanation': item.get('explanation', ''),
                'textCOT': item.get('explanation', '')  # 使用解释作为textCOT
            }
            cursor.execute(question_sql, question_data)
            question_id = cursor.lastrowid
            
            # 3. 插入答案选项并记录正确答案的ID
            correct_answer_id = None
            for option in item['options']:
                # 只插入选项内容，不包含字母前缀
                answer_data = {
                    'answerText': option['text'],  # 只插入选项内容
                    'questionID': question_id
                }
                cursor.execute(answer_sql, answer_data)
                answer_id = cursor.lastrowid  # 修正变量名拼写错误
                
                # 检查是否是正确答案
                if option['letter'] == item['correct_answer']:
                    correct_answer_id = answer_id
            
            # 4. 更新question表中的rightAnswerID
            if correct_answer_id:
                update_sql = "UPDATE question SET rightAnswerID = %s WHERE questionID = %s"
                cursor.execute(update_sql, (correct_answer_id, question_id))
            
            # 更新进度条
            print_progress_bar(i + 1, total)
        
        # 提交事务
        conn.commit()
        
        # 关闭连接
        cursor.close()
        conn.close()
        
        return True, f"成功导入 {total} 条数据"
        
    except Exception as e:
        # 发生错误时回滚
        if 'conn' in locals() and conn.is_connected():
            conn.rollback()
        return False, f"导入失败: {str(e)}"

def main():
    # 选择JSON文件
    json_file_path = select_json_file()
    if not json_file_path:
        messagebox.showinfo("信息", "未选择文件，程序退出")
        return
    
    try:
        # 读取JSON文件
        with open(json_file_path, 'r', encoding='utf-8') as f:
            json_data = json.load(f)
        
        # 处理数据
        processed_data = process_json_data(json_data)
        
        # 执行数据库导入
        success, message = import_to_database(processed_data)
        
        # 显示结果
        if success:
            print(f"\n{message}")
            messagebox.showinfo("成功", message)
        else:
            print(f"\n{message}")
            messagebox.showerror("错误", message)
        
    except Exception as e:
        error_msg = f"处理文件时出错: {str(e)}"
        print(error_msg)
        messagebox.showerror("错误", error_msg)

if __name__ == "__main__":
    main()