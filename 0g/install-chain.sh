#!/bin/bash

NODE="0g"
CHAIN_ID=zgtendermint_16600-2
export DAEMON_HOME=$HOME/.0gchain
export DAEMON_NAME=0gchaind
bash_profile=$HOME/.bash_profile
VERSION=1.21.13
OG_VERSION=0.3.1

exists()

{
  command -v "$1" >/dev/null 2>&1
}

if exists curl; then
echo ''
else
  sudo apt update && sudo apt install curl -y < "/dev/null"
fi


if [ -f "$bash_profile" ]; then
    source $HOME/.bash_profile
fi


function install_0g() {

	if [ -d "$DAEMON_HOME" ]; then
		new_folder_name="${DAEMON_HOME}_$(date +"%Y%m%d_%H%M%S")"
		mv "$DAEMON_HOME" "$new_folder_name"
	fi

	echo 'export CHAIN_ID='\"${CHAIN_ID}\" >> $HOME/.bash_profile

	if [ ! $VALIDATOR ]; then
		read -p "Enter validator name: " VALIDATOR
		echo 'export VALIDATOR='\"${VALIDATOR}\" >> $HOME/.bash_profile
	fi

	echo 'source $HOME/.bashrc' >> $HOME/.bash_profile
	source $HOME/.bash_profile

	sleep 1
	cd $HOME
	sudo apt update
	sudo apt install make unzip clang pkg-config lz4 libssl-dev build-essential git jq ncdu bsdmainutils htop -y < "/dev/null"

	echo -e '\n\e[42mInstall Go\e[0m\n' && sleep 1
	cd $HOME

	wget -O go.tar.gz https://go.dev/dl/go$VERSION.linux-amd64.tar.gz
	sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go.tar.gz && rm go.tar.gz
	echo 'export GOROOT=/usr/local/go' >> $HOME/.bash_profile
	echo 'export GOPATH=$HOME/go' >> $HOME/.bash_profile
	echo 'export GO111MODULE=on' >> $HOME/.bash_profile
	echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile && . $HOME/.bash_profile
	go version

	echo -e '\n\e[42mInstall software\e[0m\n' && sleep 1

	sleep 1
	
	# install 0g-chain
	cd $HOME
	rm -rf 0g-chain
	git clone -b v${OG_VERSION} https://github.com/0glabs/0g-chain.git
	cd 0g-chain
	make install
	source ~/.profile
	$DAEMON_NAME version

	# init node

	$DAEMON_NAME init "${VALIDATOR}" --chain-id "$CHAIN_ID"
	sleep 1
	$DAEMON_NAME config chain-id $CHAIN_ID
	$DAEMON_NAME config keyring-backend test
	
	# download genesis
	rm $DAEMON_HOME/config/genesis.json
	wget https://github.com/0glabs/0g-chain/releases/download/v0.2.3/genesis.json  -O $DAEMON_HOME/config/genesis.json

	# add seed and peer
	SEEDS="81987895a11f6689ada254c6b57932ab7ed909b6@54.241.167.190:26656,010fb4de28667725a4fef26cdc7f9452cc34b16d@54.176.175.48:26656,e9b4bc203197b62cc7e6a80a64742e752f4210d5@54.193.250.204:26656,68b9145889e7576b652ca68d985826abd46ad660@18.166.164.232:26656"
	sed -i.bak -e "s/^seeds *=.*/seeds = \"${SEEDS}\"/" $DAEMON_HOME/config/config.toml
	PEERS="6dbb0450703d156d75db57dd3e51dc260a699221@152.53.47.155:13456,1bf93ac820773970cf4f46a479ab8b8206de5f60@62.171.185.81:12656,df4cc52fa0fcdd5db541a28e4b5a9c6ce1076ade@37.60.246.110:13456,66d59739b6b4ff0658e63832a5bbeb29e5259742@144.76.79.209:26656,76cc5b9beaff9f33dc2a235e80fe2d47448463a7@95.216.114.170:26656,adc616f440155f4e5c2bf748e9ac3c9e24bf78ac@51.161.13.62:26656,cd662c11f7b4879b3861a419a06041c782f1a32d@89.116.24.249:26656,40cf5c7c11931a4fdab2b721155cc236dfe7a809@84.46.255.133:12656,11945ced69c3448adeeba49355703984fcbc3a1a@37.27.130.146:26656,c02bf872d61f5dd04e877105ded1bd03243516fb@65.109.25.252:12656,d5e294d6d5439f5bd63d1422423d7798492e70fd@77.237.232.146:26656,386c82b09e0ec6a68e653a5d6c57f766ae73e0df@194.163.183.208:26656,4eac33906b2ba13ab37d0e2fe8fc5801e75f25a0@154.38.168.168:13456,c96b65a5b02081e3111b8b38cd7f5df76c7f9404@185.182.185.160:26656,48e3cab55ba7a1bc8ea940586e4718a857de84c4@178.63.4.186:26656"
	sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $DAEMON_HOME/config/config.toml

	# set min gas price
	sed -i "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"0ua0gi\"/" $DAEMON_HOME/config/app.toml


	sed -i.bak -e "s/^pruning *=.*/pruning = \"custom\"/" $DAEMON_HOME/config/app.toml
	sed -i.bak -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"100\"/" $DAEMON_HOME/config/app.toml
	sed -i.bak -e "s/^pruning-interval *=.*/pruning-interval = \"50\"/" $DAEMON_HOME/config/app.toml
	sed -i.bak -e "s/prometheus = false/prometheus = true/" $DAEMON_HOME/config/config.toml


	if awk "BEGIN {exit ($OG_VERSION < 0.3.0) ? 0 : 1}"; then
	sudo tee /etc/systemd/system/${NODE}.service > /dev/null <<EOF
[Unit]
Description=$NODE Node
After=network.target

[Service]
User=$USER
Type=simple
ExecStart=$(which 0gchaind) start
Restart=on-failure
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
	else
	sudo tee /etc/systemd/system/${NODE}.service > /dev/null <<EOF
[Unit]
Description=$NODE Node
After=network.target

[Service]
User=$USER
Type=simple
ExecStart=$(which 0gchaind) start --log_output_console
Restart=on-failure
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
fi

sudo tee <<EOF >/dev/null /etc/systemd/journald.conf
Storage=persistent
EOF

	echo -e '\n\e[42mDownloading a snapshot\e[0m\n'
	curl https://snapshots.nodes.guru/og/latest_snapshot.tar.lz4 | lz4 -dc - | tar -xf - -C $DAEMON_HOME
	wget -O $DAEMON_HOME/config/addrbook.json https://snapshots.nodes.guru/og/addrbook.json

	echo -e '\n\e[42mChecking a ports\e[0m\n'
	#CHECK PORTS
	PORT=335
	if ss -tulpen | awk '{print $5}' | grep -q ":26656$" ; then
		echo -e "\e[31mPort 26656 already in use.\e[39m"
		sleep 2
		sed -i -e "s|:26656\"|:${PORT}56\"|g" $DAEMON_HOME/config/config.toml
		echo -e "\n\e[42mPort 26656 changed to ${PORT}56.\e[0m\n"
		sleep 2
	fi
	if ss -tulpen | awk '{print $5}' | grep -q ":26657$" ; then
		echo -e "\e[31mPort 26657 already in use\e[39m"
		sleep 2
		sed -i -e "s|:26657\"|:${PORT}57\"|" $DAEMON_HOME/config/config.toml
		echo -e "\n\e[42mPort 26657 changed to ${PORT}57.\e[0m\n"
		sleep 2
		$DAEMON_NAME config node tcp://localhost:${PORT}57
	fi
	if ss -tulpen | awk '{print $5}' | grep -q ":26658$" ; then
		echo -e "\e[31mPort 26658 already in use.\e[39m"
		sleep 2
		sed -i -e "s|:26658\"|:${PORT}58\"|" $DAEMON_HOME/config/config.toml
		echo -e "\n\e[42mPort 26658 changed to ${PORT}58.\e[0m\n"
		sleep 2
	fi
	if ss -tulpen | awk '{print $5}' | grep -q ":6060$" ; then
		echo -e "\e[31mPort 6060 already in use.\e[39m"
		sleep 2
		sed -i -e "s|:6060\"|:${PORT}60\"|" $DAEMON_HOME/config/config.toml
		echo -e "\n\e[42mPort 6060 changed to ${PORT}60.\e[0m\n"
		sleep 2
	fi
	if ss -tulpen | awk '{print $5}' | grep -q ":1317$" ; then
		echo -e "\e[31mPort 1317 already in use.\e[39m"
		sleep 2
		sed -i -e "s|:1317\"|:${PORT}17\"|" $DAEMON_HOME/config/app.toml
		echo -e "\n\e[42mPort 1317 changed to ${PORT}17.\e[0m\n"
		sleep 2
	fi
	if ss -tulpen | awk '{print $5}' | grep -q ":9090$" ; then
		echo -e "\e[31mPort 9090 already in use.\e[39m"
		sleep 2
		sed -i -e "s|:9090\"|:${PORT}90\"|" $DAEMON_HOME/config/app.toml
		echo -e "\n\e[42mPort 9090 changed to ${PORT}90.\e[0m\n"
		sleep 2
	fi
	if ss -tulpen | awk '{print $5}' | grep -q ":9091$" ; then
		echo -e "\e[31mPort 9091 already in use.\e[39m"
		sleep 2
		sed -i -e "s|:9091\"|:${PORT}91\"|" $DAEMON_HOME/config/app.toml
		echo -e "\n\e[42mPort 9091 changed to ${PORT}91.\e[0m\n"
		sleep 2
	fi
	if ss -tulpen | awk '{print $5}' | grep -q ":8545$" ; then
		echo -e "\e[31mPort 8545 already in use.\e[39m"
		sleep 2
		sed -i -e "s|:8545\"|:${PORT}45\"|" $DAEMON_HOME/config/app.toml
		echo -e "\n\e[42mPort 8545 changed to ${PORT}45.\e[0m\n"
		sleep 2
	fi
	if ss -tulpen | awk '{print $5}' | grep -q ":8546$" ; then
		echo -e "\e[31mPort 8546 already in use.\e[39m"
		sleep 2
		sed -i -e "s|:8546\"|:${PORT}46\"|" $DAEMON_HOME/config/app.toml
		echo -e "\n\e[42mPort 8546 changed to ${PORT}46.\e[0m\n"
		sleep 2
	fi

	#echo -e '\n\e[42mRunning a service\e[0m\n' && sleep 1
	sudo systemctl restart systemd-journald
	sudo systemctl daemon-reload
	sudo systemctl enable $NODE
	sudo systemctl restart $NODE
	sudo journalctl -u $NODE -f -o cat

	echo '=============== SETUP FINISHED ==================='
	echo -e '\n\e[42mCheck node status\e[0m\n' && sleep 1
	if [[ `service $NODE status | grep active` =~ "running" ]]; then
	  echo -e "Your $NODE node \e[32minstalled and works\e[39m!"
	  echo -e "You can check node status by the command \e[7mservice 0g status\e[0m"
	else
	  echo -e "Your $NODE node \e[31mwas not installed correctly\e[39m, please reinstall."
	fi
}

