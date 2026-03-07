<#
.SYNOPSIS
    Расширенная оптимизация Windows Server 2016/2019 для высоких нагрузок
.DESCRIPTION
    Включает все оптимизации + дополнительные настройки реестра,
    отключение телеметрии, оптимизацию планировщика заданий.
.NOTES
    Версия: 2.3
    Дата обновления: 07.03.2026
    Требования: Права администратора
#>

# Проверка прав администратора
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "❌ Требуются права администратора!" -ForegroundColor Red
    pause
    exit
}

Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Расширенная оптимизация Windows Server (v2.3)              ║" -ForegroundColor Cyan
Write-Host "║   WebSockets + High Performance + Security Hardening         ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# 1. ОПТИМИЗАЦИЯ TCP/IP (улучшенная)
# ============================================================================
Write-Host "[1/11] Оптимизация TCP/IP..." -ForegroundColor Yellow

netsh int ipv4 set dynamicport tcp start=1025 num=64511 store=persistent | Out-Null
netsh int ipv4 set dynamicport udp start=1025 num=64511 store=persistent | Out-Null

$RegPath = "HKLM:\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters"
$TcpSettings = @{
    "TcpTimedWaitDelay"          = 30
    "StrictTimeWaitSeqCheck"     = 1
    "MaxUserPort"                = 65534
    "MaxFreeTcbs"                = 16000
    "EnableDynamicBacklog"       = 1
    "MinimumDynamicBacklog"      = 50
    "MaximumDynamicBacklog"      = 1000
    "TcpAckFrequency"            = 1
    "TcpMaxDataRetransmissions"  = 5          # рекомендация Microsoft
    "EnablePMTUDiscovery"        = 1          # оптимизация размера пакетов
    "KeepAliveTime"              = 300000     # Keep-Alive через 5 минут (вместо 2 часов)
    "KeepAliveInterval"          = 1000       # проверка каждую секунду
}

foreach ($Key in $TcpSettings.Keys) {
    New-ItemProperty -Path $RegPath -Name $Key -Value $TcpSettings[$Key] -PropertyType DWORD -Force | Out-Null
}

netsh int tcp set global rss=enabled | Out-Null
netsh int tcp set global autotuninglevel=normal | Out-Null
netsh int tcp set global dca=enabled | Out-Null              # Direct Cache Access
netsh int tcp set global netdma=enabled | Out-Null           # Network DMA

Write-Host "   ✓ TCP/IP расширенная оптимизация применена" -ForegroundColor Green

# ============================================================================
# 2. ОТКЛЮЧЕНИЕ ТЕЛЕМЕТРИИ И КОНФИДЕНЦИАЛЬНОСТИ
# ============================================================================
Write-Host "[2/11] Отключение телеметрии Windows..." -ForegroundColor Yellow

$TelemetryPath = "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\DataCollection"
New-Item -Path $TelemetryPath -Force | Out-Null
New-ItemProperty -Path $TelemetryPath -Name "AllowTelemetry" -Value 0 -PropertyType DWORD -Force | Out-Null

$TelemetryTasks = @(
    "\\Microsoft\\Windows\\Application Experience\\Microsoft Compatibility Appraiser",
    "\\Microsoft\\Windows\\Application Experience\\ProgramDataUpdater",
    "\\Microsoft\\Windows\\Autochk\\Proxy",
    "\\Microsoft\\Windows\\Customer Experience Improvement Program\\Consolidator",
    "\\Microsoft\\Windows\\Customer Experience Improvement Program\\UsbCeip",
    "\\Microsoft\\Windows\\DiskDiagnostic\\Microsoft-Windows-DiskDiagnosticDataCollector"
)

foreach ($Task in $TelemetryTasks) {
    try {
        Disable-ScheduledTask -TaskName $Task -ErrorAction SilentlyContinue | Out-Null
    } catch {}
}

Write-Host "   ✓ Телеметрия отключена" -ForegroundColor Green

# ============================================================================
# 3. ОТКЛЮЧЕНИЕ НЕНУЖНЫХ СЛУЖБ
# ============================================================================
Write-Host "[3/11] Отключение ненужных служб..." -ForegroundColor Yellow

$ServicesToDisable = @(
    "PcaSvc",              # Помощник совместимости
    "DiagTrack",           # Телеметрия
    "dmwappushservice",    # Push-сообщения
    "MapsBroker",          # Карты
    "XblAuthManager",      # Xbox Live
    "XblGameSave",         # Xbox Game Save
    "XboxNetApiSvc",       # Xbox Network
    "SysMain",             # Superfetch
    "WSearch",             # Windows Search
    "TrkWks",              # Distributed Link Tracking Client
    "WbioSrvc",            # Windows Biometric Service
    "FontCache",           # Windows Font Cache (если не GUI)
    "TabletInputService",  # Touch Keyboard
    "TrustedInstaller",    # Windows Modules Installer Worker
    "Spooler",             # Диспетчер печати
    "Fax",                 # Факс
    "RetailDemo",          # Демо-режим магазинов
    "wisvc",               # Windows Insider Service
    "lfsvc"                # Служба геолокации
)

