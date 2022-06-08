export IMAGE_TAG=2.2.4
export CA_IMAGE_TAG=1.5.2
export COMPOSE_PROJECT_NAME=net

# discover peers --configFile=discoveryService.yaml --server localhost:7051 --channel mychannel
# discover endorsers --configFile=discoveryService.yaml --server localhost:7051 --channel mychannel --chaincode fot
# awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}'  ca.pem
# sudo lsof -i -P -n | grep LISTEN
