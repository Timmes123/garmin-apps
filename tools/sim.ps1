# Startet eine App im Connect-IQ-Simulator und steuert ihn per Fensternachrichten,
# ohne Maus, Tastatur oder Vordergrundfenster des Nutzers anzufassen.
#
#   tools\sim.ps1 -Run aufgussplan                 App (neu) starten; der Simulator wird dafür neu gestartet
#   tools\sim.ps1 -Click "440,450" -Shot glance    Klick (Fensterkoordinaten) und Bildschirmfoto nach <app>\bin\glance.png
#   tools\sim.ps1 -VKeys 0x0D -Wait 5 -Shot list   Taste senden: 0x0D = START, 0x1B = BACK, 0x4D = Menü
#
# Erfahrungswerte (Fenster ca. 700 px breit, fr965): Glance öffnen = Klick 440,450; DOWN-Knopf = Klick 85,655.
# Pfeiltasten kommen per Nachricht nicht an, dafür die Knöpfe im Uhrenbild anklicken. Tasten gehen gelegentlich
# verloren: nach jedem Schritt ein Bildschirmfoto prüfen.
param([string]$Run = "", [string]$Device = "fr965", [string]$App = "aufgussplan",
      [string]$Click = "", [int[]]$VKeys = @(), [string]$Shot = "", [int]$Wait = 2)
$root = Split-Path $PSScriptRoot -Parent
if ($Run) { $App = $Run }
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System; using System.Runtime.InteropServices;
public class SimWin {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint f);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern bool ScreenToClient(IntPtr h, ref POINT p);
  [DllImport("user32.dll")] public static extern IntPtr ChildWindowFromPointEx(IntPtr h, POINT p, uint f);
  public struct RECT { public int L, T, R, B; }
  public struct POINT { public int X, Y; } }
'@
[SimWin]::SetProcessDPIAware() | Out-Null
if ($Run) {
    $sdk = (Get-Content "$env:APPDATA\Garmin\ConnectIQ\current-sdk.cfg").Trim()
    $env:JAVA_HOME = (Get-ChildItem "C:\Program Files\Eclipse Adoptium" | Select-Object -Last 1).FullName
    $env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
    # Ein laufender Simulator zeigt sonst weiter den alten Build
    Get-Process simulator -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep 2
    Start-Process "$sdk\bin\simulator.exe"; Start-Sleep 8
    Start-Process cmd -ArgumentList "/c `"`"$sdk\bin\monkeydo.bat`" `"$root\$App\bin\$App.prg`" $Device > `"$root\$App\bin\sim.log`" 2>&1`"" -WindowStyle Hidden
    Start-Sleep 10
}
$proc = Get-Process simulator | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
$h = $proc.MainWindowHandle
$r = New-Object SimWin+RECT; [SimWin]::GetWindowRect($h, [ref]$r) | Out-Null
function Target([int]$wx, [int]$wy) {
    # tiefstes Kindfenster unter dem Punkt (Fensterkoordinaten wie im unbeschnittenen Bildschirmfoto)
    $win = $h; $sx = $r.L + $wx; $sy = $r.T + $wy
    while ($true) {
        $pt = New-Object SimWin+POINT; $pt.X = $sx; $pt.Y = $sy; [SimWin]::ScreenToClient($win, [ref]$pt) | Out-Null
        $child = [SimWin]::ChildWindowFromPointEx($win, $pt, 1)
        if ($child -eq [IntPtr]::Zero -or $child -eq $win) { return @($win, $pt.X, $pt.Y) }
        $win = $child
    }
}
$t = Target 440 600
if ($Click) {
    $c = $Click.Split(","); $t = Target ([int]$c[0]) ([int]$c[1])
    $l = [IntPtr](($t[2] -shl 16) -bor ($t[1] -band 0xFFFF))
    [SimWin]::PostMessage($t[0], 0x0200, [IntPtr]0, $l) | Out-Null; Start-Sleep -Milliseconds 100
    [SimWin]::PostMessage($t[0], 0x0201, [IntPtr]1, $l) | Out-Null; Start-Sleep -Milliseconds 100
    [SimWin]::PostMessage($t[0], 0x0202, [IntPtr]0, $l) | Out-Null; Start-Sleep 2
}
foreach ($k in $VKeys) {
    [SimWin]::PostMessage($t[0], 0x0100, [IntPtr]$k, [IntPtr]1) | Out-Null; Start-Sleep -Milliseconds 80
    if ($k -ge 0x41 -and $k -le 0x5A) { [SimWin]::PostMessage($t[0], 0x0102, [IntPtr]($k + 32), [IntPtr]1) | Out-Null }
    [SimWin]::PostMessage($t[0], 0x0101, [IntPtr]$k, [IntPtr]0xC0000001) | Out-Null; Start-Sleep -Milliseconds 1500
}
Start-Sleep $Wait
if ($Shot) {
    $bmp = New-Object System.Drawing.Bitmap ($r.R - $r.L), ($r.B - $r.T)
    $g = [System.Drawing.Graphics]::FromImage($bmp); $hdc = $g.GetHdc(); [SimWin]::PrintWindow($h, $hdc, 2) | Out-Null; $g.ReleaseHdc($hdc); $g.Dispose()
    $bmp.Save("$root\$App\bin\$Shot.png"); $bmp.Dispose()
}
Get-Content "$root\$App\bin\sim.log" -ErrorAction SilentlyContinue | Select-Object -Last 15
