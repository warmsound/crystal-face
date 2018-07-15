#!/usr/bin/python

import xml.etree.ElementTree as ET
import subprocess

tree = ET.parse("manifest.xml")

root = tree.getroot()

namespaces = {'iq': 'http://www.garmin.com/xml/connectiq'} 

for item in root.findall("./iq:application",namespaces):
    appname = item.attrib['entry']



#print root.attrib

#for child in root.iter():
#    print child.tag

for item in root.findall("./iq:application/iq:products/iq:product",namespaces):
    watch = item.attrib['id']
    progname = appname + "-" + watch
    subprocess.call(["./test.sh",progname,watch])
