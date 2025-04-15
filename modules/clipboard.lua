local config = {
    max_entries = 50,
    max_display = 10,
    historyFile = os.getenv("HOME") .. "/.hammerspoon/clipboard_history.json",
    clipboardHistory = {},
    paste_on_select = true,
    hotkey = { { "cmd", "shift" }, "v" },
    clipboard_check_interval = 0.5,
    excluded_apps = { "1Password" },
    play_sound = true,
    sound_name = "Tink",
}

-- 加载历史记录
local function loadHistory()
    local file = io.open(config.historyFile, "r")
    if file then
        local content = file:read("*a")
        file:close()
        local data = hs.json.decode(content)
        if data then
            config.clipboardHistory = data
        end
    end
end

-- 保存历史记录
local function saveHistory()
    local file = io.open(config.historyFile, "w")
    if file then
        file:write(hs.json.encode(config.clipboardHistory))
        file:close()
    end
end

loadHistory()

-- 监听剪贴板变化
local lastChange = hs.pasteboard.changeCount()
hs.timer.doEvery(config.clipboard_check_interval, function()
    local change = hs.pasteboard.changeCount()
    if change == lastChange then
        return
    end
    lastChange = change

    local content = hs.pasteboard.getContents()
    local image = hs.pasteboard.readImage()

    if not content and not image then
        return
    end

    local item = {}
    if image then
        item.type = "image"
        item.content = image
        item.preview = "[Image]"
    elseif content then
        item.type = "text"
        item.content = content
        item.preview = content:sub(1, 30) .. (#content > 30 and "..." or "")
    else
        return
    end

    local latest = config.clipboardHistory[1]
    if not latest or latest.content ~= item.content then
        table.insert(config.clipboardHistory, 1, item)
        if #config.clipboardHistory > config.max_entries then
            table.remove(config.clipboardHistory)
        end
        saveHistory()
        if config.play_sound then
            hs.sound.getByName(config.sound_name):play()
        end
    end
end)

local function escapeHTML(str)
    if not str then
        return ""
    end
    str = str:gsub("%%", "%%%%") -- 先转义百分号
    str = str:gsub("&", "&amp;")
    str = str:gsub("<", "&lt;")
    str = str:gsub(">", "&gt;")
    str = str:gsub('"', "&quot;")
    str = str:gsub("'", "&#39;")
    return str
end

-- UI 展示
local function showClipboardHistory()
    local webview = hs.webview
        .new({ x = 200, y = 200, w = 600, h = 500 })
        :windowStyle(hs.webview.windowMasks.titled + hs.webview.windowMasks.closable)

    -- 动态构建 HTML
    local html = [[
    <html><head><style>
    body { font-family: -apple-system; padding: 10px; background: #f9f9f9; }
    .item { padding: 10px; margin: 10px 0; background: #fff; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); cursor: pointer; }
    .item:hover { background: #e6f3ff; }
    img { max-width: 100%; max-height: 120px; border-radius: 6px; }
    .preview { font-size: 12px; color: #888; margin-top: 4px; }
    </style></head><body>%s</body>
    <script>
      function send(index) { window.location.href = "hammerspoon://select?index=" + index; }
    </script></html>
    ]]

    local contentHtml = ""
    for i, item in ipairs(config.clipboardHistory) do
        local block = ""
        if item.type == "text" then
            block = string.format(
                "<div class='item' onclick='send(%d)'>%s<div class='preview'>%s</div></div>",
                i - 1,
                escapeHTML(item.content),
                item.preview
            )
        elseif item.type == "image" then
            local base64 = hs.image.imageToBase64String(item.content, "PNG")
            block = string.format(
                "<div class='item' onclick='send(%d)'><img src='data:image/png;base64,%s'><div class='preview'>%s</div></div>",
                i - 1,
                base64,
                item.preview
            )
        end
        contentHtml = contentHtml .. block
    end

    webview:html(string.format(html, contentHtml))
    webview:show()

    -- 绑定事件响应
    hs.urlevent.bind("select", function(_, params)
        local index = tonumber(params.index)
        local item = config.clipboardHistory[index + 1]
        if item then
            if item.type == "text" then
                hs.pasteboard.setContents(item.content)
            elseif item.type == "image" then
                hs.pasteboard.writeImage(item.content)
            end
            if config.paste_on_select then
                hs.eventtap.keyStroke({ "cmd" }, "v")
            end
        end
        webview:hide()
        hs.urlevent.bind("select", nil) -- 清理绑定
    end)
end

-- 快捷键绑定
hs.hotkey.bind(config.hotkey[1], config.hotkey[2], showClipboardHistory)
