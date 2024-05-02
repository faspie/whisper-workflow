#!/bin/bash

# apt-get install ffmpeg mailutils jq 
# dpkg-reconfigure exim4-config

# Anleitung für den Start als service
# https://gist.github.com/emxsys/a507f3cad928e66f6410e7ac28e2990f

# cd /lib/systemd/system/
# sudo nano workflow.service

#root@dpm1:/lib/systemd/system# cat workflow.service 
#[Unit]
#Description=Workflow for DPM
#After=multi-user.target
#
#[Service]
#Type=simple
#ExecStart=/etc/workflow.sh
#Restart=on-abort
#
#[Install]
#WantedBy=multi-user.target

#sudo chmod 644 /lib/systemd/system/workflow.service
#chmod +x /etc/workflow.sh
#sudo systemctl daemon-reload
#sudo systemctl enable workflow.service
#sudo systemctl start workflow.service

RECIPIENT="mail@example.com"

LASTSTATE=0

# set path to watch
DIR="/mnt/dpm"
mkdir -p $DIR

WORKDIR="/var/lib/workflow"
mkdir -p $WORKDIR/finished

device_present(){
VENDOR_ID="0911"
PRODUCT_ID="1f40"

# Philips Pocket Memo 9370 251c
# Philips Pocket memo 9350 2486
# Philips Speech Pocket Memo 4 1f40


if [ "$(lsusb -d $VENDOR_ID:$PRODUCT_ID)" == "" ]; then
	echo "device_present: VENDOR: $VENDOR_ID, PRODUCT: $PRODUCT_ID Not present"
	if [ $LASTSTATE == 0 ];
	then
		echo "device_present: Nothing has changed. Waiting..."
		return 0
	else
		echo "device_present: Device has been removed"
		return 0
	fi
	
else
	echo "device_present: VENDOR: $VENDOR_ID, PRODUCT: $PRODUCT_ID Device present"
	if [ $LASTSTATE == 0 ];
	then
		echo "device_present: New device found, this is new"
		return 1
	else
		echo "device_present: Device still found, but nothing to do..."
		return 2
	fi
	
fi
}

mount_device(){
# https://stackoverflow.com/questions/4189383/bash-script-to-detect-when-my-usb-is-plugged-in-and-to-then-sync-it-with-a-direc
# https://serverfault.com/questions/398187/how-to-delete-all-characters-in-one-line-after-with-sed

# different Volume labels for different recorder devices
for SDCARD_LABEL in "PHILIPS" "SANVOL" "DPM-VOLUME"
do
	BLKID=$(blkid -o full | grep $SDCARD_LABEL | sed 's|\(.*\)\: .*$|\1|')
	if [ "$BLKID" != "" ]; then
		echo "mount_device: Foung block device with label $SDCARD_LABEL, BLKID is $BLKID"
		umount -q $BLKID && echo "mount_device: Unmounting successful, umount errorcode is $?" || echo "mount_device: Error unmounting, umount errorcode is $?"
		sleep 1
		mount -o rw $BLKID /mnt/dpm && echo "mount_device: Mounting $BLKID successful, mount errorcode is $?" || echo "mount_device: Error mounting $BLKID, mount errorcode is $?"
		return $?	
	else
		echo "mount_device: No block device with label $SDCARD_LABEL found."
	fi

done

}

umount_device(){
echo "umount_device: Trying to unmount the device before remounting it..."
umount -q $DIR && echo "umount_device: Unmounting successful" || echo "umount_device: Error unmounting"
}

