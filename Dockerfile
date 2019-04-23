FROM gitpod/workspace-full:latest

USER root

ENV SDK_VERSION=3.0.10
ENV SDK_URL=https://developer.garmin.com/downloads/connect-iq/sdks/connectiq-sdk-lin-$SDK_VERSION-2019-4-9-b0d8876.zip
ENV SDK_FILE=sdk.zip
ENV SDK_DIR=/opt/connectiq


#RUN echo "deb http://ftp.us.debian.org/debian/ jessie main" >> /etc/apt/sources.list
#RUN echo "deb http://ftp.us.debian.org/debian/ wheezy main" >> /etc/apt/sources.list
RUN DEBIAN_FRONTEND=noninteractive && apt-get update -qq 
RUN DEBIAN_FRONTEND=noninteractive && apt-get install -y wget openjdk-8-jdk unzip build-essential xvfb libusb-1.0-0-dev xorg 
RUN DEBIAN_FRONTEND=noninteractive && apt-get install -y libpng12-0 libwebkitgtk-1.0-0
RUN DEBIAN_FRONTEND=noninteractive && apt-get install -y libjpeg8 imagemagick
RUN wget -O "$SDK_FILE" "$SDK_URL"
RUN unzip "$SDK_FILE" -d "${SDK_DIR}"
RUN chmod 777 ${SDK_DIR}/bin/*
