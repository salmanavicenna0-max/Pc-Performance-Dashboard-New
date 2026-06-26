import psutil
from fastapi import FastAPI, WebSocket, Request
from fastapi.responses import HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import asyncio
import json
import os
import subprocess

try:
    from ping3 import ping
except ImportError:
    ping = None

try:
    import wmi
    w_ohm = wmi.WMI(namespace="root\\OpenHardwareMonitor")
except Exception:
    w_ohm = None

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

html_content = """
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Minimalist System Dashboard</title>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap');
        
        body { 
            font-family: 'Inter', sans-serif; 
            margin: 0; 
            padding: 40px;
            background-color: #f8fafc; 
            color: #1e293b;
        }
        h1 { 
            text-align: center;
            font-size: 2.2rem; 
            color: #0f172a;
            margin-bottom: 40px;
            font-weight: 700;
            letter-spacing: -0.5px;
        }
        .grid-container {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
            gap: 25px;
            max-width: 1200px;
            margin: 0 auto;
        }
        .card {
            background-color: #ffffff;
            padding: 30px 20px;
            border: 1px solid #e2e8f0;
            border-radius: 16px;
            text-align: center;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.02), 0 2px 4px -1px rgba(0, 0, 0, 0.02);
            transition: transform 0.2s ease, box-shadow 0.2s ease;
        }
        .card:hover {
            transform: translateY(-2px);
            box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.05), 0 4px 6px -2px rgba(0, 0, 0, 0.025);
            border-color: #cbd5e1;
        }
        .value { 
            font-size: 3.5rem; 
            font-weight: 700; 
            margin: 15px 0;
            color: #3b82f6;
            line-height: 1;
        }
        .label {
            font-size: 0.95rem;
            color: #64748b;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 1.5px;
        }
        
        /* Control Panel */
        .controls-panel {
            max-width: 1200px;
            margin: 40px auto;
            background-color: #ffffff;
            border: 1px solid #e2e8f0;
            padding: 30px;
            border-radius: 16px;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.02);
            display: flex;
            justify-content: center;
            align-items: center;
            flex-wrap: wrap;
            gap: 30px;
        }
        
        .btn { 
            padding: 12px 24px; 
            font-size: 0.95rem; 
            cursor: pointer; 
            border: none; 
            border-radius: 8px; 
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 1px;
            transition: all 0.2s;
        }
        
        .launcher-section {
            display: flex;
            gap: 15px;
        }
        .btn-steam { background: #1b2838; color: white; }
        .btn-steam:hover { background: #2a475e; box-shadow: 0 4px 10px rgba(27, 40, 56, 0.2); }
        .btn-discord { background: #5865F2; color: white; }
        .btn-discord:hover { background: #4752C4; box-shadow: 0 4px 10px rgba(88, 101, 242, 0.2); }
        
        .notice {
            text-align: center;
            color: #ef4444;
            font-weight: 600;
            display: none;
            background: #fef2f2;
            padding: 15px;
            border-radius: 12px;
            max-width: 1200px;
            margin: 30px auto 0;
            border: 1px solid #fecaca;
        }
    </style>
</head>
<body>
    <h1>System Dashboard</h1>
    
    <div class="grid-container">
        <div class="card">
            <div class="label">Ping</div>
            <div class="value"><span id="ping">0</span> ms</div>
        </div>
        <div class="card">
            <div class="label">CPU Usage</div>
            <div class="value"><span id="cpu_usage">0</span>%</div>
        </div>
        <div class="card">
            <div class="label">CPU Temp</div>
            <div class="value"><span id="cpu_temp">0</span>°C</div>
        </div>
        <div class="card">
            <div class="label">CPU Power</div>
            <div class="value"><span id="cpu_power">N/A</span> W</div>
        </div>
        <div class="card">
            <div class="label">RAM Usage</div>
            <div class="value"><span id="ram_usage">0</span>%</div>
        </div>
        <div class="card">
            <div class="label">GPU Usage</div>
            <div class="value"><span id="gpu_usage">N/A</span>%</div>
        </div>
        <div class="card">
            <div class="label">GPU Temp</div>
            <div class="value"><span id="gpu_temp">N/A</span>°C</div>
        </div>
        <div class="card">
            <div class="label">Storage C:</div>
            <div class="value"><span id="disk_c">0</span> GB</div>
        </div>
    </div>
    
    <div class="controls-panel">
        <div class="launcher-section">
            <button class="btn btn-steam" onclick="launchApp('steam')">Steam</button>
            <button class="btn btn-discord" onclick="launchApp('discord')">Discord</button>
        </div>
    </div>
    
    <div id="ohm-notice" class="notice">
        ⚠️ Open Hardware Monitor belum berjalan. Silakan buka aplikasi OHM agar data Sensor Suhu dan GPU terbaca.
    </div>

    <script>
        var ws = new WebSocket("ws://" + window.location.host + "/ws");
        ws.onmessage = function(event) {
            try {
                var data = JSON.parse(event.data);
                document.getElementById('ping').innerText = data.ping;
                document.getElementById('cpu_usage').innerText = data.cpu_usage;
                document.getElementById('cpu_temp').innerText = data.cpu_temp;
                document.getElementById('cpu_power').innerText = data.cpu_power;
                document.getElementById('ram_usage').innerText = data.ram_usage;
                document.getElementById('gpu_usage').innerText = data.gpu_usage;
                document.getElementById('gpu_temp').innerText = data.gpu_temp;
                document.getElementById('disk_c').innerText = data.disk_c;
                
                if (data.ohm_status === false) {
                    document.getElementById('ohm-notice').style.display = "block";
                } else {
                    document.getElementById('ohm-notice').style.display = "none";
                }
            } catch(e) {
                console.error("Error", e);
            }
        };

        function launchApp(appId) {
            fetch('/api/launch/' + appId, {method: 'POST'});
        }
    </script>
</body>
</html>
"""