copy_file()
{
echo "copy_file: Listing all files via ls: $(ls $DIR)"

for f in "$DIR"/*; do
	echo "copy_file: Processing file $f..."
	case $f in 
	*.MP3|*.mp3)
		[ -f "$f" ] && echo "copy_file: MP3 file found, processing File: $f"
		[ -f "$f" ] && FILENAME="`rev <<< "$f" | cut -d"." -f2- | rev`.mp3"
		[ -f "$f" ] && echo "copy_file: moving $f to $WORKDIR/$(basename $FILENAME)"
		[ -f "$f" ] && mv "$f" $WORKDIR/$(basename $FILENAME)
	;;
	
	*.DSS|*.dss)
		[ -f "$f" ] && echo "copy_file: DSS file found, processing File: $f"
		# https://stackoverflow.com/questions/2664740/extract-file-basename-without-path-and-extension-in-bash
		[ -f "$f" ] && FILENAME="`rev <<< "$f" | cut -d"." -f2- | rev`.mp3"
		[ -f "$f" ] && echo "copy_file:  Convert MP3 Filename: $FILENAME"
		#  Example: ffmpeg -i /media/fabian/PHILIPS/spie0484.DSS test.mp3
		[ -f "$f" ] && ffmpeg -i "$f" "$FILENAME"
		[ -f "$f" ] && mv "$f" $WORKDIR/finished
		[ -f "$FILENAME" ] && mv "$FILENAME" $WORKDIR
	;;
	
	*.DS2|*.DS2)
		[ -f "$f" ] && echo "copy_file: DS2 file found, processing File: $f"
		# https://stackoverflow.com/questions/2664740/extract-file-basename-without-path-and-extension-in-bash
		[ -f "$f" ] && FILENAME="`rev <<< "$f" | cut -d"." -f2- | rev`.mp3"
		[ -f "$f" ] && echo "copy_file:  Convert MP3 Filename: $FILENAME"
		#  Example: ffmpeg -i /media/fabian/PHILIPS/spie0484.DSS test.mp3
		[ -f "$f" ] && ffmpeg -i "$f" "$FILENAME"
		[ -f "$f" ] && mv "$f" $WORKDIR/finished
		[ -f "$FILENAME" ] && mv "$FILENAME" $WORKDIR
	;;
		
	*)
		echo "copy_file: Unknown file type, ignoring"
	;;  
	esac
done

echo "copy_file: File copy finished, errorlevel $?"
} 

whisper()
{

WHISPER_SERVER=whisper


[ -f "$1" ] && TXTNAME="`rev <<< "$1" | cut -d"." -f2- | rev`.txt"
echo "whisper: TXTNAME is $TXTNAME"

while ! ping -c1 $WHISPER_SERVER &>/dev/null
        do echo "whisper: ping Fail - `date`"
done
echo "whisper Host Found - `date`"

curl http://$WHISPER_SERVER:8082/api/transcriptions \
 -H "Content-Type: multipart/form-data" \
 -F language="de" \
 -F modelSize="large-v3" \
 -F device="cuda" \
 -F file="@$1" \
 && echo "whisper: Web API whisperapi curl success" || echo "whisper: curl error"


curl http://$WHISPER_SERVER:8000/v1/audio/transcriptions \
  -H "Content-Type: multipart/form-data" \
  -F model="whisper-1" \
  -F file="@$1" \
  | jq -r '.text' \
  > $TXTNAME \
  && echo "whisper: tiny-whisper-api curl success" || echo "whisper: curl error"

[ -s "$TXTNAME" ] && echo "whisper: here is the output text of $TXTNAME" || echo "whisper: $TXTNAME does not exist or is empty"
cat $TXTNAME | fold -s -w 100

}

send_mail()
{


[ -f "$1" ] && echo "send_mail: Sending mail, recipient $RECIPIENT, content: $1"
cat $1 | fold -s -w 100 | mail.mailutils -M -aFrom:whisper@example.com -s "Whisper: Aktuelle Aufzeichnung `rev <<< "$(basename $1)" | cut -d"." -f2- | rev`" -A $1 "$RECIPIENT" && echo "send_mail: success" || echo "send_mail: error"

}



main(){

device_present

case "$?" in
  0)   echo "main: Main Function waiting for device..."
       LASTSTATE=0
       sleep 1
       ;;
       
  1)   echo "main: Found DPM device"
      
       sleep 1

       mount_device
       if [ $? == 0 ]; then
		echo "main: mount_device successful, return code is $?"
		copy_file
		echo "main: copy_file return code is $?"
		sleep 1	
       else
		echo "main: mount_device error, return code is $?"	
		echo "main: copy_file overridden, because mount failed"
		LASTSTATE=0
		
	fi

	umount_device; echo "main: umount_device return code is $?"; sleep 1

	if [ "$(ls -A $WORKDIR/*.mp3 2> /dev/null)" ]; then
		echo "main: Listing all files via ls in WORKDIR $WORKDIR: $(ls $WORKDIR/*.mp3)"
		for f in "$WORKDIR"/*.mp3 ; do 
			LASTSTATE=1
			[ -f "$f" ] && echo "main: calling Whisper for file: $f" || LASTSTATE=0
			[ -f "$f" ] && whisper $f || LASTSTATE=0
			[ -f "$f" ] && TXTNAME="`rev <<< "$f" | cut -d"." -f2- | rev`.txt" || LASTSTATE=0
			[ -f "$TXTNAME" ] && [ -s "$TXTNAME" ] && send_mail $TXTNAME || LASTSTATE=0
			[ -f "$f" ] && [ -s "$TXTNAME" ] && mv "$f" $WORKDIR/finished || LASTSTATE=0
			[ -f "$TXTNAME" ] && [ -s "$TXTNAME" ] && mv "$TXTNAME" $WORKDIR/finished || LASTSTATE=0
		done   
        else
        	echo "main: Workdir empty"
        	LASTSTATE=1
        fi
                     
       ;;
     
    
  2)   echo "main: Device stil present - Nothing to do"
       sleep 10
       ;;
esac


}

while true 
do
	main
	echo "-------------------------------------------------------------------"
done

