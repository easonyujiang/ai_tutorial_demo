# AI Tutorial Backend API 文档（前端参考）

## 基础信息

- **Base URL**: `http://{host}:8000/api/v1/tutorial`
- **Content-Type**: `application/json`
- **响应格式**: 统一 JSON。成功时直接返回数据，失败时返回 `{ "detail": "错误描述" }`

---

## 一、接口总览

```
POST   /create              → 提交视频链接，后台分析
GET    /{session_id}/status → 轮询教程状态
GET    /{session_id}/steps  → 获取所有步骤

POST   /{session_id}/execute    → 开始/继续执行当前步骤
POST   /{session_id}/screenshot → 上传截图，OCR 返回高亮坐标
POST   /{session_id}/confirm    → 确认步骤完成
POST   /{session_id}/skip       → 跳过当前步骤
DELETE /{session_id}        → 取消会话
```

---

## 二、交互流程

```
1. POST /create → 得到 session_id
2. 轮询 GET /{id}/status → 等到 status == "ready"
3. POST /{id}/execute → 拿到当前步骤的引导信息
4. 前端引导用户到对应页面 → 截图
5. POST /{id}/screenshot → 得到 OCR 识别结果（坐标）
6. 前端高亮目标区域 → 用户点击
7. POST /{id}/confirm → 确认完成
8. 重复 3-7 直到 execute 返回 completed: true
```

---

## 三、接口详情

### 1. POST /create — 创建教程

提交视频链接，后台异步下载 + AI 分析。

**Request**

```json
{
  "url": "https://v.douyin.com/xxxxx/"
}
```

**Response** `202 Accepted`

```json
{
  "session_id": "a1b2c3d4e5f67890abcd",
  "status": "processing",
  "message": "视频下载中，请稍候..."
}
```

**说明**：返回 202 后，后台异步执行下载→AI分析。前端需轮询 `/status` 等待完成。

---

### 2. GET /{session_id}/status — 查询状态

**Response** `200 OK`

```json
{
  "session_id": "a1b2c3d4e5f67890abcd",
  "status": "ready",
  "title": "小米手机去广告教程",
  "total_steps": 5,
  "current_step": 0,
  "steps": [
    {
      "index": 0,
      "instruction": "进入设置页面，点击'设置'图标",
      "target_text": "设置",
      "page_description": "手机桌面主屏幕",
      "status": "pending"
    },
    {
      "index": 1,
      "instruction": "选择'账号管理'选项",
      "target_text": "账号管理",
      "page_description": "设置页面",
      "status": "pending"
    }
  ]
}
```

**status 枚举**：

| 值 | 含义 | 前端行为 |
|----|------|---------|
| `processing` | 后台分析中 | 继续轮询（建议 2 秒间隔） |
| `ready` | 分析完毕 | 可以调用 `/execute` 开始 |
| `in_progress` | 逐步执行中 | 继续当前流程 |
| `completed` | 全部完成 | 展示结束页 |
| `error` | 异常终止 | 展示错误信息 |

---

### 3. GET /{session_id}/steps — 获取所有步骤

**Response** `200 OK`

```json
{
  "session_id": "a1b2c3d4e5f67890abcd",
  "title": "小米手机去广告教程",
  "steps": [
    {
      "index": 0,
      "instruction": "进入设置页面，点击'设置'图标",
      "target_text": "设置",
      "page_description": "手机桌面主屏幕",
      "status": "pending"
    }
  ]
}
```

**步骤字段说明**：

| 字段 | 说明 | 前端用法 |
|------|------|---------|
| `index` | 步骤编号（从 0 开始） | 显示 "步骤 1/5" |
| `instruction` | 操作说明文字 | 展示给用户 |
| `target_text` | 需要查找的目标文字 | 传给 `/screenshot` 做 OCR 匹配 |
| `page_description` | 所在页面描述 | 提示用户当前应该在哪个页面 |
| `status` | 步骤状态 | `pending` → `active` → `completed` / `skipped` |

---

### 4. POST /{session_id}/execute — 执行当前步骤

**Request**：无 body

**Response** `200 OK`

```json
// 正常步骤
{
  "completed": false,
  "step_index": 0,
  "total_steps": 5,
  "instruction": "进入设置页面，点击'设置'图标",
  "target_text": "设置",
  "page_description": "手机桌面主屏幕"
}

// 全部完成
{
  "completed": true,
  "step_index": -1,
  "total_steps": 0,
  "instruction": "",
  "target_text": "",
  "page_description": ""
}
```

**说明**：
- `completed: false` → 前端展示 instruction，引导用户截屏
- `completed: true` → 教程结束，展示完成页
- 调用后 session 状态自动变为 `in_progress`

---

### 5. POST /{session_id}/screenshot — 上传截图做 OCR

**Request**

```json
{
  "step_index": 0,
  "image_base64": "iVBORw0KGgoAAAANSUhEUgAA...",
  "screen_width": 1080,
  "screen_height": 2340
}
```

