/**
 * 🦞 PicoClaw API — Command Palette Style
 * Ctrl+K 呼出提供商切换面板，类似 cc switch
 */

// ═══════════════════════════════════════════════════
// 状态
// ═══════════════════════════════════════════════════

let allProviders = [];
let cloudProviders = {};
let localModels = [];
let activeProviderId = null;
let chatHistory = [];

// 切换面板状态
let switcherOpen = false;
let selectedIndex = 0;
let filteredItems = [];

const $ = (s) => document.querySelector(s);

// ═══════════════════════════════════════════════════
// API
// ═══════════════════════════════════════════════════

async function api(path, opts = {}) {
  const r = await fetch(path, {
    headers: { "Content-Type": "application/json" },
    ...opts,
  });
  const data = await r.json();
  if (!r.ok) throw new Error(data.detail || "请求失败");
  return data;
}

async function loadStatus() {
  return await api("/api/status");
}

async function switchProvider(id) {
  return await api("/api/providers/switch", {
    method: "POST",
    body: JSON.stringify({ provider_id: id }),
  });
}

async function saveConfig(providerId, model, apiKey) {
  return await api("/api/providers/config", {
    method: "POST",
    body: JSON.stringify({ provider_id: providerId, model, api_key: apiKey }),
  });
}

async function removeProvider(id) {
  return await api("/api/providers/remove", {
    method: "POST",
    body: JSON.stringify({ provider_id: id }),
  });
}

async function sendChat(messages) {
  return await api("/api/chat", {
    method: "POST",
    body: JSON.stringify({
      messages,
      temperature: 0.7,
      max_tokens: 2048,
    }),
  });
}

// ═══════════════════════════════════════════════════
// 触发器栏
// ═══════════════════════════════════════════════════

function renderTrigger() {
  const active = allProviders.find((p) => p.id === activeProviderId);

  if (active && active.health?.healthy) {
    $("#trigger-icon").textContent = active.icon;
    $("#trigger-name").textContent = active.name;
    $("#trigger-model").textContent = active.model || "";
    $("#health-dot").className = "dot dot-ok";
  } else if (active) {
    $("#trigger-icon").textContent = active.icon;
    $("#trigger-name").textContent = active.name;
    $("#trigger-model").textContent = "点击配置";
    $("#health-dot").className = "dot dot-loading";
  } else {
    $("#trigger-icon").textContent = "🔮";
    $("#trigger-name").textContent = "选择提供商...";
    $("#trigger-model").textContent = "";
    $("#health-dot").className = "dot dot-err";
  }

  // 聊天框状态
  const ready = active?.health?.healthy;
  $("#chat-input").disabled = !ready;
  $("#chat-send").disabled = !ready;
  if (ready) $("#chat-input").focus();
}

// ═══════════════════════════════════════════════════
// 切换面板 (Command Palette)
// ═══════════════════════════════════════════════════

function openSwitcher() {
  switcherOpen = true;
  selectedIndex = 0;
  $("#switcher-input").value = "";
  $("#switcher-overlay").classList.remove("hidden");
  $("#switcher-input").focus();
  renderSwitcherList();
}

function closeSwitcher() {
  switcherOpen = false;
  $("#switcher-overlay").classList.add("hidden");
}

function closeSwitcherOutside(e) {
  if (e.target.id === "switcher-overlay") closeSwitcher();
}

