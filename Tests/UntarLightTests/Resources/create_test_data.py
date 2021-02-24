
import json
import os
import glob
import random
from pathlib import Path
import hashlib
import sys

list_json_files = []

try:
    os.remove('./list.json')
except:
    print(sys.exc_info()[0])

for json_file_path in glob.glob('./*.json'):

    with open(json_file_path) as json_file:

        list_json_files.append(json_file_path)

        data = json.load(json_file)

        os.system('mkdir tmp')
        os.chdir('tmp')

        file_name = data["name"]

        entries = data["entries"]

        for entry in entries:
            print(entry)
            
            print(entry["path"])

            if entry["type"] == "file":
                os.system("cp ../sample.txt %s" % entry["path"])
                with open("../sample.txt", "rb") as fr:
                    bin = fr.read()
                    a = hashlib.sha256(bin)
                    print(a.digest())
                    
                    digest = hashlib.sha256(bin).hexdigest()
                    print(digest)
            elif entry["type"] == "directory":
                os.system("mkdir %s" % entry["path"])
            elif entry["type"] == "symboliclink":
                os.system("ln -s %s %s" % (entry["link"], entry["path"]))

        os.system("tar -cf ../%s *" % file_name)

        os.chdir('../')
        os.system("rm -r ./tmp")

list_json_files = list(map(lambda x: Path(x).name, list_json_files))

with open('./list.json', 'w') as json_file:
    json.dump(list_json_files, json_file)
