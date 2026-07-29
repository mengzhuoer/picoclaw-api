# 🎤 语音功能配置指南

## 硬件准备

### 麦克风选择

| 类型 | 推荐产品 | 价格 | 音质 | 难度 |
|------|---------|------|------|------|
| USB 麦克风 | Blue Snowball / 博雅 | ¥100-300 | ⭐⭐⭐⭐ | ⭐ 即插即用 |
| USB 声卡 + 3.5mm | 免驱 USB 声卡 | ¥15-30 | ⭐⭐⭐ | ⭐ 即插即用 |
| ReSpeaker 2-Mic | Seeed 官方 | ¥150 | ⭐⭐⭐⭐⭐ | ⭐⭐ 需驱动 |
| ReSpeaker 4-Mic Array | Seeed 官方 | ¥350 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ 需配置 |

### 推荐方案 (树莓派4)

**入门**: USB 麦克风 (即插即用)
**进阶**: ReSpeaker 2-Mic HAT (远场拾音)

---

## 软件配置

### 1. 检测设备

```bash
# 查看音频输入设备
arecord -l

# 查看音频输出设备
aplay -l

# 测试录音 (5秒)
arecord -d 5 -f cd test.wav

# 测试播放
aplay test.wav
```

### 2. 配置 ALSA

```bash
# 查看当前配置
cat /etc/asound.conf

# 设置默认麦克风
sudo nano /etc/asound.conf
```

```conf
# /etc/asound.conf
pcm.!default {
    type asym
    playback.pcm "hw:0,0"
    capture.pcm "hw:1,0"
}
```

### 3. 安装语音依赖

```bash
# 语音识别 (Whisper)
pip install faster-whisper

# 语音合成
pip install pyttsx3

# 音频处理
pip install pyaudio
sudo apt install portaudio19-dev
```

### 4. 配置 PicoClaw 语音

```bash
sudo nano /etc/picoclaw/config.yaml
```

```yaml
voice:
  enabled: true
  wake_word: "hey lobster"        # 唤醒词
  stt_engine: whisper             # whisper / google
  tts_engine: pyttsx3             # pyttsx3 / espeak
  microphone_device: "hw:1,0"     # 根据 arecord -l 结果填写
  speaker_device: "hw:0,0"
  language: zh-CN                 # 识别语言
```

---

## 唤醒词配置

### 使用 Porcupine (推荐)

```bash
pip install pvporcupine pvorcupine
```

```yaml
voice:
  wake_word_engine: porcupine
  wake_word: "hey lobster"
  # 自定义唤醒词需要在 https://picovoice.ai/console/ 训练
```

### 使用 Snowboy (备选)

```bash
pip install snowboy
```

---

## 语音合成 (TTS) 选项

### pyttsx3 (离线，质量一般)

```yaml
voice:
  tts_engine: pyttsx3
```

### espeak (离线，多语言)

```bash
sudo apt install espeak
```

```yaml
voice:
  tts_engine: espeak
  tts_language: zh
```

### Edge-TTS (在线，质量高)

```bash
pip install edge-tts
```

```yaml
voice:
  tts_engine: edge-tts
  tts_voice: zh-CN-XiaoxiaoNeural
```

---

## 故障排除

### 麦克风无输入

```bash
# 检查设备
arecord -l

# 调整音量
alsamixer
# 按 F6 选择声卡，调整 Mic 音量

# 测试
arecord -d 5 test.wav && aplay test.wav
```

### 录音噪音大

```bash
# 使用 sox 降噪
sox test.wav noisered.wav noiseprof 0.21
sox test.wav clean.wav noisered.wav 0.21
```

### 语音识别不准确

```bash
# 使用更大的 Whisper 模型
# 编辑配置:
voice:
  stt_model: small  # base / small / medium
```

---

## 性能参考

| Whisper 模型 | 内存 | 速度 (RPi4) | 中文准确率 |
|-------------|------|------------|-----------|
| tiny | 300MB | 2x 实时 | 70% |
| base | 500MB | 1x 实时 | 80% |
| small | 1GB | 0.5x 实时 | 90% |
| medium | 3GB | 0.2x 实时 | 95% |

> **推荐**: 树莓派4 使用 `base` 或 `small` 模型
