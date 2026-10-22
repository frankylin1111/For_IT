@echo off
:: 啟用延遲擴展，用於處理動態生成的網卡陣列
setlocal EnableDelayedExpansion
title 變更網路卡 IP 設定工具 (不顯示IP快速修改版) By STI-Terrence Ver 20260712

:: 檢查系統管理員權限
net session >nul 2>&1
if %errorlevel% equ 0 goto :INIT_PRESETS

echo ==========================================
echo  [錯誤] 權限不足！
echo  請「以系統管理員身分執行」此腳本。
echo ==========================================
pause
exit /b

:INIT_PRESETS
:: 建立網卡選單對應的字元表 (依照順序排列，並保留 X, Y, Z 給常用 IP 設定使用)
set "map=0123456789ABCDEFGHIJKLMNOPQRSTUVW"

:: ==========================================
:: 常用 IP 設定區 (請在此處修改你的預設值)
:: ==========================================
:: 【常用IP設定 X】
set "SET_X_IP=172.29.133.250"
set "SET_X_MASK=255.255.252.0"
set "SET_X_GW=172.29.128.254"
set "SET_X_DNS1=168.95.1.1"
set "SET_X_DNS2=8.8.4.4"

:: 【常用IP設定 Y】
set "SET_Y_IP=10.20.30.50"
set "SET_Y_MASK=255.255.255.0"
set "SET_Y_GW="
set "SET_Y_DNS1="
set "SET_Y_DNS2="

:: 【常用IP設定 Z】
set "SET_Z_IP=192.168.1.211"
set "SET_Z_MASK=255.255.255.0"
set "SET_Z_GW="
set "SET_Z_DNS1="
set "SET_Z_DNS2="
:: ==========================================

:START_MENU
cls
echo ===================================
echo         網路卡 IP 快速變更工具
echo ===================================
echo.
echo  [系統提示] 正在偵測網路卡，請稍候...
echo.

:: 透過 PowerShell 動態抓取所有網路卡，將「名稱|硬體描述」存入變數
set "idx=0"
for /f "tokens=1* delims=|" %%I in ('powershell -NoProfile -Command "Get-NetAdapter | Sort-Object Name | ForEach-Object { $_.Name + '|' + $_.InterfaceDescription }"') do (
    set /a idx+=1
    set "adapter_!idx!=%%I"
    set "desc_!idx!=%%J"
)
:: 限制最多支援 32 張網卡防呆 (避免超出 map 字元範圍)
if !idx! gtr 32 set idx=32

:: 抓取完畢，重新繪製乾淨的選單畫面
cls
echo ===================================
echo         網路卡 IP 快速變更工具
echo ===================================
echo  請選擇要設定的網路卡 [由系統偵測，順序可能每次不同]：

:: 動態建立 choice 指令的按鍵清單 (一定包含 0)
set "choices=0"
for /l %%N in (1,1,%idx%) do (
    set "char=!map:~%%N,1!"
    set "choices=!choices!!char!"
    echo  !char!. !adapter_%%N! [!desc_%%N!]
)

echo  0. 離開程式
echo ===================================
:: 改用 choice 指令，瞬間觸發
choice /c !choices! /n /m "請選擇快速鍵： "

:: 將 choice 回傳的 errorlevel (1 為基礎) 轉換回索引值 (0 為基礎)
set /a sel=!errorlevel!-1
if "!sel!"=="0" exit /b

set "adapter=!adapter_%sel%!"
goto ACTION_MENU

:ACTION_MENU
cls
echo ===================================
echo  目前選擇的網路卡：【%adapter%】
echo ===================================
echo  1. 手動輸入 IP
echo  2. 恢復為 DHCP (強制清空所有設定)
echo -----------------------------------
echo  X. 套用 常用IP設定 X [%SET_X_IP%]
echo  Y. 套用 常用IP設定 Y [%SET_Y_IP%]
echo  Z. 套用 常用IP設定 Z [%SET_Z_IP%]
echo -----------------------------------
echo  0. 返回上一層重選網卡
echo ===================================
:: 改用 choice 指令，瞬間觸發
choice /c 12XYZ0 /n /m "請選擇快速鍵： "

if !errorlevel! equ 6 goto START_MENU
if !errorlevel! equ 5 goto APPLY_Z
if !errorlevel! equ 4 goto APPLY_Y
if !errorlevel! equ 3 goto APPLY_X
if !errorlevel! equ 2 goto DO_DHCP
if !errorlevel! equ 1 goto SET_IP_MANUAL