@app.get("/")
def get_dashboard():
    return HTMLResponse(content=html_content)

@app.post("/api/launch/{app_id}")
def launch_app(app_id: str):
    if app_id == "steam":
        os.system("start steam://")
    elif app_id == "discord":
        os.system("start discord:")
    return {"status": "ok"}

def get_ohm_data():
    data = {
        "cpu_temp": "N/A", "cpu_power": "N/A",
        "gpu_temp": "N/A", "gpu_usage": "N/A",
        "is_running": False
    }
    
    if not w_ohm:
        return data
        
    try:
        sensors = w_ohm.Sensor()
        if len(sensors) > 0:
            data["is_running"] = True
            
        for s in sensors:
            identifier = str(s.Identifier).lower()
            name = str(s.Name).lower()
            sensor_type = str(s.SensorType).lower()
            if s.Value is None: continue
            value = round(float(s.Value), 1)

            if 'gpu' in identifier:
                if sensor_type == 'temperature' and 'core' in name:
                    data["gpu_temp"] = value
                elif sensor_type == 'load' and 'core' in name:
                    data["gpu_usage"] = value
            elif 'cpu' in identifier:
                if sensor_type == 'temperature' and ('package' in name or 'core' in name):
                    data["cpu_temp"] = value
                elif sensor_type == 'power' and 'package' in name:
                    data["cpu_power"] = value
    except Exception:
        pass
    return data

def get_ping():
    if ping:
        try:
            latency = ping('8.8.8.8', timeout=1)
            if latency is not None:
                return round(latency * 1000)
        except Exception:
            pass
    return "N/A"

def get_disk_c_free():
    try:
        usage = psutil.disk_usage('C:\\')
        free_gb = usage.free / (1024 ** 3)
        return round(free_gb, 1)
    except Exception:
        return "N/A"

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    psutil.cpu_percent(interval=None) 
    
    try:
        while True:
            await asyncio.sleep(1) 
            
            cpu_usage = psutil.cpu_percent(interval=None)
            ram_usage = psutil.virtual_memory().percent
            ohm_data = get_ohm_data()
            latency = get_ping()
            disk_c = get_disk_c_free()
            
            payload = {
                "ping": latency,
                "disk_c": disk_c,
                "cpu_usage": f"{cpu_usage:.1f}",
                "ram_usage": f"{ram_usage:.1f}",
                "cpu_temp": ohm_data["cpu_temp"],
                "cpu_power": ohm_data["cpu_power"],
                "gpu_usage": ohm_data["gpu_usage"],
                "gpu_temp": ohm_data["gpu_temp"],
                "ohm_status": ohm_data["is_running"]
            }
            
            await websocket.send_text(json.dumps(payload))
    except Exception:
        pass

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)