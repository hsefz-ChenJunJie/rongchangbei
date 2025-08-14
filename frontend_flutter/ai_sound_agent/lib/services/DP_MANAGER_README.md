# DPManager 使用指南

## 概述

DPManager是一个用于管理对话包（Dialogue Package）的类，提供了对话包的创建、加载、保存和删除功能。对话包以JSON格式存储在应用的documents目录下的`dp`文件夹中。

## 初始化

在使用DPManager之前，需要先进行初始化：

```dart
final dpManager = DPManager();
await dpManager.init(); // 会自动创建dp文件夹和default.dp
```

## 基本用法

### 获取默认对话包

```dart
final defaultDp = await dpManager.getDefaultDp();
```

### 获取指定对话包

```dart
final dp = await dpManager.getDp('my_dialogue');
```

### 创建新对话包

```dart
await dpManager.createNewDp(
  'new_dialogue',
  scenarioDescription: '新的对话情景',
  initialMessages: [
    Message(
      idx: 0,
      name: 'user',
      content: '你好',
      time: '2024/1/1 12:00:00',
      isMe: true,
    ),
  ],
);
```

### 保存对话包

```dart
await dpManager.saveDp(dialoguePackage);
```

### 删除对话包

```dart
await dpManager.deleteDp('dialogue_name'); // 不能删除default
```

## 与ChatDialogue集成

### 从ChatDialogue保存对话

```dart
// 获取ChatDialogue的所有消息
final messages = chatState.getAllMessages();

// 保存为对话包
await dpManager.createDpFromChatSelection(
  'saved_chat',
  messages,
  scenarioDescription: '保存的聊天记录',
);
```

### 加载对话包到ChatDialogue

```dart
// 加载对话包
final dp = await dpManager.getDp('dialogue_name');

// 转换为ChatMessage格式
final chatMessages = dpManager.toChatMessages(dp);

// 清空ChatDialogue并加载消息
chatState.clear();
for (final msg in chatMessages) {
  chatState.addMessage(
    name: msg['name'],
    content: msg['content'],
    isMe: msg['is_me'],
  );
}
```

## 数据结构

### Message类

与ChatDialogue的getSelection返回格式保持一致：

```json
{
  "idx": 0,
  "name": "用户名",
  "content": "消息内容",
  "time": "2024/1/1 12:00:00",
  "is_me": true
}
```

### DialoguePackage类

```json
{
  "type": "dialogue_package",
  "name": "对话包名称",
  "response_count": 3,
  "scenario_description": "对话情景描述",
  "message": [/* Message列表 */],
  "modification": "",
  "user_opinion": "",
  "scenario_supplement": ""
}
```

## 文件存储

- 存储位置：`/data/data/your.package.name/app_flutter/dp/`
- 文件格式：`.dp`（实际上是JSON文件）
- 默认文件：`default.dp`

## 完整示例

参见`dp_integration_example.dart`文件，展示了完整的集成使用方法。

## 注意事项

1. 初始化必须在UI构建之前完成
2. 不能删除默认对话包（default.dp）
3. 对话包名称不能包含特殊字符
4. 时间格式必须与ChatDialogue保持一致