| 字段 | 说明 |
|------|------|
| `step_index` | 当前步骤编号（与 execute 返回的一致） |
| `image_base64` | 截图的 Base64 编码字符串（不含 data:image 前缀） |
| `screen_width` | 设备屏幕宽度（像素） |
| `screen_height` | 设备屏幕高度（像素） |

**Response** `200 OK`

```json
// 找到目标
{
  "step_index": 0,
  "found": true,
  "target_text": "设置",
  "bboxes": [
    {
      "text": "设置",
      "confidence": 0.95,
      "rect": {
        "left": 320.0,
        "top": 180.0,
        "width": 120.0,
        "height": 90.0
      }
    }
  ],
  "all_texts": [
    { "text": "时钟", "confidence": 0.92, "rect": {...} },
    { "text": "设置", "confidence": 0.95, "rect": {...} },
    { "text": "相册", "confidence": 0.88, "rect": {...} }
  ],
  "suggestion": ""
}

// 未找到目标
{
  "step_index": 0,
  "found": false,
  "target_text": "设置",
  "bboxes": [],
  "all_texts": [...],
  "suggestion": "未找到目标文字，请确认当前页面是否正确"
}
```

**坐标说明**：`left/top/width/height` 为**绝对像素值**，与截图像素一一对应。前端直接用这些坐标高亮。

**多匹配处理**：`bboxes` 可能返回多个匹配（页面中有多处相同文字），按 `confidence` 降序排列。建议优先使用第一个。

---

### 6. POST /{session_id}/confirm — 确认步骤完成

**Request**

```json
{
  "step_index": 0
}
```

**Response** `200 OK`

```json
{
  "ok": true,
  "next_step": 1
}
```

调用后自动推进到下一步。前端接着调 `/execute` 获取下一步信息。

---

### 7. POST /{session_id}/skip — 跳过当前步骤

**Request**

```json
{
  "step_index": 0,
  "reason": "目标按钮在当前页面不可见"
}
```

| 字段 | 说明 |
|------|------|
| `step_index` | 当前步骤编号 |
| `reason` | 跳过原因（可选） |

**Response** `200 OK`

```json
{
  "ok": true,
  "next_step": 1
}
```

---

### 8. DELETE /{session_id} — 取消会话

**Response** `200 OK`

```json
{
  "ok": true
}
```

---

## 四、错误码速查

| HTTP 状态 | 含义 | 示例 detail |
|-----------|------|------------|
| `400` | 参数校验失败 | `"请输入视频链接"` / `"步骤索引 0 超出范围"` |
| `404` | 会话不存在 | `"会话不存在"` |
| `500` | 服务端异常 | `"视频下载失败：ERROR: ..."` |

---

## 五、Flutter 调用示例（参考）

```dart
final base = 'http://192.168.1.100:8000/api/v1/tutorial';

// 1. 创建教程
final createRes = await http.post(
  Uri.parse('$base/create'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({'url': 'https://v.douyin.com/xxx'}),
);
final sessionId = jsonDecode(createRes.body)['session_id'];

// 2. 轮询状态
String status;
do {
  await Future.delayed(Duration(seconds: 2));
  final res = await http.get(Uri.parse('$base/$sessionId/status'));
  status = jsonDecode(res.body)['status'];
} while (status == 'processing');

// 3. 逐步执行
while (true) {
  // 获取当前步骤
  final execRes = await http.post(Uri.parse('$base/$sessionId/execute'));
  final execData = jsonDecode(execRes.body);
  if (execData['completed']) break;

  final stepIndex = execData['step_index'];
  final targetText = execData['target_text'];

  // TODO: 前端引导用户跳转页面
  // ...

  // 4. 截图并上传
  final screenshotBase64 = await captureScreen(); // 你的截图方法
  final ocrRes = await http.post(
    Uri.parse('$base/$sessionId/screenshot'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'step_index': stepIndex,
      'image_base64': screenshotBase64,
      'screen_width': 1080,
      'screen_height': 2340,
    }),
  );
  final ocrData = jsonDecode(ocrRes.body);
  if (ocrData['found']) {
    final bbox = ocrData['bboxes'][0]['rect'];
    // TODO: 用 bbox.left, bbox.top, bbox.width, bbox.height 高亮区域
  }

  // 5. 确认完成
  await http.post(
    Uri.parse('$base/$sessionId/confirm'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'step_index': stepIndex}),
  );
}
```

---

## 六、注意事项

1. **轮询间隔**：`/status` 建议 2 秒，分析通常需要 10~30 秒
2. **Base64 格式**：原始编码字符串，**不要**加 `data:image/jpeg;base64,` 前缀
3. **坐标是像素值**：与截图尺寸一致，直接用
4. **多匹配时**：`bboxes` 可能有多项，按 confidence 排序，建议展示第一个或让用户选择
5. **OCR 可能找不到**：`found: false` 时提示用户确认页面或重试
6. **session 有时效**：30 分钟无操作自动过期
