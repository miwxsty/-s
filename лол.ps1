# === POWERSELL CLICKER — server + client в одном файле ===
param(
    [ValidateSet("server","client")]
    [string]$Mode = "server"
)

$ROOT = $PSScriptRoot
if (-not $ROOT) { $ROOT = (Get-Location).Path }
$STATE_FILE = Join-Path $ROOT "state.json"
$INPUT_FILE = Join-Path $ROOT "input.json"
$SAVE_FILE  = Join-Path $ROOT "save.json"
$SELF       = $MyInvocation.MyCommand.Path

# ============================================================
#  РЕЖИМ: КЛИЕНТ — только отображение, ноль логики
# ============================================================
if ($Mode -eq "client") {

    [Console]::CursorVisible = $false
    $Host.UI.RawUI.WindowTitle = "🎮 ИГРА"
    try { $Host.UI.RawUI.WindowSize = New-Object System.Management.Automation.Host.Size(90, 34) } catch {}

    $W = 88
    function Center($t) { $p = [math]::Floor(($W - $t.Length) / 2); if ($p -lt 0) { $p = 0 }; return (" " * $p) + $t }
    function Fmt($n) {
        if ($n -ge 1e12) { return [string]::Format("{0:N2}T", $n / 1e12) }
        if ($n -ge 1e9)  { return [string]::Format("{0:N2}B", $n / 1e9) }
        if ($n -ge 1e6)  { return [string]::Format("{0:N2}M", $n / 1e6) }
        if ($n -ge 1e3)  { return [string]::Format("{0:N1}K", $n / 1e3) }
        return [string]::Format("{0:N0}", $n)
    }

    # Отправка действия серверу (перезапись input.json)
    function Send-Input($action, $payload = @{}) {
        $obj = @{ action = $action; payload = $payload; ts = (Get-Date).ToString("o") }
        try { $obj | ConvertTo-Json -Depth 5 | Out-File $INPUT_FILE -Encoding UTF8 } catch {}
    }

    $prevKey = $null

    while ($true) {
        # Читаем состояние от сервера
        $s = $null
        if (Test-Path $STATE_FILE) {
            try { $s = Get-Content $STATE_FILE -Raw | ConvertFrom-Json } catch {}
        }

        if (-not $s) {
            Clear-Host
            Write-Host (Center "⏳ Ожидание сервера...") -ForegroundColor DarkGray
            Start-Sleep -Milliseconds 200
            continue
        }

        # --- Отрисовка (только по данным сервера) ---
        Clear-Host
        $line = "═" * $W
        Write-Host ("╔" + $line + "╗") -ForegroundColor DarkCyan
        Write-Host (Center "💰  P O W E R S H E L L   C L I C K E R  💰") -ForegroundColor Cyan
        Write-Host ("╚" + $line + "╝") -ForegroundColor DarkCyan

        Write-Host ""
        Write-Host ("  💰 Монеты:   " + (Fmt $s.Coins).PadRight(15)) -ForegroundColor Yellow -NoNewline
        Write-Host ("👆 За клик: " + (Fmt $s.PerClick).PadRight(15)) -ForegroundColor Green -NoNewline
        Write-Host ("⚙ В сек: " + (Fmt $s.AutoIncome)) -ForegroundColor Green
        Write-Host ("  📊 Всего:    " + (Fmt $s.TotalCoins).PadRight(15)) -ForegroundColor DarkYellow -NoNewline
        Write-Host ("🗡 Боссов: " + $s.BossesKilled.ToString().PadRight(15)) -ForegroundColor DarkYellow -NoNewline
        Write-Host ("⏱ " + $s.UptimeStr) -ForegroundColor DarkGray
        Write-Host ""

        # Экран
        switch ($s.Screen) {
            "game" {
                $color = if ($s.ClickFlash -gt 0) { "Yellow" } else { "Magenta" }
                Write-Host (Center "╔═══════════════════════════════════╗") -ForegroundColor $color
                Write-Host (Center "║          Н А Ж М И                ║") -ForegroundColor $color
                Write-Host (Center "║          [   F   ]                ║") -ForegroundColor $color
                Write-Host (Center "║          Ч Т О Б Ы                ║") -ForegroundColor $color
                Write-Host (Center "║          З А Р А Б О Т А Т Ь      ║") -ForegroundColor $color
                Write-Host (Center "╚═══════════════════════════════════╝") -ForegroundColor $color
                Write-Host ""
                if ($s.ClickFlash -gt 0) { Write-Host (Center ("+ " + (Fmt $s.ClickGain))) -ForegroundColor Yellow }
                else { Write-Host "" }
                Write-Host ""
                # Прогресс до апгрейда
                if ($s.NextUpgradeName) {
                    $prog = [math]::Min(1.0, $s.Coins / $s.NextUpgradeCost)
                    $filled = [math]::Floor(50 * $prog)
                    $bar = ("█" * $filled) + ("░" * (50 - $filled))
                    Write-Host ("  Следующий: " + $s.NextUpgradeName) -ForegroundColor DarkGray
                    Write-Host ("  [" + $bar + "] " + [math]::Floor($prog*100) + "%") -ForegroundColor Cyan
                    Write-Host ("  " + (Fmt $s.Coins) + " / " + (Fmt $s.NextUpgradeCost)) -ForegroundColor DarkGray
                }
            }
            "shop" {
                Write-Host "  🛒 МАГАЗИН АПГРЕЙДОВ" -ForegroundColor White
                Write-Host ("  " + ("─" * ($W - 4))) -ForegroundColor DarkCyan
                Write-Host ""
                for ($i = 0; $i -lt $s.Shop.Count; $i++) {
                    $it = $s.Shop[$i]
                    $cursor = if ($i -eq $s.Selected) { "▶" } else { " " }
                    $price = (Fmt $it.Cost).PadLeft(10)
                    $lvl = ("ур." + $it.Level).PadRight(8)
                    $color = if ($i -eq $s.Selected) { "White" } elseif ($it.CanBuy) { "Green" } else { "DarkGray" }
                    $ic = if ($it.Type -eq "click") { "👆" } else { "⚙ " }
                    Write-Host ("  $cursor $ic $($it.Name.PadRight(18)) $($it.Desc.PadRight(18)) $price  $lvl") -ForegroundColor $color
                }
            }
            "boss" {
                Write-Host ("  " + ("═" * ($W - 4))) -ForegroundColor DarkRed
                Write-Host (Center "⚠  Б О С С  ⚠") -ForegroundColor Red
                Write-Host (Center $s.Boss.Name) -ForegroundColor Magenta
                Write-Host ("  " + ("═" * ($W - 4))) -ForegroundColor DarkRed
                Write-Host ""
                $prog = [math]::Max(0, $s.Boss.HP / $s.Boss.MaxHP)
                $filled = [math]::Floor(60 * $prog)
                $bar = ("█" * $filled) + ("░" * (60 - $filled))
                $hpColor = if ($prog -gt 0.5) { "Green" } elseif ($prog -gt 0.2) { "Yellow" } else { "Red" }
                Write-Host ("  HP: [" + $bar + "]") -ForegroundColor $hpColor
                Write-Host ("  " + (Fmt $s.Boss.HP) + " / " + (Fmt $s.Boss.MaxHP)) -ForegroundColor White
                Write-Host ""
                $tc = if ($s.Boss.Timer -gt 10) { "Green" } elseif ($s.Boss.Timer -gt 5) { "Yellow" } else { "Red" }
                Write-Host (Center ("⏱ Осталось: " + $s.Boss.Timer + " сек")) -ForegroundColor $tc
                Write-Host ""
                Write-Host (Center ("🏆 Награда: + " + (Fmt $s.Boss.Reward))) -ForegroundColor Green
                Write-Host (Center ("💀 Проигрыш: - " + (Fmt $s.Boss.Penalty))) -ForegroundColor DarkRed
                Write-Host ""
                if ($s.Boss.HitFlash -gt 0) { Write-Host (Center "⚔  У Д А Р !  ⚔") -ForegroundColor Yellow }
                else { Write-Host (Center "Жми  [ F ]  чтобы бить!") -ForegroundColor Magenta }
            }
        }

        Write-Host ""
        if ($s.MessageTimer -gt 0) { Write-Host (Center $s.Message) -ForegroundColor Yellow }
        else { Write-Host "" }
        Write-Host ""

        # Подсказки
        switch ($s.Screen) {
            "game" {
                Write-Host (Center "[F] клик   [TAB] магазин   [S] сохранить   [Q] выход") -ForegroundColor DarkGray
                Write-Host (Center ("Следующий босс через ~" + [math]::Max(0,$s.BossSpawnIn) + " сек")) -ForegroundColor DarkRed
            }
            "shop" { Write-Host (Center "[↑↓] выбор   [ENTER] купить   [TAB] назад   [Q] выход") -ForegroundColor DarkGray }
            "boss" { Write-Host (Center "[F] УДАР!") -ForegroundColor Red }
        }

        # --- Ввод игрока — только отправляем серверу ---
        $deadline = (Get-Date).AddMilliseconds(150)
        while ((Get-Date) -lt $deadline -and -not [Console]::KeyAvailable) { Start-Sleep -Milliseconds 15 }
        if (-not [Console]::KeyAvailable) { continue }
        $key = [Console]::ReadKey($true)

        $isRepeat = $false
        if ($prevKey -and $prevKey.Key -eq $key.Key -and ((Get-Date) - $prevKey.Time).TotalMilliseconds -lt 80) { $isRepeat = $true }
        $prevKey = @{ Key = $key.Key; Time = Get-Date }
        if ($isRepeat) { continue }

        switch ($key.Key) {
            'Q' { Send-Input "quit"; Start-Sleep -Milliseconds 200; [Console]::CursorVisible = $true; exit }
            'F' { Send-Input "click" }
            'Tab' { Send-Input "toggle_screen" }
            'S' { Send-Input "save" }
            'Enter' { Send-Input "buy" }
            'UpArrow' { Send-Input "up" }
            'DownArrow' { Send-Input "down" }
        }
    }
}

