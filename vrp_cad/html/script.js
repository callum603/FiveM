let userPermissions = { isCop: false, isEms: false };
let cachedCalls = [];
let cachedOfficers = {};
let activeTab = "dispatches";

window.addEventListener('message', function(event) {
    let data = event.data;
    
    if (data.action === "openMDT") {
        document.getElementById('mdt-container').classList.remove('hidden');
        userPermissions = data.permissions || { isCop: true, isEms: false };
        cachedCalls = data.calls || [];
        cachedOfficers = data.officers || {};
        
        let titleElem = document.getElementById('mdt-title');
        if (userPermissions.isCop && userPermissions.isEms) {
            titleElem.innerText = "UNIFIED CAD / MDT TERMINAL";
        } else if (userPermissions.isCop) {
            titleElem.innerText = "POLICE MDT TERMINAL";
        } else {
            titleElem.innerText = "EMS MEDICAL TERMINAL";
        }
        
        let plateBtn = document.getElementById('plate-nav-btn');
        if (plateBtn) {
            plateBtn.style.display = userPermissions.isCop ? "block" : "none";
        }
        
        renderActiveTab();
    }
    
    if (data.action === "updateRoster") {
        cachedOfficers = data.officers || {};
        if (activeTab === "personnel") renderOfficerRosterView();
    }

    if (data.action === "updateCalls") {
        cachedCalls = data.calls || [];
        if (activeTab === "dispatches") renderMainDashboard();
    }

    if (data.action === "playAudio") {
        let existingAudio = document.getElementById('persistent-distress-audio');
        if (existingAudio) {
            existingAudio.remove();
        }

        let audio = document.createElement('audio');
        audio.id = 'persistent-distress-audio';
        audio.src = data.file;
        audio.volume = 0.8;
        document.body.appendChild(audio);
        
        audio.play().catch(err => {
            console.log("Audio play blocked by browser policy: ", err);
        });
    }

    if (data.action === "civilianSearchResult") {
        renderCivilianResults(data.results);
    }
    
    if (data.action === "plateResult") {
        renderPlateResult(data.result);
    }
});

document.onkeyup = function(data) {
    if (data.key === "Escape") {
        closeMDT();
    }
};

function closeMDT() {
    document.getElementById('mdt-container').classList.add('hidden');
    fetch(`https://vrp_cad/closeMDT`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
}

function switchTab(tabName, btnElem) {
    activeTab = tabName;
    document.querySelectorAll('.mdt-nav-btn').forEach(b => b.classList.remove('active'));
    if (btnElem) btnElem.classList.add('active');
    renderActiveTab();
}

function renderActiveTab() {
    if (activeTab === "dispatches") renderMainDashboard();
    else if (activeTab === "personnel") renderOfficerRosterView();
    else if (activeTab === "civilian") renderCivilianSearchView();
    else if (activeTab === "plates" && userPermissions.isCop) renderPlateLookupView();
}

function renderMainDashboard() {
    let bodyElem = document.getElementById('mdt-body-content');
    bodyElem.innerHTML = `<h3>Active Dispatches</h3><div id="active-calls-list" style="display: flex; flex-direction: column; gap: 10px; margin-top: 15px;"></div>`;
    
    let callsContainer = document.getElementById('active-calls-list');
    if (!cachedCalls || cachedCalls.length === 0) {
        callsContainer.innerHTML = "<p style='color: #90a4ae;'>No active dispatches.</p>";
        return;
    }
    
    cachedCalls.forEach(call => {
        let isDistress = call.call_type && call.call_type.includes("10-99");
        let bgStyle = isDistress ? "background: rgba(239, 83, 80, 0.1); border: 1px solid #ef5350;" : "background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.08);";

        let item = document.createElement('div');
        item.style.cssText = `${bgStyle} padding: 12px; border-radius: 6px;`;
        
        let assignedUnitsText = call.assigned_units ? call.assigned_units : "None";
        let callerName = call.caller_name || "Unknown";
        let callerPhone = call.caller_phone || "N/A";
        let callerAge = call.caller_age || "N/A";
        let callerAddress = call.caller_address || "N/A";

        item.innerHTML = `
            <div style="display: flex; justify-content: space-between; align-items: center;">
                <strong style="color: ${isDistress ? '#ef5350' : '#64b5f6'};">${call.call_type}</strong>
                <span style="font-size: 11px; color: #78909c;">${call.date || ''}</span>
            </div>
            <div style="margin-top: 4px; font-size: 13px;"><strong>Location:</strong> ${call.location}</div>
            <div style="margin-top: 2px; font-size: 12px; color: #b0bec5;">${call.description || ''}</div>
            <div style="margin-top: 6px; font-size: 11px; background: rgba(0,0,0,0.2); padding: 6px; border-radius: 4px; border-left: 2px solid #64b5f6;">
                <strong>Caller:</strong> ${callerName} | <strong>Phone:</strong> ${callerPhone} | <strong>Age:</strong> ${callerAge} | <strong>Address:</strong> ${callerAddress}
            </div>
            <div style="margin-top: 6px; font-size: 11px; color: #90a4ae;"><strong>Assigned Units:</strong> ${assignedUnitsText}</div>
            <div style="margin-top: 8px; display: flex; gap: 8px;">
                <button class="action-btn" style="padding: 4px 10px; font-size: 11px; background: #0288d1;" onclick="setCallWaypoint(${call.coords_x}, ${call.coords_y})">GPS Route</button>
                <button class="action-btn" style="padding: 4px 10px; font-size: 11px; background: #388e3c;" onclick="assignToCall(${call.id})">Attach Self</button>
                <button class="action-btn" style="padding: 4px 10px; font-size: 11px; background: #d32f2f;" onclick="closeCall(${call.id})">Close Call</button>
            </div>
        `;
        callsContainer.appendChild(item);
    });
}

function setCallWaypoint(x, y) {
    fetch(`https://${GetParentResourceName()}/setWaypoint`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ x: x, y: y })
    });
}

