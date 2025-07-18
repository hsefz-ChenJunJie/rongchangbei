// 全局变量
let mediaRecorder;
let audioChunks = [];
let selectedSuggestionId = null;
let isRecording = false;

// API基础URL
const API_BASE_URL = 'http://localhost:8000';

// DOM元素
const elements = {
    // 步骤1
    scenarioContext: document.getElementById('scenarioContext'),
    permissionPanel: document.getElementById('permissionPanel'),
    recordingPanel: document.getElementById('recordingPanel'),
    requestPermissionBtn: document.getElementById('requestPermissionBtn'),
    recordBtn: document.getElementById('recordBtn'),
    stopRecordBtn: document.getElementById('stopRecordBtn'),
    recordingStatus: document.getElementById('recordingStatus'),
    audioText: document.getElementById('audioText'),
    
    // 步骤2
    userOpinion: document.getElementById('userOpinion'),
    generateBtn: document.getElementById('generateBtn'),
    generateLoading: document.getElementById('generateLoading'),
    
    // 步骤3
    suggestionsContainer: document.getElementById('suggestionsContainer'),
    modificationSuggestion: document.getElementById('modificationSuggestion'),
    regenerateBtn: document.getElementById('regenerateBtn'),
    
    // 步骤4
    finalText: document.getElementById('finalText'),
    speakBtn: document.getElementById('speakBtn'),
    copyBtn: document.getElementById('copyBtn'),
    audioControls: document.getElementById('audioControls'),
    audioPlayer: document.getElementById('audioPlayer'),
    outputArea: document.getElementById('outputArea')
};

// 初始化
document.addEventListener('DOMContentLoaded', function() {
    initializeEventListeners();
    checkMicrophonePermission();
});

// 事件监听器初始化
function initializeEventListeners() {
    // 录音相关
    elements.requestPermissionBtn.addEventListener('click', requestMicrophonePermission);
    elements.recordBtn.addEventListener('click', startRecording);
    elements.stopRecordBtn.addEventListener('click', stopRecording);
    
    // 生成建议
    elements.generateBtn.addEventListener('click', generateSuggestions);
    elements.regenerateBtn.addEventListener('click', regenerateSuggestions);
    
    // 输出相关
    elements.speakBtn.addEventListener('click', speakText);
    elements.copyBtn.addEventListener('click', copyText);
    
    // 文本变化监听
    elements.audioText.addEventListener('input', updateGenerateButtonState);
    elements.userOpinion.addEventListener('input', updateGenerateButtonState);
}

// 检查麦克风权限
async function checkMicrophonePermission() {
    try {
        // 首先检查权限状态（如果浏览器支持）
        if (navigator.permissions) {
            const permission = await navigator.permissions.query({ name: 'microphone' });
            
            switch (permission.state) {
                case 'granted':
                    await testMicrophoneAccess();
                    showPermissionGranted();
                    return;
                case 'denied':
                    showPermissionDenied();
                    return;
                case 'prompt':
                    showPermissionPrompt();
                    return;
            }
        }
        
        // 如果浏览器不支持权限查询，直接尝试获取权限
        await testMicrophoneAccess();
        showPermissionGranted();
        
    } catch (error) {
        console.log('权限检查失败:', error);
        showPermissionPrompt();
    }
}

// 测试麦克风访问
async function testMicrophoneAccess() {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    stream.getTracks().forEach(track => track.stop());
    return true;
}

// 申请麦克风权限
async function requestMicrophonePermission() {
    try {
        elements.requestPermissionBtn.disabled = true;
        elements.requestPermissionBtn.textContent = '🔄 申请中...';
        
        showStatus('正在申请麦克风权限，请在浏览器弹窗中选择"允许"', 'processing');
        
        // 尝试获取麦克风权限
        const stream = await navigator.mediaDevices.getUserMedia({ 
            audio: {
                sampleRate: 16000,
                channelCount: 1,
                echoCancellation: true,
                noiseSuppression: true
            }
        });
        
        // 立即停止流，我们只是为了获取权限
        stream.getTracks().forEach(track => track.stop());
        
        showPermissionGranted();
        showStatus('麦克风权限申请成功！现在可以开始录音了', 'success');
        
    } catch (error) {
        console.error('权限申请失败:', error);
        
        if (error.name === 'NotAllowedError') {
            showPermissionDenied();
            showStatus('麦克风权限被拒绝，请在浏览器设置中手动开启', 'error');
        } else if (error.name === 'NotFoundError') {
            showPermissionDenied();
            showStatus('未检测到麦克风设备，请检查设备连接', 'error');
        } else {
            showPermissionPrompt();
            showStatus('权限申请失败: ' + error.message, 'error');
        }
    } finally {
        elements.requestPermissionBtn.disabled = false;
        elements.requestPermissionBtn.textContent = '📋 申请录音权限';
    }
}

