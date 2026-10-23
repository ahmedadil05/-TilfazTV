# ==============================================================================
# تلفازك · TilfazTV - مثبت ويندوز التلقائي (One-Click Setup for Windows)
# Developed & Maintained by Medo B (https://github.com/ahmedail05)
# ==============================================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "TilfazTV - إعداد تلفازك بنقرة واحدة"

function Write-Step ($num, $msg) {
    Write-Host "`n[$num] $msg" -ForegroundColor Cyan
}

function Write-Success ($msg) {
    Write-Host " ✔ $msg" -ForegroundColor Green
}

function Write-Warn ($msg) {
    Write-Host " ⚠ $msg" -ForegroundColor Yellow
}

function Write-Err ($msg) {
    Write-Host " ✖ $msg" -ForegroundColor Red
}

Clear-Host
Write-Host @"
==================================================================
           تلفازك · TilfazTV (إصدار قطر والمظهر الملكي ونور)
           المطور: Medo B (@ahmedail05)
==================================================================
"@ -ForegroundColor Magenta

# 1. التحقق من بايثون
Write-Step 1 "التحقق من تثبيت بايثون (Python)..."
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCmd) {
    Write-Warn "بايثون غير مثبت. جاري التثبيت التلقائي..."
    winget install -e --id Python.Python.3.12 --accept-source-agreements --accept-package-agreements
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
} else {
    Write-Success "بايثون جاهز: $($pythonCmd.Source)"
}

# 2. التحقق من أدوات أندرويد (ADB)
Write-Step 2 "التحقق من أدوات الاتصال بالتلفزيون (ADB)..."
$adbCmd = Get-Command adb -ErrorAction SilentlyContinue
if (-not $adbCmd) {
    # Check default Android SDK locations
    $sdkAdb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
    if (Test-Path $sdkAdb) {
        $env:Path += ";$env:LOCALAPPDATA\Android\Sdk\platform-tools"
        Write-Success "تم العثور على ADB في مجلد SDK المحلي."
    } else {
        Write-Warn "أداة adb غير موجودة في المسار. جاري التثبيت عبر winget..."
        winget install -e --id Google.PlatformTools --accept-source-agreements --accept-package-agreements
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
} else {
    Write-Success "أداة ADB متوفرة: $($adbCmd.Source)"
}

# 3. بناء الواجهة والقوالب
Write-Step 3 "بناء ملفات الواجهة وخلفيات قطر الملكية..."
try {
    python src/build.py
    Write-Success "تم بناء ملفات الواجهة بنجاح في dist/"
} catch {
    Write-Err "حدث خطأ أثناء بناء الواجهة: $_"
}

# 4. البحث التلقائي عن التلفزيون في شبكة الواي فاي
Write-Step 4 "البحث عن التلفزيون على شبكة Wi-Fi المحلية (Port 5555)..."
Write-Host "تأكد من تفعيل «تصحيح أخطاء USB/الشبكة» (USB Debugging) من خيارات المطور على التلفزيون." -ForegroundColor Yellow

$localIP = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Wi-Fi*", "Ethernet*" -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notlike "169.*" -and $_.IPAddress -notlike "127.*" } | Select-Object -First 1).IPAddress
$tvIP = $null

if ($localIP) {
    $subnet = $localIP.Substring(0, $localIP.LastIndexOf('.'))
    Write-Host "الشبكة المحلية الحالية: $subnet.0/24 (جهازك: $localIP)" -ForegroundColor Gray
    
    # Fast scan ARP and recent devices
    $arpEntries = Get-NetNeighbor -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -like "$subnet.*" -and $_.State -ne "Unreachable" }
    foreach ($entry in $arpEntries) {
        $ip = $entry.IPAddress
        if ($ip -eq $localIP) { continue }
        $tcp = Test-NetConnection -ComputerName $ip -Port 5555 -WarningAction SilentlyContinue -InformationLevel Quiet
        if ($tcp) {
            $tvIP = $ip
            Write-Success "تم العثور على تلفزيون أندرويد تلقائياً على العنوان: $tvIP"
            break
        }
    }
}

if (-not $tvIP) {
    Write-Host ""
    $tvIP = Read-Host "لم يتم اكتشاف التلفزيون تلقائياً. اكتب عنوان IP الخاص بالتلفزيون (مثال: 192.168.1.55)"
}

if ($tvIP) {
    Write-Step 5 "جاري الاتصال بالتلفزيون: $tvIP:5555 ..."
    adb disconnect | Out-Null
    $connectResult = adb connect "$($tvIP):5555"
    Write-Host $connectResult -ForegroundColor Green

    Write-Host "`nتنبيه: إذا ظهرت نافذة «Allow USB debugging?» على شاشة التلفزيون، اضغط «السماح دائماً» (Always Allow)." -ForegroundColor Cyan

    $devices = adb devices
    if ($devices -match "$tvIP.*device\b") {
        Write-Success "تم الاتصال بالتلفزيون بنجاح!"

        # تثبيت التطبيقات إذا وجدت ملفات APK في dist
        $apks = Get-ChildItem -Path "dist", "optimize" -Filter "*.apk" -Recurse -ErrorAction SilentlyContinue
        if ($apks) {
            Write-Step 6 "تثبيت تطبيقات UrTV على التلفزيون..."
            foreach ($apk in $apks) {
                Write-Host "تثبيت $($apk.Name)..." -ForegroundColor Gray
                adb install -r $apk.FullName
            }
            Write-Success "اكتمل تثبيت التطبيقات."
        } else {
            Write-Host "ملحوظة: يمكنك تشغيل الواجهة مباشرة أو بناء APK عبر Android Studio." -ForegroundColor Gray
        }
    } else {
        Write-Warn "لم يتم تأكيد الاتصال بالتلفزيون بعد. يرجى الضغط على «Allow» على شاشة التلفزيون ثم إعادة المحاولة."
    }
}

Write-Host "`n==================================================================" -ForegroundColor Magenta
Write-Host "                 اكتمل الإعداد بنجاح!                             " -ForegroundColor Green
Write-Host "==================================================================`n" -ForegroundColor Magenta
pause