# ============================================================
#  РЕЖИМ: СЕРВЕР — вся логика, все проверки, невидим для игрока
# ============================================================

# Скрываем окно сервера насколько возможно
$Host.UI.RawUI.WindowTitle = "⚙ SERVER — do not touch"
try { $Host.UI.RawUI.WindowSize = New-Object System.Management.Automation.Host.Size(60, 16) } catch {}

# --- Состояние (единственный источник истины) ---
$game = @{
    Coins = 0; TotalCoins = 0; Clicks = 0; PerClick = 1; AutoIncome = 0
    Selected = 0; Screen = "game"; Message = ""; MessageTimer = 0
    ClickFlash = 0; ClickGain = 0
    SessionStart = Get-Date; LastSave = Get-Date
    BossesKilled = 0; BossActive = $false; BossSpawnIn = 60
}
$boss = @{ Active=$false; Name=""; HP=0; MaxHP=0; Timer=0; Reward=0; Penalty=0; HitFlash=0; Damage=0 }

$upgrades = @(
    @{ Name = "Крепкий палец";   Desc = "+1 к клику";      BaseCost = 10;     Type = "click"; Power = 1 }
    @{ Name = "Стальной палец";  Desc = "+5 к клику";      BaseCost = 100;    Type = "click"; Power = 5 }
    @{ Name = "Титановый палец"; Desc = "+25 к клику";     BaseCost = 1200;   Type = "click"; Power = 25 }
    @{ Name = "Автокликер";      Desc = "+1 монета/сек";   BaseCost = 50;     Type = "auto";  Power = 1 }
    @{ Name = "Ферма";           Desc = "+5 монет/сек";    BaseCost = 300;    Type = "auto";  Power = 5 }
    @{ Name = "Фабрика";         Desc = "+25 монет/сек";   BaseCost = 1500;   Type = "auto";  Power = 25 }
    @{ Name = "Мегакорпорация";  Desc = "+150 монет/сек";  BaseCost = 10000;  Type = "auto";  Power = 150 }
    @{ Name = "Космическая КС";  Desc = "+1000 монет/сек"; BaseCost = 75000;  Type = "auto";  Power = 1000 }
)
$owned = @{}
for ($i = 0; $i -lt $upgrades.Count; $i++) { $owned[$i] = 0 }

