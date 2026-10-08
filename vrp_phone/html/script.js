// author: Callum Jackson
let myPhoneNumber = "";
let currentActiveChat = null;
let activeCallTarget = null;
let incomingCaller = null;
let cachedContacts = {};

// --- USER PREFERENCES ---
let userSettings = {
    theme: 'dark',
    accent: '#0a84ff',
    ringtone: 'gta',
    alertTone: 'classic'
};

// --- WEB AUDIO API FOR RINGTONES, ALERTS & SOUNDS ---
let audioCtx = null;
let ringInterval = null;

function initAudio() {
    if (!audioCtx) {
        audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    }
    if (audioCtx.state === 'suspended') {
        audioCtx.resume();
    }
}

function playNote(frequency, type, duration, delay = 0, volume = 0.1) {
    try {
        initAudio();
        setTimeout(() => {
            if (!audioCtx) return;
            let osc = audioCtx.createOscillator();
            let gain = audioCtx.createGain();

            osc.type = type || 'sine';
            osc.frequency.setValueAtTime(frequency, audioCtx.currentTime);

            gain.gain.setValueAtTime(volume, audioCtx.currentTime);
            gain.gain.exponentialRampToValueAtTime(0.0001, audioCtx.currentTime + duration);

            osc.connect(gain);
            gain.connect(audioCtx.destination);

            osc.start();
            osc.stop(audioCtx.currentTime + duration);
        }, delay);
    } catch (e) {
        console.error("Audio error:", e);
    }
}

// --- RINGTONE LIBRARY ---
function startIncomingRingtone() {
    stopAudio();
    playSelectedRingtone();
    
    let intervalTime = 2500;
    if (userSettings.ringtone === 'digital') intervalTime = 1500;
    if (userSettings.ringtone === 'nokia') intervalTime = 3200;
    if (userSettings.ringtone === 'mario') intervalTime = 3000;
    if (userSettings.ringtone === 'arcade') intervalTime = 2200;
    if (userSettings.ringtone === 'synth') intervalTime = 2000;
    if (userSettings.ringtone === 'classic') intervalTime = 3000;

    ringInterval = setInterval(() => {
        playSelectedRingtone();
    }, intervalTime);
}

function playSelectedRingtone() {
    switch(userSettings.ringtone) {
        case 'nokia':
            playNote(659.25, 'sine', 0.2, 0, 0.08);
            playNote(587.33, 'sine', 0.2, 200, 0.08);
            playNote(369.99, 'sine', 0.4, 400, 0.08);
            playNote(415.30, 'sine', 0.4, 800, 0.08);
            playNote(554.37, 'sine', 0.4, 1200, 0.08);
            playNote(493.88, 'sine', 0.2, 1600, 0.08);
            break;
        case 'mario':
            playNote(659.25, 'square', 0.15, 0, 0.06);
            playNote(659.25, 'square', 0.15, 150, 0.06);
            playNote(659.25, 'square', 0.3, 450, 0.06);
            playNote(523.25, 'square', 0.15, 650, 0.06);
            playNote(659.25, 'square', 0.3, 850, 0.06);
            playNote(783.99, 'square', 0.3, 1150, 0.06);
            break;
        case 'arcade':
            playNote(523.25, 'triangle', 0.1, 0, 0.08);
            playNote(659.25, 'triangle', 0.1, 100, 0.08);
            playNote(783.99, 'triangle', 0.1, 200, 0.08);
            playNote(1046.50, 'triangle', 0.25, 300, 0.08);
            break;
        case 'digital':
            playNote(1200, 'square', 0.1, 0, 0.05);
            playNote(1200, 'square', 0.1, 150, 0.05);
            break;
        case 'synth':
            playNote(440, 'sawtooth', 0.2, 0, 0.06);
            playNote(659.25, 'sawtooth', 0.2, 200, 0.06);
            playNote(880, 'sawtooth', 0.3, 400, 0.06);
            break;
        case 'classic':
            playNote(900, 'sine', 0.3, 0, 0.08);
            playNote(1100, 'sine', 0.3, 150, 0.08);
            playNote(900, 'sine', 0.3, 400, 0.08);
            playNote(1100, 'sine', 0.3, 550, 0.08);
            break;
        case 'gta':
        default:
            playNote(853.5, 'triangle', 0.15, 0);
            playNote(1280.0, 'triangle', 0.15, 150);
            playNote(853.5, 'triangle', 0.15, 350);
            playNote(1280.0, 'triangle', 0.15, 500);
            playNote(1700.0, 'sine', 0.25, 750, 0.08);
            break;
    }
}