// 显示权限已授予状态
function showPermissionGranted() {
    elements.permissionPanel.style.display = 'none';
    elements.recordingPanel.style.display = 'block';
    elements.recordBtn.disabled = false;
    
    // 更新权限面板样式（如果显示的话）
    const permissionNotice = elements.permissionPanel.querySelector('.permission-notice');
    if (permissionNotice) {
        permissionNotice.className = 'permission-notice permission-granted';
        permissionNotice.innerHTML = `
            <h4>✅ 麦克风权限已获取</h4>
            <p>现在可以使用录音功能了！</p>
        `;
    }
}

// 显示权限被拒绝状态
function showPermissionDenied() {
    elements.permissionPanel.style.display = 'block';
    elements.recordingPanel.style.display = 'none';
    elements.recordBtn.disabled = true;
    
    const permissionNotice = elements.permissionPanel.querySelector('.permission-notice');
    permissionNotice.className = 'permission-notice permission-denied';
    permissionNotice.innerHTML = `
        <h4>❌ 麦克风权限被拒绝</h4>
        <p>录音功能需要麦克风权限。请按以下步骤手动开启：</p>
        <div class="help-text">
            <strong>Chrome/Edge浏览器：</strong><br>
            1. 点击地址栏左侧的锁图标或麦克风图标<br>
            2. 选择"始终允许此网站使用麦克风"<br>
            3. 刷新页面<br><br>
            <strong>Firefox浏览器：</strong><br>
            1. 点击地址栏左侧的盾牌图标<br>
            2. 在弹出菜单中允许麦克风权限<br>
            3. 刷新页面
        </div>
        <button id="retryPermissionBtn" class="btn">🔄 重新检查权限</button>
    `;
    
    // 添加重试按钮事件
    const retryBtn = document.getElementById('retryPermissionBtn');
    if (retryBtn) {
        retryBtn.addEventListener('click', checkMicrophonePermission);
    }
}

// 显示需要权限申请状态
function showPermissionPrompt() {
    elements.permissionPanel.style.display = 'block';
    elements.recordingPanel.style.display = 'none';
    elements.recordBtn.disabled = true;
    
    const permissionNotice = elements.permissionPanel.querySelector('.permission-notice');
    permissionNotice.className = 'permission-notice';
    permissionNotice.innerHTML = `
        <h4>🎤 需要麦克风权限</h4>
        <p>为了使用录音功能，需要获取您的麦克风权限。点击下面的按钮将弹出权限申请窗口。</p>
        <div class="help-text">
            <strong>温馨提示：</strong><br>
            • 我们只在录音时使用麦克风，不会在后台监听<br>
            • 录音数据仅用于语音识别，不会被保存或传输给第三方<br>
            • 您可以随时在浏览器设置中撤销权限
        </div>
        <button id="requestPermissionBtn" class="btn">📋 申请录音权限</button>
    `;
    
    // 重新绑定事件（因为元素被重新创建）
    const newRequestBtn = document.getElementById('requestPermissionBtn');
    if (newRequestBtn) {
        newRequestBtn.addEventListener('click', requestMicrophonePermission);
    }
}

// 开始录音
async function startRecording() {
    try {
        const stream = await navigator.mediaDevices.getUserMedia({ 
            audio: {
                sampleRate: 16000,
                channelCount: 1,
                echoCancellation: true,
                noiseSuppression: true
            }
        });
        
        mediaRecorder = new MediaRecorder(stream, {
            mimeType: 'audio/webm;codecs=opus'
        });
        
        audioChunks = [];
        
        mediaRecorder.ondataavailable = function(event) {
            if (event.data.size > 0) {
                audioChunks.push(event.data);
            }
        };
        
        mediaRecorder.onstop = function() {
            const audioBlob = new Blob(audioChunks, { type: 'audio/webm' });
            uploadAudio(audioBlob);
            stream.getTracks().forEach(track => track.stop());
        };
        
        mediaRecorder.start();
        isRecording = true;
        updateRecordingUI(true);
        showStatus('录音中... 请说话', 'recording');
        
    } catch (error) {
        console.error('录音失败:', error);
        showStatus('录音失败: ' + error.message, 'error');
    }
}

// 停止录音
function stopRecording() {
    if (mediaRecorder && isRecording) {
        mediaRecorder.stop();
        isRecording = false;
        updateRecordingUI(false);
        showStatus('录音已停止，正在处理...', 'processing');
    }
}

