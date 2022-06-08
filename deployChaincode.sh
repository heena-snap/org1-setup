

export FABRIC_CFG_PATH=${PWD}/config
export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/tlsca/localhost-6000.pem
export ORG1_CA=${PWD}/organizations/peerOrganizations/org1.com/tlsca/localhost-6001.pem


function setEnvOrg1Peer0(){
  echo "Using Organization Peer:$1"
  export CORE_PEER_TLS_ENABLED=true
  export CORE_PEER_LOCALMSPID="Org1MSP"
  export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.com/tlsca/localhost-6001.pem
  export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.com/users/Admin@org1.com/msp
  export CORE_PEER_ADDRESS=localhost:7051
}

function setEnvOrg1Peer1(){
  echo "Using Organization Peer:$1"
  export CORE_PEER_TLS_ENABLED=true
  export CORE_PEER_LOCALMSPID="Org1MSP"
  export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.com/tlsca/localhost-6001.pem
  export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.com/users/Admin@org1.com/msp
  export CORE_PEER_ADDRESS=localhost:10051
}

function setEnvOrg1Peer2(){
  echo "Using Organization Peer:$1"
  export CORE_PEER_TLS_ENABLED=true
  export CORE_PEER_LOCALMSPID="Org1MSP"
  export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.com/tlsca/localhost-6001.pem
  export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.com/users/Admin@org1.com/msp
  export CORE_PEER_ADDRESS=localhost:10052
}