function get_block_weight() {
    curl -s localhost:26657/status | jq
	
}

function get_block_sync_status() {
    result=$(curl -s localhost:26657/status | jq .result.sync_info.catching_up)
	if [[ $result =~ "false" ]]; then
		echo -e "\e[32m 你的 $NODE 节点已经同步 \e[39m!"
	else
		echo -e "\e[31m 你的 $NODE 节点未同步 \e[39m!"
		local_height=$($DAEMON_NAME status | jq -r .sync_info.latest_block_height)
		network_height=$(curl -s https://chainscan-newton.0g.ai/v1/homeDashboard | jq -r .result.blockNumber)
		block_left=$(($network_height - $local_height ))
		echo "Your node height: " $local_height
		echo "Network height: " $network_height
		echo "Blocks lef:" $block_left
	fi
	
	
}

function get_0g_run_log() {
	journalctl -u 0g -f
	
}

# 主菜单
function main_menu() {
	while true; do
		clear
		curl -s https://raw.githubusercontent.com/jumpsre/nodes/main/logo.sh | bash
		echo "=========================0g节点安装======================================="
		echo "请选择要执行的操作:"
		echo "1. 安装验证者节点"
		echo "7. 检测区块高度"
		echo "8. 检测同步状态"
		echo "9. 查看验证者运行日志"
		echo "0. 退出脚本"
		
		read -p "请输入选项（1-8）: " OPTION
		
		case $OPTION in
			1) install_0g ;;
			7) get_block_weight ;;
			8) get_block_sync_status ;;
			9) get_0g_run_log ;;
			0) exit 0 ;;
			*) echo "无效的选项, 请重新输入" ;;
		esac
		echo "按任意键返回主菜单..."
        read -n 1
	done
}

# 显示主菜单
main_menu