function Get-Cost($i) { return [math]::Floor($upgrades[$i].BaseCost * [math]::Pow(1.5, $owned[$i])) }

$bossTemplates = @(
    @{ Name = "🐀 Крыса-мутант";    HPMult = 8;   TimerSec = 15; RewardMult = 5 }
    @{ Name = "👹 Гоблин-налётчик"; HPMult = 15;  TimerSec = 15; RewardMult = 8 }
    @{ Name = "🐉 Молодой дракон";  HPMult = 30;  TimerSec = 20; RewardMult = 15 }
    @{ Name = "👾 Космический жук"; HPMult = 60;  TimerSec = 20; RewardMult = 25 }
    @{ Name = "💀 Тёмный лорд";     HPMult = 120; TimerSec = 25; RewardMult = 50 }
)

function Save-Game {
    $data = @{
        TotalCoins = $game.TotalCoins; Clicks = $game.Clicks
        PerClick = $game.PerClick; AutoIncome = $game.AutoIncome
        Owned = $owned; BossesKilled = $game.BossesKilled
    }
    $data | ConvertTo-Json | Out-File $SAVE_FILE -Encoding UTF8
}
function Load-Game {
    if (Test-Path $SAVE_FILE) {
        try {
            $d = Get-Content $SAVE_FILE -Raw | ConvertFrom-Json
            $game.TotalCoins = $d.TotalCoins; $game.Clicks = $d.Clicks
            $game.PerClick = $d.PerClick; $game.AutoIncome = $d.AutoIncome
            $game.BossesKilled = if ($d.BossesKilled) { $d.BossesKilled } else { 0 }
            foreach ($k in $d.Owned.PSObject.Properties.Name) { $owned[[int]$k] = $d.Owned.$k }
        } catch {}
    }
}

