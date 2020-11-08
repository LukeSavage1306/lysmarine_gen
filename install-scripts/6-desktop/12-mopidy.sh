#!/bin/bash -e

# Install Mopidy and all dependencies:
#apt-get -y install mopidy mopidy-mpd mopidy-spotify mopidy-tunein libspotify-dev xdotool
apt-get -y install mopidy mopidy-mpd mopidy-tunein xdotool

adduser mopidy video
adduser mopidy audio

# Install some needed packages
python3 -m pip install mem systems

# Install Mopidy MusicBox Web Client:
python3 -m pip install Mopidy-MusicBox-Webclient

# Install YouTube support
apt-get -y install gstreamer1.0-plugins-bad
#python3 -m pip install --pre Mopidy-YouTube
python3 -m pip install https://github.com/natumbri/mopidy-youtube/archive/develop.zip

# Enable mopidy service
systemctl enable mopidy

install -m 644 $FILE_FOLDER/musicbox.desktop "/usr/local/share/applications/"
