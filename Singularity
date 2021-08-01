BootStrap: library
From: ubuntu:16.04

%files
    create_omtb_garmin_img.sh /usr/local/bin/create_omtb_garmin_img.sh 

%post
    apt-get update
    apt-get install -y zsh p7zip-full mkgmap wget unzip
    wget http://www.gmaptool.eu/sites/default/files/lgmt08220.zip
    unzip lgmt08220.zip gmt
    mv gmt /usr/local/bin/