function previewCurrentRingtone() {
    stopAudio();
    playSelectedRingtone();
}

// --- MESSAGE ALERT TONE LIBRARY ---
function playMessageNotificationSound() {
    try {
        initAudio();
        switch(userSettings.alertTone) {
            case 'bubble':
                playNote(523.25, 'sine', 0.08, 0, 0.08);
                playNote(783.99, 'sine', 0.12, 80, 0.08);
                break;
            case 'laser':
                playNote(1200, 'sawtooth', 0.1, 0, 0.05);
                playNote(400, 'sawtooth', 0.15, 60, 0.05);
                break;
            case 'marimba':
                playNote(880, 'triangle', 0.15, 0, 0.08);
                playNote(1320, 'triangle', 0.2, 100, 0.08);
                break;
            case 'classic':
            default:
                playNote(987.77, 'sine', 0.1, 0, 0.08);
                playNote(1318.51, 'sine', 0.2, 120, 0.08);
                break;
        }
    } catch (e) {}
}

function previewCurrentAlertTone() {
    playMessageNotificationSound();
}

function startRingingTone() {
    stopAudio();
    playNote(440, 'sine', 0.8, 0, 0.05);
    playNote(480, 'sine', 0.8, 200, 0.05);
    ringInterval = setInterval(() => {
        playNote(440, 'sine', 0.8, 0, 0.05);
        playNote(480, 'sine', 0.8, 200, 0.05);
    }, 4000);
}

function stopAudio() {
    if (ringInterval) {
        clearInterval(ringInterval);
        ringInterval = null;
    }
}

// --- SETTINGS CONTROLS & PERSISTENCE ---
function updateTheme(themeName, save = true) {
    userSettings.theme = themeName;
    document.body.classList.remove('theme-light', 'theme-midnight');
    if (themeName === 'light') document.body.classList.add('theme-light');
    if (themeName === 'midnight') document.body.classList.add('theme-midnight');
    if (save) saveSettingsToServer();
}

function updateAccent(colorHex, save = true) {
    userSettings.accent = colorHex;
    document.documentElement.style.setProperty('--accent-color', colorHex);
    if (save) saveSettingsToServer();
}

function updateRingtoneSelection(ringtoneKey, save = true) {
    userSettings.ringtone = ringtoneKey;
    if (save) saveSettingsToServer();
}

function updateAlertToneSelection(alertToneKey, save = true) {
    userSettings.alertTone = alertToneKey;
    if (save) saveSettingsToServer();
}

function saveSettingsToServer() {
    if (!myPhoneNumber) return;
    fetch(`https://vrp_phone/saveSettings`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ myPhone: myPhoneNumber, settings: userSettings })
    });
}

function loadSavedSettingsFromData(savedObj) {
    if (!savedObj) return;
    try {
        userSettings = {
            theme: savedObj.theme || 'dark',
            accent: savedObj.accent || '#0a84ff',
            ringtone: savedObj.ringtone || 'gta',
            alertTone: savedObj.alertTone || 'classic'
        };

        updateTheme(userSettings.theme, false);
        updateAccent(userSettings.accent, false);

        let themeSelect = document.getElementById('setting-theme');
        if (themeSelect) themeSelect.value = userSettings.theme;

        let ringtoneSelect = document.getElementById('setting-ringtone');
        if (ringtoneSelect) ringtoneSelect.value = userSettings.ringtone;

        let alertSelect = document.getElementById('setting-alert-tone');
        if (alertSelect) alertSelect.value = userSettings.alertTone;
    } catch (e) {}
}

function fetchSettingsFromServer() {
    if (!myPhoneNumber) return;
    fetch(`https://vrp_phone/getSettings`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ myPhone: myPhoneNumber })
    }).then(res => res.json()).then(data => {
        if (data && data.settings) {
            loadSavedSettingsFromData(data.settings);
        }
    }).catch(err => {});
}

function getContactDisplayName(number) {
    return cachedContacts[number] || number;
}

