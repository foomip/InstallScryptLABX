#########################################################################################################
#                                  LABX MASTERNODE INSTALLATION SCRIPT                                  #
#                                          VERSION: 1.0                                                 #
#                              EXTENDS: 'LABX MASTERNODE INSTALLATION SCRIPT'                           #
#                              AUTHORS: Stakinglab developers                                           #
#########################################################################################################

# COLORS
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
BLUE='\e[34m'

CONFIG_FOLDER=/root/.labx
CONFIG_FILE=labx.conf
COIN_PATH=/usr/local/bin/
COIN_PORT=33330
RPC_PORT=33331
COIN_DAEMON=labxd
RPCUSER=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w10 | head -n1)
RPCPASSWORD=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w22 | head -n1)
COIN_CLI=labx-cli
COIN_REPO=(
  [0]='https://github.com/StakingLab/stakinglab-coin/releases/download/v1.0.0/labx-1.0.0-x86_64-linux-gnu.tar.gz'
)
NODES=no
OTHER_REPO=no



NODE_IP=$(curl -s4 api.ipify.org)


# HANDLE RESULT (SHOW ERROR OR SUCCESS MESSAGE)
function handleResult() {
  if [ $? -ne 0 ]; then
    echo -e $2
    exit 1
  else
    echo $1
  fi
}

# CREATE CONFIGURATION
function createConfig() {
  echo -e "Generating the config..."
  mkdir $CONFIG_FOLDER >/dev/null 2>&1
  echo -e "Generating the config file..."
  cat << EOF > $CONFIG_FOLDER/$CONFIG_FILE
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcallowip=127.0.0.1
rpcport=$RPC_PORT
port=$COIN_PORT
externalip=$NODE_IP
bind=$NODE_IP:$COIN_PORT
masternodeprivkey=$COIN_KEY
listen=1
server=1
daemon=1
logtimestamps=1
maxconnections=256
masternode=1
EOF



  # ADD NODES
  if [ $NODES != "no" ]; then
	for key in "${!NODES[@]}"
  do
 	  echo "addnode=${NODES["$key"]}" >> $CONFIG_FOLDER/$CONFIG_FILE
  done
  fi

  echo -e "Configuration file successfully created!"
}

#CREATE MASTER NODE KEY
function createMasterNodeKey() {
  echo -e "Enter your ${GREEN}Stakinglab Masternode Private Key${NC}"
  read -e COIN_KEY
  if [[ -z "$COIN_KEY" ]]; then
  echo -e "${RED}You didn't provide the masternode key so the installation will stop, please try again...${NC}"
  exit 1
fi
clear
}

#ENABLE FIREWALL
function enableFirewall() {
  echo -e "Installing and setting up firewall... ${GREEN}$COIN_PORT${NC}"
  ufw allow $COIN_PORT/tcp comment "Stakinglab MN port" >/dev/null
  ufw allow ssh comment "SSH" >/dev/null 2>&1
  ufw limit ssh/tcp >/dev/null 2>&1
  ufw default allow outgoing >/dev/null 2>&1
  echo "y" | ufw enable >/dev/null 2>&1
}


#########################################################################################################
#                                          1. CHECKS                                                    #
#########################################################################################################
function checks()
{
  echo "Preparing"
  # CHECK SYSTEM VERSION
  if [[ $(lsb_release -d) != *16.04* ]]; then
    echo -e "${RED}You are not running Ubuntu 16.04. Installation is cancelled.${NC}"
    exit 1
  fi

  # CHECK USER
  if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}$0 must be run as root.${NC}"
   exit 1
  fi
}

#########################################################################################################
#                                          2. PREPARE NODE                                              #
#########################################################################################################
function prepareNode(){
  checks

  #CHECK EXISTENCE OF COIN
  if [ -n "$(pidof $COIN_DAEMON)" ] || [ -e "$COIN_DAEMON" ] ; then
    echo -e "${RED}Stakinglab ifs already installed.${NC}"
    exit 1
  fi
  echo -e "Prepare the system to install ${GREEN}Stakinglab${NC} master node."


  echo -e "Checking if swap space is required."
  PHYMEM=$(free -g | awk '/^Mem:/{print $2}')
  
  if [ "$PHYMEM" -lt "2" ]; then
    SWAP=$(swapon -s get 1 | awk '{print $1}')
    if [ -z "$SWAP" ]; then
      echo -e "${GREEN}Server is running without a swap file and less than 2G of RAM, creating a 2G swap file.${NC}"
      dd if=/dev/zero of=/swapfile bs=1024 count=2M
      chmod 600 /swapfile
      mkswap /swapfile
      swapon -a /swapfile
    else
      echo -e "${GREEN}Swap file already exists.${NC}"
    fi
  else
    echo -e "${GREEN}Server is running with at least 2G of RAM, no swap file needed.${NC}"
  fi


   # EXECUTE COMMANDS
  echo -e "Installing libraries..."
 
  apt-get -y update
  apt -y install software-properties-common
  apt-get install -y unzip nano htop git
  apt-add-repository -y ppa:bitcoin/bitcoin
  apt-get -y update
  apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" make software-properties-common build-essential libtool autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev libboost-program-options-dev libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git wget curl libdb4.8-dev bsdmainutils libdb4.8++-dev libminiupnpc-dev libgmp3-dev ufw pkg-config libevent-dev  libdb5.3++ unzip libzmq5

  clear
}

