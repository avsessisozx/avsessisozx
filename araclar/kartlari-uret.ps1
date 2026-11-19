# Profil sayfasını üretir: projeler.json -> kartlar/*.svg + README.md
# Her projenin son sürümü GitHub'dan okunur. GitHub Actions her gün çalıştırır; elle de çalıştırılabilir:
#   powershell -ExecutionPolicy Bypass -File araclar\kartlari-uret.ps1
# Yeni proje eklemek için yalnızca projeler.json'a bir satır ekleyin.

$ErrorActionPreference = 'Stop'
$kok = Split-Path -Parent $PSScriptRoot
$kullanici = 'avsessisozx'
$utf8 = New-Object System.Text.UTF8Encoding $false

function Yaz-Dosya([string]$yol, [string]$metin) { [IO.File]::WriteAllText($yol, $metin, $utf8) }
function Kacir([string]$s) { $s.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;') }

$veri = [IO.File]::ReadAllText((Join-Path $kok 'projeler.json'), $utf8) | ConvertFrom-Json

# ---------------- Renkler ----------------
$platformRenk = @{
    android = @{ ad = 'Android';           acik = @('#EAF3DE', '#3B6D11', '#27500A'); koyu = @('#173404', '#97C459', '#C0DD97') }
    windows = @{ ad = 'Windows';           acik = @('#E6F1FB', '#185FA5', '#0C447C'); koyu = @('#042C53', '#85B7EB', '#B5D4F4') }
    ikisi   = @{ ad = 'Android + Windows'; acik = @('#EEEDFE', '#534AB7', '#3C3489'); koyu = @('#26215C', '#AFA9EC', '#CECBF6') }
}
$tema = @{
    acik = @{ zemin = '#ffffff'; cizgi = '#d0d7de'; baslik = '#1f2328'; metin = '#59636e'; surumZ = '#F1EFE8'; surumY = '#444441'; onZ = '#FAEEDA'; onY = '#633806' }
    koyu = @{ zemin = '#151b23'; cizgi = '#3d444d'; baslik = '#f0f6fc'; metin = '#9198a1'; surumZ = '#262c36'; surumY = '#D3D1C7'; onZ = '#412402'; onY = '#FAC775' }
}
$yazi = "-apple-system,BlinkMacSystemFont,'Segoe UI','Noto Sans',Helvetica,Arial,sans-serif"

# ---------------- Yardımcılar ----------------
function Ikon-Ic([string]$ad) {
    $yol = Join-Path $kok "kartlar/ikonlar/$ad.svg"
    if (-not (Test-Path $yol)) { return '' }
    $s = [IO.File]::ReadAllText($yol, $utf8)
    $s = [regex]::Replace($s, '(?s)^.*?<svg[^>]*>', '')
    $s = $s -replace '</svg>\s*$', ''
    $s = $s -replace '<path stroke="none" d="M0 0h24v24H0z" fill="none"\s*/>', ''
    return $s.Trim()
}

function Satirlara-Bol([string]$metin, [int]$en, [int]$adet) {
    $kelimeler = $metin -split '\s+'
    $satirlar = New-Object System.Collections.Generic.List[string]
    $satir = ''
    foreach ($k in $kelimeler) {
        $aday = if ($satir) { "$satir $k" } else { $k }
        if ($aday.Length -gt $en -and $satir) { $satirlar.Add($satir); $satir = $k } else { $satir = $aday }
    }
    if ($satir) { $satirlar.Add($satir) }
    if ($satirlar.Count -gt $adet) {
        $kes = $satirlar.GetRange(0, $adet)
        $son = $kes[$adet - 1]
        if ($son.Length -gt $en - 1) { $son = $son.Substring(0, $en - 1) }
        $kes[$adet - 1] = $son.TrimEnd(' ', ',', ';', ':') + '…'
        return $kes
    }
    return $satirlar
}

function Hap([double]$x, [double]$y, [string]$metin, [string]$zemin, [string]$renk) {
    $g = [math]::Round($metin.Length * 6.6 + 18)
    $s = "<rect x='$x' y='$y' width='$g' height='22' rx='11' fill='$zemin'/>" +
         "<text x='$($x + $g / 2)' y='$($y + 15)' text-anchor='middle' font-size='11.5' font-weight='600' fill='$renk'>$(Kacir $metin)</text>"
    return @{ svg = $s; genislik = $g }
}

function Surum-Oku([string]$repo) {
    $basliklar = @{ 'User-Agent' = 'profil-kartlari'; 'Accept' = 'application/vnd.github+json' }
    if ($env:GITHUB_TOKEN) { $basliklar['Authorization'] = "Bearer $($env:GITHUB_TOKEN)" }
    try {
        $r = Invoke-RestMethod -Uri "https://api.github.com/repos/$kullanici/$repo/releases?per_page=1" -Headers $basliklar
        if ($r -and $r.Count -gt 0) { return @{ etiket = $r[0].tag_name; on = [bool]$r[0].prerelease } }
        return @{ etiket = $null; on = $false }
    }
    catch { Write-Warning "$repo sürümü okunamadı: $($_.Exception.Message)"; return $null }
}

function Kart([object]$p, [string]$platform, [hashtable]$surum, [string]$mod) {
    $t = $tema[$mod]
    $pr = $platformRenk[$platform]
    $pc = $pr[$mod]
    $satirlar = Satirlara-Bol $p.aciklama 50 2
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append("<svg xmlns='http://www.w3.org/2000/svg' width='440' height='132' viewBox='0 0 440 132' font-family=`"$yazi`">")
    [void]$sb.Append("<title>$(Kacir $p.ad)</title>")
    [void]$sb.Append("<rect x='0.5' y='0.5' width='439' height='131' rx='12' fill='$($t.zemin)' stroke='$($t.cizgi)'/>")
    [void]$sb.Append("<rect x='18' y='20' width='52' height='52' rx='12' fill='$($pc[0])'/>")
    [void]$sb.Append("<g transform='translate(29 31) scale(1.25)' fill='none' stroke='$($pc[1])' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'>$(Ikon-Ic $p.ikon)</g>")
    [void]$sb.Append("<text x='86' y='40' font-size='17' font-weight='600' fill='$($t.baslik)'>$(Kacir $p.ad)</text>")
    $y = 61
    foreach ($s in $satirlar) {
        [void]$sb.Append("<text x='86' y='$y' font-size='12.5' fill='$($t.metin)'>$(Kacir $s)</text>")
        $y += 17
    }
    $x = 86
    $h = Hap $x 96 $pr.ad $pc[0] $pc[2]
    if ($mod -eq 'koyu') { $h = Hap $x 96 $pr.ad $pc[0] $pc[1] }
    [void]$sb.Append($h.svg); $x += $h.genislik + 6
    if ($surum -and $surum.etiket) {
        $h = Hap $x 96 $surum.etiket $t.surumZ $t.surumY
        [void]$sb.Append($h.svg); $x += $h.genislik + 6
        if ($surum.on) { $h = Hap $x 96 'ön sürüm' $t.onZ $t.onY; [void]$sb.Append($h.svg) }
    }
    elseif ($surum) {
        $h = Hap $x 96 'geliştiriliyor' $t.onZ $t.onY; [void]$sb.Append($h.svg)
    }
    [void]$sb.Append('</svg>')
    return $sb.ToString()
}

function Baslik([int]$toplam, [hashtable]$sayilar) {
    $ik = Ikon-Ic 'sparkles'
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append("<svg xmlns='http://www.w3.org/2000/svg' width='900' height='170' viewBox='0 0 900 170' font-family=`"$yazi`">")
    [void]$sb.Append("<title>avsessisozx projeleri</title>")
    [void]$sb.Append("<rect width='900' height='170' rx='16' fill='#3C3489'/>")
    [void]$sb.Append("<circle cx='800' cy='20' r='110' fill='#534AB7' opacity='0.55'/><circle cx='870' cy='150' r='70' fill='#7F77DD' opacity='0.35'/><circle cx='690' cy='160' r='34' fill='#534AB7' opacity='0.6'/>")
    [void]$sb.Append("<rect x='36' y='38' width='60' height='60' rx='14' fill='#534AB7'/>")
    [void]$sb.Append("<g transform='translate(48 50) scale(1.5)' fill='none' stroke='#EEEDFE' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'>$ik</g>")
    [void]$sb.Append("<text x='116' y='66' font-size='30' font-weight='700' fill='#ffffff'>Projelerim</text>")
    [void]$sb.Append("<text x='116' y='92' font-size='15' fill='#CECBF6'>Kendi ihtiyacım için yaptığım küçük, açık kaynak uygulamalar</text>")
    $x = 36
    foreach ($m in @("$toplam proje", "$($sayilar.android) Android", "$($sayilar.windows) Windows", "$($sayilar.ikisi) ikisinde de")) {
        $g = [math]::Round($m.Length * 7.4 + 24)
        [void]$sb.Append("<rect x='$x' y='118' width='$g' height='28' rx='14' fill='#26215C'/>")
        [void]$sb.Append("<text x='$($x + $g / 2)' y='137' text-anchor='middle' font-size='13' font-weight='600' fill='#EEEDFE'>$(Kacir $m)</text>")
        $x += $g + 8
    }
    [void]$sb.Append('</svg>')
    return $sb.ToString()
}

# ---------------- Üretim ----------------
$kartKlasoru = Join-Path $kok 'kartlar'
$sayilar = @{ android = 0; windows = 0; ikisi = 0 }
$toplam = 0
$md = New-Object System.Text.StringBuilder

foreach ($b in $veri.bolumler) {
    $simge = @{ android = '📱'; windows = '💻'; ikisi = '🔁' }[$b.platform]
    [void]$md.AppendLine("### $simge $($b.baslik)")
    [void]$md.AppendLine()
    [void]$md.AppendLine('<p>')
    foreach ($p in $b.projeler) {
        $sayilar[$b.platform]++; $toplam++
        $surum = Surum-Oku $p.repo
        if ($null -eq $surum) {
            # API okunamadıysa eski kartı koru (varsa).
            if (Test-Path (Join-Path $kartKlasoru "$($p.repo).svg")) { Write-Host "  $($p.ad): eski kart korunuyor" }
            else { $surum = @{ etiket = $null; on = $false } }
        }
        if ($null -ne $surum) {
            Yaz-Dosya (Join-Path $kartKlasoru "$($p.repo).svg") (Kart $p $b.platform $surum 'acik')
            Yaz-Dosya (Join-Path $kartKlasoru "$($p.repo)-koyu.svg") (Kart $p $b.platform $surum 'koyu')
            Write-Host "  $($p.ad): $($surum.etiket)$(if ($surum.on) { ' (ön sürüm)' })"
        }
        $alt = Kacir "$($p.ad): $($p.aciklama)"
        [void]$md.AppendLine("<a href=`"https://github.com/$kullanici/$($p.repo)`"><picture><source media=`"(prefers-color-scheme: dark)`" srcset=`"kartlar/$($p.repo)-koyu.svg`"><img src=`"kartlar/$($p.repo).svg`" width=`"49%`" alt=`"$alt`"></picture></a>")
    }
    [void]$md.AppendLine('</p>')
    [void]$md.AppendLine()
}

Yaz-Dosya (Join-Path $kartKlasoru 'baslik.svg') (Baslik $toplam $sayilar)

$diger = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'diger.md'), $utf8).Trim()
$readme = @"
<p align="center"><img src="kartlar/baslik.svg" width="100%" alt="Projelerim: kendi ihtiyacım için yaptığım küçük, açık kaynak uygulamalar"></p>

Her projenin sayfasında ne işe yaradığı, nasıl kurulacağı ve indirme bağlantısı var. Bir karta tıklayınca o projenin sayfası açılır.

$($md.ToString().Trim())

$diger

---

<sub>Kartlardaki sürüm numaraları her gün kendiliğinden güncellenir. Uygulamaları yalnızca bu hesabın sürüm sayfalarından indir.</sub>
"@
Yaz-Dosya (Join-Path $kok 'README.md') ($readme.Replace("`r`n", "`n") + "`n")
Write-Host "Tamam: $toplam proje, README.md yazıldı."