function fetchAndCacheContacts(callback) {
    fetch(`https://vrp_phone/getContacts`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ myPhone: myPhoneNumber })
    });
    if (callback) callback();
}

// --- KEYBOARD & UI LISTENERS ---
window.addEventListener('keydown', function(event) {
    if (event.key === 'm' || event.key === 'M') {
        let activeElement = document.activeElement;
        if (activeElement && activeElement.tagName === 'INPUT') {
            return;
        }
        closePhoneUI();
    }
});

function closePhoneUI() {
    stopAudio();
    document.getElementById('phone-container').classList.add('hidden');
    fetch(`https://vrp_phone/closePhone`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
}

function formatPhoneNumberInput(input) {
    let value = input.value.replace(/\D/g, '');
    if (value.length > 3) {
        value = value.substring(0, 3) + '-' + value.substring(3, 7);
    }
    input.value = value;
}

function showPhoneNotification(text) {
    let notif = document.getElementById('phone-notification');
    let notifText = document.getElementById('phone-notification-text');
    notifText.innerText = text;
    notif.classList.remove('hidden');
    setTimeout(() => {
        notif.classList.add('hidden');
    }, 3000);
}

window.addEventListener('message', function(event) {
    let data = event.data;

    if (data.action === "openPhone") {
        let phoneContainer = document.getElementById('phone-container');
        if (data.status) {
            phoneContainer.classList.remove('hidden');
            fetchSettingsFromServer();
            fetchAndCacheContacts();
            goHome();
        } else {
            phoneContainer.classList.add('hidden');
            stopAudio();
        }
    } else if (data.action === "updatePhoneNumber") {
        if (data.phoneNumber) {
            myPhoneNumber = data.phoneNumber;
            document.getElementById('my-number').innerText = myPhoneNumber;
            fetchSettingsFromServer();
            fetchAndCacheContacts();
        }
    } else if (data.action === "loadSettings") {
        if (data.settings) {
            loadSavedSettingsFromData(data.settings);
        }
    } else if (data.action === "receiveText") {
        playMessageNotificationSound();
        loadConversationsData();
    } else if (data.action === "textSentSuccess") {
        if (currentActiveChat) loadChatLog(currentActiveChat);
    } else if (data.action === "loadContacts") {
        cachedContacts = {};
        if (data.contacts) {
            data.contacts.forEach(c => {
                cachedContacts[c.number] = c.name;
            });
        }
        renderContactsList(data.contacts);
    } else if (data.action === "loadConversations") {
        renderConversationsList(data.conversations);
    } else if (data.action === "loadChatLog") {
        renderChatLog(data.targetPhone, data.messages);
    } else if (data.action === "loadCallHistory") {
        renderCallHistoryList(data.history);
    } else if (data.action === "incomingCall") {
        incomingCaller = data.callerPhone;
        document.getElementById('incoming-caller-number').innerText = getContactDisplayName(incomingCaller);
        document.getElementById('incoming-call-modal').classList.remove('hidden');
        startIncomingRingtone();
    } else if (data.action === "callConnected") {
        stopAudio();
        document.getElementById('incoming-call-modal').classList.add('hidden');
        document.getElementById('active-call-overlay').classList.remove('hidden');
        document.getElementById('call-status-title').innerText = "On Call";
        let targetNum = activeCallTarget || incomingCaller;
        document.getElementById('active-call-with').innerText = getContactDisplayName(targetNum);
    } else if (data.action === "callDeclined") {
        stopAudio();
        showPhoneNotification("Call was declined.");
        resetCallState();
    } else if (data.action === "callEnded") {
        stopAudio();
        resetCallState();
    } else if (data.action === "refreshContacts") {
        openApp('contacts');
    }
});

function goHome() {
    document.querySelectorAll('.app-view').forEach(el => el.classList.add('hidden'));
    document.getElementById('home-screen').classList.remove('hidden');
}

function openApp(appName) {
    document.querySelectorAll('.app-view').forEach(el => el.classList.add('hidden'));
    document.getElementById('app-' + appName).classList.remove('hidden');

    fetchAndCacheContacts();

    if (appName === 'contacts') {
        fetch(`https://vrp_phone/getContacts`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ myPhone: myPhoneNumber })
        });
    } else if (appName === 'messages') {
        backToConversations();
    } else if (appName === 'calls') {
        fetch(`https://vrp_phone/getCallHistory`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ myPhone: myPhoneNumber })
        });
    }
}

