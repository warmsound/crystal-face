#!/usr/bin/python

import xml.etree.ElementTree as ET
import subprocess

tree = ET.parse("manifest.xml")

root = tree.getroot()

namespaces = {'iq': 'http://www.garmin.com/xml/connectiq'} 

devicelist = ""

for item in root.findall("./iq:application/iq:products/iq:product",namespaces):
    watch = item.attrib['id']
    devicelist =  devicelist + " " + watch

print devicelist
