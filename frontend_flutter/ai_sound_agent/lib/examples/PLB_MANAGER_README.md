# PLB Manager 使用说明

## 概述
PLB Manager是一个用于管理plb包的类，它提供了完整的plb文件管理功能，包括创建、读取、更新、删除plb文件，以及自动创建默认plb文件。

## 功能特性

- **自动初始化**：首次使用时自动创建`default.plb`
- **JSON存储**：所有数据以JSON格式存储在`${getApplicationDocumentsDirectory()}/plb`目录下
- **单例模式**：使用单例模式确保全局唯一实例
- **数据模型**：提供`PlbData`类封装plb数据结构
- **完整CRUD**：支持创建、读取、更新、删除操作

## 使用方法

### 1. 基本初始化

```dart
import 'package:ai_sound_agent/services/plb_manager.dart';

final plbManager = PlbManager();

// 初始化（会自动创建default.plb如果不存在）
await plbManager.initialize();
```

### 2. 获取默认plb数据

```dart
// 获取默认plb
final defaultPlb = await plbManager.getDefaultPlb();

// 修改默认plb数据
final updatedData = defaultPlb!.copyWith(
  data: {
    ...defaultPlb.data,
    'newSetting': 'newValue',
  },
);
await plbManager.saveDefaultPlb(updatedData);

// 重置默认plb到初始状态
await plbManager.resetDefaultPlb();
```

### 3. 创建自定义plb文件

```dart
final customPlb = PlbData(
  name: 'my_config',
  data: {
    'theme': 'dark',
    'language': 'en-US',
    'customSettings': {
      'setting1': 'value1',
      'setting2': 123,
    },
  },
);

await plbManager.createPlb('custom.plb', customPlb);
```

### 4. 加载plb文件

```dart
final loadedPlb = await plbManager.loadPlb('custom.plb');
if (loadedPlb != null) {
  print('Loaded PLB: ${loadedPlb.name}');
  print('Data: ${loadedPlb.data}');
}
```

### 5. 管理plb文件

```dart
// 列出所有plb文件
final files = await plbManager.listPlbFiles();
print('Available PLB files: $files');

// 检查文件是否存在
final exists = await plbManager.plbExists('custom.plb');

// 删除plb文件
await plbManager.deletePlb('custom.plb');
```

## 默认数据结构

`default.plb`包含以下默认结构：

```json
{
  "name": "default",
  "data": {
    "version": "1.0.0",
    "settings": {
      "theme": "light",
      "language": "zh-CN",
      "audio": {
        "input_device": "default",
        "output_device": "default",
        "volume": 0.8,
        "sample_rate": 16000
      },
      "ai": {
        "provider": "openai",
        "model": "gpt-3.5-turbo",
        "max_tokens": 1000,
        "temperature": 0.7
      }
    },
    "shortcuts": [
      {
        "name": "快速录音",
        "key": "Ctrl+Space",
        "action": "start_recording"
      },
      {
        "name": "停止录音",
        "key": "Ctrl+S",
        "action": "stop_recording"
      }
    ],
    "history": []
  },
  "createdAt": "2024-01-01T00:00:00.000Z",
  "updatedAt": "2024-01-01T00:00:00.000Z"
}
```

## 存储位置

所有plb文件存储在：
- **Windows**: `C:\Users\[用户名]\AppData\Roaming\[应用名]\plb\`
- **macOS**: `~/Library/Application Support/[应用名]/plb/`
- **Linux**: `~/.local/share/[应用名]/plb/`
- **Android**: `/data/user/0/[包名]/app_flutter/plb/`
- **iOS**: `Documents/plb/`

## 示例代码

参考 `lib/examples/plb_manager_example.dart` 文件获取完整的使用示例。

## 测试

运行单元测试：
```bash
flutter test test/plb_manager_test.dart
```

## 注意事项

1. **初始化顺序**：在使用任何plb操作前，确保先调用`initialize()`
2. **异常处理**：所有方法都可能抛出异常，建议添加适当的错误处理
3. **文件命名**：plb文件名应该包含`.plb`后缀
4. **单例使用**：使用`PlbManager()`获取单例实例，不要创建多个实例