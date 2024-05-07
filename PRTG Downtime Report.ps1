# Developed by: Paul Roeber, 2024.

# Import PrtgApi and Microsoft PowerShell Utility modules (PrtgApi is the v1 version, available on Github)
Import-Module PrtgAPI
Import-Module Microsoft.PowerShell.Utility

# Set PRTG server details
$prtgServer = "<yourservername>"
$username = "<yourusername>"
$passhash = <yourpasshash>

# Calculate time range and convert to negative offset in seconds
$n = -1
$timeRange = 7 # Time range in days
$timeRangeSec = $timeRange * 86400 * $n 

# Connect to PRTG server
Connect-PrtgServer $prtgServer (New-Credential $username $passhash) -PassHash -IgnoreSSL

# Get all sensors tagged with YourDeviceTag
$sensors = Get-Sensor Ping -Tags YourDeviceTag

# Initialize array and CSV file to store downtime for each sensor
$sensorDowntime = @('Name,ID,TotalDaysDown,PercentDown') # Headers for output file
$sensorDowntime | Out-File -FilePath "C:\<yourfilepath>\sensor_downtime.csv" # Write headers to new file

# Step through each sensor and extract relevant data/calculate percent downtime, add results to array
foreach ($sensor in $sensors) {
	$ID = $sensor.ID # Get sensor ID
	$device = $sensor.Device # Get Device name

    	# Get downtime
	$deviceStatus = [TimeSpan]::FromSeconds(((Get-Sensor -Id $ID | Get-SensorHistory -Report -EndDate (Get-Date).AddSeconds($timeRangeSec) | where Status -eq Down).Duration | Measure-Object -Sum TotalSeconds).Sum)

        # Skip sensors with 0 downtime - comment out If statement and closing brace to include 0 downtime devices
	If ($deviceStatus.TotalSeconds -ne 0) {

        	# Calculate percentage downtime
		$percentageDowntime = $deviceStatus.TotalSeconds / ($n * $timeRangeSec)

        	# Add results to comma delimited array and write to csv file
        	$sensorDowntimeTemp = ($device, $ID, $deviceStatus.TotalDays, $percentageDowntime) -join ","
		$sensorDowntime += $sensorDowntimeTemp
		$sensorDowntimeTemp | Out-File -FilePath 'C:\<yourfilepath>\sensor_downtime.csv' -Append					
	}
		
        # echo $device # For debugging (comment out if not needed)
}

# For debugging (comment out next 4 lines if not needed)
#echo ""
#echo "===============FINISHED==============="
#echo ""
#echo $sensorDowntime

Write-Host "Sensor data saved to $csvFile"

# Email report
$sendMailMessageBlob = @{
    From = "PRTG-Downtime-Report <PRTG-noreply@<yourdomain>.com>"
    To = "user1 <user1@example.com>", "user2 <user2@example.com>" # Comment out while testing, uncomment if in production
    # To = "user1 <user1@example.com>" # Uncomment for testing. Comment out if in production
    Subject = "Device Downtime Report"
    Body = "Downtime report for the last 7 days"
    Attachments = "C:\<yourfilepath>\sensor_downtime.csv"
    SmtpServer = "aaa.bbb.ccc.ddd" #SMTP server IP address
}

Send-MailMessage @sendMailMessageBlob

Disconnect-PrtgServer