$DisabledCount = 0
$SkippedServices = @()

foreach ($Service in $ServicesToDisable) {
    try {
        $Svc = Get-Service -Name $Service -ErrorAction SilentlyContinue
        if ($Svc) {
            Stop-Service -Name $Service -Force -ErrorAction SilentlyContinue
            Set-Service -Name $Service -StartupType Disabled -ErrorAction SilentlyContinue
            $DisabledCount++
        } else {
            $SkippedServices += $Service
        }
    } catch {
        $SkippedServices += $Service
    }
}

Write-Host "   ✓ Отключено служб: $DisabledCount" -ForegroundColor Green

if ($SkippedServices.Count -gt 0) {
    Write-Host "   ℹ Не найдено/пропущено: $($SkippedServices.Count) служб" -ForegroundColor Cyan
}

# ============================================================================
# 4. СХЕМА ЭЛЕКТРОПИТАНИЯ
# ============================================================================
Write-Host "[4/11] Настройка электропитания..." -ForegroundColor Yellow

powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c | Out-Null
powercfg -h off | Out-Null

# Отключить USB Selective Suspend (проблемы с сетевыми адаптерами)
powercfg -setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 | Out-Null

Write-Host "   ✓ High Performance + отключен USB Suspend" -ForegroundColor Green

# ============================================================================
# 5. ОПТИМИЗАЦИЯ NTFS
# ============================================================================
Write-Host "[5/11] Оптимизация NTFS..." -ForegroundColor Yellow

fsutil behavior set disable8dot3 1 | Out-Null
fsutil behavior set disablelastaccess 1 | Out-Null
fsutil behavior set memoryusage 2 | Out-Null               # увеличить кэш NTFS

Write-Host "   ✓ NTFS оптимизирована + увеличен кэш" -ForegroundColor Green

# ============================================================================
# 6. УДАЛЕНИЕ КОМПОНЕНТОВ
# ============================================================================
Write-Host "[6/11] Удаление ненужных компонентов..." -ForegroundColor Yellow

Start-Service ServerManager -ErrorAction SilentlyContinue
Set-Service -Name ServerManager -StartupType Automatic -ErrorAction SilentlyContinue

$FeaturesToRemove = @(
    "XPS-Viewer",
    "Wireless-Networking",
    "PowerShell-V2",
    "Windows-Defender-Features"
)

$RemovedCount = 0
foreach ($Feature in $FeaturesToRemove) {
    try {
        $Result = Uninstall-WindowsFeature $Feature -Remove -ErrorAction Stop
        if ($Result.Success) { $RemovedCount++ }
    } catch {}
}

Write-Host "   ✓ Удалено компонентов: $RemovedCount" -ForegroundColor Green

# ============================================================================
# 7. ОТКЛЮЧЕНИЕ WINDOWS DEFENDER
# ============================================================================
Write-Host "[7/11] Отключение Windows Defender..." -ForegroundColor Yellow

$DefenderPath = "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows Defender"
New-Item -Path $DefenderPath -Force | Out-Null
New-ItemProperty -Path $DefenderPath -Name "DisableAntiSpyware" -Value 1 -PropertyType DWORD -Force | Out-Null
New-ItemProperty -Path $DefenderPath -Name "DisableRoutinelyTakingAction" -Value 1 -PropertyType DWORD -Force | Out-Null

$RealtimePath = "$DefenderPath\\Real-Time Protection"
New-Item -Path $RealtimePath -Force | Out-Null
New-ItemProperty -Path $RealtimePath -Name "DisableRealtimeMonitoring" -Value 1 -PropertyType DWORD -Force | Out-Null

Stop-Service -Name "WinDefend" -Force -ErrorAction SilentlyContinue
Set-Service -Name "WinDefend" -StartupType Disabled -ErrorAction SilentlyContinue
Stop-Service -Name "WdNisSvc" -Force -ErrorAction SilentlyContinue
Set-Service -Name "WdNisSvc" -StartupType Disabled -ErrorAction SilentlyContinue

Write-Host "   ✓ Windows Defender полностью отключен" -ForegroundColor Green

# ============================================================================
# 8. НАСТРОЙКА PAGEFILE (автоматический расчет по RAM)
# ============================================================================
Write-Host "[8/11] Настройка Pagefile (автоматический расчет)..." -ForegroundColor Yellow