# Set environment variables for the peer org
setGlobals() {
  USING_ORG=$1
  USING_PEER=$3
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



verifyResult() {
  if [ $1 -ne 0 ]; then
    echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
    echo
    exit 1
  fi
}


# packing the chaincode
packageChaincode() {
  ORG=$1
  PEER=$3
  setGlobals $ORG $PEER
  set -x
  peer lifecycle chaincode package cc_packages/${CC_NAME}_${CC_VERSION}.tar.gz --path ${CC_SRC_PATH} --label ${CC_NAME}_${CC_VERSION} --lang ${CC_RUNTIME_LANGUAGE} >&log.txt
  res=$?
  set +x
  cat log.txt
  verifyResult $res "Chaincode packaging on peer${PEER}.org${ORG}.com has failed"
  echo "===================== Chaincode is packaged on peer${PEER}.org${ORG}.com ===================== "
  echo
}


# installChaincode PEER ORG
installChaincode() {
  ORG=$1
  PEER=$3
  setGlobals $ORG $PEER
  set -x
  peer lifecycle chaincode install cc_packages/${CC_NAME}_${CC_VERSION}.tar.gz >&log.txt
  res=$?
  set +x
  cat log.txt
  verifyResult $res "Chaincode installation on peer${PEER}.org${ORG} has failed"
  echo "===================== Chaincode is installed on peer${PEER}.org${ORG} ===================== "
  echo
}



# queryInstalled on ORG PEER
queryInstalled() {
  ORG=$1
  PEER=$3
  setGlobals $ORG $PEER
  set -x
  peer lifecycle chaincode queryinstalled >&log.txt
  res=$?
  set +x
  cat log.txt
        PACKAGE_ID=$(sed -n "/${CC_NAME}_${CC_VERSION}/{s/^Package ID: //; s/, Label:.*$//; p;}" log.txt)
        export PACKAGE_ID=${PACKAGE_ID}
  verifyResult $res "Query installed on peer${PEER}.org${ORG} has failed"
  echo PackageID is ${PACKAGE_ID}
  echo "===================== Query installed successful on peer${PEER}.org${ORG} on channel ===================== "
  echo
}



# approveForMyOrg VERSION PEER ORG
approveForMyOrg() {
  ORG=$1
  PEER=$3
  setGlobals $ORG $PEER
  set -x
  peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls true --cafile $ORDERER_CA --channelID $CHANNEL_NAME --signature-policy "AND('Org1.member', 'Org2.member','org1.member')" --name ${CC_NAME} --version ${CC_VERSION} --package-id ${PACKAGE_ID} --sequence ${CC_SEQUENCE}
  set +x
  cat log.txt
  verifyResult $res "Chaincode definition approved on peer${PEER}.org${ORG} on channel '$CHANNEL_NAME' failed"
  echo "===================== Chaincode definition approved on peer${PEER}.org${ORG} on channel '$CHANNEL_NAME' ===================== "
  echo
}


# checkCommitreadiness VERSION PEER ORG (PEER ORG)...
checkCommitreadiness() {
  ORG=$1
  PEER=$3
  setGlobals $ORG $PEER
  set -x
  peer lifecycle chaincode checkcommitreadiness --channelID $CHANNEL_NAME --signature-policy "AND('Org1.member', 'Org2.member','org1.member')" --name ${CC_NAME} --version ${CC_VERSION} --sequence ${CC_SEQUENCE} --output json
  res=$?
  set +x
  cat log.txt
  verifyResult $res "Chaincode Checkcommitreadiness failed on peer${PEER}.org${ORG} on channel '$CHANNEL_NAME' failed"
  echo "===================== Chaincode Checkcommitreadiness Successfull on peer${PEER}.org${ORG} on channel '$CHANNEL_NAME' ===================== "
  echo
}


# commitChaincodeDefinition VERSION PEER ORG (PEER ORG)...
commitChaincodeDefinition() {
  ORG=$1
  PEER=$3
  setGlobals $ORG $PEER
  set -x
  peer lifecycle chaincode commit -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls true --cafile $ORDERER_CA --channelID $CHANNEL_NAME --signature-policy "AND('Org1.member', 'Org2.member','org1.member')" --name ${CC_NAME} --version ${CC_VERSION} --sequence ${CC_SEQUENCE} --peerAddresses localhost:7051 --tlsRootCertFiles $ORG1_CA
  res=$?
  set +x
  cat log.txt
  verifyResult $res "Chaincode definition commit failed on peer${PEER}.org${ORG} on channel '$CHANNEL_NAME' failed"
  echo "===================== Chaincode definition committed on channel '$CHANNEL_NAME' ===================== "
  echo
}



queryCommittedChaincode() {
  ORG=$1
  PEER=$3
  setGlobals $ORG $PEER
  set -x
  peer lifecycle chaincode querycommitted --channelID $CHANNEL_NAME --name ${CC_NAME} -O json
  res=$?
  set +x
  cat log.txt
  verifyResult $res "Query Committed Chaincode definition failed on peer${PEER}.org${ORG} on channel '$CHANNEL_NAME' failed"
  echo "===================== Successfully Queried Committed Chaincode definition on channel '$CHANNEL_NAME' ===================== "
  echo
}




## Modify the Channel Name, if needed
CHANNEL_NAME="mychannel"             # channel to deploy the chaincode
CC_NAME=fot                  # chaincode name
CC_SRC_PATH=${PWD}/chaincode/fot_v3.0        # can be absolute path (recommended) or relative path 
CC_RUNTIME_LANGUAGE=golang             # for Go Programming = golang, for NodeJs = node, for Java = java
CC_VERSION=v3.0                         # should be like 1.0, 2.3, 3.2.1, etc
CC_SEQUENCE=1                         # should be integer like 1, 2, 3, etc




## at first we package the chaincode
packageChaincode 1 0

## Install chaincode 
echo "Installing Chaincode..."
installChaincode 1 0
installChaincode 1 1


## query whether the chaincode is installed
queryInstalled 1 0
queryInstalled 1 1

## approve the definition for org1
approveForMyOrg 1 0

## check commitreadiness
sleep 5
checkCommitreadiness 1 0

## now that we know org have approved, commit the definition
commitChaincodeDefinition 1 0

## Query committed Chaincode
sleep 5
queryCommittedChaincode 1 0


echo "-------------Deployment Successfull-------------------"










