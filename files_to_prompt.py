#!/usr/bin/env python3

import subprocess
import sys
from pathlib import Path

# Directorio base desde el que buscar (por defecto: actual)
base_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")

# Fichero de salida (puedes cambiarlo si quieres)
output_file = "all_files.txt"

# Comando: encuentra todos los .swift y los pasa a files-to-prompt
find_cmd = ["find", str(base_dir), "-name", "*.swift"]
with subprocess.Popen(find_cmd, stdout=subprocess.PIPE) as find_proc:
    with open(output_file, "w") as out:
        subprocess.run(["files-to-prompt"], stdin=find_proc.stdout, stdout=out)

print(f"✅ Ficheros .swift procesados y guardados en: {output_file}")
