Purpose of this project is a small workflow script for an automated transcription of voice recorded on a speech recorder.

The script consists of a few parts

1.) Check if the voice recorder is avaible
2.) Copy / convert files (supported formats: MP3, DSS, DSS2 is unfortunately not supported by ffmpeg)
3.) Call API
4.) Send an email with the transcript

The script is designed for use on a raspberry pi but can also be used in many different other scenarios.

GETTING STARTED

Prerequisites on debian based systems

1.) apt-get install ffmpeg mailutils jq
2.) Configure mail system for sending mails: dpkg-reconfigure exim4-config

3.) Move script to a directory of your choice (e. g. /etc)

4.) Install it as a service

cd /lib/systemd/system/
nano workflow.service

Content of workflow.service
[Unit]
Description=Workflow for DPM
After=multi-user.target

[Service]
Type=simple
ExecStart=/etc/workflow.sh
Restart=on-abort

[Install]
WantedBy=multi-user.target

5.) chmod 644 /lib/systemd/system/workflow.service

6.) chmod +x /etc/workflow.sh

systemctl daemon-reload
systemctl enable workflow.service
systemctl start workflow.service

API

I would recommend to use the script with two local APIs which are available on github

https://github.com/morioka/tiny-openai-whisper-api