:APPLY_X
    set "ip=%SET_X_IP%"
    set "mask=%SET_X_MASK%"
    set "gw=%SET_X_GW%"
    set "dns1=%SET_X_DNS1%"
    set "dns2=%SET_X_DNS2%"
    goto APPLY_IP

:APPLY_Y
    set "ip=%SET_Y_IP%"
    set "mask=%SET_Y_MASK%"
    set "gw=%SET_Y_GW%"
    set "dns1=%SET_Y_DNS1%"
    set "dns2=%SET_Y_DNS2%"
    goto APPLY_IP

:APPLY_Z
    set "ip=%SET_Z_IP%"
    set "mask=%SET_Z_MASK%"
    set "gw=%SET_Z_GW%"
    set "dns1=%SET_Z_DNS1%"
    set "dns2=%SET_Z_DNS2%"
    goto APPLY_IP


:DO_DHCP
echo.
echo 正在清除【%adapter%】的所有靜態設定並轉為 DHCP...
powershell -NoProfile -Command "try { Remove-NetRoute -InterfaceAlias '%adapter%' -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue; Remove-NetIPAddress -InterfaceAlias '%adapter%' -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue; Set-NetIPInterface -InterfaceAlias '%adapter%' -Dhcp Enabled; Set-DnsClientServerAddress -InterfaceAlias '%adapter%' -ResetServerAddresses } catch { }"

:: 重啟網卡設定(把這段程式碼前方:: 移除可自動重啟網卡)
:: echo [提示] 正在重新啟動網卡以重整狀態...
:: netsh interface set interface name="%adapter%" admin=disabled
:: timeout /t 2 /nobreak >nul
:: netsh interface set interface name="%adapter%" admin=enabled

echo.
echo ===================================
echo  [完成] 已設為 DHCP！
echo ===================================
goto SHOW_ALL_IP


:SET_IP_MANUAL
echo.
echo -----------------------------------
echo 開始手動設定【%adapter%】
echo -----------------------------------

:INPUT_IP
set "ip="
set /p ip="1. 請輸入 IP 位址 [必要，例如 192.168.1.100]: "
if "%ip%"=="" echo [錯誤] IP 位址不可空白！ & goto INPUT_IP

:: 嚴格驗證 IP 格式是否為標準 IPv4
powershell -NoProfile -Command "if ('%ip%' -match '^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$') { exit 0 } else { exit 1 }"
if %errorlevel% neq 0 (
    echo [錯誤] IP 格式不正確或超出範圍 0~255！請重新輸入。
    goto INPUT_IP
)

:INPUT_MASK
set "mask="
set /p mask="2. 請輸入 Mask [直接按Enter預設為24 或輸入 255.255.255.X 等]: "
if "%mask%"=="" set "mask=255.255.255.0" & goto MASK_VALIDATED

:: 處理 CIDR (8~30)
if "%mask%"=="8" set "mask=255.0.0.0" & goto MASK_VALIDATED
if "%mask%"=="9" set "mask=255.128.0.0" & goto MASK_VALIDATED
if "%mask%"=="10" set "mask=255.192.0.0" & goto MASK_VALIDATED
if "%mask%"=="11" set "mask=255.224.0.0" & goto MASK_VALIDATED
if "%mask%"=="12" set "mask=255.240.0.0" & goto MASK_VALIDATED
if "%mask%"=="13" set "mask=255.248.0.0" & goto MASK_VALIDATED
if "%mask%"=="14" set "mask=255.252.0.0" & goto MASK_VALIDATED
if "%mask%"=="15" set "mask=255.254.0.0" & goto MASK_VALIDATED
if "%mask%"=="16" set "mask=255.255.0.0" & goto MASK_VALIDATED
if "%mask%"=="17" set "mask=255.255.128.0" & goto MASK_VALIDATED
if "%mask%"=="18" set "mask=255.255.192.0" & goto MASK_VALIDATED
if "%mask%"=="19" set "mask=255.255.224.0" & goto MASK_VALIDATED
if "%mask%"=="20" set "mask=255.255.240.0" & goto MASK_VALIDATED
if "%mask%"=="21" set "mask=255.255.248.0" & goto MASK_VALIDATED
if "%mask%"=="22" set "mask=255.255.252.0" & goto MASK_VALIDATED
if "%mask%"=="23" set "mask=255.255.254.0" & goto MASK_VALIDATED
if "%mask%"=="24" set "mask=255.255.255.0" & goto MASK_VALIDATED
if "%mask%"=="25" set "mask=255.255.255.128" & goto MASK_VALIDATED
if "%mask%"=="26" set "mask=255.255.255.192" & goto MASK_VALIDATED
if "%mask%"=="27" set "mask=255.255.255.224" & goto MASK_VALIDATED
if "%mask%"=="28" set "mask=255.255.255.240" & goto MASK_VALIDATED
if "%mask%"=="29" set "mask=255.255.255.248" & goto MASK_VALIDATED
if "%mask%"=="30" set "mask=255.255.255.252" & goto MASK_VALIDATED