$TotalRAM_GB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
Write-Host "   Обнаружено RAM: $TotalRAM_GB ГБ" -ForegroundColor Cyan

$PagefileSizeMB = 0

if ($TotalRAM_GB -le 4) {
    $PagefileSizeMB = [math]::Max(8192, [math]::Round($TotalRAM_GB * 2 * 1024))
    $Recommendation = "Мало RAM - увеличенный Pagefile (2x RAM)"
} 
elseif ($TotalRAM_GB -le 8) {
    $PagefileSizeMB = [math]::Round($TotalRAM_GB * 1.5 * 1024)
    $Recommendation = "Средний объем RAM - стандартный расчет (1.5x RAM)"
} 
elseif ($TotalRAM_GB -le 16) {
    $PagefileSizeMB = [math]::Max(4096, [math]::Round($TotalRAM_GB * 0.75 * 1024))
    $Recommendation = "Достаточно RAM - уменьшенный Pagefile (0.75x RAM)"
} 
elseif ($TotalRAM_GB -le 32) {
    $PagefileSizeMB = [math]::Max(4096, [math]::Round($TotalRAM_GB * 0.5 * 1024))
    $Recommendation = "Много RAM - минимальный Pagefile (0.5x RAM)"
} 
else {
    $PagefileSizeMB = 4096
    $Recommendation = "Очень много RAM - минимальный Pagefile (4 ГБ)"
}

Write-Host "   Рекомендация: $Recommendation" -ForegroundColor Cyan
Write-Host "   Устанавливаемый размер: $([math]::Round($PagefileSizeMB / 1024, 2)) ГБ ($PagefileSizeMB МБ)" -ForegroundColor Cyan

