

export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/tlsca/localhost-6000.pem


if [ ! -d "channel-artifacts" ]; then
        mkdir channel-artifacts
fi


verifyResult() {
  if [ $1 -ne 0 ]; then
    echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
    echo
    exit 1
  fi
}

# Set environment variables for the peer org
setGlobals() {
  USING_ORG=$1
  USING_PEER=$2
  echo "Using Organization:$USING_ORG, Peer:$USING_PEER"
  if [ $USING_ORG -eq 1 ]; then
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID="Org1MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.com/tlsca/localhost-6001.pem
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.com/users/Admin@org1.com/msp
    if [ $USING_PEER -eq 0 ]; then
      export CORE_PEER_ADDRESS=localhost:7051
    elif [ $USING_PEER -eq 1 ]; then
      export CORE_PEER_ADDRESS=localhost:10051
    else
      echo "================== ERROR !!! Peer:$USING_PEER Unknown =================="
    fi
  else
    echo "================== ERROR !!! ORG:$USING_ORG Unknown =================="
  fi
}


# Check Whether Given Channel Already Exists or not
isChannelExists(){
  ORG=$1
  PEER=$3
  setGlobals $ORG $PEER
  FABRIC_LOGGING_SPEC=error peer channel getinfo -c $CHANNEL_NAME 2>&1 > /dev/null
  if [ $? -eq 0 ]; then
    echo "The Specified Channel:$CHANNEL_NAME Already Exists!!! Try Creating the Channel with a different channel name."
    exit 1
  else
    echo "Check whether Channel:$CHANNEL_NAME exists or not using peer${PEER} in Org${ORG}: Not Exists!"
  fi
}




createChannelTx() {
	if [ ! -f "./channel-artifacts/${CHANNEL_NAME}.tx" ]; then
	  echo "Check whether Channel Transaction for the channel already exists or not: Not Exists!"
	  echo "Creating Channel Transaction..."
	  set -x
          configtxgen -profile OneOrgChannel -outputCreateChannelTx ./channel-artifacts/${CHANNEL_NAME}.tx -channelID $CHANNEL_NAME
          res=$?
          { set +x; } 2>/dev/null
          verifyResult $res "Failed to generate channel configuration transaction..."
	  echo "Generated the Channel Transaction:${CHANNEL_NAME}.tx"
	else
	  echo "Channel Transaction for the channel already exists..."
	fi
}



createChannel() {
        setGlobals $ORG $PEER
        # Poll in case the raft leader is not set yet
        local rc=1
        local COUNTER=1
        while [ $rc -ne 0 -a $COUNTER -lt 5 ] ; do
                sleep 3
                set -x
		peer channel create -o localhost:7050 -c $CHANNEL_NAME --ordererTLSHostnameOverride orderer.example.com -f ./channel-artifacts/${CHANNEL_NAME}.tx --outputBlock $BLOCKFILE --tls true --cafile $ORDERER_CA >&log.txt
                res=$?
                { set +x; } 2>/dev/null
                let rc=$res
                COUNTER=$(expr $COUNTER + 1)
        done
        cat log.txt
        verifyResult $res "Channel creation failed"
}


# joinChannel ORG
joinChannel() {
  FABRIC_CFG_PATH=${PWD}/config
  ORG=$1
  PEER=$3
  setGlobals $ORG $PEER
        local rc=1
        local COUNTER=1
        ## Sometimes Join takes time, hence retry
        while [ $rc -ne 0 -a $COUNTER -lt 5 ] ; do
    sleep 3
    set -x
    peer channel join -b $BLOCKFILE >&log.txt
    res=$?
    { set +x; } 2>/dev/null
                let rc=$res
                COUNTER=$(expr $COUNTER + 1)
        done
        cat log.txt
        verifyResult $res "After 5 attempts, peer${PEER}.org${ORG} has failed to join channel '$CHANNEL_NAME' "
}

setAnchorPeers(){
  export CH_NAME=mychannel
  export TLS_ROOT_CA=${PWD}/organizations/ordererOrganizations/example.com/tlsca/localhost-6000.pem
  export CORE_PEER_LOCALMSPID=Org1MSP
  export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.com/users/Admin@org1.com/msp
  export ORDERER_CONTAINER=localhost:7050

  set -x
  peer channel fetch config temp/config_block.pb -o $ORDERER_CONTAINER -c $CH_NAME --tls --cafile $TLS_ROOT_CA

  configtxlator proto_decode --input temp/config_block.pb --type common.Block --output temp/config_block.json

  jq .data.data[0].payload.data.config temp/config_block.json > temp/config.json

  jq '.channel_group.groups.Application.groups.Org1MSP.values += {"AnchorPeers":{"mod_policy": "Admins","value":{"anchor_peers": [{"host": "peer0.org1.com","port": 7051}]},"version": "0"}}' temp/config.json > temp/modified_config.json
  
  configtxlator proto_encode --input temp/config.json --type common.Config --output temp/config.pb

  configtxlator proto_encode --input temp/modified_config.json --type common.Config --output temp/modified_config.pb

  configtxlator compute_update --channel_id $CH_NAME --original temp/config.pb --updated temp/modified_config.pb --output temp/config_update.pb

  configtxlator proto_decode --input temp/config_update.pb --type common.ConfigUpdate --output temp/config_update.json

  echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CH_NAME'", "type":2}},"data":{"config_update":'$(cat temp/config_update.json)'}}}' | jq . > temp/config_update_in_envelope.json

  configtxlator proto_encode --input temp/config_update_in_envelope.json --type common.Envelope --output temp/config_update_in_envelope.pb

  peer channel update -f temp/config_update_in_envelope.pb -c $CH_NAME -o $ORDERER_CONTAINER --tls --cafile $TLS_ROOT_CA
  set +x
  echo "Anchor Peer Update Successfull!"
}

## Can be Modified, if needed ##
CHANNEL_NAME="mychannel"
BLOCKFILE="./channel-artifacts/${CHANNEL_NAME}.block"




## Check Channel Exists or not before creating.
export FABRIC_CFG_PATH=${PWD}/config
isChannelExists 1 0
isChannelExists 1 1

export FABRIC_CFG_PATH=${PWD}/configtx
## Create channeltx
echo "Generating channel create transaction '${CHANNEL_NAME}.tx'"
createChannelTx

export FABRIC_CFG_PATH=${PWD}/config
## Create channel
echo "Creating channel ${CHANNEL_NAME}"
createChannel 1 0
echo "Channel '$CHANNEL_NAME' created"

## Join all the peers to the channel
echo "Joining org1 peer0 to the channel..."
joinChannel 1 0
echo "Joining org1 peer1 to the channel..."
joinChannel 1 1

echo "Joining org1 peer1 to the channel..."
joinChannel 1 2


## Update Anchor Peers
echo "Setting Anchor Peers for the Channel..."
setAnchorPeers
                                                 



