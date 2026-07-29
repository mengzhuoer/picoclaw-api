# 🏠 智能家居集成指南

## 支持的平台

| 平台 | 协议 | 难度 | 推荐度 |
|------|------|------|--------|
| Home Assistant | REST API / WebSocket | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| MQTT | MQTT Broker | ⭐ | ⭐⭐⭐⭐ |
| Node-RED | HTTP / MQTT | ⭐⭐ | ⭐⭐⭐ |

---

## Home Assistant 集成

### 前置条件

1. 已有 Home Assistant 实例运行
2. 已创建长期访问令牌 (Long-Lived Access Token)

### 获取 HA Token

1. 打开 HA → 用户资料 → 长期访问令牌
2. 点击「创建令牌」
3. 复制令牌 (只显示一次!)

### 配置 PicoClaw

```bash
sudo nano /etc/picoclaw/config.yaml
```

```yaml
smart_home:
  enabled: true
  home_assistant:
    url: "http://homeassistant.local:8123"
    token: "eyJ0eXAiOiJKV1QiLCJhbGciOi..."  # 你的 HA 令牌
```

### 测试连接

```bash
# 在浏览器中测试
curl -X GET \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  http://homeassistant.local:8123/api/

# 查看所有实体
curl -X GET \
  -H "Authorization: Bearer YOUR_TOKEN" \
  http://homeassistant.local:8123/api/states
```

### 语音控制示例

配置完成后，你可以说:

- "嘿龙虾，打开客厅灯"
- "嘿龙虾，把空调调到 26 度"
- "嘿龙虾，现在家里多少度？"

---

## MQTT 集成

### 安装 Mosquitto Broker

```bash
# 在树莓派上安装 MQTT Broker
sudo apt install mosquitto mosquitto-clients

# 配置
sudo nano /etc/mosquitto/conf.d/default.conf
```

```conf
# /etc/mosquitto/conf.d/default.conf
listener 1883
allow_anonymous true

# 如果需要认证:
# allow_anonymous false
# password_file /etc/mosquitto/passwd
```

```bash
# 设置密码 (可选)
sudo mosquitto_passwd -c /etc/mosquitto/passwd lobster

# 重启
sudo systemctl restart mosquitto
```

### 配置 PicoClaw 使用 MQTT

```yaml
smart_home:
  enabled: true
  mqtt:
    broker: "localhost"
    port: 1883
    username: "lobster"
    password: "your_password"
    topics:
      command: "home/command"
      state: "home/state"
```

### MQTT 测试

```bash
# 订阅主题
mosquitto_sub -h localhost -t "home/command" -v

# 发布消息
mosquitto_pub -h localhost -t "home/command" -m '{"device":"light","action":"on"}'
```

---

## 常用智能家居命令

### 通过 AI 助手控制

配置完成后，在 Web 面板或语音中说:

| 命令 | 说明 |
|------|------|
| "打开/关闭 XX" | 开关灯/电器 |
| "把 XX 调到 XX" | 调节温度/亮度/音量 |
| "当前 XX 状态" | 查询传感器数据 |
| "执行 XX 场景" | 触发 HA 场景 |

### 通过 API 控制 (OpenClaw Agent)

```python
# Agent 工具调用示例
{
  "tool": "smart_home.control",
  "params": {
    "entity_id": "light.living_room",
    "action": "turn_on",
    "brightness": 200
  }
}
```

---

## 高级：自定义 Agent 工具

### 创建自定义工具

```python
# /opt/openclaw/plugins/light_control.py
from openclaw.tools import tool

@tool(
    name="control_light",
    description="控制灯光开关和亮度"
)
def control_light(entity_id: str, action: str, brightness: int = None):
    """控制智能家居灯光"""
    # 调用 HA API
    url = f"http://homeassistant.local:8123/api/services/light/{action}"
    headers = {"Authorization": "Bearer YOUR_TOKEN"}
    data = {"entity_id": entity_id}
    if brightness:
        data["brightness"] = brightness
    
    response = requests.post(url, headers=headers, json=data)
    return response.json()
```

---

## 故障排除

### HA 连接失败

```bash
# 检查 HA 是否运行
curl -s http://homeassistant.local:8123/api/ | jq '.message'

# 检查网络
ping homeassistant.local

# 检查令牌
curl -H "Authorization: Bearer TOKEN" \
  http://homeassistant.local:8123/api/config
```

### MQTT 连接失败

```bash
# 检查 Mosquitto 状态
sudo systemctl status mosquitto

# 查看日志
sudo journalctl -u mosquitto -f

# 测试连接
mosquitto_sub -h localhost -t "#" -v
```

### 语音命令无响应

```bash
# 检查 PicoClaw 日志
sudo journalctl -u picoclaw -f

# 检查 wake word 引擎
# 确认麦克风工作正常
arecord -d 5 test.wav && aplay test.wav
```
