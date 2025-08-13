# Examples 文件夹

## 说明

该文件夹包含了一些示例代码，用于演示如何使用该项目的功能与组件。

## 示例列表

- [vad 示例](vad_example.dart)：演示如何使用vad。
- [base 示例](base_example.dart)：演示如何使用项目的`base`组件，也就是所有页面的公共父类。
- [chat 示例](chat_example.dart)：演示如何使用项目两个聊天组件`ChatDialogue`和`ChatInput`。
- [tabs 示例](tabs_example.dart)：演示如何使用项目的`tabs`组件。
- [text_area 示例](text_area_example.dart)：演示如何使用项目的`text_area`组件。
- [chat_input 示例](chat_input_example.dart)：演示如何使用项目的`ChatInput`组件。
- [base_elevated_button 示例](base_elevated_button_example.dart)：演示如何使用项目的`BaseElevatedButton`组件。
- [base_button 示例](base_button_example.dart)：演示如何使用项目的`BaseButton`组件。
- [bottom_navigator 示例](bottom_navigator_example.dart)：演示如何使用项目的`BottomNavigator`组件。
- [tts 示例](tts_example.dart)：演示如何使用项目的`Tts`。







## ChatDialogue 组件使用说明

这是一个仿微信聊天的多人对话框组件，支持主题色跟随和消息管理功能。

### 基本用法

```dart
// 创建组件
ChatDialogue chatDialogue = ChatDialogue(key: GlobalKey());

// 获取状态以调用方法
final chatKey = GlobalKey<ChatDialogueState>();
ChatDialogue(key: chatKey);
```

### 可用方法

#### 1. 添加消息
```dart
chatKey.currentState?.addMessage(
  name: '张三',
  content: '你好！',
  isMe: false, // 是否为本人发送
  time: DateTime.now(), // 可选，默认为当前时间
  icon: Icons.person, // 可选，默认为头像图标
);
```

#### 2. 清除所有消息
```dart
chatKey.currentState?.clear();
```

#### 3. 删除最后一条消息

```dart
chatKey.currentState?.deleteLatestMessage();
```
#### 4. 删除指定消息
```dart
// 通过索引删除
chatKey.currentState?.deleteMessage(index: 2);

// 通过时间删除
chatKey.currentState?.deleteMessage(time: DateTime.parse('2024-01-01 12:00:00'));
```

#### 5. 消息选择功能

```dart
// 显示选择框
chatKey.currentState?.showSelection();

// 隐藏选择框
chatKey.currentState?.hideSelection();

// 获取选择的消息
final selectedMessages = chatKey.currentState?.getSelection();
// 返回格式：
// [
//   {
//     "idx": 6,
//     "name": "xxx",
//     "content": "xxxxx……xxxxx",
//     "time": "2025/8/11 12:34:56",
//     "is_me": false
//   }
// ]
```

### 视觉样式

- **主题色跟随**：背景色和边框色会自动跟随应用主题色变化
- **消息布局**：
  - 本人消息：右侧显示，绿色背景泡泡
  - 他人消息：左侧显示，主题色背景泡泡
- **头像显示**：每个消息都显示发送者头像
- **时间戳**：每条消息显示发送时间

### 完整示例

```dart
import 'package:flutter/material.dart';
import '../widgets/chat_recording/chat_dialogue.dart';

class MyChatPage extends StatefulWidget {
  @override
  _MyChatPageState createState() => _MyChatPageState();
}

class _MyChatPageState extends State<MyChatPage> {
  final GlobalKey<ChatDialogueState> _chatKey = GlobalKey<ChatDialogueState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('聊天')),
      body: Column(
        children: [
          Expanded(
            child: ChatDialogue(key: _chatKey),
          ),
          Row(
            children: [
              ElevatedButton(
                onPressed: () {
                  _chatKey.currentState?.addMessage(
                    name: '测试用户',
                    content: '这是一条测试消息',
                    isMe: true,
                  );
                },
                child: Text('发送测试消息'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

### 注意事项

1. 必须使用 `GlobalKey<ChatDialogueState>` 来获取组件状态
2. 所有消息会自动按时间排序
3. 选择功能需要先调用 `showSelection()` 才能使用
4. 组件会自动滚动到最新消息



## Base
```dart
// 使用示例：

class HomePage extends BasePage {
  const HomePage({Key? key}) : super(
    key: key,
    title: '首页',
    showBottomNav: true,
    showBreadcrumb: true,
    showSettingsFab: true,
  );

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends BasePageState<HomePage> {
  @override
  Widget buildContent(BuildContext context) {
    return const Center(
      child: Text('这是首页内容'),
    );
  }

  @override
  void onPageChange(int index) {
    super.onPageChange(index);
    // 根据索引切换页面内容
    switch (index) {
      case 0:
        // 首页
        break;
      case 1:
        // 发现页
        break;
      case 2:
        // 我的页面
        break;
    }
  }

  // 使用默认的底部导航栏（来自constants.dart）
  // 如需自定义，可以重写此方法
}
```

##