function renderSwitcherList() {
  const query = $("#switcher-input").value.toLowerCase().trim();
  const list = $("#switcher-list");

  // 构建可选项
  const items = [];

  // 本地提供商
  const localProviders = allProviders.filter((p) => p.type === "local");
  localProviders.forEach((p) => items.push({ ...p, group: "local" }));

  // 已配置的云端提供商
  const configuredCloud = allProviders.filter((p) => p.type === "cloud");
  configuredCloud.forEach((p) => items.push({ ...p, group: "cloud" }));

  // 可添加的云端提供商
  const configuredIds = new Set(configuredCloud.map((p) => p.id));
  Object.entries(cloudProviders).forEach(([id, cfg]) => {
    if (!configuredIds.has(id)) {
      items.push({
        id,
        name: cfg.name,
        icon: cfg.icon,
        description: cfg.description,
        models: cfg.models,
        website: cfg.website,
        group: "add",
        type: "cloud",
      });
    }
  });

  // 过滤
  filteredItems = query
    ? items.filter(
        (p) =>
          p.name.toLowerCase().includes(query) ||
          p.id.toLowerCase().includes(query) ||
          (p.model || "").toLowerCase().includes(query) ||
          (p.description || "").toLowerCase().includes(query)
      )
    : items;

  // 渲染
  if (filteredItems.length === 0) {
    list.innerHTML = `<div style="padding:20px;text-align:center;color:var(--text-dim);font-size:0.85rem">没有找到匹配的提供商</div>`;
    return;
  }

  let html = "";
  let currentGroup = "";

  const groupTitles = {
    local: "🏠 本地推理",
    cloud: "☁️ 云端 API",
    add: "➕ 添加提供商",
  };

  filteredItems.forEach((item, i) => {
    if (item.group !== currentGroup) {
      currentGroup = item.group;
      html += `<div class="switcher-group-title">${groupTitles[currentGroup] || ""}</div>`;
    }

    const isActive = item.id === activeProviderId;
    const isSelected = i === selectedIndex;

    let badge = "";
    if (item.group === "add") {
      badge = `<span class="badge badge-add">添加</span>`;
    } else if (isActive) {
      badge = `<span class="badge badge-active">当前</span>`} else if (item.type === "cloud" && !item.has_api_key) {
      badge = `<span class="badge badge-need-key">需 Key</span>`;
    } else if (item.health?.healthy) {
      badge = `<span class="badge badge-active">就绪</span>`;
    }

    html += `
      <div class="switcher-item${isActive ? " active" : ""}${isSelected ? " selected" : ""}"
           data-index="${i}" onclick="handleSelect(${i})">
        <div class="icon">${item.icon}</div>
        <div class="info">
          <div class="name">${item.name}</div>
          <div class="meta">${
            item.group === "add"
              ? `🔗 ${item.website}`
              : item.model || item.description || "未配置"
          }</div>
        </div>
        ${badge}
      </div>`;
  });

  list.innerHTML = html;
}

async function handleSelect(index) {
  const item = filteredItems[index];
  if (!item) return;

  // 需要添加的云端提供商 → 打开配置弹窗
  if (item.group === "add") {
    closeSwitcher();
    showConfigModal(item.id, true);
    return;
  }

  // 云端提供商但没有 API Key → 打开配置弹窗
  if (item.type === "cloud" && !item.has_api_key) {
    closeSwitcher();
    showConfigModal(item.id, false);
    return;
  }

  // 本地提供商但没有模型 → 打开配置弹窗
  if (item.id === "local_llama" && !item.model) {
    closeSwitcher();
    showConfigModal(item.id, false);
    return;
  }

  // 直接切换
  closeSwitcher();
  doSwitch(item.id);
}

async function doSwitch(id) {
  try {
    const r = await switchProvider(id);
    showToast(r.message, "success");
  } catch (e) {
    showToast(e.message, "error");
  }
  await refresh();
}

// ═══════════════════════════════════════════════════
// 配置弹窗
// ═══════════════════════════════════════════════════

function showConfigModal(providerId, isNew) {
  const cfg = cloudProviders[providerId];
  const existing = allProviders.find((p) => p.id === providerId);

  if (providerId === "local_llama") {
    // 本地模型选择
    const models = localModels
      .map(
        (m) =>
          `<option value="${m.name}"${existing?.model === m.name ? "selected" : ""}>${m.name} (${m.size_human})</option>`
      )
      .join("");

    $("#config-title").textContent = "🏠 选择本地模型";
    $("#config-body").innerHTML = `
      <div class="form-group">
        <label>模型文件</label>
        <select id="cfg-model">${models}</select>
        ${
          !localModels.length
            ? '<div class="hint">没有可用模型。下载 GGUF 文件到 /var/lib/picoclaw/models/</div>'
            : ""
        }
      </div>
      <button class="btn-primary" onclick="submitConfig('${providerId}')">加载模型</button>
    `;
  } else if (cfg) {
    // 云端提供商配置
    const models = cfg.models
      .map((m) => `<option value="${m}">${m}</option>`)
      .join("");

    $("#config-title").textContent = `${cfg.icon} ${isNew ? "添加" : "配置"} ${cfg.name}`;
    $("#config-body").innerHTML = `
      <div class="form-group">
        <label>API Key</label>
        <input type="password" id="cfg-api-key" placeholder="输入 API Key...">
        <div class="hint">
          在 <a href="${cfg.website}" target="_blank" style="color:var(--blue)">${cfg.website}</a> 免费申请
        </div>
      </div>
      <div class="form-group">
        <label>模型</label>
        <select id="cfg-model">${models}</select>
      </div>
      <button class="btn-primary" onclick="submitConfig('${providerId}')">${
      isNew ? "保存并切换" : "保存"
    }</button>
      ${!isNew ? `<button class="btn-danger" onclick="handleRemove('${providerId}')">移除</button>` : ""}
    `;
  }

  $("#config-modal").classList.remove("hidden");
}

function closeConfig() {
  $("#config-modal").classList.add("hidden");
}