// --- CONTACTS ---
function renderContactsList(contacts) {
    let list = document.getElementById('contacts-list');
    list.innerHTML = "";
    if (contacts && contacts.length > 0) {
        contacts.forEach(c => {
            list.innerHTML += `
                <div style="padding: 6px 8px; border-bottom: 1px solid var(--border-color); display: flex; justify-content: space-between; align-items: center;">
                    <div>
                        <b style="font-size: 12px;">${c.name}</b><br><span style="color: #8e8e93; font-size: 11px;">${c.number}</span>
                    </div>
                    <div style="display:flex; gap:3px;">
                        <button onclick="startCallDirect('${c.number}')" style="background:#34c759; color:white; border:none; padding:4px 6px; border-radius:4px; font-size:10px; cursor:pointer;">📞</button>
                        <button onclick="openChatWith('${c.number}')" style="background:var(--accent-color); color:white; border:none; padding:4px 6px; border-radius:4px; font-size:10px; cursor:pointer;">💬</button>
                        <button onclick="deleteContact(${c.id})" style="background:#ff3b30; color:white; border:none; padding:4px 6px; border-radius:4px; font-size:10px; cursor:pointer;">Del</button>
                    </div>
                </div>`;
        });
    } else {
        list.innerHTML = `<p style="color: #8e8e93; text-align: center; margin-top: 20px; font-size: 11px;">No contacts found.</p>`;
    }
}

function saveNewContact() {
    let name = document.getElementById('c-name').value;
    let number = document.getElementById('c-number').value;
    if (!name || !number) return;

    fetch(`https://vrp_phone/addContact`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ myPhone: myPhoneNumber, name: name, number: number })
    });
    document.getElementById('c-name').value = "";
    document.getElementById('c-number').value = "";
    setTimeout(() => { fetchAndCacheContacts(); }, 200);
}

function deleteContact(id) {
    fetch(`https://vrp_phone/deleteContact`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ myPhone: myPhoneNumber, id: id })
    });
    setTimeout(() => { fetchAndCacheContacts(); }, 200);
}

// --- MESSAGES & THREADS ---
function loadConversationsData() {
    fetch(`https://vrp_phone/getConversations`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ myPhone: myPhoneNumber })
    });
}

function renderConversationsList(rows) {
    let convList = document.getElementById('conversations-list');
    convList.innerHTML = "";
    
    let uniqueNumbers = [];
    rows.forEach(r => {
        let otherNum = (r.sender === myPhoneNumber) ? r.target : r.sender;
        if (otherNum && !uniqueNumbers.includes(otherNum)) {
            uniqueNumbers.push(otherNum);
        }
    });

    if (uniqueNumbers.length > 0) {
        uniqueNumbers.forEach(num => {
            let displayName = getContactDisplayName(num);
            convList.innerHTML += `
                <div onclick="openChatWith('${num}')" style="padding: 8px 10px; border-bottom: 1px solid var(--border-color); cursor:pointer; display: flex; justify-content:space-between; align-items:center;">
                    <div><b style="font-size:12px;">${displayName}</b> ${displayName !== num ? `<br><span style="color:#8e8e93; font-size:10px;">${num}</span>` : ''}</div>
                    <span style="color: var(--accent-color); font-size: 11px;">Chat &gt;</span>
                </div>`;
        });
    } else {
        convList.innerHTML = `<p style="color: #8e8e93; text-align: center; margin-top: 20px; font-size: 11px;">No messages yet.</p>`;
    }
}

function promptNewMessage() {
    document.getElementById('new-message-modal').classList.remove('hidden');
}

function closeNewMessageModal() {
    document.getElementById('new-message-modal').classList.add('hidden');
    document.getElementById('new-msg-number').value = "";
}

function submitNewMessage() {
    let target = document.getElementById('new-msg-number').value;
    if (!target) return;
    closeNewMessageModal();
    openChatWith(target);
}

function openChatWith(targetPhone) {
    openApp('messages');
    currentActiveChat = targetPhone;
    document.getElementById('conversations-list').classList.add('hidden');
    document.getElementById('chat-thread').classList.remove('hidden');
    let displayName = getContactDisplayName(targetPhone);
    document.getElementById('active-chat-title').innerText = "Chat with " + displayName;
    loadChatLog(targetPhone);
}

