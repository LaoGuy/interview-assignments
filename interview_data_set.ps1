$logpath = '.\interview_data_set'
$log = Get-Content $logpath
$outputs = New-Object -TypeName System.Collections.ArrayList     #创建最终数组

ForEach($log_line in $log)     #逐行读取
{
    if ( $log_line.Contains( '---') )    #判断是否是省略行
	{
		$log_line = $pre_line
	}
    elseif ($log_line.Contains('syslogd'))             #判断syslog数据
    {
        $t=0
        $pre_line=$log_line
        continue
    }
    elseif ($log_line.Contains('	') -and ($t -ne 1))         #判断是否未连续行数据
    {
        $pre_line=$pre_line.Split('`n')[0]+$log_line.Split('	')[1]   #剔除换行符，将两行合并
        $t+=1
        continue
    }
    elseif ($log_line.Contains('	') -and ($t -eq 1))
    {
        $log_line=$pre_line+$log_line                        #将三行合并
    }
    
	$collecting = CollectError $log_line
}

Function TimeToWindow ($time)       #处理时间
{
	$time_parts = $time.split(':')
	$hour = [int]$time_parts[0]
	$nexthour = $hour+1
	if($hour -lt 10){
	$hour_string = "0"+ $hour.ToString()
	}
	else{
	$hour_string = $hour.ToString()
	}
	if($nexthour -lt 10){
	$nexthour_string = "0"+ $nexthour.ToString()
	}
	else{
	$nexthour_string = $nexthour.ToString()
	}
	return $hour_string + "00-" + $nexthour_string + "00"
}

Function AddErrorToOutput([string]$deviceName,[string]$processId,[string]$processName,[string]$description,[string]$timeWindow)   #将处理好的错误日志加入结果数组
{
	foreach($output in $outputs)
	{
		if (($output.description -eq $description)-and ($output.timeWindow -eq $timeWindow))      #统计和去重
		{
			$output.numberOfOccurrence += 1
			return
		}
	}
	$error = New-Object -TypeName PSObject -Property $properties @{     #将新错误加入数组
	   'deviceName' = $deviceName
	   'processId' = $processId                                 
	   'processName' = $processName
	   'description' = $description
	   'timeWindow' = $timeWindow
	   'numberOfOccurrence' = 1
   }
	$outputs.Add($error)
}

Function CollectError ($line)    #处理错误日志
{
	$mapping = $line -match '\((.*)\[(\d.*)\]\)\: (.*)'             #查找是否有格式类似(XXX[XXXX]): XXX的错误显示
	if ($matches)
	{
		$part = $line.split(' ')                                    #按照空格分隔开，以便找到各项信息
		$deviceName = $part[3]
		$time = $part[2]
		$timeWindow = TimeToWindow $time                           
		$processId = $matches[2]
		$processname = $matches[1]
		$description = $matches[3]
		$adding = AddErrorToOutput $deviceName $processId $processName $description $timeWindow    #加入结果数组
	}
    else                                                            #处理其他非标准日志
    {
        $mapping = $line.split(' ')[4] -match '^[a-zA-Z\.]*'   #切分并提取进程名称
        $part = $line.split(' ') 
        $deviceName = $part[3]
		$time = $part[2]
		$timeWindow = TimeToWindow $time                            
		$processId = $line.split('[')[1].split(']')[0]
		$processname = $matches[0]
		$temp = $line -split ':',4                          #提取描述内容
        $description = $temp[3]
		$adding = AddErrorToOutput $deviceName $processId $processName $description $timeWindow 
    }
}



Write-Output $outputs

$output_body = $outputs | ConvertTo-Json       #转换成json

Invoke-WebRequest https://foo.com/bar -Method POST -ContentType "application/json" -Body $output_body