#include <pgmspace.h>

const char dashboard_html[] PROGMEM = R"=====(
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>RoomAlert - RiCH Advanced Technology</title>
    <style>
        :root {
            --bg-base: #f4f7f6; --bg-panel: #ffffff; --bg-card: #ffffff;
            --text-main: #2b3a42; --text-muted: #6b7c85;
            --primary: #2563eb; --primary-glow: rgba(37, 99, 235, 0.2);
            --success: #10b981; --success-glow: rgba(16,185,129,0.2);
            --warning: #f59e0b; --danger: #ef4444; --danger-glow: rgba(239,68,68,0.2);
            --border: #e2e8f0; --radius: 12px;
            --transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background-color: var(--bg-base); color: var(--text-main); overflow-x: hidden; display: flex; height: 100vh; }
        h1, h2, h3, h4 { margin-bottom: 0.5rem; font-weight: 600; }
        p { color: var(--text-muted); line-height: 1.5; }
        .flex { display: flex; } .items-center { align-items: center; } .justify-between { justify-content: space-between; }
        .grid { display: grid; } .gap-4 { gap: 1rem; } .gap-6 { gap: 1.5rem; } .hidden { display: none !important; }
        #login-screen { position: fixed; top: 0; left: 0; width: 100vw; height: 100vh; background: linear-gradient(135deg, #f4f7f6 0%, #e2e8f0 100%); display: flex; justify-content: center; align-items: center; z-index: 1000; transition: opacity 0.5s; }
        .login-box { background: rgba(255,255,255,0.9); backdrop-filter: blur(10px); padding: 2.5rem; border-radius: var(--radius); border: 1px solid var(--border); width: 100%; max-width: 400px; box-shadow: 0 10px 30px rgba(0,0,0,0.05); text-align: center; }
        .login-box h2 { font-size: 1.75rem; color: var(--primary); }
        .input-group { margin-bottom: 1.25rem; text-align: left; }
        .input-group label { display: block; margin-bottom: 0.5rem; font-size: 0.875rem; color: var(--text-muted); }
        input[type="text"], input[type="password"], input[type="number"] { width: 100%; padding: 0.75rem 1rem; background: var(--bg-base); border: 1px solid var(--border); color: var(--text-main); border-radius: 8px; transition: var(--transition); }
        input:focus { outline: none; border-color: var(--primary); box-shadow: 0 0 0 3px var(--primary-glow); }
        button { width: 100%; padding: 0.875rem; background: var(--primary); color: white; border: none; border-radius: 8px; font-size: 1rem; font-weight: 600; cursor: pointer; transition: var(--transition); display: flex; justify-content: center; align-items: center; gap: 0.5rem; }
        button:hover { background: #2563eb; transform: translateY(-1px); }
        button.danger { background: var(--danger); } button.danger:hover { background: #dc2626; box-shadow: 0 4px 12px var(--danger-glow); }
        #app { display: none; width: 100%; height: 100%; }
        .sidebar { width: 260px; background: var(--bg-panel); border-right: 1px solid var(--border); display: flex; flex-direction: column; padding: 1.5rem 0; flex-shrink: 0; }
        .brand { padding: 0 1.5rem 2rem; border-bottom: 1px solid var(--border); margin-bottom: 1rem; display: flex; align-items: center; gap: 0.75rem; }
        .brand-icon { width: 32px; height: 32px; border-radius: 8px; background: linear-gradient(135deg, var(--primary), #8b5cf6); display: flex; align-items: center; justify-content: center; font-weight: bold; box-shadow: 0 0 15px var(--primary-glow); }
        .nav-item { padding: 1rem 1.5rem; display: flex; align-items: center; gap: 1rem; color: var(--text-muted); text-decoration: none; cursor: pointer; transition: var(--transition); border-left: 3px solid transparent; }
        .nav-item:hover { color: var(--text-main); background: rgba(0,0,0,0.03); }
        .nav-item.active { color: var(--primary); background: rgba(37,99,235,0.08); border-left-color: var(--primary); font-weight: 500; }
        .nav-icon { width: 20px; height: 20px; fill: currentColor; }
        .main-content { flex-grow: 1; overflow-y: auto; padding: 2rem; background: var(--bg-base); }
        .header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 2.5rem; }
        .header h1 { font-size: 1.8rem; margin: 0; }
        .status-badge { background: #ffffff; color: var(--success); padding: 0.4rem 0.8rem; border-radius: 20px; font-size: 0.875rem; display: flex; align-items: center; gap: 0.5rem; border: 1px solid var(--border); box-shadow: 0 2px 5px rgba(0,0,0,0.02); }
        .status-dot { width: 8px; height: 8px; border-radius: 50%; background: var(--success); box-shadow: 0 0 8px var(--success); transition: background 0.3s; }
        .status-dot.offline { background: var(--danger); box-shadow: 0 0 8px var(--danger); }
        .tab-pane { display: none; animation: fadeIn 0.4s ease forwards; } .tab-pane.active { display: block; }
        @keyframes fadeIn { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: translateY(0); } }
        .card { background: var(--bg-card); border-radius: var(--radius); padding: 1.5rem; border: 1px solid var(--border); transition: var(--transition); position: relative; overflow: hidden; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05), 0 2px 4px -1px rgba(0,0,0,0.03); }
        .card:hover { border-color: #cbd5e1; transform: translateY(-3px); box-shadow: 0 10px 15px -3px rgba(0,0,0,0.08), 0 4px 6px -2px rgba(0,0,0,0.04); }
        .sensor-card .temp-display { font-size: 3rem; font-weight: 700; color: var(--text-main); margin: 1rem 0; }
        .sensor-card .temp-unit { font-size: 1.5rem; color: var(--text-muted); font-weight: normal; }
        .sensor-card .meta { display: flex; justify-content: space-between; font-size: 0.875rem; color: var(--text-muted); }
        .sensor-card .port-badge { position: absolute; top: 1rem; right: 1rem; background: var(--bg-base); color: var(--primary); border: 1px solid var(--border); padding: 0.2rem 0.6rem; border-radius: 6px; font-family: monospace; font-size: 0.75rem; font-weight: 600; }
        .dashboard-grid { grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); }
        .devices-grid { grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); }
        .device-row { display: flex; align-items: center; justify-content: space-between; margin-bottom: 0.5rem; }
        .stats-grid { grid-template-columns: repeat(3, 1fr); margin-bottom: 2rem; }
        .stat-card h3 { font-size: 0.875rem; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.5px; }
        .stat-card .value { font-size: 2rem; font-weight: bold; margin-top: 0.5rem; }
        .progress-bar-container { width: 100%; height: 8px; background: var(--bg-panel); border-radius: 4px; overflow: hidden; margin-top: 1rem; }
        .progress-bar { height: 100%; background: var(--primary); width: 0%; transition: width 1s ease; }
        .chart-placeholder { height: 250px; background: var(--bg-base); border-radius: 8px; border: 1px dashed var(--border); display: flex; align-items: center; justify-content: center; color: var(--text-muted); margin-top: 1.5rem; }
        .alert-item { padding: 1rem; border-left: 4px solid var(--warning); background: var(--bg-card); display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem; border-radius: 0 var(--radius) var(--radius) 0; }
        .alert-item.critical { border-left-color: var(--danger); }
        .slider-container { margin: 1.5rem 0; }
        .slider-container label { display: flex; justify-content: space-between; margin-bottom: 0.5rem; }
        input[type="range"] { width: 100%; accent-color: var(--primary); }
        ::-webkit-scrollbar { width: 8px; } ::-webkit-scrollbar-track { background: var(--bg-base); } ::-webkit-scrollbar-thumb { background: var(--border); border-radius: 4px; }
        @media (max-width: 768px) {
            body, #app { flex-direction: column; } .sidebar { width: 100%; height: auto; padding: 0; border-right: none; border-bottom: none; border-top: 1px solid var(--border); display: block; order: 2; z-index: 1000; background: var(--bg-panel); }
            .brand { display: none; } .mobile-logo { display: block !important; } nav { display: flex; flex-direction: row; overflow-x: auto; width: 100%; white-space: nowrap; justify-content: space-between; } .nav-item { flex: 1; justify-content: center; align-items: center; padding: 0.75rem; flex-direction: column; gap: 0.2rem; font-size: 0.65rem; border-left: none; border-bottom: 3px solid transparent; } .nav-item.active { border-bottom-color: var(--primary); border-left-color: transparent; }
            .nav-item span { font-size: 0.65rem; } .main-content { padding: 0.75rem; order: 1; overflow-y: auto; flex-grow: 1; } .stats-grid { grid-template-columns: 1fr; }
            .header { flex-direction: column; align-items: flex-start; gap: 0.5rem; margin-bottom: 1.5rem; }
            .header h1 { font-size: 1.3rem; }
            .status-badge { font-size: 0.72rem; padding: 0.3rem 0.6rem; }
            .devices-grid { grid-template-columns: 1fr; }
            .dashboard-grid { grid-template-columns: 1fr; }
            .card { padding: 1rem; }
        }
    </style>
</head>
<body>
    <div id="login-screen">
        <div class="login-box">
            <div style="display: flex; justify-content: center; margin-bottom: 1rem;">
                <svg width="180" height="70" viewBox="0 0 160 80" xmlns="http://www.w3.org/2000/svg">
                    <path d="M 5 50 L 5 30 L 40 20 L 75 30" fill="none" stroke="var(--primary)" stroke-width="2.5" />
                    <path d="M 35 50 L 5 50" fill="none" stroke="var(--primary)" stroke-width="2.5" />
                    <rect x="25" y="30" width="16" height="16" fill="var(--primary)"/>
                    <path d="M 33 30 v 16 M 25 38 h 16" stroke="var(--bg-card)" stroke-width="1.5"/>
                    <path d="M 30 23 v -8 h -8 v 4" fill="none" stroke="var(--primary)" stroke-width="2.5"/>
                    <circle cx="22" cy="19" r="3" fill="var(--primary)"/>
                    <path d="M 50 23 v -8 h 8 v 4" fill="none" stroke="var(--primary)" stroke-width="2.5"/>
                    <circle cx="58" cy="19" r="3" fill="var(--primary)"/>
                    <path d="M 20 65 Q 40 10 110 42" fill="none" stroke="var(--primary)" stroke-width="1.2"/>
                    <text x="58" y="44" font-family="'Segoe UI', Roboto, sans-serif" font-weight="300" font-size="28" fill="var(--primary)" letter-spacing="-1">RiCH</text>
                    <text x="36" y="70" font-family="'Times New Roman', Georgia, serif" font-size="11" fill="var(--text-main)">Advanced Technology</text>
                </svg>
            </div>
            <h2>Hub Admin Access</h2>
            <form id="login-form">
                <div class="input-group">
                    <label>Username</label>
                    <input type="text" id="username" required>
                </div>
                <div class="input-group">
                    <label>Password</label>
                    <input type="password" id="password" required>
                </div>
                <button type="submit">Login to System</button>
                <div id="login-error" style="color:var(--danger); margin-top:1rem; display:none;">Invalid Credentials</div>
            </form>
        </div>
    </div>

    <div id="app">
        <aside class="sidebar">
            <div class="brand" style="justify-content: center; padding: 1.5rem 0;">
                <svg width="180" height="70" viewBox="0 0 160 80" xmlns="http://www.w3.org/2000/svg">
                    <path d="M 5 50 L 5 30 L 40 20 L 75 30" fill="none" stroke="var(--primary)" stroke-width="2.5" />
                    <path d="M 35 50 L 5 50" fill="none" stroke="var(--primary)" stroke-width="2.5" />
                    <rect x="25" y="30" width="16" height="16" fill="var(--primary)"/>
                    <path d="M 33 30 v 16 M 25 38 h 16" stroke="var(--bg-card)" stroke-width="1.5"/>
                    <path d="M 30 23 v -8 h -8 v 4" fill="none" stroke="var(--primary)" stroke-width="2.5"/>
                    <circle cx="22" cy="19" r="3" fill="var(--primary)"/>
                    <path d="M 50 23 v -8 h 8 v 4" fill="none" stroke="var(--primary)" stroke-width="2.5"/>
                    <circle cx="58" cy="19" r="3" fill="var(--primary)"/>
                    <path d="M 20 65 Q 40 10 110 42" fill="none" stroke="var(--primary)" stroke-width="1.2"/>
                    <text x="58" y="44" font-family="'Segoe UI', Roboto, sans-serif" font-weight="300" font-size="28" fill="var(--primary)" letter-spacing="-1">RiCH</text>
                    <text x="36" y="70" font-family="'Times New Roman', Georgia, serif" font-size="11" fill="var(--text-main)">Advanced Technology</text>
                </svg>
            </div>
            <nav>
                <a class="nav-item active" data-tab="home"><svg class="nav-icon" viewBox="0 0 24 24"><path d="M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z"/></svg><span> Dashboard</span></a>
                <a class="nav-item" data-tab="devices"><svg class="nav-icon" viewBox="0 0 24 24"><path d="M4 6h16v2H4zm0 5h16v2H4zm0 5h16v2H4z"/></svg><span> Devices</span></a>
                <a class="nav-item" data-tab="analytics"><svg class="nav-icon" viewBox="0 0 24 24"><path d="M3 3v18h18M7 16l4-4 4 4 5-6"/></svg><span> Analytics</span></a>
                <a class="nav-item" data-tab="alerts"><svg class="nav-icon" viewBox="0 0 24 24"><path d="M12 22c1.1 0 2-.9 2-2h-4c0 1.1.9 2 2 2zm6-6v-5c0-3.07-1.64-5.64-4.5-6.32V4c0-.83-.67-1.5-1.5-1.5s-1.5.67-1.5 1.5v.68C7.63 5.36 6 7.92 6 11v5l-2 2v1h16v-1l-2-2z"/></svg><span> Alerts</span></a>
                <a class="nav-item" data-tab="settings"><svg class="nav-icon" viewBox="0 0 24 24"><path d="M19.14 12.94c.04-.3.06-.61.06-.94 0-.32-.02-.64-.06-.94l2.03-1.58c.18-.14.23-.41.12-.61l-1.92-3.32c-.12-.22-.37-.29-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54c-.04-.24-.24-.41-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.56-1.62.94l-2.39-.96c-.22-.08-.47 0-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.04.3-.06.63-.06.94s.02.64.06.94l-2.03 1.58c-.18.14-.23.41-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.49-.12-.61l-2.01-1.58zM12 15.6c-1.98 0-3.6-1.62-3.6-3.6s1.62-3.6 3.6-3.6 3.6 1.62 3.6 3.6-1.62 3.6-3.6 3.6z"/></svg><span> Settings</span></a>
            </nav>
        </aside>

        <main class="main-content">
            <header class="header">
                <div>
                    <div style="display:flex; align-items:center; gap:0.75rem;">
                        <svg class="mobile-logo" style="display:none; height:32px;" width="80" viewBox="0 0 160 80" xmlns="http://www.w3.org/2000/svg">
                            <path d="M 5 50 L 5 30 L 40 20 L 75 30" fill="none" stroke="var(--primary)" stroke-width="2.5" />
                            <path d="M 35 50 L 5 50" fill="none" stroke="var(--primary)" stroke-width="2.5" />
                            <rect x="25" y="30" width="16" height="16" fill="var(--primary)"/>
                            <path d="M 33 30 v 16 M 25 38 h 16" stroke="var(--bg-card)" stroke-width="1.5"/>
                            <path d="M 30 23 v -8 h -8 v 4" fill="none" stroke="var(--primary)" stroke-width="2.5"/>
                            <circle cx="22" cy="19" r="3" fill="var(--primary)"/>
                            <path d="M 50 23 v -8 h 8 v 4" fill="none" stroke="var(--primary)" stroke-width="2.5"/>
                            <circle cx="58" cy="19" r="3" fill="var(--primary)"/>
                            <path d="M 20 65 Q 40 10 110 42" fill="none" stroke="var(--primary)" stroke-width="1.2"/>
                            <text x="58" y="44" font-family="'Segoe UI', Roboto, sans-serif" font-weight="300" font-size="28" fill="var(--primary)" letter-spacing="-1">RiCH</text>
                        </svg>
                        <h1 id="tab-title" style="margin:0;">RoomAlert Dashboard</h1>
                    </div>
                    <p style="margin-top:0.5rem;"><span id="tab-desc">Monitor live temperature data from connected sensors.</span> <span id="local-ip" style="background: rgba(0,0,0,0.05); padding: 0.2rem 0.4rem; border-radius: 4px; font-family: monospace; font-size:0.75rem; border: 1px solid var(--border); margin-left: 0.5rem;">IP Unknown</span></p>
                </div>
                <div class="status-badge" id="hub-status">
                    <div class="status-dot" id="online-dot"></div>
                    <span id="online-text">System Online</span> &middot; <span id="clock">00:00</span>
                </div>
            </header>

            <div id="tab-home" class="tab-pane active">
                <div class="grid dashboard-grid gap-6" id="active-sensors-container"></div>
                <div id="no-sensors" class="card hidden" style="text-align: center; padding: 3rem;">
                    <h3 style="color: var(--text-muted);">No Active Sensors</h3>
                    <p>Connect a supported sensor to one of the available ports.</p>
                </div>
                <div class="card" style="margin-top: 1.5rem;">
                    <div class="flex justify-between items-center">
                        <div>
                            <h2>Auxiliary Relay</h2>
                            <p style="margin-top:0.25rem;">Control connected auxiliary devices.</p>
                        </div>
                        <label style="display:flex;align-items:center;gap:0.75rem;cursor:pointer;">
                            <span id="relay-label" style="font-weight:600;color:var(--text-muted);">OFF</span>
                            <div id="relay-switch" onclick="toggleRelay()" style="width:52px;height:28px;background:var(--border);border-radius:14px;position:relative;cursor:pointer;transition:background 0.3s;">
                                <div id="relay-knob" style="position:absolute;top:3px;left:3px;width:22px;height:22px;background:white;border-radius:50%;transition:left 0.3s;box-shadow:0 1px 4px rgba(0,0,0,0.2);"></div>
                            </div>
                        </label>
                    </div>
                </div>
            </div>

            <div id="tab-devices" class="tab-pane">
                <div class="grid devices-grid gap-6" id="all-ports-container"></div>
            </div>

            <div id="tab-analytics" class="tab-pane">
                <div class="grid stats-grid gap-6">
                    <div class="card stat-card"><h3>Avg Temperature</h3><div class="value" id="stat-avg">--<span style="font-size: 1rem; color: var(--text-muted)">°C</span></div></div>
                    <div class="card stat-card"><h3>Connected Ports</h3><div class="value" id="stat-ports">0/0</div></div>
                    <div class="card stat-card"><h3>System Uptime</h3><div class="value" id="stat-uptime">0h</div></div>
                </div>

                <div class="card" style="margin-bottom: 2rem;">
                    <div class="flex justify-between items-center">
                        <h2>SD Card Storage</h2>
                        <span id="sd-percentage" style="font-weight: bold; color: var(--primary);">0% Used</span>
                    </div>
                    <p id="sd-details">Capacity: -- | Used: -- | Free: --</p>
                    <div class="progress-bar-container"><div class="progress-bar" id="sd-bar" style="width: 0%;"></div></div>
                    <div class="flex gap-4" style="margin-top: 1.5rem;">
                        <button onclick="downloadCSV()">Download CSV</button>
                        <button class="danger" onclick="clearData()">Format / Clear Log</button>
                    </div>
                </div>
            </div>

            <div id="tab-alerts" class="tab-pane">
                <div class="card" style="margin-bottom: 2rem;">
                    <div class="flex justify-between items-center" style="margin-bottom: 1rem;">
                        <h2>Alarm Configuration</h2>
                        <button style="width: auto; padding: 0.5rem 1rem;" class="danger" onclick="apiCall('/api/buzzer')">Test Buzzer</button>
                    </div>
                    <div class="slider-container" style="margin-top: 2rem;">
                        <label><span>Global Max Alert</span><span id="max-val-display" style="color: var(--danger); font-weight: bold;">125°C</span></label>
                        <input type="range" id="max-temp" min="-55" max="125" value="125" oninput="document.getElementById('max-val-display').innerText = convertTemp(this.value) + getUnitString()">
                    </div>
                    <div class="slider-container">
                        <label><span>Global Min Alert</span><span id="min-val-display" style="color: var(--primary); font-weight: bold;">-55°C</span></label>
                        <input type="range" id="min-temp" min="-55" max="125" value="-55" oninput="document.getElementById('min-val-display').innerText = convertTemp(this.value) + getUnitString()">
                    </div>
                    <button style="margin-top: 1rem;" onclick="saveThresholds()">Save Rules</button>
                </div>
            </div>

            <div id="tab-settings" class="tab-pane">
                <div class="grid gap-6" style="grid-template-columns: repeat(auto-fit, minmax(min(400px,100%), 1fr));">
                    <div class="card">
                        <h2>Wi-Fi Configuration</h2>
                        <p style="margin-bottom: 1.5rem;">Connect to an existing Wi-Fi router for broader network access.</p>
                        <div class="input-group">
                            <label>Network Name (SSID)</label>
                            <input type="text" id="wifi-ssid" placeholder="Ex: MyHomeNetwork">
                        </div>
                        <div class="input-group" style="margin-top: 1rem;">
                            <label>Wi-Fi Password</label>
                            <input type="password" id="wifi-pass" placeholder="Enter password">
                        </div>
                        <button style="margin-top: 1.5rem;" onclick="saveWifi()">Save & Reboot</button>
                    </div>

                    <div class="card">
                        <h2>Admin Credentials</h2>
                        <div class="input-group"><label>New Password</label><input type="password" id="new-pwd"></div>
                        <button onclick="updateCreds()">Update Password</button>
                    </div>
                    <div class="card">
                        <h2>Display Preferences</h2>
                        <div class="input-group">
                            <label>Temperature Unit</label>
                            <select id="unit-select" onchange="changeUnit(this.value)" style="width: 100%; padding: 0.75rem 1rem; background: var(--bg-base); border: 1px solid var(--border); color: var(--text-main); border-radius: 8px; font-size: 1rem;">
                                <option value="C">Celsius (°C)</option>
                                <option value="F">Fahrenheit (°F)</option>
                            </select>
                        </div>
                    </div>
                    <div class="card">
                        <h2>Hub Clock</h2>
                        <p style="margin-bottom:1rem;">Sync the RTC with your device's current time.</p>
                        <button onclick="syncTime()">Sync Hub Time</button>
                    </div>
                </div>
                <div class="card" style="margin-top: 1.5rem;">
                    <div class="flex justify-between items-center" style="margin-bottom: 0.5rem;">
                        <div>
                            <h2 style="margin-bottom:0.25rem;">Sensor Calibration</h2>
                            <p style="font-size:0.8rem;">Fine-tune each zone's reading by adding or subtracting a fixed offset.</p>
                        </div>
                    </div>
                    <div id="calibration-grid" style="display:grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 0.75rem; margin-top: 1rem;"></div>
                </div>
                <div class="card" style="margin-top: 1.5rem;">
                    <h2 style="margin-bottom:0.25rem;">Firmware Update</h2>
                    <p style="font-size:0.8rem;">Upload a compiled <code>.bin</code> firmware file to update the device over Wi-Fi. The device will reboot automatically when done. Do not power off during the update.</p>
                    <div style="display:flex; gap:0.75rem; align-items:center; margin-top:1rem; flex-wrap:wrap;">
                        <input type="file" id="ota-file" accept=".bin" style="flex:1; min-width:200px;">
                        <button style="width:auto; padding:0.5rem 1.5rem;" onclick="otaUpload()">Upload &amp; Flash</button>
                    </div>
                    <div id="ota-status" style="margin-top:0.75rem; font-size:0.85rem; color: var(--text-muted);"></div>
                </div>
                <div class="card" style="margin-top: 1.5rem; text-align: center;">
                    <button class="danger" style="width: auto; margin: 0 auto; padding: 0.75rem 2rem;" onclick="rebootHub()">Reboot Hub</button>
                </div>
            </div>
        </main>
    </div>

    <script>
    let authHeader = "";
    let ports = [];
    let currentUnit = localStorage.getItem('tempUnit') || 'C';
    let isFetching = false; // LOCK: Prevents multiple simultaneous requests

    function convertTemp(tC) {
        const val = Number(tC);
        if (currentUnit === 'F') return ((val * 9/5) + 32).toFixed(1);
        return val.toFixed(1);
    }

    function getUnitString() {
        return '°' + currentUnit;
    }

    function changeUnit(u) {
        currentUnit = u;
        localStorage.setItem('tempUnit', u);
        renderActiveSensors();
        renderAllPorts();
        updateAnalyticsFromPorts();
    }

    document.getElementById('login-form').addEventListener('submit', async (e) => {
        e.preventDefault();
        const u = document.getElementById('username').value;
        const p = document.getElementById('password').value;
        authHeader = "Basic " + btoa(u + ":" + p);
        
        // Use POST for auth to match the C++ logic better
        const result = await apiCall('/api/auth', 'POST'); 
        if(result) {
            document.getElementById('login-screen').style.opacity = '0';
            setTimeout(() => {
                document.getElementById('login-screen').style.display = 'none';
                document.getElementById('app').style.display = 'flex';
                initDashboard();
            }, 500);
        } else {
            document.getElementById('login-error').style.display = 'block';
        }
    });

    async function apiCall(endpoint, method = 'POST', body = null) {
        try {
            const res = await fetch(endpoint, {
                method: method,
                headers: {
                    'Authorization': authHeader,
                    'Content-Type': 'application/json'
                },
                body: body ? JSON.stringify(body) : undefined
            });
            if (res.ok) {
                const text = await res.text();
                return text ? JSON.parse(text) : {status: "ok"};
            }
            if (res.status === 401) alert("Session expired. Please reload.");
            return null;
        } catch(e) {
            console.error("Connection dropped", e);
            return null;
        }
    }

    async function fetchStatus() {
        if (isFetching) return;
        isFetching = true;
        const data = await apiCall('/api/status', 'GET');
        isFetching = false;
        if (data) {
            ports = data.ports;
            renderActiveSensors();
            renderAllPorts();
            updateAnalytics(data);
            document.getElementById('online-dot').classList.remove('offline');
            document.getElementById('online-text').innerText = "System Online";
        } else {
            document.getElementById('online-dot').classList.add('offline');
            document.getElementById('online-text').innerText = "Connecting...";
        }
    }

    function initDashboard() {
        // Wire up tab navigation
        document.querySelectorAll('.nav-item').forEach(item => {
            item.addEventListener('click', () => {
                const tab = item.getAttribute('data-tab');
                document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
                document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));
                item.classList.add('active');
                document.getElementById('tab-' + tab).classList.add('active');
                const titles = {home:'RoomAlert Dashboard',devices:'All Ports (Devices)',analytics:'Analytics & SD Card',alerts:'Alerts & Rules',settings:'Settings'};
                const descs = {home:'Monitor live temperature data from connected sensors.',devices:'Configure and monitor all physical sensor ports.',analytics:'View data trends and manage SD card storage.',alerts:'Configure thresholds and buzzer triggers.',settings:'Configure user credentials and network.'};
                document.getElementById('tab-title').innerText = titles[tab] || tab;
                if(document.getElementById('tab-desc')) document.getElementById('tab-desc').innerText = descs[tab] || '';
            });
        });

        setInterval(() => { 
            document.getElementById('clock').innerText = new Date().toLocaleTimeString(); 
        }, 1000);
        fetchStatus();
        setInterval(fetchStatus, 4000); // Increased to 4s for stability
    }

        function renderActiveSensors() {
            const container = document.getElementById('active-sensors-container');
            const noSensors = document.getElementById('no-sensors');
            container.innerHTML = '';
            
            const active = ports.filter(p => p.conn);
            if(active.length === 0) noSensors.classList.remove('hidden');
            else noSensors.classList.add('hidden');

            active.forEach(p => {
                let colorClass = 'var(--text-main)';
                let glowClass = 'none';
                if (p.temp > 28) colorClass = 'var(--warning)';
                if (p.temp > 30) { colorClass = 'var(--danger)'; glowClass = '0 0 15px var(--danger-glow)'; }

                container.innerHTML += `
                    <div class="card sensor-card">
                        <div class="port-badge">PORT ${p.id}</div>
                        <h3 style="color: var(--text-main); font-weight: 600;">${p.name}</h3>
                        <div class="temp-display" style="color: ${colorClass}; text-shadow: ${glowClass};">
                            <span>${convertTemp(p.temp)}</span><span class="temp-unit">${getUnitString()}</span>
                        </div>
                        <div class="meta"><span><span style="color: var(--success); font-weight: bold; margin-right: 4px;">●</span>Online</span></div>
                    </div>
                `;
            });
        }

        function renderAllPorts() {
            const container = document.getElementById('all-ports-container');
            if(container.children.length === 0) {
                ports.forEach(p => {
                    const stat = p.conn ? `<span id="stat-${p.id}" style="color:var(--success);">CONN (${convertTemp(p.temp)}${getUnitString()})</span>` : `<span id="stat-${p.id}" style="color:var(--text-muted);">DISCONN</span>`;
                    container.innerHTML += `
                        <div class="card">
                            <div class="device-row"><h3>Port ${p.id}</h3>${stat}</div>
                            <div class="input-group" style="margin-top: 1rem;">
                                <label>Zone Name</label>
                                <input type="text" value="${p.name}" id="rename-${p.id}">
                            </div>
                            <button onclick="renamePort(${p.id})" style="margin-top:0.5rem">Save Name</button>
                        </div>
                    `;
                });
            } else {
                ports.forEach(p => {
                    const statSpan = document.getElementById(`stat-${p.id}`);
                    if (statSpan) {
                         if (p.conn) {
                             statSpan.style.color = 'var(--success)';
                             statSpan.innerText = `CONN (${convertTemp(p.temp)}${getUnitString()})`;
                         } else {
                             statSpan.style.color = 'var(--text-muted)';
                             statSpan.innerText = 'DISCONN';
                         }
                    }
                });
            }
        }

        function updateAnalytics(data) {
            window.bootEpoch = Date.now()/1000 - (data.uptime || 0);
            const active = ports.filter(p => p.conn);
            document.getElementById('stat-ports').innerText = `${active.length}/${ports.length}`;
            if(active.length > 0) {
                const avg = active.reduce((sum, p) => sum + p.temp, 0) / active.length;
                document.getElementById('stat-avg').innerHTML = `${convertTemp(avg)}<span style="font-size: 1rem; color: var(--text-muted)">${getUnitString()}</span>`;
            }
            document.getElementById('stat-uptime').innerText = `${((data.uptime || 0)/3600).toFixed(1)}h`;
            
            if(data.sd) {
                document.getElementById('sd-percentage').innerText = `${data.sd.used}% Used`;
                document.getElementById('sd-bar').style.width = `${data.sd.used}%`;
                document.getElementById('sd-details').innerText = `Capacity: ${data.sd.cap} GB`;
            }

            // Update relay toggle UI
            if (data.relay !== undefined) {
                const on = data.relay === true;
                document.getElementById('relay-switch').style.background = on ? 'var(--success)' : 'var(--border)';
                document.getElementById('relay-knob').style.left = on ? '27px' : '3px';
                document.getElementById('relay-label').innerText = on ? 'ON' : 'OFF';
                document.getElementById('relay-label').style.color = on ? 'var(--success)' : 'var(--text-muted)';
                window.relayOn = on;
            }
            if(data.ip) {
                document.getElementById('local-ip').innerText = data.ip;
            }
            
            if (data.thresholds) {
                document.getElementById('max-temp').value = data.thresholds.max;
                document.getElementById('max-val-display').innerText = convertTemp(data.thresholds.max) + getUnitString();
                document.getElementById('min-temp').value = data.thresholds.min;
                document.getElementById('min-val-display').innerText = convertTemp(data.thresholds.min) + getUnitString();
            }
            if (data.offsets) {
                window.sensorOffsets = data.offsets;
                renderCalibration();
            }
        }

        function updateAnalyticsFromPorts() {
            const active = ports.filter(p => p.conn);
            if(active.length > 0) {
                const avg = active.reduce((sum, p) => sum + p.temp, 0) / active.length;
                document.getElementById('stat-avg').innerHTML = `${convertTemp(avg)}<span style="font-size: 1rem; color: var(--text-muted)">${getUnitString()}</span>`;
            }
        }

        async function renamePort(id) {
            const name = document.getElementById(`rename-${id}`).value;
            const res = await apiCall('/api/rename?id=' + id + '&name=' + encodeURIComponent(name), 'POST');
            if (res) fetchStatus();
        }

        function renderCalibration() {
            const grid = document.getElementById('calibration-grid');
            if (!grid || !window.sensorOffsets || !ports.length) return;
            // Only build once
            if (grid.children.length === 0) {
                ports.forEach((p, i) => {
                    const val = (window.sensorOffsets[i] || 0).toFixed(2);
                    grid.innerHTML += `
                        <div style="background:var(--bg-base);padding:0.75rem;border-radius:8px;border:1px solid var(--border);">
                            <label style="display:block;font-size:0.78rem;color:var(--text-muted);margin-bottom:0.35rem;">${p.name} <span style="opacity:0.5;">(Port ${p.id})</span></label>
                            <div style="display:flex;gap:0.5rem;align-items:center;">
                                <input type="number" id="offset-${p.id}" value="${val}" step="0.1" style="flex:1;padding:0.5rem;font-size:0.875rem;text-align:center;">
                                <span style="font-size:0.78rem;color:var(--text-muted);white-space:nowrap;">±°C</span>
                                <button onclick="saveOffset(${p.id})" style="width:auto;padding:0.5rem 0.75rem;font-size:0.78rem;">Set</button>
                            </div>
                        </div>
                    `;
                });
            } else {
                // Update values only if not focused
                ports.forEach((p, i) => {
                    const inp = document.getElementById(`offset-${p.id}`);
                    if (inp && document.activeElement !== inp) {
                        inp.value = (window.sensorOffsets[i] || 0).toFixed(2);
                    }
                });
            }
        }

        async function saveOffset(id) {
            const inp = document.getElementById(`offset-${id}`);
            const val = parseFloat(inp.value) || 0;
            const res = await apiCall('/api/offset?id=' + id + '&val=' + val, 'POST');
            if (res) {
                inp.style.borderColor = 'var(--success)';
                setTimeout(() => { inp.style.borderColor = ''; }, 1500);
            }
        }

        async function saveWifi() {
            const ssid = document.getElementById('wifi-ssid').value;
            const pass = document.getElementById('wifi-pass').value;
            if(!ssid) return alert("Please enter an SSID.");
            const res = await apiCall('/api/wifi?ssid=' + encodeURIComponent(ssid) + '&pass=' + encodeURIComponent(pass), 'POST');
            if(res) {
                alert("Wi-Fi credentials saved! Hub is rebooting to connect to the new network. Please reconnect manually in 15 seconds.");
                setTimeout(() => location.reload(), 15000);
            }
        }

        async function saveThresholds() {
            const maxT = document.getElementById('max-temp').value;
            const minT = document.getElementById('min-temp').value;
            const res = await apiCall('/api/thresholds?max=' + maxT + '&min=' + minT, 'POST');
            if(res) alert("Threshold rules saved!");
        }

        async function toggleRelay() {
            const newState = !(window.relayOn || false);
            const result = await apiCall('/api/relay?state=' + (newState ? '1' : '0'), 'POST');
            if (result) {
                // Use confirmed state from server, not just assumption
                const on = result.relay === true;
                window.relayOn = on;
                document.getElementById('relay-switch').style.background = on ? 'var(--success)' : 'var(--border)';
                document.getElementById('relay-knob').style.left = on ? '27px' : '3px';
                document.getElementById('relay-label').innerText = on ? 'ON' : 'OFF';
                document.getElementById('relay-label').style.color = on ? 'var(--success)' : 'var(--text-muted)';
            }
        }

        async function clearData() {
            if(confirm("Clear all logged data?")) {
                await apiCall('/api/sd/clear', 'POST');
                document.getElementById('sd-bar').style.width = '0%';
                document.getElementById('sd-percentage').innerText = '0% Used';
            }
        }

        async function downloadCSV() {
            try {
                const res = await fetch('/api/sd/download', {headers: {'Authorization': authHeader}});
                if(res.ok) {
                    const blob = await res.blob();
                    const url = window.URL.createObjectURL(blob);
                    const a = document.createElement('a');
                    a.href = url;
                    // Use Content-Disposition filename from server, or fallback to timestamped name
                    const cd = res.headers.get('Content-Disposition');
                    let fname = 'RoomAlert_' + new Date().toISOString().slice(0,10) + '.csv';
                    if (cd) {
                        const match = cd.match(/filename="?([^"]+)"?/);
                        if (match) fname = match[1];
                    }
                    a.download = fname;
                    a.click();
                    window.URL.revokeObjectURL(url);
                } else if (res.status === 404) {
                    alert('No data logged yet. The log file is empty or missing.');
                } else {
                    alert('Download failed. Please try again.');
                }
            } catch(e) { alert('Network error. Is the Hub connected?'); }
        }

        async function syncTime() {
            try {
                const res = await fetch('/api/sync_time', {
                    method: 'POST',
                    headers: {'Authorization': authHeader, 'Content-Type': 'application/json'},
                    body: JSON.stringify({unixtime: Math.floor(Date.now() / 1000)})
                });
                if (res.ok) alert('Hub clock synchronized!');
            } catch(e) { alert('Sync failed.'); }
        }

        async function rebootHub() {
            if (!confirm('Reboot the Hub? You will need to wait ~10 seconds for it to restart.')) return;
            try {
                await fetch('/api/reboot', {
                    method: 'POST',
                    headers: {'Authorization': authHeader},
                });
            } catch(e) { /* connection drops on reboot, that is expected */ }
            alert('Hub is rebooting…');
        }

        async function updateCreds() {
            const newPwd = document.getElementById('new-pwd').value;
            if (!newPwd) { alert('Enter a new password'); return; }
            await apiCall('/api/update_credentials', 'POST', {password: newPwd});
            alert('Password updated.');
        }

        function otaUpload() {
            const input = document.getElementById('ota-file');
            const status = document.getElementById('ota-status');
            const file = input.files[0];
            if (!file) { alert('Choose a .bin firmware file first'); return; }
            if (!confirm('Flash "' + file.name + '" to the device? It will reboot when finished.')) return;

            const form = new FormData();
            form.append('firmware', file, file.name);

            const xhr = new XMLHttpRequest();
            xhr.open('POST', '/api/ota', true);
            xhr.setRequestHeader('Authorization', authHeader);

            xhr.upload.onprogress = (e) => {
                if (e.lengthComputable) {
                    const pct = Math.round((e.loaded / e.total) * 100);
                    status.style.color = 'var(--text-muted)';
                    status.innerText = 'Uploading… ' + pct + '%';
                }
            };
            xhr.onload = () => {
                if (xhr.status === 200) {
                    status.style.color = 'var(--success, #22c55e)';
                    status.innerText = 'Upload complete. Device is rebooting — reconnect in ~15 seconds.';
                } else {
                    status.style.color = 'var(--danger, #ef4444)';
                    status.innerText = 'Update failed (HTTP ' + xhr.status + '). Try again.';
                }
            };
            xhr.onerror = () => {
                // Connection drops as the device reboots after a successful flash.
                status.style.color = 'var(--text-muted)';
                status.innerText = 'Connection closed — if the upload reached 100%, the device is rebooting. Reconnect in ~15 seconds.';
            };
            status.style.color = 'var(--text-muted)';
            status.innerText = 'Uploading… 0%';
            xhr.send(form);
        }
    </script>
</body>
</html>
)=====" ;