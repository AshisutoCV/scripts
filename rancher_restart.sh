####################
### K.K. Ashisuto
### VER=20241224a
####################

#!/bin/bash
docker container restart $(docker ps | grep rancher/rancher | awk '{print $1}')
