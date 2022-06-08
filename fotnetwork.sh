
## Environmental Variables
export IMAGE_TAG=2.2.4
export CA_IMAGE_TAG=1.5.2
export COMPOSE_PROJECT_NAME=net


function printHelp(){
  echo ""
  echo "./fotnetwork.sh up           - To Bring Up the Network"
  echo "./fotnetwork.sh down         - To Bring Down the Network"
  echo "./fotnetwork.sh displayNodes - To Display the Running Docker Containers"
  echo ""
}

function setEnvOrg1Peer0(){
  export CORE_PEER_TLS_ENABLED=true
  export CORE_PEER_LOCALMSPID="Org1MSP"
  export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.com/tlsca/localhost-6001.pem
  export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.com/users/Admin@org1.com/msp
  export CORE_PEER_ADDRESS=localhost:7051
}

function setEnvOrg1Peer1(){
  export CORE_PEER_TLS_ENABLED=true
  export CORE_PEER_LOCALMSPID="Org1MSP"
  export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.com/tlsca/localhost-6001.pem
  export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.com/users/Admin@org1.com/msp
  export CORE_PEER_ADDRESS=localhost:10051
}


checkGenesisBlock() {
        if [ ! -f "./system-genesis-block/genesis.block" ]; then
	  export FABRIC_CFG_PATH=${PWD}/configtx
          echo "Check whether Genesis Block for the System Channel already exists or not: Not Exists!"
          echo "Creating Genesis Block..."
          set -x
          configtxgen -profile OneOrgOrdererGenesis -channelID system-channel -outputBlock ./system-genesis-block/genesis.block
          res=$?
	  unset FABRIC_CFG_PATH
          { set +x; } 2>/dev/null
	  if [ $res -ne 0 ]; then
            echo "Failed to create a Genesis Block!"
            exit 1
	  else
            echo "Genesis Block Created for a System Channel!"
	  fi
        else
          echo "Genesis Block for the System Channe already exists..."
	  echo "Continuing to Bring Up the CA, Orderers and Peers..."
        fi
}


# Bring Up the Network
function networkUp(){
  checkGenesisBlock
  echo "Bringing Up the Network..."
  echo "Bringing Up the Certificate Authorities"
  docker-compose -f docker/docker-compose-ca.yaml up -d
  if [ $? -ne 0 ]; then
    echo "Failed to Bring Up the network"
    exit 1
  fi
  echo "Bringing Up the Orderers and Peers"
  docker-compose -f docker/docker-compose-test.yaml -f docker/docker-compose-couchdb.yaml up -d
  if [ $? -ne 0 ]; then
    echo "Failed to Bring Up the network"
    exit 1
  else
    echo "Network Up - Successfull"
  fi


}


# Check Whether Given Channel Already Exists or not
function isChannelExists(){
  export FABRIC_CFG_PATH=${PWD}/config
  setEnvOrg1Peer0
  FABRIC_LOGGING_SPEC=error peer channel getinfo -c mychannel > /dev/null
  if [ $? -eq 0 ]; then
    echo "The Specified Channel Already Exists!!! Try Creating the Channel with Some Other Name."
    exit 1
  else
    echo "Channel Doesn't Exists."
    exit 0
  fi
}




# Tear down running network
function networkDown() {
  echo "Bringing Down the Running Network..."
  docker-compose -f docker/docker-compose-ca.yaml down
  docker-compose -f docker/docker-compose-test.yaml -f docker/docker-compose-couchdb.yaml down
  if [ $? -ne 0 ]; then
    echo "Failed to Bring Down the network"
    exit 1
  else
    echo "Network Down - Successfull"
  fi
}


# Display Running Docker Containers
function displayNodes(){
  docker ps --format {{.Names}}
}


# Parse commandline args
## Parse mode
if [[ $# -lt 1 ]] ; then
  printHelp
  exit 0
else
  MODE=$1
  echo "Entered Mode: $MODE"
  shift
fi



if [ "${MODE}" == "up" ]; then
  networkUp
elif [ "${MODE}" == "createChannel" ]; then
  createChannel
elif [ "${MODE}" == "deployCC" ]; then
  deployCC
elif [ "${MODE}" == "down" ]; then
  networkDown
elif [ "${MODE}" == "displayNodes" ]; then
  displayNodes
elif [ "${MODE}" == "channelExists" ]; then
  isChannelExists
else
  printHelp
  exit 1
fi
