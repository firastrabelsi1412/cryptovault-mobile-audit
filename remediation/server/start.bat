@echo off
REM ✅ Lance le backend SECURISE (Express + HTTPS + JWT RS256).
REM    Remplace l'ancien json-server --routes routes.json.
cd /d "%~dp0"
if not exist node_modules ( echo Installing deps... && npm install )
set PORT=3000
set HOST=0.0.0.0
REM IPs autorisees a appeler /admin (en plus du role admin). Localhost par defaut.
set ADMIN_IPS=127.0.0.1,::1,::ffff:127.0.0.1
echo [CryptoVault] SECURED API (HTTPS) on :3000  (real device: --dart-define=API_HOST=YOUR_LAN_IP)
node server.js