function assignToCall(callId) {
    fetch(`https://${GetParentResourceName()}/assignToCall`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: callId })
    });
}

function closeCall(callId) {
    fetch(`https://${GetParentResourceName()}/closeCall`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: callId })
    });
}

function renderOfficerRosterView() {
    let bodyElem = document.getElementById('mdt-body-content');
    bodyElem.innerHTML = `
        <h3>Personnel & 10-Codes Management</h3>
        
        ${userPermissions.isCop ? `
        <div style="background: rgba(0,0,0,0.2); padding: 12px; border-radius: 6px; margin-top: 10px; border-left: 3px solid #64b5f6;">
            <h4 style="margin: 0 0 8px 0; color: #64b5f6;">Police Status Control</h4>
            <div style="display: flex; gap: 8px; flex-wrap: wrap;">
                <button class="action-btn" onclick="setStatus('police', '10-8', 'In Service')">10-8 In Service</button>
                <button class="action-btn" style="background: #f57c00;" onclick="setStatus('police', '10-6', 'Busy')">10-6 Busy</button>
                <button class="action-btn" style="background: #0288d1;" onclick="setStatus('police', '10-11', 'Traffic Stop')">10-11 Traffic Stop</button>
                <button class="action-btn" style="background: #7b1fa2;" onclick="setStatus('police', '10-23', 'Arrived on Scene')">10-23 Arrived</button>
                <button class="action-btn" style="background: #388e3c;" onclick="setStatus('police', '10-97', 'En Route')">10-97 En Route</button>
                <button class="action-btn" style="background: #d32f2f;" onclick="setStatus('police', '10-7', 'Off Duty')">10-7 Off Duty</button>
                <button class="action-btn" style="background: #c62828;" onclick="setStatus('police', '10-99', 'Officer Down / Distress')">10-99 DISTRESS</button>
            </div>
        </div>` : ''}

        ${userPermissions.isEms ? `
        <div style="background: rgba(0,0,0,0.2); padding: 12px; border-radius: 6px; margin-top: 10px; border-left: 3px solid #66bb6a;">
            <h4 style="margin: 0 0 8px 0; color: #66bb6a;">EMS Status Control</h4>
            <div style="display: flex; gap: 8px; flex-wrap: wrap;">
                <button class="action-btn" style="background: #388e3c;" onclick="setStatus('ems', '10-8', 'In Service')">10-8 In Service</button>
                <button class="action-btn" style="background: #f57c00;" onclick="setStatus('ems', '10-6', 'Busy')">10-6 Busy</button>
                <button class="action-btn" style="background: #0288d1;" onclick="setStatus('ems', '10-26', 'En Route to Patient')">10-26 En Route</button>
                <button class="action-btn" style="background: #7b1fa2;" onclick="setStatus('ems', '10-23', 'At Scene')">10-23 At Scene</button>
                <button class="action-btn" style="background: #e65100;" onclick="setStatus('ems', '10-41', 'Transporting to Hospital')">10-41 Transporting</button>
                <button class="action-btn" style="background: #d32f2f;" onclick="setStatus('ems', '10-7', 'Off Duty')">10-7 Off Duty</button>
                <button class="action-btn" style="background: #c62828;" onclick="setStatus('ems', '10-99', 'Medic Down / Distress')">10-99 DISTRESS</button>
            </div>
        </div>` : ''}

        <div style="display: flex; gap: 20px; margin-top: 15px;">
            <div style="flex: 1;">
                <h4 style="color: #64b5f6; border-bottom: 1px solid rgba(255,255,255,0.08); padding-bottom: 5px;">Police On Duty</h4>
                <div id="police-roster-list" style="display: flex; flex-direction: column; gap: 8px; margin-top: 10px;"></div>
            </div>
            <div style="flex: 1;">
                <h4 style="color: #66bb6a; border-bottom: 1px solid rgba(255,255,255,0.08); padding-bottom: 5px;">EMS On Duty</h4>
                <div id="ems-roster-list" style="display: flex; flex-direction: column; gap: 8px; margin-top: 10px;"></div>
            </div>
        </div>
    `;
    
    let policeContainer = document.getElementById('police-roster-list');
    let emsContainer = document.getElementById('ems-roster-list');
    
    let policeCount = 0;
    let emsCount = 0;
    
    for (let id in cachedOfficers) {
        let officer = cachedOfficers[id];
        let isDistress = officer.code === "10-99";
        let badgeStyle = isDistress ? "background: #c62828; color: white;" : "";

        let item = document.createElement('div');
        item.style.cssText = "background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.08); padding: 10px 14px; border-radius: 6px; display: flex; justify-content: space-between; align-items: center;";
        item.innerHTML = `<span><strong>${officer.name}</strong></span><span class="badge badge-interaction" style="${badgeStyle}">[${officer.code}] ${officer.description || ''}</span>`;
        
        if (officer.department === "police") {
            policeContainer.appendChild(item);
            policeCount++;
        } else if (officer.department === "ems") {
            emsContainer.appendChild(item);
            emsCount++;
        }
    }
    
    if (policeCount === 0) {
        policeContainer.innerHTML = "<p style='color: #90a4ae; font-size: 12px;'>No police officers on duty.</p>";
    }
    if (emsCount === 0) {
        emsContainer.innerHTML = "<p style='color: #90a4ae; font-size: 12px;'>No EMS personnel on duty.</p>";
    }
}