function backToConversations() {
    currentActiveChat = null;
    document.getElementById('chat-thread').classList.add('hidden');
    document.getElementById('conversations-list').classList.remove('hidden');
    loadConversationsData();
}

function loadChatLog(targetPhone) {
    fetch(`https://vrp_phone/getChatLog`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ myPhone: myPhoneNumber, targetPhone: targetPhone })
    });
}

function renderChatLog(targetPhone, messages) {
    let history = document.getElementById('chat-history');
    history.innerHTML = "";
    if (messages && messages.length > 0) {
        messages.forEach(m => {
            let isMe = m.sender === myPhoneNumber;
            let senderDisplay = isMe ? "You" : getContactDisplayName(m.sender);
            let align = isMe ? "text-align: right; color: var(--accent-color);" : "text-align: left; color: var(--text-color);";
            history.innerHTML += `<div style="${align} margin-bottom: 6px; font-size: 11px;"><b>${senderDisplay}:</b> ${m.message}</div>`;
        });
        history.scrollTop = history.scrollHeight;
    } else {
        history.innerHTML = `<p style="color: #8e8e93; text-align: center; font-size: 11px;">Start of conversation.</p>`;
    }
}

function sendChatMessage() {
    let text = document.getElementById('chat-input').value;
    if (!text || !currentActiveChat) return;

    fetch(`https://vrp_phone/sendText`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ senderPhone: myPhoneNumber, targetPhone: currentActiveChat, message: text })
    });
    document.getElementById('chat-input').value = "";
}

// --- CALLS & KEYPAD ---
function pressKey(char) {
    let input = document.getElementById('dialer-input');
    if (input.value.length < 8) {
        input.value += char;
        if (input.value.length === 3) {
            input.value += '-';
        }
    }
}

function clearKeypad() {
    document.getElementById('dialer-input').value = "";
}

function makeCall() {
    let num = document.getElementById('dialer-input').value;
    if (!num) return;
    startCallDirect(num);
}

function startCallDirect(targetNumber) {
    activeCallTarget = targetNumber;
    
    document.getElementById('active-call-overlay').classList.remove('hidden');
    document.getElementById('call-status-title').innerText = "Calling...";
    document.getElementById('active-call-with').innerText = getContactDisplayName(targetNumber);

    startRingingTone();

    fetch(`https://vrp_phone/startCall`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ callerPhone: myPhoneNumber, targetPhone: targetNumber })
    });
}

function answerIncomingCall() {
    stopAudio();
    fetch(`https://vrp_phone/acceptCall`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ callerPhone: incomingCaller, targetPhone: myPhoneNumber })
    });
}

function declineIncomingCall() {
    stopAudio();
    document.getElementById('incoming-call-modal').classList.add('hidden');
    fetch(`https://vrp_phone/rejectCall`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ callerPhone: incomingCaller })
    });
    incomingCaller = null;
}

function hangUpCall() {
    stopAudio();
    let target = activeCallTarget || incomingCaller;
    fetch(`https://vrp_phone/endCall`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ otherPhone: target })
    });
    resetCallState();
}

function resetCallState() {
    stopAudio();
    document.getElementById('incoming-call-modal').classList.add('hidden');
    document.getElementById('active-call-overlay').classList.add('hidden');
    activeCallTarget = null;
    incomingCaller = null;
}

function renderCallHistoryList(history) {
    let historyList = document.getElementById('call-history-list');
    historyList.innerHTML = "";
    if (history && history.length > 0) {
        history.forEach(h => {
            let displayName = getContactDisplayName(h.other_number);
            let color = h.type === 'Incoming' ? '#34c759' : 'var(--accent-color)';
            historyList.innerHTML += `
                <div style="padding: 4px 6px; border-bottom: 1px solid var(--border-color); display: flex; justify-content: space-between; align-items: center; font-size: 11px;">
                    <div><b>${displayName}</b> <span style="color: ${color};">(${h.type})</span></div>
                    <button onclick="startCallDirect('${h.other_number}')" style="background:#34c759; color:white; border:none; padding:2px 6px; border-radius:4px; cursor:pointer;">📞</button>
                </div>`;
        });
    } else {
        historyList.innerHTML = `<p style="color: #8e8e93; text-align: center; font-size: 11px;">No recent calls.</p>`;
    }
}