// 更新录音UI状态
function updateRecordingUI(recording) {
    elements.recordBtn.disabled = recording;
    elements.stopRecordBtn.disabled = !recording;
    
    if (recording) {
        elements.recordBtn.classList.add('recording');
        elements.recordBtn.textContent = '🎤 录音中...';
    } else {
        elements.recordBtn.classList.remove('recording');
        elements.recordBtn.textContent = '🎤 开始录音';
    }
}

// 上传音频并进行STT
async function uploadAudio(audioBlob) {
    try {
        const formData = new FormData();
        formData.append('audio', audioBlob, 'recording.webm');
        
        showStatus('正在识别语音...', 'processing');
        
        const response = await fetch(`${API_BASE_URL}/api/stt`, {
            method: 'POST',
            body: formData
        });
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        const result = await response.json();
        
        if (result.text) {
            elements.audioText.value = result.text;
            showStatus(`语音识别完成 (置信度: ${(result.confidence * 100).toFixed(1)}%)`, 'success');
            updateGenerateButtonState();
        } else {
            showStatus('语音识别结果为空，请重新录音', 'warning');
        }
        
    } catch (error) {
        console.error('STT失败:', error);
        showStatus('语音识别失败: ' + error.message, 'error');
    }
}

// 生成建议
async function generateSuggestions() {
    const request = {
        scenario_context: elements.scenarioContext.value.trim() || null,
        user_opinion: elements.userOpinion.value.trim() || null,
        target_dialogue: elements.audioText.value.trim() || null,
        suggestion_count: 3
    };
    
    if (!request.target_dialogue && !request.scenario_context && !request.user_opinion) {
        showStatus('请至少输入对话情景、录音文字或意见中的一项', 'warning');
        return;
    }
    
    try {
        elements.generateBtn.disabled = true;
        elements.generateLoading.style.display = 'inline-block';
        showStatus('正在生成建议...', 'processing');
        
        const result = await callGenerateSuggestionsAPI(request);
        if (result && result.suggestions) {
            displaySuggestions(result.suggestions);
            showStatus(`建议生成完成 (处理时间: ${result.processing_time?.toFixed(2)}s)`, 'success');
        }
        
    } catch (error) {
        console.error('生成建议失败:', error);
        showStatus('生成建议失败: ' + error.message, 'error');
    } finally {
        elements.generateBtn.disabled = false;
        elements.generateLoading.style.display = 'none';
    }
}

// 调用生成建议API（非流式响应）
async function callGenerateSuggestionsAPI(request) {
    try {
        const response = await fetch(`${API_BASE_URL}/api/generate_suggestions`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(request)
        });
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        elements.suggestionsContainer.innerHTML = '<p>正在生成建议...</p>';
        
        const result = await response.json();
        
        if (result.suggestions && result.suggestions.length > 0) {
            return result;
        } else {
            elements.suggestionsContainer.innerHTML = '<p style="color: #666;">未能生成有效建议，请检查输入内容</p>';
            return null;
        }
        
    } catch (error) {
        console.error('API调用失败:', error);
        elements.suggestionsContainer.innerHTML = '<p style="color: #e74c3c;">生成建议失败，请稍后重试</p>';
        throw error;
    }
}

// 显示建议列表
function displaySuggestions(suggestions) {
    if (!suggestions || suggestions.length === 0) {
        elements.suggestionsContainer.innerHTML = '<p style="color: #666;">暂无建议</p>';
        return;
    }
    
    let html = '<h4 style="margin-bottom: 15px; color: #333;">选择一个回答建议：</h4>';
    
    suggestions.forEach((suggestion, index) => {
        html += `
            <div class="suggestion-item" data-id="${suggestion.id || index}" onclick="selectSuggestion(${suggestion.id || index}, this)">
                <strong>建议 ${index + 1}:</strong>
                <p style="margin-top: 8px; line-height: 1.6;">${suggestion.content}</p>
                ${suggestion.confidence ? `<small style="color: #666;">置信度: ${(suggestion.confidence * 100).toFixed(1)}%</small>` : ''}
            </div>
        `;
    });
    
    elements.suggestionsContainer.innerHTML = html;
    elements.regenerateBtn.disabled = false;
}

// 选择建议
function selectSuggestion(id, element) {
    // 移除之前的选中状态
    document.querySelectorAll('.suggestion-item').forEach(item => {
        item.classList.remove('selected');
    });
    
    // 添加选中状态
    element.classList.add('selected');
    selectedSuggestionId = id;
    
    // 将选中的建议内容复制到最终文本框
    const contentElement = element.querySelector('p');
    if (contentElement) {
        elements.finalText.value = contentElement.textContent.trim();
        showStatus('已选择建议，您可以在下方进一步修改', 'success');
    }
}