#########################################################################################################
#                                          3. DOWNLOAD NODE                                             #
#########################################################################################################
function downloadNode(){

 # PREPARE ARGUMENTS
  C_REPO=$1
  C_PATH=$2

  # CREATE TEMP FOLDR
  TMP_FOLDER=$(mktemp -d)

  # OPEN TEMP FOLDER
  cd $TMP_FOLDER >/dev/null 2>&1
  echo -e "Downloading ${GREEN}Stakinglab${NC}..."
  wget $C_REPO
  handleResult "Download completed!" "Error while downloading!"

  C_FILE_NAME=$(echo $C_REPO | awk -F'/' '{print $NF}')
  C_EXTENSION=".$(echo $C_REPO | awk -F'.' '{print $NF}')"

  # EXTRACT FILE
  case "$C_EXTENSION" in
     ".gz")
       tar -xzvf $C_FILE_NAME >/dev/null 2>&1
       rm $C_FILE_NAME >/dev/null 2>&1
       handleResult "Compressed file deleted!" "Failed to delete compressed file!"
     ;;
     ".tar")
       tar -xfv $C_FILE_NAME >/dev/null 2>&1
       rm $C_FILE_NAME >/dev/null 2>&1
       handleResult "Compressed file deleted!" "Failed to delete compressed file!"
     ;;
     ".zip")
       unzip $C_FILE_NAME >/dev/null 2>&1
       rm $C_FILE_NAME >/dev/null 2>&1
       handleResult "Compressed file deleted!" "Failed to delete compressed file!"
     ;;
  esac
  
  handleResult "Installation completed!" "Error while installing!"
  # SET PRIVILEGES
  chmod 755 *

  mv stakinglab-1.2.0/bin/* $C_PATH
  handleResult "Moving of files was completed" "Error while moving files!"

  cd -
  rm -rf $TMP_FOLDER >/dev/null 2>&1
  handleResult "Completed!" "Error while removing temporary folder!"
  clear
}

#########################################################################################################
#                                          4. SETUP NODE                                                #
#########################################################################################################
function setupNode() {
  createMasterNodeKey
  createConfig
  enableFirewall
}


#########################################################################################################
#                                          5. START SERVICE                                             #
#########################################################################################################
function startNode() {
  cat << EOF > /etc/systemd/system/Stakinglab.service
[Unit]
Description=Stakinglab service
After=network.target

[Service]
User=root
Group=root

Type=forking

ExecStart=$COIN_PATH$COIN_DAEMON -daemon -conf=$CONFIG_FOLDER/$CONFIG_FILE -datadir=$CONFIG_FOLDER
ExecStop=-$COIN_PATH$COIN_CLI -conf=$CONFIG_FOLDER/$CONFIG_FILE -datadir=$CONFIG_FOLDER stop

Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  sleep 3
  systemctl start Stakinglab.service
  systemctl enable Stakinglab.service >/dev/null 2>&1

  if [[ -z "$(ps axo cmd:100 | egrep $COIN_DAEMON)" ]]; then
    echo -e "${RED}Stakinglab is not running${NC}, please investigate. You should start by running the following commands as root:"
    echo -e "${GREEN}systemctl start Stakinglab.service"
    echo -e "systemctl status Stakinglab.service"
    echo -e "less /var/log/syslog${NC}"
    exit 1
  fi
}

#########################################################################################################
#                                      6. OUTPUT NODE INFORMATION                                       #
#########################################################################################################
function outputNode() {
  echo -e "*****START OF INFO*****"
  echo -e "${GREEN}Stakinglab${NC} Masternode is installed, please verify that your wallet port ${GREEN}$COIN_PORT${NC} is listening by running fallowing command ${RED}netstat -plnt${NC}."
  echo -e "Configuration file is located in: ${GREEN}$CONFIG_FOLDER/$CONFIG_FILE${NC}"
  echo -e " Your Server IP:PORT are ${GREEN}$NODE_IP:$COIN_PORT${NC}"
  echo -e "MASTERNODE PRIVATEKEY is: ${GREEN}$COIN_KEY${NC}"
  echo -e "Use ${GREEN}'$COIN_CLI masternode status'${NC} to check your MN."
  echo -e "*****END OF INFO*****"
}



#########################################################################################################
#                                       INSTALL NODE                                                    #
#########################################################################################################
function installNode()
{
  # INSTALL AND START NODE
  prepareNode

  # COIN REPOS
  if [ $COIN_REPO != "no" ]; then
	for key in "${!COIN_REPO[@]}"
	do
	  downloadNode "${COIN_REPO["$key"]}" "$COIN_PATH"
	done
  fi

  setupNode

  # OTHER REPOS
  if [ $OTHER_REPO != "no" ]; then
    for key in "${!OTHER_REPO[@]}"
    do
      downloadNode "${OTHER_REPO["$key"]}" "$OTHER_PATH"
    done
  fi

  startNode
  outputNode
}




#########################################################################################################
#                                                RUN                                                    #
#########################################################################################################
clear
apt-get -y install curl
installNode
  

