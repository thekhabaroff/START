<div align="center"><h1> 🖥️ Windows Server Optimization Script v2.3 </div>

***

<div align="center">

![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue?style=for-the-badge&logo=powershell&logoColor=white)
![Windows Server](https://img.shields.io/badge/Windows%20Server-2016%20|%202019%20|%202022-0078D4?style=for-the-badge&logo=windows&logoColor=white)
![Version](https://img.shields.io/badge/Version-2.3-brightgreen?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)
![Requires](https://img.shields.io/badge/Requires-Administrator-red?style=for-the-badge&logo=windows-terminal&logoColor=white)
![Updated](https://img.shields.io/badge/Updated-07.03.2026-lightgrey?style=for-the-badge)
![Stars](https://img.shields.io/github/stars/thekhabaroff/START?style=for-the-badge)
![Last Commit](https://img.shields.io/github/last-commit/thekhabaroff/START?style=for-the-badge)
![Issues](https://img.shields.io/github/issues/thekhabaroff/START?style=for-the-badge)

</div>

***

Расширенная оптимизация Windows Server для высоконагруженных окружений: WebSockets, высокая пропускная способность сети, минимальные задержки. Скрипт автоматически рассчитывает параметры под конкретное железо, применяет более 40 оптимизаций и генерирует подробный отчёт.

***

## 📋 Содержание

- [Что делает скрипт](#-что-делает-скрипт)
- [Требования](#-требования)
- [Быстрый старт](#-быстрый-старт)
- [Детали оптимизаций](#-детали-оптимизаций)
- [Расчёт Pagefile](#-расчёт-pagefile)
- [Отчёт](#-отчёт)
- [Важные предупреждения](#-важные-предупреждения)
- [Changelog](#-changelog)
- [Поддержать проект](#-поддержать-проект)

***

## ⚡ Что делает скрипт

| # | Блок | Действие |
|---|------|----------|
| 1 | **TCP/IP** | Расширение диапазона портов до 64510, TIME_WAIT 30 сек, Keep-Alive 5 мин, DCA, NetDMA |
| 2 | **Телеметрия** | Полное отключение сбора данных Microsoft, задачи CEIP |
| 3 | **Службы** | Отключение 19 ненужных служб (Superfetch, WSearch, Xbox, Spooler и др.) |
| 4 | **Электропитание** | Схема High Performance, отключение USB Selective Suspend |
| 5 | **NTFS** | Отключение 8.3-имён, LastAccess, увеличение кэша |
| 6 | **Компоненты** | Удаление XPS-Viewer, PowerShell v2, Wireless и др. |
| 7 | **Defender** | Полное отключение Windows Defender и Real-Time Protection |
| 8 | **Pagefile** | Автоматический расчёт размера по объёму RAM |
| 9 | **Сеть** | Буферы RX/TX адаптеров 2048, IPv6 сохраняется |
| 10 | **Очистка** | Temp, Prefetch, кэш Windows Update |
| 11 | **Отчёт** | Генерация детального `.txt`-отчёта в `C:\` |

***

## 🔧 Требования

- **ОС:** Windows Server 2016 или Windows Server 2019
- **Права:** Локальный Администратор или Domain Admin
- **PowerShell:** версия 5.1 и выше
- **Роли:** ServerManager должен быть доступен (для удаления компонентов)

***

## 🚀 Быстрый старт

### Способ 1 — запуск из файла (рекомендуется)

```powershell
# 1. Скачайте скрипт
Invoke-WebRequest -Uri "https://your-url/optimize.ps1" -OutFile "C:\optimize.ps1"

# 2. Запустите от имени администратора
Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File C:\optimize.ps1" -Verb RunAs
```

### Способ 2 — через правую кнопку мыши

1. Скачайте `START.ps1`
2. ПКМ → **«Запустить с помощью PowerShell»**
3. При запросе UAC — нажмите **«Да»**

### Способ 3 — через консоль администратора

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\START.ps1
```

> ⚠️ **Не запускайте через** `powershell -Command "irm url | iex"` — скрипт запрашивает ввод (перезагрузка).

***

## 🔍 Детали оптимизаций

### TCP/IP — ключевые параметры реестра

| Параметр | Значение | Эффект |
|----------|----------|--------|
| `TcpTimedWaitDelay` | 30 сек | Быстрее переиспользование портов (вместо 240 с) |
| `MaxUserPort` | 65534 | Максимум эфемерных портов |
| `MaxFreeTcbs` | 16000 | Больше одновременных соединений |
| `KeepAliveTime` | 300 000 мс | Обнаружение мёртвых соединений за 5 мин |
| `KeepAliveInterval` | 1000 мс | Частота проверки Keep-Alive |
| `TcpAckFrequency` | 1 | ACK на каждый пакет (снижает задержки) |
| `EnablePMTUDiscovery` | 1 | Автоподбор оптимального MTU |
| `EnableDynamicBacklog` | 1 | Динамическая очередь подключений |

Дополнительно через `netsh`:
- **RSS** (Receive Side Scaling) — распределение прерываний по ядрам
- **AutoTuning** `normal` — автонастройка TCP-окна
- **DCA** (Direct Cache Access) — снижение задержки L3-кэша
- **NetDMA** — разгрузка DMA-операций с CPU

### Отключаемые службы

```
PcaSvc           — Помощник совместимости программ
DiagTrack        — Connected User Experiences (телеметрия)
dmwappushservice — WAP Push Message Routing
SysMain          — Superfetch (бесполезен на SSD-серверах)
WSearch          — Windows Search (индексация)
Spooler          — Диспетчер очереди печати
XblAuthManager   — Xbox Live Auth
XboxNetApiSvc    — Xbox Network API
TrkWks           — Distributed Link Tracking
WbioSrvc         — Windows Biometric Service
lfsvc            — Геолокация
wisvc            — Windows Insider Service
RetailDemo       — Демонстрационный режим
Fax              — Факс
...и ещё 5
```

### Удаляемые компоненты Windows

- `XPS-Viewer` — просмотрщик XPS-документов
- `PowerShell-V2` — устаревший движок PowerShell 2.0
- `Wireless-Networking` — WiFi (не нужен на серверах)
- `Windows-Defender-Features` — Защитник Windows

### NTFS оптимизация

```powershell
fsutil behavior set disable8dot3      1   # Отключить короткие имена (8.3)
fsutil behavior set disablelastaccess 1   # Не обновлять время последнего доступа
fsutil behavior set memoryusage       2   # Увеличить лимит кэша NTFS
```

### Сетевые адаптеры

Для всех активных адаптеров устанавливаются:
- **Receive Buffers:** 2048 (вместо 512 по умолчанию)
- **Transmit Buffers:** 2048

> IPv6 **намеренно сохраняется** — отключение ломает Active Directory, DNS, Failover Clustering.

***

## 📊 Расчёт Pagefile

Размер рассчитывается автоматически на основе физической RAM:

| RAM | Формула | Пример (8 ГБ RAM) |
|-----|---------|-------------------|
| ≤ 4 ГБ | `max(8 ГБ, RAM × 2)` | — |
| 4–8 ГБ | `RAM × 1.5` | 12 ГБ |
| 8–16 ГБ | `max(4 ГБ, RAM × 0.75)` | 6 ГБ |
| 16–32 ГБ | `max(4 ГБ, RAM × 0.5)` | 8 ГБ |
| > 32 ГБ | `4 ГБ` | 4 ГБ |

Pagefile устанавливается **фиксированным** (InitialSize = MaximumSize) — исключает фрагментацию и непредсказуемые задержки при росте файла.

***

## 📄 Отчёт

После выполнения в корне диска `C:\` создаётся файл:

```
C:\Optimization-Report-2026-03-07-1430.txt
```

Содержимое отчёта:
- Дата, имя компьютера, пользователь
- Список всех применённых оптимизаций
- Ключевые параметры TCP/IP
- Размер Pagefile и общий объём виртуальной памяти
- Рекомендации после перезагрузки

***

## ⚠️ Важные предупреждения

> **🔴 Windows Defender отключается полностью.**
> Перед запуском убедитесь, что используется сторонний антивирус или сервер изолирован в защищённой сети.

> **🟡 Требуется перезагрузка.**
> Часть параметров (Pagefile, NTFS, некоторые TCP-настройки) вступает в силу только после перезагрузки.

> **🟡 Spooler отключается.**
> Если на сервере работает печать — исключите `Spooler` из списка `$ServicesToDisable`.

> **🟢 IPv6 сохраняется намеренно.**
> Отключение IPv6 на контроллерах домена ломает DNS, репликацию AD и Failover Clustering.

***

## 🔄 Откат изменений

Скрипт не создаёт автоматический бэкап реестра. Перед запуском рекомендуется:

```powershell
# Бэкап TCP-параметров реестра
reg export "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" C:\tcp-backup.reg

# Точка восстановления системы
Checkpoint-Computer -Description "Before optimization" -RestorePointType MODIFY_SETTINGS
```

Восстановление конкретной службы:
```powershell
Set-Service -Name "WSearch" -StartupType Automatic
Start-Service -Name "WSearch"
```

***

## 📁 Структура

```
START.ps1                            # Основной скрипт
README.md                            # Документация
C:\Optimization-Report-*.txt         # Генерируется после запуска
```

***

## 📝 Changelog

### v2.3 — 07.03.2026
- Автоматический расчёт Pagefile по объёму RAM
- TCP Keep-Alive снижен с 2 часов до 5 минут
- Буферы сетевых адаптеров увеличены до 2048
- IPv6 сохраняется (исправлена совместимость с AD и Failover Cluster)
- Увеличен кэш NTFS (`memoryusage=2`)
- Добавлены DCA и NetDMA в TCP-оптимизацию
- Улучшен отчёт: сводная таблица виртуальной памяти

### v2.2
- Расширен список телеметрийных задач планировщика
- Отключение USB Selective Suspend
- Счётчик отключённых/пропущенных служб

### v2.1
- Первичная версия со стандартной оптимизацией TCP/IP
- Базовая очистка Temp и SoftwareDistribution

***

## ☕ Поддержать проект

Если скрипт сэкономил тебе время — можешь поддержать разработку криптовалютой:

<details>
<summary><b>🟠 BTC</b></summary>

```
1CAWPNFJMAWxCany1A317yqHoZz4mq9MTE
```

</details>

<details>
<summary><b>🔷 EVM</b></summary>

```
0xbdfa3a427e457a99d7254af04b44fe76c347bd10
```

</details>

<details>
<summary><b>💚 TRC</b></summary>

```
TFGa8KRdcyCv3gk6khGU8NQvR8ot5UtiP5
```

</details>

<details>
<summary><b>🟣 TON</b></summary>

```
UQCacF30U98zSCbzd1NM5qMjjdkTygJwMjgDURobdXTIDN4-
```

</details>

<details>
<summary><b>💜 SOL</b></summary>

```
ETdRsuSYgpijG4RFckEQUoLfQ4CctibcoshTKyk1sCoW
```

</details>

<details>
<summary><b>🔵 APT</b></summary>

```
0x82b02deef3c3d8d21a665c53d9ea2e046813b6a92085efbc241b8acf69dc3af5
```

</details>

> Каждый донат мотивирует развивать проект дальше 🙏

***

## 📜 Лицензия

[MIT](LICENSE) — используйте свободно, упоминание автора приветствуется.

---

<div align="center">⭐ Поставь звезду, если проект оказался полезным!</div>