// 重新生成建议
async function regenerateSuggestions() {
    const modificationText = elements.modificationSuggestion.value.trim();
    
    if (!modificationText) {
        showStatus('请输入修改意见后再重新生成', 'warning');
        return;
    }
    
    const request = {
        scenario_context: elements.scenarioContext.value.trim() || null,
        user_opinion: elements.userOpinion.value.trim() || null,
        target_dialogue: elements.audioText.value.trim() || null,
        modification_suggestion: [modificationText],
        suggestion_count: 3
    };
    
    try {
        elements.regenerateBtn.disabled = true;
        showStatus('正在重新生成建议...', 'processing');
        
        const result = await callGenerateSuggestionsAPI(request);
        if (result && result.suggestions) {
            displaySuggestions(result.suggestions);
            showStatus(`建议重新生成完成 (处理时间: ${result.processing_time?.toFixed(2)}s)`, 'success');
        }
        
    } catch (error) {
        console.error('重新生成失败:', error);
        showStatus('重新生成失败: ' + error.message, 'error');
    } finally {
        elements.regenerateBtn.disabled = false;
    }
}

// 语音播放
async function speakText() {
    const text = elements.finalText.value.trim();
    
    if (!text) {
        showStatus('请先输入要播放的文本', 'warning');
        return;
    }
    
    try {
        elements.speakBtn.disabled = true;
        elements.speakBtn.textContent = '🔊 生成中...';
        showStatus('正在生成语音...', 'processing');
        
        const response = await fetch(`${API_BASE_URL}/api/tts`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                text: text,
                voice: 'default',
                speed: 1.0
            })
        });
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        const audioBlob = await response.blob();
        const audioUrl = URL.createObjectURL(audioBlob);
        
        elements.audioPlayer.src = audioUrl;
        elements.audioControls.style.display = 'block';
        elements.audioPlayer.play();
        
        showStatus('语音生成完成，正在播放', 'success');
        elements.outputArea.textContent = `📢 语音输出:\n${text}`;
        
    } catch (error) {
        console.error('TTS失败:', error);
        showStatus('语音生成失败: ' + error.message, 'error');
    } finally {
        elements.speakBtn.disabled = false;
        elements.speakBtn.textContent = '🔊 语音播放';
    }
}

// 复制文本
function copyText() {
    const text = elements.finalText.value.trim();
    
    if (!text) {
        showStatus('请先输入要复制的文本', 'warning');
        return;
    }
    
    navigator.clipboard.writeText(text).then(() => {
        showStatus('文本已复制到剪贴板', 'success');
        elements.outputArea.textContent = `📋 文本输出:\n${text}`;
    }).catch((error) => {
        console.error('复制失败:', error);
        showStatus('复制失败，请手动选择文本复制', 'error');
    });
}

// 显示状态信息
function showStatus(message, type = 'info') {
    const statusElement = elements.recordingStatus;
    statusElement.style.display = 'block';
    statusElement.textContent = message;
    
    // 移除之前的状态类
    statusElement.className = 'status-message';
    
    // 添加新的状态类
    switch (type) {
        case 'success':
            statusElement.style.borderColor = '#27ae60';
            statusElement.style.backgroundColor = '#d5f4e6';
            statusElement.style.color = '#1e8449';
            break;
        case 'error':
            statusElement.style.borderColor = '#e74c3c';
            statusElement.style.backgroundColor = '#fadbd8';
            statusElement.style.color = '#c0392b';
            break;
        case 'warning':
            statusElement.style.borderColor = '#f39c12';
            statusElement.style.backgroundColor = '#fef9e7';
            statusElement.style.color = '#d68910';
            break;
        case 'processing':
        case 'recording':
            statusElement.style.borderColor = '#3498db';
            statusElement.style.backgroundColor = '#ebf3fd';
            statusElement.style.color = '#2980b9';
            break;
        default:
            statusElement.style.borderColor = '#4facfe';
            statusElement.style.backgroundColor = '#e8f4fd';
            statusElement.style.color = '#1e40af';
    }
    
    // 自动隐藏一般状态消息
    if (type === 'success' || type === 'warning') {
        setTimeout(() => {
            statusElement.style.display = 'none';
        }, 3000);
    }
}

// 更新生成按钮状态
function updateGenerateButtonState() {
    const hasContent = elements.scenarioContext.value.trim() || 
                      elements.audioText.value.trim() || 
                      elements.userOpinion.value.trim();
    
    elements.generateBtn.disabled = !hasContent;
}

// 错误处理
window.addEventListener('error', function(event) {
    console.error('全局错误:', event.error);
    showStatus('发生未预期的错误，请刷新页面重试', 'error');
});

// 未处理的Promise拒绝
window.addEventListener('unhandledrejection', function(event) {
    console.error('未处理的Promise拒绝:', event.reason);
    showStatus('网络或服务器错误，请检查连接', 'error');
});