function Spawn-Boss {
    $power = [math]::Max(1, $game.PerClick + $game.AutoIncome)
    $tpl = $bossTemplates[(Get-Random -Minimum 0 -Maximum $bossTemplates.Count)]
    $hp = [math]::Floor($power * $tpl.HPMult)
    $boss.Active=$true; $boss.Name=$tpl.Name; $boss.MaxHP=$hp; $boss.HP=$hp
    $boss.Timer=$tpl.TimerSec
    $boss.Reward=[math]::Floor($hp * 0.5 * $tpl.RewardMult / 10)
    $boss.Penalty=[math]::Floor($game.Coins * 0.1)
    $boss.Damage=$game.PerClick * 3
    $boss.HitFlash=0
    $game.BossActive=$true; $game.Screen="boss"
    $game.Message="⚠ БОСС! Жми F!"; $game.MessageTimer=3
}

# Публикация состояния для клиента (все проверки уже сделаны, тут только цифры)
function Publish-State {
    $up = (Get-Date) - $game.SessionStart
    $upStr = "{0:d2}:{1:d2}:{2:d2}" -f $up.Hours, $up.Minutes, $up.Seconds

    # Расчёт магазина
    $shopList = @()
    for ($i = 0; $i -lt $upgrades.Count; $i++) {
        $c = Get-Cost $i
        $shopList += @{
            Name = $upgrades[$i].Name; Desc = $upgrades[$i].Desc
            Cost = $c; Level = $owned[$i]; CanBuy = ($game.Coins -ge $c)
            Type = $upgrades[$i].Type
        }
    }

    # Ближайший апгрейд
    $nextIdx = -1; $nextCost = [double]::MaxValue
    for ($i = 0; $i -lt $upgrades.Count; $i++) { $c = Get-Cost $i; if ($c -lt $nextCost) { $nextCost = $c; $nextIdx = $i } }

    $state = @{
        Coins = $game.Coins; TotalCoins = $game.TotalCoins
        PerClick = $game.PerClick; AutoIncome = $game.AutoIncome
        Clicks = $game.Clicks; BossesKilled = $game.BossesKilled
        Screen = $game.Screen; Selected = $game.Selected
        Message = $game.Message; MessageTimer = $game.MessageTimer
        ClickFlash = $game.ClickFlash; ClickGain = $game.ClickGain
        BossSpawnIn = $game.BossSpawnIn
        UptimeStr = $upStr
        NextUpgradeName = if ($nextIdx -ge 0) { $upgrades[$nextIdx].Name } else { "" }
        NextUpgradeCost = if ($nextIdx -ge 0) { $nextCost } else { 0 }
        Shop = $shopList
        Boss = @{
            Name = $boss.Name; HP = $boss.HP; MaxHP = $boss.MaxHP
            Timer = $boss.Timer; Reward = $boss.Reward; Penalty = $boss.Penalty
            HitFlash = $boss.HitFlash
        }
    }
    try { $state | ConvertTo-Json -Depth 6 | Out-File $STATE_FILE -Encoding UTF8 } catch {}
}