async function submitConfig(providerId) {
  const apiKey = $("#cfg-api-key")?.value.trim() || "";
  const model = $("#cfg-model")?.value || "";

  if (!model) return showToast("请选择模型", "error");

  try {
    await saveConfig(providerId, model, apiKey);
    closeConfig();
    showToast("配置已保存", "success");
    // 如果是新添加的，自动切换
    await doSwitch(providerId);
  } catch (e) {
    showToast(e.message, "error");
  }
}

async function handleRemove(providerId) {
  if (!confirm("确定移除此提供商？")) return;
  try {
    await removeProvider(providerId);
    closeConfig();
    showToast("已移除", "success");
    await refresh();
  } catch (e) {
    showToast(e.message, "error");
  }
}

// ═══════════════════════════════════════════════════
// 对话
// ═══════════════════════════════════════════════════

async function handleChat(e) {
  e.preventDefault();
  const text = $("#chat-input").value.trim();
  if (!text) return;

  addMsg("user", text);
  $("#chat-input").value = "";
  chatHistory.push({ role: "user", content: text });

  const waiting = document.createElement("div");
  waiting.className = "chat-msg msg-assistant";
  waiting.textContent = "思考中...";
  $("#chat-box").appendChild(waiting);
  scrollChat();

  try {
    const r = await sendChat(chatHistory);
    waiting.remove();
    addMsg("assistant", r.reply);
    chatHistory.push({ role: "assistant", content: r.reply });
  } catch (e) {
    waiting.remove();
    addMsg("error", `错误: ${e.message}`);
  }
}

function addMsg(type, text) {
  const div = document.createElement("div");
  div.className = `chat-msg msg-${type}`;
  div.textContent = text;
  $("#chat-box").appendChild(div);
  scrollChat();
}

function scrollChat() {
  const box = $("#chat-box");
  box.scrollTop = box.scrollHeight;
}

// ═══════════════════════════════════════════════════
// API 文档 Drawer
// ═══════════════════════════════════════════════════

function openDrawer() {
  $("#api-drawer").classList.remove("hidden");
}

function closeDrawer() {
  $("#api-drawer").classList.add("hidden");
}

// ═══════════════════════════════════════════════════
// Toast
// ═══════════════════════════════════════════════════

function showToast(msg, type = "") {
  const t = $("#toast");
  t.textContent = msg;
  t.className = `toast ${type}`;
  setTimeout(() => t.classList.add("hidden"), 2500);
}

// ═══════════════════════════════════════════════════
// 刷新 & 轮询
// ═══════════════════════════════════════════════════

async function refresh() {
  try {
    const status = await loadStatus();
    allProviders = status.providers || [];
    localModels = status.local_models || [];
    activeProviderId = status.active_provider;
    renderTrigger();
    if (switcherOpen) renderSwitcherList();
  } catch (e) {
    console.error("刷新失败:", e);
  }
}

// ═══════════════════════════════════════════════════
// 键盘快捷键
// ═══════════════════════════════════════════════════

document.addEventListener("keydown", (e) => {
  // Ctrl+K / Cmd+K → 打开切换面板
  if ((e.ctrlKey || e.metaKey) && e.key === "k") {
    e.preventDefault();
    if (!switcherOpen) openSwitcher();
    return;
  }

  if (!switcherOpen) return;

  switch (e.key) {
    case "Escape":
      e.preventDefault();
      closeSwitcher();
      break;
    case "ArrowDown":
      e.preventDefault();
      selectedIndex = Math.min(selectedIndex + 1, filteredItems.length - 1);
      renderSwitcherList();
      scrollSelectedIntoView();
      break;
    case "ArrowUp":
      e.preventDefault();
      selectedIndex = Math.max(selectedIndex - 1, 0);
      renderSwitcherList();
      scrollSelectedIntoView();
      break;
    case "Enter":
      e.preventDefault();
      handleSelect(selectedIndex);
      break;
  }
});

function scrollSelectedIntoView() {
  const el = $("#switcher-list .switcher-item.selected");
  if (el) el.scrollIntoView({ block: "nearest" });
}

// 搜索框输入
$("#switcher-input")?.addEventListener("input", () => {
  selectedIndex = 0;
  renderSwitcherList();
});

// ═══════════════════════════════════════════════════
// 初始化
// ═══════════════════════════════════════════════════

async function init() {
  $("#chat-form").addEventListener("submit", handleChat);
  $("#config-modal").addEventListener("click", (e) => {
    if (e.target.id === "config-modal") closeConfig();
  });

  // 加载云端提供商列表
  try {
    cloudProviders = await api("/api/providers/cloud");
  } catch (e) {
    console.error("加载云端提供商失败:", e);
  }

  // 首次加载
  await refresh();

  // 轮询
  setInterval(refresh, 5000);
}

init();
