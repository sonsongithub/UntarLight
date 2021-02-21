
import json
import os
import glob
import random
from pathlib import Path

list_json_files = []

os.remove('../UntarLightTests/Resources/list.json')

for json_file_path in glob.glob('../UntarLightTests/Resources/*.json'):

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
                if int(random.uniform(0, 1)*10%2) == 0:
                    os.system("cp ../sample.png %s" % entry["path"])
                else:
                    os.system("cp ../sample.txt %s" % entry["path"])
            elif entry["type"] == "directory":
                os.system("mkdir %s" % entry["path"])
            elif entry["type"] == "symboliclink":
                os.system("ln -s %s %s" % (entry["link"], entry["path"]))

        os.system("tar -cf ../../UntarLightTests/Resources/%s *" % file_name)

        os.chdir('../')
        os.system("rm -r ./tmp")

list_json_files = list(map(lambda x: Path(x).name, list_json_files))

with open('../UntarLightTests/Resources/list.json', 'w') as json_file:
    json.dump(list_json_files, json_file)
