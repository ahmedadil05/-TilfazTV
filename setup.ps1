# ==============================================================================
# تلفازك · TilfazTV - مثبت ويندوز التلقائي (One-Click Setup for Windows)
# Developed & Maintained by Medo B (https://github.com/ahmedadil05)
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
           المطور: Medo B (@ahmedadil05)
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
if (-not (Test-Path "dist")) { New-Item -ItemType Directory -Path "dist" | Out-Null }
try {
    & python src/build.py
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw "build.py exited with code $LASTEXITCODE" }
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

$installOk = $false
if ($tvIP) {
    Write-Step 5 "جاري الاتصال بالتلفزيون: $tvIP:5555 ..."
    & adb disconnect | Out-Null
    $connectResult = & adb connect "$($tvIP):5555" 2>&1
    Write-Host ($connectResult | Out-String).Trim() -ForegroundColor Green

    Write-Host "`nتنبيه: إذا ظهرت نافذة «Allow USB debugging?» على شاشة التلفزيون، اضغط «السماح دائماً» (Always Allow)." -ForegroundColor Cyan
    Start-Sleep -Seconds 2

    $devices = & adb devices 2>&1 | Out-String
    if ($devices -match [regex]::Escape($tvIP) + ".*\bdevice\b") {
        Write-Success "تم الاتصال بالتلفزيون بنجاح!"

        # تثبيت التطبيقات: استخدم ملفات dist/optimize إن وُجدت، وإلا جرّب تنزيل APKs الرسمية (شاشة التوقف + اللاونشر)
        $apks = @(Get-ChildItem -Path "dist", "optimize" -Filter "*.apk" -File -Recurse -ErrorAction SilentlyContinue | Sort-Object FullName -Unique)
        if ($apks.Count -eq 0) {
            Write-Host "جاري تنزيل حزم APK الرسمية الموقعة من GitHub (إن توفرت)..." -ForegroundColor Gray
            $releaseBase = "https://github.com/ahmedadil05/-TilfazTV/releases/download/apk-latest"
            foreach ($name in @("urtv-screensaver.apk", "urtv-home.apk")) {
                try {
                    Invoke-WebRequest -Uri "$releaseBase/$name" -OutFile (Join-Path "dist" $name) -TimeoutSec 60 -ErrorAction Stop
                    Write-Success "تم تنزيل $name"
                } catch {
                    Write-Warn "تعذر تنزيل $name من الإصدارات: $($_.Exception.Message)"
                }
            }
            $apks = @(Get-ChildItem -Path "dist" -Filter "*.apk" -File -ErrorAction SilentlyContinue | Sort-Object Name)
        }

        if ($apks.Count -gt 0) {
            Write-Step 6 "تثبيت تطبيقات تلفازك · TilfazTV على التلفزيون..."
            $allInstalled = $true
            foreach ($apk in $apks) {
                Write-Host "تثبيت $($apk.Name)..." -ForegroundColor Gray
                $out = & adb -s "$($tvIP):5555" install -r $apk.FullName 2>&1 | Out-String
                if ($out -match "\bSuccess\b") {
                    Write-Success "تم تثبيت $($apk.Name)"
                } else {
                    $allInstalled = $false
                    Write-Warn "نتيجة تثبيت $($apk.Name): $($out.Trim())"
                }
            }
            $installOk = $allInstalled
            if ($installOk) { Write-Success "اكتمل تثبيت التطبيقات." } else { Write-Warn "اكتمل التثبيت مع تحذيرات — راجع الرسائل أعلاه." }
        } else {
            Write-Host "ملحوظة: لم يتم العثور على ملفات APK. يمكنك بناء APK عبر Android Studio/Gradle أو تشغيل الواجهة عبر المتصفح." -ForegroundColor Gray
        }
    } else {
        Write-Warn "لم يتم تأكيد الاتصال بالتلفزيون بعد. تأكد من ظهور رسالة الاتصال كـ device، واضغط «Allow» على شاشة التلفزيون ثم أعد المحاولة."
        Write-Host $devices -ForegroundColor DarkGray
    }
}

Write-Host "`n==================================================================" -ForegroundColor Magenta
if ($installOk) {
    Write-Host "                 اكتمل الإعداد والتثبيت بنجاح!                    " -ForegroundColor Green
} elseif ($tvIP) {
    Write-Host "           انتهى الإعداد مع ملاحظات — راجع الرسائل أعلاه          " -ForegroundColor Yellow
} else {
    Write-Host "      تم بناء الواجهة محلياً — أدخل IP التلفزيون للتثبيت لاحقاً   " -ForegroundColor Yellow
}
Write-Host "==================================================================`n" -ForegroundColor Magenta
pause
