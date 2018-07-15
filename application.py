#!/usr/bin/python

import xml.etree.ElementTree as ET
import subprocess

tree = ET.parse("manifest.xml")

root = tree.getroot()

namespaces = {'iq': 'http://www.garmin.com/xml/connectiq'} 

for item in root.findall("./iq:application",namespaces):
    appname = item.attrib['entry']

print appname