set "ValidMasks= 255.0.0.0 255.128.0.0 255.192.0.0 255.224.0.0 255.240.0.0 255.248.0.0 255.252.0.0 255.254.0.0 255.255.0.0 255.255.128.0 255.255.192.0 255.255.224.0 255.255.240.0 255.255.248.0 255.255.252.0 255.255.254.0 255.255.255.0 255.255.255.128 255.255.255.192 255.255.255.224 255.255.255.240 255.255.255.248 255.255.255.252 "
echo %ValidMasks% | findstr /C:" %mask% " >nul
if %errorlevel% neq 0 (
    echo [錯誤] 格式錯誤或不在允許範圍！
    goto INPUT_MASK
)

:MASK_VALIDATED
echo   -^> 已確認 Mask 為：%mask%

:INPUT_GW
set "gw="
set /p gw="3. 請輸入預設閘道 [選填，直接按 Enter 略過]: "
if "%gw%"=="" goto INPUT_DNS

:: 網段防呆驗證 (Gateway 與 IP 比對，並禁止相同)
powershell -NoProfile -Command "try { $ip=[ipaddress]'%ip%'; $gw=[ipaddress]'%gw%'; $mask=[ipaddress]'%mask%'; if ($ip.Address -eq $gw.Address) { exit 3 }; if (($ip.Address -band $mask.Address) -eq ($gw.Address -band $mask.Address)) { exit 0 } else { exit 1 } } catch { exit 2 }"
if %errorlevel% equ 3 (
    echo [錯誤] 閘道器不能與本機 IP 相同！請重新輸入。
    goto INPUT_GW
)
if %errorlevel% equ 2 (
    echo [錯誤] 閘道器格式輸入錯誤！請重新輸入。
    goto INPUT_GW
)
if %errorlevel% equ 1 (
    echo [錯誤] 閘道器 [%gw%] 與 IP [%ip%] 不在相同網段！ Mask: [%mask%]
    echo        請確認網段是否計算錯誤。
    goto INPUT_GW
)
echo   -^> 網段驗證通過！


:INPUT_DNS
set "dns1="
set /p dns1="4. 請輸入慣用 DNS [選填]: "
set "dns2="
if not "%dns1%"=="" (
    set /p dns2="5. 請輸入備用 DNS [選填]: "
)

:APPLY_IP
echo.
echo 正在套用設定至【%adapter%】，請稍候...

:: 套用 IP 與 Gateway
if "%gw%"=="" (
    netsh interface ipv4 set address name="%adapter%" static %ip% %mask%
) else (
    netsh interface ipv4 set address name="%adapter%" static %ip% %mask% %gw%
)

:: 套用 DNS
if not "%dns1%"=="" (
    netsh interface ipv4 set dnsserver name="%adapter%" static %dns1% primary validate=no
    if not "%dns2%"=="" (
        netsh interface ipv4 add dnsserver name="%adapter%" address=%dns2% index=2 validate=no
    )
)

:SHOW_ALL_IP
echo.
echo --- 目前所有網路卡 IP 狀態 ---
powershell -NoProfile -Command "Get-NetIPAddress -AddressFamily IPv4 | Where-Object InterfaceAlias -notmatch 'Loopback' | Select-Object InterfaceAlias, IPAddress | Format-Table -AutoSize"

echo.
echo ===================================
echo  設定完成！請選擇下一步：
echo  1. 返回網卡 【%adapter%】 操作選單
echo  2. 返回主選單 (重新偵測網卡)
echo  0. 關閉程式
echo ===================================
:: 改用 choice 指令，瞬間觸發結束選單動作
choice /c 120 /n /m "請選擇快速鍵： "

if !errorlevel! equ 3 exit /b
if !errorlevel! equ 2 goto START_MENU
if !errorlevel! equ 1 goto ACTION_MENU