# --- Запуск клиента ---
Load-Game
if (Test-Path $INPUT_FILE) { Remove-Item $INPUT_FILE -Force -ErrorAction SilentlyContinue }

Start-Process powershell -ArgumentList @(
    "-NoProfile", "-ExecutionPolicy", "Bypass",
    "-File", "`"$SELF`"", "-Mode", "client"
) | Out-Null

# Скрываем окно сервера за пределами экрана (по возможности)
try {
    Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    public class Win {
        [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
        [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    }
"@
    $h = [Win]::GetConsoleWindow()
    # 0 = SW_HIDE, 6 = SW_MINIMIZE. Ставим MINIMIZE — сервер уедет в панель задач.
    [Win]::ShowWindow($h, 6) | Out-Null
} catch {}

# --- Цикл сервера ---
$lastAuto = Get-Date
$lastBossTick = Get-Date
$lastPublish = Get-Date
$lastInputTs = ""
$quit = $false

while (-not $quit) {
    $now = Get-Date

    # Пассив
    if (($now - $lastAuto).TotalSeconds -ge 1) {
        if ($game.AutoIncome -gt 0) {
            $game.Coins += $game.AutoIncome
            $game.TotalCoins += $game.AutoIncome
        }
        $lastAuto = $now
    }

    # Босс
    if ($boss.Active) {
        if (($now - $lastBossTick).TotalSeconds -ge 1) {
            $boss.Timer--; $lastBossTick = $now
            if ($boss.Timer -le 0) {
                $game.Coins = [math]::Max(0, $game.Coins - $boss.Penalty)
                $boss.Active = $false; $game.BossActive = $false; $game.Screen = "game"
                $game.Message = "💀 Босс сбежал! - " + $boss.Penalty
                $game.MessageTimer = 4
                $game.BossSpawnIn = Get-Random -Minimum 45 -Maximum 90
            }
        }
    } else {
        if (($now - $lastBossTick).TotalSeconds -ge 1) {
            $game.BossSpawnIn--; $lastBossTick = $now
            if ($game.BossSpawnIn -le 0) { Spawn-Boss; $lastBossTick = Get-Date }
        }
    }

    if ($game.MessageTimer -gt 0) { $game.MessageTimer-- }
    if ($game.ClickFlash -gt 0) { $game.ClickFlash-- }
    if ($boss.HitFlash -gt 0) { $boss.HitFlash-- }

    # --- Чтение ввода от клиента ---
    if (Test-Path $INPUT_FILE) {
        try {
            $inp = Get-Content $INPUT_FILE -Raw | ConvertFrom-Json
            if ($inp.ts -ne $lastInputTs) {
                $lastInputTs = $inp.ts
                # ВСЕ ПРОВЕРКИ ЗДЕСЬ
                switch ($inp.action) {
                    "quit" { $quit = $true }
                    "click" {
                        if ($boss.Active) {
                            $boss.HP -= $boss.Damage
                            $boss.HitFlash = 2
                            $game.Clicks++
                            if ($boss.HP -le 0) {
                                $game.Coins += $boss.Reward
                                $game.TotalCoins += $boss.Reward
                                $game.BossesKilled++
                                $boss.Active = $false; $game.BossActive = $false; $game.Screen = "game"
                                $game.Message = "🏆 Босс побеждён! + " + $boss.Reward
                                $game.MessageTimer = 4
                                $game.BossSpawnIn = Get-Random -Minimum 45 -Maximum 90
                                Save-Game
                            }
                        }
                        elseif ($game.Screen -eq "game") {
                            $game.Coins += $game.PerClick
                            $game.TotalCoins += $game.PerClick
                            $game.Clicks++
                            $game.ClickFlash = 2
                            $game.ClickGain = $game.PerClick
                        }
                    }
                    "toggle_screen" {
                        if ($boss.Active) {
                            $game.Message = "⚠ Нельзя в магазин во время боя!"
                            $game.MessageTimer = 2
                        } else {
                            if ($game.Screen -eq "game") { $game.Screen = "shop" } else { $game.Screen = "game" }
                        }
                    }
                    "save" { Save-Game; $game.Message = "💾 Сохранено!"; $game.MessageTimer = 2 }
                    "buy" {
                        if ($game.Screen -eq "shop") {
                            $cost = Get-Cost $game.Selected
                            if ($game.Coins -ge $cost) {
                                $game.Coins -= $cost
                                $u = $upgrades[$game.Selected]
                                if ($u.Type -eq "click") { $game.PerClick += $u.Power }
                                else { $game.AutoIncome += $u.Power }
                                $owned[$game.Selected]++
                                $game.Message = "✅ Куплено: $($u.Name)!"; $game.MessageTimer = 2
                                Save-Game
                            } else { $game.Message = "❌ Не хватает монет!"; $game.MessageTimer = 2 }
                        }
                    }
                    "up" { if ($game.Screen -eq "shop") { $game.Selected--; if ($game.Selected -lt 0) { $game.Selected = $upgrades.Count - 1 } } }
                    "down" { if ($game.Screen -eq "shop") { $game.Selected++; if ($game.Selected -ge $upgrades.Count) { $game.Selected = 0 } } }
                }
            }
        } catch {}
    }

    # Автосейв
    if (((Get-Date) - $game.LastSave).TotalSeconds -ge 30) { Save-Game; $game.LastSave = Get-Date }

    # Публикация состояния ~10 раз/сек
    if (((Get-Date) - $lastPublish).TotalMilliseconds -ge 100) {
        Publish-State
        $lastPublish = Get-Date
    }

    Start-Sleep -Milliseconds 30
}

Save-Game
if (Test-Path $STATE_FILE) { Remove-Item $STATE_FILE -Force -ErrorAction SilentlyContinue }
if (Test-Path $INPUT_FILE) { Remove-Item $INPUT_FILE -Force -ErrorAction SilentlyContinue }