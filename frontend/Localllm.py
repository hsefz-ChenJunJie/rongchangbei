import erniebot
from flask import Flask, request, jsonify
import json
import random
import time

erniebot.api_type = "aistudio"
erniebot.access_token = "edb44342d3319fffe23dbd1e0d4808ef64beb641"
stream = False
app = Flask(__name__)


def get_response(suggestion_count,scenario_context="工作场景",user_opinion="",target_dialogue=""):
    result=[]
    prompt = f"你现在在一个{scenario_context}，请根据用户输入的{user_opinion}，以下是之前的对话上下文：\n{target_dialogue}\n，请用中文一句话回答。只用输出一句话，回答短，精炼，简洁。"
    for i in range(suggestion_count):
        response = erniebot.ChatCompletion.create(
            model="ernie-3.5",
            messages=[{
            "role": "user",
            "content": prompt
            }],
            temperature=0.95,
            top_p=0.95,
            stream=stream)
        
        result_one = response.get_result()
        result.append(result_one)
    return result

# 将函数封装为API
@app.route('/api/generate_suggestions', methods=['GET', 'POST'])
def add_api():
    """
    {
    "scenario_context": "string",
    "user_opinion": "string",
    "target_dialogue": "string",
    "modification_suggestion": [
        "string"
    ],
    "suggestion_count": 3
    }
    """
    # 获取参数（支持GET/POST）
    data = request.get_json() if request.method == 'POST' else request.args
    try:
        print(data)
        suggestion_count = data.get('suggestion_count')
        scenario_context = data.get('scenario_context')
        user_opinion = data.get('user_opinion')
        target_dialogue = data.get('target_dialogue')
        print()
        result:list[str] = get_response(suggestion_count,scenario_context,user_opinion,target_dialogue)
        #print("data:"+jsonify({"suggestions":[{"content":i, "confidence":0.8} for i in result]}))
        return "data:"+json.dumps({"suggestions":[{"content":i, "confidence":0.8} for i in result]}), 200, {"Content-Type":"application/json"}
    except Exception as e:
        return jsonify({"error": str(e)}), 400

if __name__ == '__main__':
    app.run(host='192.168.0.86', port=8000, debug=True)