function renderCivilianSearchView() {
    let bodyElem = document.getElementById('mdt-body-content');
    bodyElem.innerHTML = `
        <h3>Civilian Database Lookup</h3>
        <div style="margin: 15px 0; display: flex; gap: 10px;">
            <input type="text" id="civ-search-input" placeholder="Search character name..." style="width: 300px;" onkeydown="if(event.key==='Enter') triggerCivSearch()">
            <button class="action-btn" onclick="triggerCivSearch()">Search</button>
        </div>
        <div id="civilian-results-container" style="display: flex; flex-direction: column; gap: 15px;"></div>
    `;
}

function triggerCivSearch() {
    let query = document.getElementById('civ-search-input').value;
    if (!query) return;
    searchCivilianName(query);
}

function renderCivilianResults(results) {
    let container = document.getElementById('civilian-results-container');
    if (!container) return;
    
    container.innerHTML = "";
    if (!results || results.length === 0) {
        container.innerHTML = "<p style='color: #90a4ae;'>No civilian records found matching query.</p>";
        return;
    }
    
    results.forEach(civ => {
        let div = document.createElement('div');
        div.style.cssText = "background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.08); padding: 15px; border-radius: 8px;";
        
        let safeName = civ.fullname.replace(/'/g, "\\'");
        let html = `<div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;">
                        <h4 style="margin: 0; color: #64b5f6; font-size: 16px;">${civ.fullname}</h4>
                        <span style="font-size: 12px; color: #b0bec5;">Phone: ${civ.phone} | Age: ${civ.age}</span>
                    </div><hr style="border: none; border-top: 1px solid rgba(255,255,255,0.08); margin-bottom: 10px;">`;
        
        if (userPermissions.isCop) {
            html += `<h5 style="margin: 5px 0; color: #90a4ae;">Criminal Records</h5>`;
            if (civ.criminal_records && civ.criminal_records.length > 0) {
                civ.criminal_records.forEach(rec => {
                    let typeLabel = rec.report_type || "Arrest";
                    let badgeClass = "badge-arrest";
                    if (typeLabel === "Fine Only") badgeClass = "badge-fine";
                    else if (typeLabel === "Warning") badgeClass = "badge-warning";
                    else if (typeLabel === "Interaction") badgeClass = "badge-interaction";
                    else if (typeLabel === "Arrest + Fine") badgeClass = "badge-arrest";
                    
                    html += `<div id="record-card-${rec.id}" style="font-size: 12px; margin: 6px 0; background: rgba(0,0,0,0.3); padding: 10px; border-radius: 6px; border-left: 3px solid #64b5f6;">
                                <div style="display: flex; justify-content: space-between; margin-bottom: 4px;">
                                    <span><span class="badge ${badgeClass}">${typeLabel}</span> <strong>${rec.title}</strong> ${rec.fine_amount > 0 ? '($' + rec.fine_amount + ')' : ''}</span>
                                    <span style="color: #78909c;">${rec.date}</span>
                                </div>
                                <div>${rec.details}</div>
                                
                                <div id="edit-form-${rec.id}" style="display: none; margin-top: 8px; flex-direction: column; gap: 6px; background: rgba(255,255,255,0.05); padding: 8px; border-radius: 4px;">
                                    <div style="display: flex; gap: 6px;">
                                        <select id="edit-type-${rec.id}" style="width: 130px;">
                                            <option value="Arrest" ${typeLabel==='Arrest'?'selected':''}>Arrest</option>
                                            <option value="Fine Only" ${typeLabel==='Fine Only'?'selected':''}>Fine Only</option>
                                            <option value="Warning" ${typeLabel==='Warning'?'selected':''}>Warning</option>
                                            <option value="Interaction" ${typeLabel==='Interaction'?'selected':''}>Interaction</option>
                                            <option value="Arrest + Fine" ${typeLabel==='Arrest + Fine'?'selected':''}>Arrest + Fine</option>
                                        </select>
                                        <input type="text" id="edit-title-${rec.id}" value="${rec.title}" placeholder="Title" style="flex: 1;">
                                        <input type="number" id="edit-fine-${rec.id}" value="${rec.fine_amount}" placeholder="Fine ($)" style="width: 80px;" min="0">
                                    </div>
                                    <input type="text" id="edit-details-${rec.id}" value="${rec.details}" placeholder="Details...">
                                    <div style="display: flex; gap: 6px; justify-content: flex-end;">
                                        <button onclick="saveEditCrime(${rec.id}, ${civ.user_id}, '${safeName}')" class="action-btn" style="padding: 4px 10px; font-size: 11px;">Save</button>
                                        <button onclick="toggleEditCrime(${rec.id})" style="background: #78909c; border: none; color: white; padding: 4px 10px; border-radius: 4px; cursor: pointer; font-size: 11px;">Cancel</button>
                                    </div>
                                </div>

                                <div id="rec-actions-${rec.id}" style="margin-top: 6px; display: flex; justify-content: space-between; align-items: center;">
                                    <em style="color: #90a4ae;">Officer: ${rec.author}</em>
                                    <div style="display: flex; gap: 10px;">
                                        <button onclick="toggleEditCrime(${rec.id})" style="background: transparent; border: none; color: #64b5f6; cursor: pointer; font-size: 11px;">Edit</button>
                                        <button onclick="deleteCrime(${rec.id}, '${safeName}')" style="background: transparent; border: none; color: #ef5350; cursor: pointer; font-size: 11px;">Delete Record</button>
                                    </div>
                                </div>
                             </div>`;
                });
            } else {
                html += `<p style="font-size: 12px; color: #90a4ae;">No criminal history on file.</p>`;
            }
            
            html += `<div style="margin-top: 12px; background: rgba(0,0,0,0.15); padding: 10px; border-radius: 6px; display: flex; flex-direction: column; gap: 8px;">
                        <div style="display: flex; gap: 8px;">
                            <select id="crime-type-${civ.user_id}" style="width: 140px;" onchange="toggleFineInput(${civ.user_id})">
                                <option value="Arrest">Arrest</option>
                                <option value="Fine Only">Fine Only</option>
                                <option value="Warning">Warning</option>
                                <option value="Interaction">Interaction</option>
                                <option value="Arrest + Fine">Arrest + Fine</option>
                            </select>
                            <input type="text" id="crime-title-${civ.user_id}" placeholder="Charge / Title" style="flex: 1;">
                            <input type="number" id="crime-fine-${civ.user_id}" placeholder="Fine ($)" style="width: 90px; display: none;" min="0">
                        </div>
                        <div style="display: flex; gap: 8px;">
                            <input type="text" id="crime-details-${civ.user_id}" placeholder="Detailed report description..." style="flex: 1;">
                            <button class="action-btn" onclick="addCrime('${safeName}', ${civ.user_id})">Submit Report</button>
                        </div>
                     </div>`;
        }

        if (userPermissions.isEms) {
            html += `<h5 style="margin: 15px 0 5px 0; color: #90a4ae;">Medical Records</h5>`;
            if (civ.medical_records && civ.medical_records.length > 0) {
                civ.medical_records.forEach(med => {
                    html += `<div id="med-card-${med.id}" style="font-size: 12px; margin: 6px 0; background: rgba(0,0,0,0.3); padding: 8px; border-radius: 6px; border-left: 3px solid #66bb6a;">
                                <div style="display: flex; justify-content: space-between; margin-bottom: 4px;">
                                    <strong>Diagnosis: ${med.diagnosis}</strong>
                                    <span style="color: #78909c;">${med.date}</span>
                                </div>
                                <div>Treatment: ${med.treatment} ${med.service_fee > 0 ? '(<span style="color: #66bb6a;">Fee: $' + med.service_fee + '</span>)' : ''}</div>
                                <div style="margin-top: 4px; display: flex; justify-content: space-between; align-items: center;">
                                    <em style="color: #90a4ae;">Paramedic: ${med.author}</em>
                                    <button onclick="deleteMed(${med.id}, '${safeName}')" style="background: transparent; border: none; color: #ef5350; cursor: pointer; font-size: 11px;">Delete Record</button>
                                </div>
                             </div>`;
                });
            } else {
                html += `<p style="font-size: 12px; color: #90a4ae;">No medical history on file.</p>`;
            }
            
            html += `<div style="margin-top: 12px; background: rgba(0,0,0,0.15); padding: 10px; border-radius: 6px; display: flex; flex-direction: column; gap: 8px;">
                        <div style="display: flex; gap: 8px;">
                            <input type="text" id="med-diag-${civ.user_id}" placeholder="Diagnosis" style="flex: 1;">
                            <select id="med-service-${civ.user_id}" style="flex: 1;" onchange="updateMedService(${civ.user_id})">
                                <option value="0|Custom / None">Select Medical Service / Fee...</option>
                                <option value="1000|Resuscitation ($1000)">Resuscitation - $1000</option>
                                <option value="500|Major Treatment ($500)">Major Treatment - $500</option>
                                <option value="250|Hospital Transport ($250)">Hospital Transport - $250</option>
                                <option value="100|Minor Treatment ($100)">Minor Treatment - $100</option>
                                <option value="50|Bandage / First Aid ($50)">Bandage / First Aid - $50</option>
                            </select>
                        </div>
                        <div style="display: flex; gap: 8px;">
                            <input type="text" id="med-treat-${civ.user_id}" placeholder="Treatment notes..." style="flex: 1;">
                            <input type="hidden" id="med-fee-${civ.user_id}" value="0">
                            <button class="action-btn" onclick="addMed('${safeName}', ${civ.user_id})">File Medical</button>
                        </div>
                     </div>`;
        }
        
        div.innerHTML = html;
        container.appendChild(div);
    });
}

function updateMedService(userId) {
    let selectElem = document.getElementById(`med-service-${userId}`);
    let treatInput = document.getElementById(`med-treat-${userId}`);
    let feeInput = document.getElementById(`med-fee-${userId}`);
    
    if (!selectElem) return;
    let valParts = selectElem.value.split('|');
    let fee = valParts[0];
    let title = valParts[1];
    
    feeInput.value = fee;
    if (title && title !== "Custom / None") {
        treatInput.value = title;
    }
}

function toggleFineInput(userId) {
    let typeSelect = document.getElementById(`crime-type-${userId}`);
    let fineInput = document.getElementById(`crime-fine-${userId}`);
    if (typeSelect.value === "Fine Only" || typeSelect.value === "Arrest + Fine") {
        fineInput.style.display = "block";
    } else {
        fineInput.style.display = "none";
        fineInput.value = "";
    }
}

function toggleEditCrime(recordId) {
    let editForm = document.getElementById(`edit-form-${recordId}`);
    let actionsDiv = document.getElementById(`rec-actions-${recordId}`);
    if (editForm.style.display === "flex") {
        editForm.style.display = "none";
        actionsDiv.style.display = "flex";
    } else {
        editForm.style.display = "flex";
        actionsDiv.style.display = "none";
    }
}

function saveEditCrime(recordId, userId, targetName) {
    let reportType = document.getElementById(`edit-type-${recordId}`).value;
    let title = document.getElementById(`edit-title-${recordId}`).value;
    let details = document.getElementById(`edit-details-${recordId}`).value;
    let fineAmount = Number(document.getElementById(`edit-fine-${recordId}`).value) || 0;
    
    if (!title) return;
    
    fetch(`https://${GetParentResourceName()}/updateCriminalRecord`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            id: recordId,
            target_user_id: userId,
            target_name: targetName,
            report_type: reportType,
            title: title,
            details: details,
            fine_amount: fineAmount
        })
    });
}

