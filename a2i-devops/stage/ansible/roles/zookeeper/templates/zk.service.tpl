Description= This service is used for controlling zookeeper serve

Wants=network.target
After=syslog.target network-online.target

[Service]
Type=simple
ExecStart=/usr/local/zookeeper/bin/zkServer.sh start
Restart=on-failure
RestartSec=10
KillMode=process

[Install]
WantedBy=multi-user.target
