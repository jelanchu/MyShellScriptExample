#!/bin/bash
cameraPropFile="camera.properties"
dynaminRoiPropFile="dynamicRoi.properties"
dynamicRoiTemplate=""
function check_roi()
{
	local stat=0
	
	roiStr=$1
	IFS=':' read -r -a array <<< "$roiStr"
	#echo -e "array length: ${#array[@]}"
	
	if (( ${#array[@]} < 4 )); then
		echo -e "Wrong roi setting! Please reenter the roi setting.\n" >&2
		return $stat
	fi	 
	#echo -e "x: ${array[0]}.\n"
	
	if (( $(echo "${array[0]} < 0" |bc -l) )) || (( $(echo "${array[1]} < 0" |bc -l) )); then
		echo -e "x, y ratio value cannot smaller than zero.\n" >&2
	elif (( $(echo "${array[0]} >= 1" |bc -l) )) || (( $(echo "${array[1]} >= 1" |bc -l) )); then
			echo -e "x, y ratio value cannot bigger or equal than one.\n" >&2
	elif (( $(echo "${array[2]} <= 0" |bc -l) )) || (( $(echo "${array[3]} < 0" |bc -l) )); then
		echo -e "width, height ratio value cannot smaller or equal than zero.\n" >&2
	elif (( $(echo "(${array[0]} + ${array[2]}) > 1" |bc -l) )); then
		echo -e "x ratio value plus width ratio value cannot bigger than one.\n" >&2
	elif (( $(echo "(${array[1]} + ${array[3]}) > 1" |bc -l) )); then
		echo -e "y ratio value plus height ratio value cannot bigger than one.\n" >&2
	else
		stat=1	
	fi	
		
	return $stat
}

function is_number() {
	local result=0
	
	re='^[0-9]+$'
	if ! [[ $1 =~ $re ]] ; then
		echo "error: Not a number" >&2
	else
		result=1	
	fi
	
	return $result 	
}

function read_dynamic_roi_template() {
	local tempJsonSt=""
	
	file="./dynamicRoi.template"

	if [ -f "$file" ]
	then
		#echo "$file found."
		while IFS='=' read -r key value
		do
			if [[ "$key" =~ \#.* ]]; then
				continue 
			fi
			
			key=$(echo $key | tr '.' '_')
			
			#echo "${key}='${value}'"
			is_number $value
			if (( $? == 0 )); then
				tempJsonStr="${tempJsonStr}\"${key}\":\"${value}\""
			else
				tempJsonStr="${tempJsonStr}\"${key}\":${value}"	
			fi
			tempJsonStr="${tempJsonStr},"
		done < "$file"
		
		#echo "before tempJsonStr: " $tempJsonStr
		tempJsonStr=("{""${tempJsonStr%?}""}")
		
		#echo "tempJsonStr: " $tempJsonStr
	else
		echo "$file not found."
	fi
	
	echo -e $tempJsonStr
}

function create_dynamic_roi() {
	local roiId=$1
	local tempStr='{'
	
	tempStr="$tempStr\"roiId\":$roiId,\"dynamicRoi\":$dynamicRoiTemplate"
	tempStr="$tempStr"'}'
	echo -e $tempStr
}

function create_roi() {
	local cameraId=$1
	local dynamicRoiFilename="camera"$cameraId"_dynamicRoi.properties"
	local tempStr=""
	local tempDynamicRoiStr=""
	local roiNum=0
	while true; do
	read -e -p "ROI Ratio [x:y:width:height(0.3:0:0.7:1) | empty]: " roi
	#		  read -e -p "Sample period [milliseconds]: " -i $DefaultSamplePeroid samplePeroid
	#          echo "$cameraId=$rtsp,$enable,$roi,$samplePeroid" >> $cameraPropFile
	tempStr=""
	if [ ${#roi} -eq 0 ];then
		roi="0:0:1:1"
		set -f                      # avoid globbing (expansion of *).
		array=(${roi//:/ })
		tempStr="{\"roiId\":0,\"roi\":{\"xRatio\":${array[0]},\"yRatio\":${array[1]},\"widthRatio\":${array[2]},\"heightRatio\":${array[3]}}}"
		tempDynamicRoiStr=$(create_dynamic_roi $roiNum)
		break
	else
		check_roi $roi
		if (( $? == 0 )); then
			continue
		fi
		
		set -f                      # avoid globbing (expansion of *).
		array=(${roi//:/ })
		tempStr="{\"roiId\":${roiNum},\"roi\":{\"xRatio\":${array[0]},\"yRatio\":${array[1]},\"widthRatio\":${array[2]},\"heightRatio\":${array[3]}}}"
		tempDynamicRoiStr=$(create_dynamic_roi $roiNum)		 	
		while true; do
	  		read -p "Add another ROI Ratio?(Y/N)?" yn
	  		case $yn in
	  			[Yy]* ) read -e -p "ROI Ratio [x:y:width:height(0.3:0:0.7:1)]: " aroi
	  				#[{"xRatio":0.0,"yRatio":0.0,"widthRatio":1.0,"heightRatio":1.0}]
					check_roi $aroi
					if (( $? == 0 )); then
						continue
					fi
					set -f                      # avoid globbing (expansion of *).
					array=(${aroi//:/ })
					roiNum=${roiNum+1}
	  				tempStr="${tempStr},{\"roiId\":${roiNum},\"roi\":{\"xRatio\":${array[0]},\"yRatio\":${array[1]},\"widthRatio\":${array[2]},\"heightRatio\":${array[3]}}}"
					
					tempDynamicRoiStr="${tempDynamicRoiStr},$(create_dynamic_roi $roiNum)"
	  				;;
	  			[Nn]* ) 
					break;;
	  		esac
	 	done
	    break
	fi
	done
	echo "[$tempDynamicRoiStr]" > $dynamicRoiFilename
	
	echo -e $tempStr
}



# main
dynamicRoiTemplate="$(read_dynamic_roi_template)"
echo "dynamicRoiTemplate: $dynamicRoiTemplate"

touch "$cameraPropFile"
while true; do
	read -p "New an camera and its rtsp?(Y/N)?" yn
	case $yn in
			[Yy]* ) echo "Enter the camera id and its rtsp url."
					read -e -p "Camera ID: " cameraId
					read -e -p "RTSP URL: " rtsp
					read -e -p "Enable [true|false]: " enable
 		  			jsonROI="[$(create_roi $cameraId)]"
					echo "$cameraId=$rtsp,$enable,$jsonROI" >> $cameraPropFile 
					;;
			[Nn]* ) break;;
			* ) echo "Please answer yes or no.";;
	esac
done