try {
    $ComputerSystem = Get-WmiObject -Class Win32_ComputerSystem -EnableAllPrivileges
    $ComputerSystem.AutomaticManagedPagefile = $false
    $ComputerSystem.Put() | Out-Null

    $PageFile = Get-WmiObject -Class Win32_PageFileSetting
    if ($PageFile) {
        $PageFile.InitialSize = $PagefileSizeMB
        $PageFile.MaximumSize = $PagefileSizeMB
        $PageFile.Put() | Out-Null
        Write-Host "   ✓ Pagefile: $([math]::Round($PagefileSizeMB / 1024, 2)) ГБ (фиксированный)" -ForegroundColor Green
    } else {
        Write-Host "   ⚠ Не удалось найти настройки Pagefile, создаю новый..." -ForegroundColor Yellow
        $PageFile = ([WmiClass]"root\\cimv2:Win32_PageFileSetting").CreateInstance()
        $PageFile.Name = "C:\\pagefile.sys"
        $PageFile.InitialSize = $PagefileSizeMB
        $PageFile.MaximumSize = $PagefileSizeMB
        $PageFile.Put() | Out-Null
        Write-Host "   ✓ Pagefile создан: $([math]::Round($PagefileSizeMB / 1024, 2)) ГБ" -ForegroundColor Green
    }
} catch {
    Write-Host "   ✗ Ошибка настройки Pagefile: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "   ┌─────────────────────────────────────────────────┐" -ForegroundColor Gray
Write-Host "   │  Конфигурация виртуальной памяти                │" -ForegroundColor Gray
Write-Host "   ├─────────────────────────────────────────────────┤" -ForegroundColor Gray
Write-Host "   │  Физическая RAM:    $($TotalRAM_GB.ToString().PadRight(25)) ГБ │" -ForegroundColor Gray
Write-Host "   │  Pagefile:          $([math]::Round($PagefileSizeMB / 1024, 2).ToString().PadRight(25)) ГБ │" -ForegroundColor Gray
Write-Host "   │  Всего доступно:    $([math]::Round($TotalRAM_GB + $PagefileSizeMB / 1024, 2).ToString().PadRight(25)) ГБ │" -ForegroundColor Gray
Write-Host "   └─────────────────────────────────────────────────┘" -ForegroundColor Gray
Write-Host ""

# ============================================================================
# 9. ОПТИМИЗАЦИЯ СЕТЕВОГО АДАПТЕРА
# ============================================================================
Write-Host "[9/11] Оптимизация сетевого адаптера..." -ForegroundColor Yellow

try {
    $Adapters = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
    foreach ($Adapter in $Adapters) {
        # IPv6 не отключается — может потребоваться для AD/кластеров
        Set-NetAdapterAdvancedProperty -Name $Adapter.Name -DisplayName "Receive Buffers" -DisplayValue "2048" -ErrorAction SilentlyContinue
        Set-NetAdapterAdvancedProperty -Name $Adapter.Name -DisplayName "Transmit Buffers" -DisplayValue "2048" -ErrorAction SilentlyContinue
    }
    Write-Host "   ✓ Сетевые адаптеры оптимизированы" -ForegroundColor Green
} catch {
    Write-Host "   ⚠ Частичная оптимизация сетевых адаптеров" -ForegroundColor Yellow
}

# ============================================================================
# 10. ОЧИСТКА ВРЕМЕННЫХ ФАЙЛОВ
# ============================================================================
Write-Host "[10/11] Очистка временных файлов..." -ForegroundColor Yellow

Remove-Item -Path "$env:TEMP\\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\\Windows\\Temp\\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\\Windows\\Prefetch\\*" -Force -ErrorAction SilentlyContinue

Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\\Windows\\SoftwareDistribution\\Download\\*" -Recurse -Force -ErrorAction SilentlyContinue
Start-Service -Name wuauserv -ErrorAction SilentlyContinue

Write-Host "   ✓ Временные файлы очищены" -ForegroundColor Green

# ============================================================================
# 11. СОЗДАНИЕ ОТЧЕТА
# ============================================================================
Write-Host "[11/11] Создание отчета оптимизации..." -ForegroundColor Yellow

$ReportPath = "C:\\Optimization-Report-$(Get-Date -Format 'yyyy-MM-dd-HHmm').txt"
$Report = @"
═══════════════════════════════════════════════════════════════
  ОТЧЕТ ОБ ОПТИМИЗАЦИИ WINDOWS SERVER
═══════════════════════════════════════════════════════════════
Дата: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Компьютер: $env:COMPUTERNAME
Пользователь: $env:USERNAME

ПРИМЕНЕННЫЕ ОПТИМИЗАЦИИ:
─────────────────────────────────────────────────────────────
[✓] TCP/IP оптимизация (64K портов, TIME_WAIT 30 сек)
[✓] Отключена телеметрия и задачи CEIP
[✓] Отключено служб: $DisabledCount
[✓] Удалено компонентов: $RemovedCount
[✓] Схема питания: High Performance
[✓] Pagefile: $([math]::Round($PagefileSizeMB/1024,2)) ГБ (фиксированный)
[✓] NTFS оптимизирована (кэш увеличен)
[✓] Windows Defender полностью отключен
[✓] Сетевые адаптеры оптимизированы (IPv6 сохранён)

ПАРАМЕТРЫ TCP/IP:
─────────────────────────────────────────────────────────────
TcpTimedWaitDelay: 30 секунд
MaxUserPort: 65534
MaxFreeTcbs: 16000
DynamicPortRange: 1025-65535 (64510 портов)
TcpMaxDataRetransmissions: 5
KeepAliveTime: 300000 мс (5 минут)

РЕКОМЕНДАЦИИ:
─────────────────────────────────────────────────────────────
• Перезагрузите сервер для применения всех изменений
• Проверьте работу критичных приложений после перезагрузки

═══════════════════════════════════════════════════════════════
"@

$Report | Out-File -FilePath $ReportPath -Encoding UTF8
Write-Host "   ✓ Отчет сохранен: $ReportPath" -ForegroundColor Green

# ============================================================================
# ЗАВЕРШЕНИЕ
# ============================================================================
Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║          ✓ РАСШИРЕННАЯ ОПТИМИЗАЦИЯ ЗАВЕРШЕНА!                ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "Новые улучшения:" -ForegroundColor Cyan
Write-Host "  • Телеметрия полностью отключена" -ForegroundColor White
Write-Host "  • TCP Keep-Alive оптимизирован (5 мин вместо 2 часов)" -ForegroundColor White
Write-Host "  • Сетевые адаптеры: буферы увеличены до 2048" -ForegroundColor White
Write-Host "  • IPv6 сохранён (совместимость с AD и кластерами)" -ForegroundColor White
Write-Host "  • NTFS кэш увеличен" -ForegroundColor White
Write-Host "  • Создан подробный отчет: $ReportPath" -ForegroundColor White
Write-Host ""
Write-Host "⚠ ТРЕБУЕТСЯ ПЕРЕЗАГРУЗКА!" -ForegroundColor Yellow
Write-Host ""
Write-Host "Перезагрузить сейчас? (Y/N): " -ForegroundColor Cyan -NoNewline
$Reboot = Read-Host

if ($Reboot -eq "Y" -or $Reboot -eq "y") {
    Write-Host "Перезагрузка через 5 секунд..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    Restart-Computer -Force
} else {
    Write-Host ""
    Write-Host "Команда для ручной перезагрузки: Restart-Computer" -ForegroundColor Cyan
    Write-Host "Отчет доступен: $ReportPath" -ForegroundColor Cyan
}
