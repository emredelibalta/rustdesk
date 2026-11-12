param([switch]$ReportOnly,[string]$ReportJob='')
# Tempo demo assistant: inventory is read-only; installation needs explicit confirmation.
$ErrorActionPreference = 'Stop'
function Get-TempoSqlInstances {
  $result = @{}
  foreach ($root in @('HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Microsoft SQL Server')) {
    $key = Join-Path $root 'Instance Names\SQL'
    if (!(Test-Path $key)) { continue }
    foreach ($entry in (Get-ItemProperty $key).PSObject.Properties) {
      if ($entry.Name -like 'PS*') { continue }
      $setup = Get-ItemProperty (Join-Path $root ($entry.Value+'\Setup')) -ErrorAction SilentlyContinue
      $serviceName = if ($entry.Name -eq 'MSSQLSERVER') { 'MSSQLSERVER' } else { 'MSSQL$'+$entry.Name }
      $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
      $result[$entry.Name] = [pscustomobject]@{Name=$entry.Name; Version=$setup.Version; PatchLevel=$setup.PatchLevel; Edition=$setup.Edition; Service=if($service){[string]$service.Status}else{'Servis bulunamadi'}}
    }
  }
  foreach ($service in @(Get-Service -Name 'MSSQLSERVER','MSSQL$*' -ErrorAction SilentlyContinue)) {
    $name = if($service.Name -eq 'MSSQLSERVER'){'MSSQLSERVER'}else{$service.Name.Substring(6)}
    if (!$result.ContainsKey($name)) { $result[$name]=[pscustomobject]@{Name=$name;Version='Kayit bilgisi yok';PatchLevel='';Edition='';Service=[string]$service.Status} }
  }
  return @($result.Values | Sort-Object Name)
}
function Get-TempoNextInstance($names) {
  $candidate='TEMPODEMO';$number=2
  while ($names -contains $candidate) { $candidate='TEMPODEMO'+$number; $number++ }
  return $candidate
}
function Test-TempoSaPassword([string]$Value) {
  return $Value.Length -ge 12 -and $Value -cmatch '[A-Z]' -and $Value -cmatch '[a-z]' -and $Value -match '[0-9]' -and $Value -match '[^A-Za-z0-9]' -and $Value -notmatch '["\\\r\n]'
}
function Get-TempoInventory {
  $culture=Get-Culture; $format=$culture.DateTimeFormat; $computer=Get-CimInstance Win32_ComputerSystem; $os=Get-CimInstance Win32_OperatingSystem
  $programs=@(foreach($key in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*','HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')) {
    Get-ItemProperty $key -ErrorAction SilentlyContinue | Where-Object {$_.DisplayName} | Select-Object DisplayName,DisplayVersion
  })
  $ssms=@($programs | Where-Object {$_.DisplayName -match 'SQL Server Management Studio'})
  $javaAkis=@($programs | Where-Object {$_.DisplayName -match 'Java|OpenJDK|Temurin|AKIS|AKİS'})
  $home=try{(Get-WinHomeLocation).HomeLocation}catch{'Okunamadi'}
  $languages=try{((Get-WinUserLanguageList).LanguageTag -join ', ')}catch{'Okunamadi'}
  $systemLocale=Get-WinSystemLocale
  $pending=(Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
  $principal=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
  [pscustomobject]@{
    Computer=$env:COMPUTERNAME; DesktopUser=$computer.UserName; ReportUser=[Security.Principal.WindowsIdentity]::GetCurrent().Name
    Windows=$os.Caption; WindowsVersion=$os.Version; Architecture=$os.OSArchitecture; Admin=$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    Country=$home; Culture=$culture.Name; CultureDisplay=$culture.DisplayName; UILanguage=(Get-UICulture).Name; UserLanguages=$languages
    SystemLocale=$systemLocale.Name; SystemLocaleDisplay=$systemLocale.DisplayName; AnsiCodePage=(Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage').ACP
    ShortDate=$format.ShortDatePattern; LongDate=$format.LongDatePattern; ShortTime=$format.ShortTimePattern; LongTime=$format.LongTimePattern; FirstDay=$format.GetDayName($format.FirstDayOfWeek)
    DecimalSeparator=$culture.NumberFormat.NumberDecimalSeparator; GroupSeparator=$culture.NumberFormat.NumberGroupSeparator; ListSeparator=$culture.TextInfo.ListSeparator; TimeZone=(Get-TimeZone).Id
    PendingRestart=$pending; SqlInstances=@(Get-TempoSqlInstances); SSMS=$ssms; JavaAkis=$javaAkis
  }
}
if($ReportOnly){
 try{
  $inventory=Get-TempoInventory
  $json=$inventory | ConvertTo-Json -Depth 6 -Compress
  $payload=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json))
  Write-Host (('TD'+'I|')+$ReportJob+'|'+$payload+';')
 }catch{Write-Error ('Makine bilgileri okunamadi: '+$_.Exception.Message)}
 return
}
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$form=New-Object Windows.Forms.Form
$form.Text='Tempo Bilisim | Demo Kurulumu';$form.Size=New-Object Drawing.Size(880,760);$form.MinimumSize=$form.Size;$form.StartPosition='CenterScreen'
$layout=New-Object Windows.Forms.TableLayoutPanel;$layout.Dock='Fill';$layout.ColumnCount=1;$layout.RowCount=3;$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle('Absolute',52)));$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle('Percent',100)));$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle('Absolute',280)));$form.Controls.Add($layout)
$check=New-Object Windows.Forms.Button;$check.Text='Hedef bilgisayari kontrol et';$check.Dock='Fill';$layout.Controls.Add($check,0,0)
$report=New-Object Windows.Forms.TextBox;$report.Multiline=$true;$report.ReadOnly=$true;$report.ScrollBars='Both';$report.WordWrap=$false;$report.Dock='Fill';$report.Font=New-Object Drawing.Font('Consolas',10);$report.Text='Kontrol et dugmesi SQL/SSMS ve bolge bilgilerini okur. Bu islem ayarlari degistirmez.';$layout.Controls.Add($report,0,1)
$settings=New-Object Windows.Forms.TableLayoutPanel;$settings.Dock='Fill';$settings.ColumnCount=3;$settings.RowCount=7;$settings.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Absolute',180)));$settings.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent',100)));$settings.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Absolute',115)));$layout.Controls.Add($settings,0,2)
function Add-TempoLabel($text,$row){$label=New-Object Windows.Forms.Label;$label.Text=$text;$label.Dock='Fill';$label.TextAlign='MiddleLeft';$settings.Controls.Add($label,0,$row)}
Add-TempoLabel 'Yeni instance adi' 0
$instance=New-Object Windows.Forms.TextBox;$instance.Text='TEMPODEMO';$instance.MaxLength=16;$instance.Dock='Fill';$settings.Controls.Add($instance,1,0)
Add-TempoLabel 'SQL 2019 Express medyasi' 1
$media=New-Object Windows.Forms.TextBox;$media.Dock='Fill';$settings.Controls.Add($media,1,1)
$elevate=New-Object Windows.Forms.Button;$elevate.Text='Yonetici olarak ac';$elevate.Dock='Fill';$settings.Controls.Add($elevate,2,0)
$elevate.Add_Click({try { Start-Process (Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe') -Verb RunAs -ArgumentList @('-NoProfile','-STA','-File',('"'+$PSCommandPath+'"'));$form.Close() } catch { [Windows.Forms.MessageBox]::Show($_.Exception.Message,'Yonetici onayi')|Out-Null }})
$browse=New-Object Windows.Forms.Button;$browse.Text='Dosya sec';$browse.Dock='Fill';$settings.Controls.Add($browse,2,1)
Add-TempoLabel 'Siralama duzeni (collation)' 2
$collation=New-Object Windows.Forms.ComboBox;$collation.DropDownStyle='DropDownList';$collation.Dock='Fill';$collation.Items.AddRange(@('Turkish_CI_AS','SQL_Latin1_General_CP1254_CI_AS','Latin1_General_CI_AS','SQL_Latin1_General_CP1_CI_AS'));$settings.Controls.Add($collation,1,2)
Add-TempoLabel 'Kimlik dogrulama' 3
$auth=New-Object Windows.Forms.ComboBox;$auth.DropDownStyle='DropDownList';$auth.Items.AddRange(@('Windows','Windows + SQL (karma)'));$auth.SelectedIndex=0;$auth.Dock='Fill';$settings.Controls.Add($auth,1,3)
$password=New-Object Windows.Forms.TextBox;$password.UseSystemPasswordChar=$true;$password.AccessibleName='sa parolasi (karma mod)';$password.Enabled=$false;$password.Dock='Fill';$settings.Controls.Add($password,2,3)
$auth.Add_SelectedIndexChanged({$password.Enabled=$auth.SelectedIndex -eq 1;if(!$password.Enabled){$password.Clear()}})
$license=New-Object Windows.Forms.CheckBox;$license.Text='Kurulum medyasindaki Microsoft SQL Server lisans kosullarini kabul ediyorum.';$license.Dock='Fill';$settings.Controls.Add($license,1,4);$settings.SetColumnSpan($license,2)
$install=New-Object Windows.Forms.Button;$install.Text='Onayla ve yeni instance kur';$install.Dock='Fill';$install.Enabled=$false;$settings.Controls.Add($install,1,5)
$download=New-Object Windows.Forms.Button;$download.Text='Resmi indirme';$download.Dock='Fill';$settings.Controls.Add($download,2,5)
$note=New-Object Windows.Forms.Label;$note.Text='Yonetici yetkisi gerekir. Tam SQLEXPR_x64 medyasi secin; SSEI web indiricisi kabul edilmez. Mevcut instance degistirilmez. Bolge bicimleri raporu calistiran hesaba aittir.';$note.Dock='Fill';$settings.Controls.Add($note,0,6);$settings.SetColumnSpan($note,3)
$script:inventory=$null
$script:sqlProcess=$null;$script:sqlName='';$script:sqlLog=''
$watch=New-Object Windows.Forms.Timer;$watch.Interval=1000
$watch.Add_Tick({
 if(!$script:sqlProcess -or !$script:sqlProcess.HasExited){return}
 $watch.Stop();$code=$script:sqlProcess.ExitCode;$name=$script:sqlName;$log=$script:sqlLog;$script:sqlProcess=$null
 $settings.Enabled=$true;$check.Enabled=$true;$install.Enabled=$false;$form.UseWaitCursor=$false
 $report.AppendText("`r`nSQL kurulum cikis kodu: $code`r`nKurulum logu: $log`r`n")
 try{
  if($code -notin @(0,3010)){throw ('Kurulum basarisiz. Kod: '+$code+' Log: '+$log)}
  if(!@(Get-TempoSqlInstances | Where-Object {$_.Name -eq $name}).Count){throw 'Kurulum kodu basarili ancak instance dogrulanamadi. Logu kontrol edin.'}
  [Windows.Forms.MessageBox]::Show("Instance: $env:COMPUTERNAME\$name`nSonuc: $code`n3010 kodu yeniden baslatma gerektigini belirtir. Otomatik yeniden baslatilmaz.",'Kurulum sonucu')|Out-Null
 }catch{[Windows.Forms.MessageBox]::Show($_.Exception.Message,'SQL kurulumu sonucu')|Out-Null}
})
$form.Add_FormClosing({param($sender,$eventArgs)
 if($script:sqlProcess -and !$script:sqlProcess.HasExited){
  $answer=[Windows.Forms.MessageBox]::Show('SQL kurulumu devam ediyor. Panel kapanirsa kurulum sonucu burada izlenemez; kurulum sureci durdurulmaz. Kapatilsin mi?','Kurulum suruyor','YesNo','Warning')
  if($answer -ne 'Yes'){$eventArgs.Cancel=$true}
 }
})
$check.Add_Click({
 try {
  $script:inventory=Get-TempoInventory
  $i=$script:inventory
  $report.Text="BILGISAYAR: $($i.Computer)`r`nWindows: $($i.Windows) / $($i.WindowsVersion) / $($i.Architecture)`r`nWindows konsol hesabi: $($i.DesktopUser)`r`nRapor hesabi: $($i.ReportUser) / Yonetici: $($i.Admin)`r`n`r`nULKE / DIL / BOLGE`r`nUlke: $($i.Country)`r`nBolgesel bicim: $($i.CultureDisplay) [$($i.Culture)]`r`nArayuz dili: $($i.UILanguage)`r`nKullanici dilleri: $($i.UserLanguages)`r`nUnicode olmayan programlar: $($i.SystemLocaleDisplay) [$($i.SystemLocale)]`r`nANSI kod sayfasi: $($i.AnsiCodePage) (65001: UTF-8)`r`nKisa tarih: $($i.ShortDate)`r`nUzun tarih: $($i.LongDate)`r`nKisa saat: $($i.ShortTime)`r`nUzun saat: $($i.LongTime)`r`nHaftanin ilk gunu: $($i.FirstDay)`r`nOndalik / binlik / liste ayiraci: $($i.DecimalSeparator) / $($i.GroupSeparator) / $($i.ListSeparator)`r`nSaat dilimi: $($i.TimeZone)`r`nYeniden baslatma bekliyor: $($i.PendingRestart)`r`n`r`nSQL INSTANCE'LARI`r`n$(($i.SqlInstances | Format-Table Name,Version,PatchLevel,Edition,Service -AutoSize | Out-String).Trim())`r`n`r`nSQL SERVER MANAGEMENT STUDIO`r`n$(if($i.SSMS.Count){($i.SSMS | Format-Table -AutoSize | Out-String).Trim()}else{'Kurulu SSMS kaydi bulunamadi.'})"
  $report.AppendText("`r`n`r`nJAVA / AKIS KAYITLARI`r`n$(if($i.JavaAkis.Count){($i.JavaAkis | Format-Table -AutoSize | Out-String).Trim()}else{'Kurulu Java/AKIS kaydi bulunamadi.'})")
  $instance.Text=Get-TempoNextInstance @($i.SqlInstances | ForEach-Object {$_.Name})
  $install.Enabled=$i.Admin -and [Environment]::Is64BitOperatingSystem
  if($i.SqlInstances.Count){[Windows.Forms.MessageBox]::Show('Mevcut instance bulundu. Yeni kurulum farkli bir instance adiyla yapilacak. Oneri: '+$instance.Text,'Instance uyarisi')|Out-Null}
  if(!$i.Admin){[Windows.Forms.MessageBox]::Show('Kontrol tamamlandi. SQL kurmak icin bu paneli hedefte Yonetici olarak acin.','Yonetici yetkisi gerekli')|Out-Null}
 }catch{[Windows.Forms.MessageBox]::Show($_.Exception.Message,'Kontrol hatasi')|Out-Null}
})
$browse.Add_Click({$pick=New-Object Windows.Forms.OpenFileDialog;$pick.Filter='SQL Express tam medya (SQLEXPR*.exe)|SQLEXPR*.exe';if($pick.ShowDialog() -eq 'OK'){$media.Text=$pick.FileName};$pick.Dispose()})
$download.Add_Click({Start-Process 'https://www.microsoft.com/en-us/download/details.aspx?id=108837'})
$install.Add_Click({
 try {
  $name=$instance.Text.Trim()
  if($name -notmatch '^[A-Za-z][A-Za-z0-9_]{0,15}$' -or $name -eq 'MSSQLSERVER'){throw 'Harfle baslayan, en fazla 16 karakterlik yeni ad yazin. MSSQLSERVER kullanilmaz.'}
  $names=@(Get-TempoSqlInstances | ForEach-Object {$_.Name})
  if($names -contains $name){$instance.Text=Get-TempoNextInstance $names;throw ('Bu instance zaten var. Kurulum baslatilmadi. Onerilen yeni ad: '+$instance.Text)}
  if(!$license.Checked){throw 'Lisans kosullarini onaylayin.'}
  if(!$collation.SelectedItem){throw 'Mikro/demo icin kullanacaginiz collation degerini secin.'}
  if(!(Test-Path -LiteralPath $media.Text -PathType Leaf) -or [IO.Path]::GetFileName($media.Text) -notlike 'SQLEXPR*.exe'){throw 'Tam SQL Server 2019 Express SQLEXPR kurulum medyasini secin.'}
  $signature=Get-AuthenticodeSignature -LiteralPath $media.Text
  if($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation'){throw 'Gecerli Microsoft imzasi bulunamadi. Kurulum durduruldu.'}
  if((Get-Item -LiteralPath $media.Text).VersionInfo.ProductVersion -notmatch '^15\.'){throw 'SQL Server 2019 (15.x) medyasi gerekli.'}
  $mixed=$auth.SelectedIndex -eq 1
  if($mixed -and !(Test-TempoSaPassword $password.Text)){throw 'Karma mod icin en az 12 karakter, buyuk/kucuk harf, rakam ve sembol iceren sa parolasi yazin. Cift tirnak, ters bolu ve yeni satir kullanmayin.'}
  $account=[Security.Principal.WindowsIdentity]::GetCurrent().Name
  if($account -match '["\r\n]' -or $account -match '^NT AUTHORITY\\'){throw 'Yonetici yetkili gercek Windows kullanici hesabiyla calistirin; servis hesabi kabul edilmez.'}
  $answer=[Windows.Forms.MessageBox]::Show("Hedef: $env:COMPUTERNAME`nYeni instance: $name`nSQL 2019 Express`nWindows yoneticisi: $account`nKimlik dogrulama: $($auth.SelectedItem)`nCollation: $($collation.SelectedItem)`nTCP ve Named Pipes: kapali (yerel demo)`n`nSessiz kurulumu baslatmak istiyor musunuz?",'SQL kurulumu onayi','YesNo','Warning')
  if($answer -ne 'Yes'){return}
  $install.Enabled=$false;$check.Enabled=$false;$form.UseWaitCursor=$true;$report.AppendText("`r`nSQL kurulumu hazirlaniyor. Islem bitene kadar paneli kapatmayin.`r`n");$form.Refresh()
  $dir=Join-Path $env:LOCALAPPDATA ('TempoDestek\Demo\SQL2019-'+[Guid]::NewGuid().ToString('N'))
  [IO.Directory]::CreateDirectory($dir)|Out-Null
  $extract=Start-Process -FilePath $media.Text -ArgumentList @('/Q',('/X="'+$dir+'"')) -Wait -PassThru
  if($extract.ExitCode -ne 0){throw ('Medya acilamadi. Kod: '+$extract.ExitCode)}
  $setup=Join-Path $dir 'SETUP.EXE'
  if(!(Test-Path $setup)){throw 'Tam medyada SETUP.EXE bulunamadi.'}
  $signature=Get-AuthenticodeSignature $setup
  if($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation' -or (Get-Item $setup).VersionInfo.ProductVersion -notmatch '^15\.'){throw 'SQL 2019 SETUP.EXE dogrulanamadi.'}
  # Re-check immediately before setup; the operator report can be stale.
  if(@(Get-TempoSqlInstances | ForEach-Object {$_.Name}) -contains $name){throw 'Instance adi bu sirada kullanima alindi. Kurulum baslatilmadi.'}
  $args=@('/Q','/ACTION=Install','/FEATURES=SQLENGINE',('/INSTANCENAME='+$name),('/INSTANCEID='+$name),('/SQLSYSADMINACCOUNTS="'+$account+'"'),('/SQLCOLLATION='+$collation.SelectedItem),'/SQLSVCSTARTUPTYPE=Automatic','/TCPENABLED=0','/NPENABLED=0','/IACCEPTSQLSERVERLICENSETERMS')
  if($mixed){$args+=@('/SECURITYMODE=SQL',('/SAPWD="'+$password.Text+'"'))}
  $process=Start-Process -FilePath $setup -ArgumentList $args -PassThru
  $password.Clear()
  $script:sqlLog=Join-Path $env:ProgramFiles 'Microsoft SQL Server\150\Setup Bootstrap\Log\Summary.txt'
  $script:sqlProcess=$process;$script:sqlName=$name;$settings.Enabled=$false;$form.UseWaitCursor=$false
  $report.AppendText("`r`nSQL kurulumu calisiyor: $name`r`nLog: $script:sqlLog`r`n")
  $watch.Start()
 }catch{[Windows.Forms.MessageBox]::Show($_.Exception.Message,'SQL kurulum bilgisi')|Out-Null}
 finally{if(!$script:sqlProcess){$form.UseWaitCursor=$false;$check.Enabled=$true;$install.Enabled=$false}}
})
[void]$form.ShowDialog()
$watch.Stop();$watch.Dispose();$form.Dispose()
