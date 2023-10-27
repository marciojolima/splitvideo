#https://www.w3schools.blog/using-ffmpeg-to-split-video-files-by-size

Class SpliterMedia{
    [string]$media
    [object]$mediaInfo
    [int]$mediaBytesLength
    [int]$lengthLimit
    [TimeSpan]$duration
    [int]$complementedSecond = 1 #Para compensar a quebra do video
    [string]$durationFormatted
    [int]$totalSegments = 1

    SpliterMedia([string]$media, $lengthLimit){
        $this.media = $media
        $this.lengthLimit = $lengthLimit
        $this._collectInfo()
    }

    [void]_collectInfo(){
        if (Test-Path $this.media){
            $ffmpegCommand = -join('ffmpeg -i "', $this.media, '"', ' 2>&1')
            $this.mediaInfo = Invoke-Expression $ffmpegCommand
            $saidaFFmpeg = $this.mediaInfo | Select-String -Pattern 'Duration'

            if ($saidaFFmpeg -match "Duration: (.*?),") {
                $this.duration = [TimeSpan]::Parse($Matches[1])
                $this.durationFormatted = $Matches[1]

                $this.mediaBytesLength = (Get-Item $this.media).Length
                $this.totalSegments = $this._getTotalSegments()

            } else {
                Write-Host "Não foi possível obter a duração do arquivo MP4."
            }

        } else {
            throw 'Arquivo não existe ou caminho errado'
        }
    }

    [int]_getTotalSegments(){
        $segments = ($this.mediaBytesLength) / $this.lengthLimit
        #The 'ComplmentedSecond' was added at the beginning of each video segment to enhance video viewing
        $bytesExtras = [math]::Ceiling(($this.complementedSecond / $this.duration.TotalSeconds) * $this.mediaBytesLength)
        $totalBytesExtras = $bytesExtras * ($segments - 1) #the first segment is ignored
        $segments = ($this.mediaBytesLength + $totalBytesExtras) / $this.lengthLimit
        return [math]::Ceiling($segments)
    }

    [TimeSpan]_getDuration($mediaFile){
        if (Test-Path $mediaFile){
            $outFFmpeg = ffmpeg -i $mediaFile 2>&1 | Select-String -Pattern 'Duration'
            if($outFFmpeg -match 'Duration: (.*?),'){
                return [TimeSpan]::Parse($Matches[1])
            } else {
                Write-Output $_
                throw 'Duration nao foi localizada na stderr ou stdout padrao'
            }

        } else {
            Write-Output $_
            throw -join($mediaFile, " nao localizado")
        }
    }

    [void]split(){
        $currTimeSec = 0

        $i = 1
        $segments = $this.totalSegments + $i
        While($i -lt $segments){
            $segmentName = "segmento$i.mp4"

            ffmpeg -ss $currTimeSec -i $this.media -fs $this.lengthLimit -c copy $segmentName -y
            [TimeSpan]$newDuration = $this._getDuration($segmentName)
            $currTimeSec = ($currTimeSec + $newDuration.TotalSeconds) - $this.complementedSecond

            Write-Host "arquivo: $segmentName criado."

            $i++
        }
    }

 }



$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog `
    -Property @{
        InitialDirectory = [Environment]::GetFolderPath('Desktop')
        Filter           = 'Videos (*.mp4)|*.mp4'
    }

$FileBrowser.ShowDialog()
$fileName = $FileBrowser.FileName
Write-Host $fileName

$divider = [SpliterMedia]::new($fileName, 50000000);
$divider.split()