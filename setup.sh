#!/bin/bash
###Clients will install with pointers to the server hostname
###If you have not setup a DNS A-record for this machine, you will #need to before the clients can contact the server.

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi

dir=$PWD

echo "Adding Repos"
echo
echo

add-apt-repository -y ppa:webupd8team/java

wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch |  apt-key add -

echo "deb http://packages.elastic.co/elasticsearch/2.x/debian stable main" | sudo tee -a /etc/apt/sources.list.d/elasticsearch-2.x.list

echo "deb http://packages.elastic.co/kibana/4.4/debian stable main" | sudo tee -a /etc/apt/sources.list.d/kibana-4.4.x.list

echo 'deb http://packages.elastic.co/logstash/2.2/debian stable main' | sudo tee -a /etc/apt/sources.list.d/logstash-2.2.x.list

sleep 5
echo "Updating APT and installing dependencies"
apt-get -qq update 

apt-get -qq install ctags curl git vim vim-doc vim-scripts exfat-fuse exfat-utils zip python-virtualenv tshark -y
sleep 5

####GRR Install

echo "Installing GRR"
echo

cd $dir

wget -q https://raw.githubusercontent.com/google/grr/master/scripts/install_script_ubuntu.sh

sleep 2

sudo bash install_script_ubuntu.sh


###Copy exe's to Desktop
echo
echo
echo "Creating directory for GRR installers"
echo 
echo

mkdir /$HOME/Desktop/clientinstall.$HOSTNAME


sleep 2

###Install ELK Stack
echo "Installing ELK Stack"
echo "Installing Dependencies"
apt-get -qq install oracle-java8-installer elasticsearch kibana nginx apache2-utils logstash -y

###Elastisearch
echo "Installing Elasticsearch"
update-rc.d elasticsearch defaults 95 10
service elasticsearch start
systemctl enable elasticsearch.service

sleep 2

###Kiabana
echo "Installing Kibana"
echo "server.host: 127.0.0.1" | tee -a /opt/kibana/config/kibana.yml 

update-rc.d kibana defaults 96 9
service kibana start
systemctl enable elasticsearch.service

sleep 2

echo ------------------------------------------------
echo ------------------------------------------------
echo What would you like your Kibana username to be?
read kibanauser
htpasswd -c /etc/nginx/htpasswd.users $kibanauser
 
#####Creates site default file
mv /etc/nginx/sites-available/default /etc/nginx/


cp $dir/lib/default /etc/nginx/sites-available/

service nginx restart

sleep 2

###Create Certs
mkdir -p /etc/pki/tls/certs
mkdir /etc/pki/tls/private

cd /etc/pki/tls; sudo openssl req -subj '/CN=GRR_Server/' -x509 -days 3650 -batch -nodes -newkey rsa:2048 -keyout private/logstash-forwarder.key -out certs/logstash-forwarder.crt

###Setup Beats for Logstash input to Elastisearch output

cp $dir/logstash_conf/default/001-beats-input.conf /etc/logstash/conf.d/

cp $dir/logstash_conf/default/999-elasticsearch-output.conf /etc/logstash/conf.d/

service logstash start

###Install netflow dashboards for Kibana
cd  $dir
curl -L -O -# https://download.elastic.co/beats/dashboards/beats-dashboards-1.1.0.zip

apt-get -qq install unzip -y

sleep 2

unzip beats-dashboards-*.zip

cd beats-dashboards-*
./load.sh
echo
read -p "Do you want to download Beats shippers? Y/N" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
  then
  ###Configure packetbeat clients
  cp -r $dir/packetbeat /$HOME/Desktop/clientinstall.$HOSTNAME/
  cp /etc/pki/tls/certs/logstash-forwarder.crt /$HOME/Desktop/clientinstall.$HOSTNAME/
  bash $dir/supporting_scripts/beats_download.sh
  cp -r /usr/share/grr-server/executables/installers /$HOME/Desktop/clientinstall.$HOSTNAME/
fi

###SOF-ELK setup
echo
read -p "Do you want to install SOF-ELK dashboards and configurations? Y/N" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
bash $dir/supporting_scripts/sof-elk_setup.sh
#sof-elk_setup must be ran BEFORE add_dashboards or directories will not be created
bash $dir/supporting_scripts/add_dashboards.sh

fi



##################################Test
###Forensic tools install
echo
read -p "Do you want to install forensic tools? Y/N" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    echo ""
    
    mkdir ~/Desktop/Cases 
    mkdir ~/Desktop/Tools
    chown $USER:$USER ~/Desktop/Cases/
    chown $USER:$USER ~/Desktop/Tools/

 
# Add scripts from different sources
    cd ~/Desktop/Tools/
# https://www.virustotal.com/en/documentation/public-api/#getting-file-scans
    wget -q -O ~/Desktop/Tools/vt.py \
    https://raw.githubusercontent.com/Xen0ph0n/VirusTotal_API_Tool/master/vt.py && \
    chmod +x ~/Desktop/Tools/vt.py 
    echo "Installed vt.py"
    
# https://n0where.net/malware-analysis-damm/
    git clone --quiet https://github.com/504ensicsLabs/DAMM 
    echo "Installed DAMM"
     
# https://github.com/DidierStevens/DidierStevensSuite
    git clone --quiet https://github.com/DidierStevens/DidierStevensSuite.git 
    echo "Checked out DidierStevensSuite." 
    
# https://github.com/Yara-Rules/rules.git
    git clone --quiet https://github.com/Yara-Rules/rules.git 
    echo "Checked out Yara-Rules."

# https://github.com/decalage2/oletools.git
    git clone --quiet https://github.com/decalage2/oletools.git 
    echo "Checked out oletools."
    
    git clone --quiet https://github.com/USArmyResearchLab/Dshell.git
    echo "Checked out DShell."
    
     git clone --quie https://github.com/BinaryDefense/goatrider.git
    echo "Checked out GoatRider."
    
    apt-get -qq install yara -y
    
    #Volatility   
    git clone --quiet https://github.com/volatilityfoundation/volatility.git
    echo "Dwonloaded Volatility"
    cd volatility
    python setup.py install
fi

####################################End test
echo
echo
echo "Your GRR-ELK stack has been installed, client installations are located on your desktop in a folder called clientinstall.$HOSTNAME"
echo
echo "Your GRR dashboard is located at $HOSTNAME:8000 and your Kibana dashboard is at $HOSTNAME:80"
echo
echo "If you need to configure packetbeat, you will need to modify the yml file by replacing the server:5044 with the logstash server host/ip. You will also need to install the included .crt for the client to use."
echo