function addCrime(targetName, userId) {
    let reportType = document.getElementById(`crime-type-${userId}`).value;
    let title = document.getElementById(`crime-title-${userId}`).value;
    let details = document.getElementById(`crime-details-${userId}`).value;
    let fineAmount = document.getElementById(`crime-fine-${userId}`).value || 0;
    
    if (!title) return;
    
    fetch(`https://${GetParentResourceName()}/addCriminalRecord`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            target_name: targetName,
            target_user_id: userId,
            report_type: reportType,
            title: title,
            details: details,
            fine_amount: Number(fineAmount)
        })
    });
}

function deleteCrime(recordId, targetName) {
    let cardElem = document.getElementById(`record-card-${recordId}`);
    if (cardElem) {
        cardElem.style.transition = "opacity 0.3s ease";
        cardElem.style.opacity = "0";
        setTimeout(() => cardElem.remove(), 300);
    }

    fetch(`https://${GetParentResourceName()}/deleteCriminalRecord`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: recordId, target_name: targetName })
    });
}

function addMed(targetName, userId) {
    let diagnosis = document.getElementById(`med-diag-${userId}`).value;
    let treatment = document.getElementById(`med-treat-${userId}`).value;
    let serviceFee = document.getElementById(`med-fee-${userId}`).value || 0;
    
    if (!diagnosis) return;
    
    fetch(`https://${GetParentResourceName()}/addMedicalRecord`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            target_name: targetName,
            target_user_id: userId,
            diagnosis: diagnosis,
            treatment: treatment,
            service_fee: Number(serviceFee)
        })
    });
}

function deleteMed(recordId, targetName) {
    let cardElem = document.getElementById(`med-card-${recordId}`);
    if (cardElem) {
        cardElem.style.transition = "opacity 0.3s ease";
        cardElem.style.opacity = "0";
        setTimeout(() => cardElem.remove(), 300);
    }

    fetch(`https://${GetParentResourceName()}/deleteMedicalRecord`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: recordId, target_name: targetName })
    });
}

function renderPlateLookupView() {
    let bodyElem = document.getElementById('mdt-body-content');
    bodyElem.innerHTML = `
        <h3>Vehicle Plate Lookup</h3>
        <div style="margin: 15px 0; display: flex; gap: 10px;">
            <input type="text" id="plate-search-input" placeholder="Enter license plate..." style="width: 250px;" onkeydown="if(event.key==='Enter') triggerPlateSearch()">
            <button class="action-btn" onclick="triggerPlateSearch()">Lookup Plate</button>
        </div>
        <div id="plate-result-container" style="margin-top: 15px;"></div>
    `;
}

function triggerPlateSearch() {
    let plate = document.getElementById('plate-search-input').value;
    if (!plate) return;
    fetch(`https://${GetParentResourceName()}/lookupPlate`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ plate: plate })
    });
}

function renderPlateResult(result) {
    let container = document.getElementById('plate-result-container');
    if (!container) return;
    
    if (!result.found) {
        container.innerHTML = "<p style='color: #ef5350;'>Vehicle plate not registered in database.</p>";
    } else {
        container.innerHTML = `<div style="background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.08); padding: 15px; border-radius: 8px;">
                                <strong style="color: #64b5f6;">Plate:</strong> ${result.plate}<br>
                                <strong style="color: #64b5f6;">Vehicle:</strong> ${result.vehicle}<br>
                                <strong style="color: #64b5f6;">Registered Owner:</strong> ${result.owner}
                               </div>`;
    }
}

function setStatus(department, code, description) {
    fetch(`https://${GetParentResourceName()}/updateStatus`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ department: department, code: code, description: description })
    });
}

function searchCivilianName(queryText) {
    fetch(`https://${GetParentResourceName()}/searchCivilian`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ query: queryText })
    });
}