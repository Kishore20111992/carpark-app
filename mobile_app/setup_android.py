import os
import shutil
import subprocess
import sys

def main():
    root_dir = os.path.dirname(os.path.abspath(__file__))
    print(f"Working in: {root_dir}")
    
    temp_backup = os.path.join(os.path.dirname(root_dir), "parkflow_temp_backup")
    os.makedirs(temp_backup, exist_ok=True)
    
    lib_dir = os.path.join(root_dir, "lib")
    pubspec_file = os.path.join(root_dir, "pubspec.yaml")
    
    backup_lib = os.path.join(temp_backup, "lib")
    backup_pubspec = os.path.join(temp_backup, "pubspec.yaml")
    
    if os.path.exists(backup_lib):
        shutil.rmtree(backup_lib)
    shutil.copytree(lib_dir, backup_lib)
    shutil.copy2(pubspec_file, backup_pubspec)
    print("Backed up lib/ and pubspec.yaml.")
    
    cmd = ["flutter", "create", ".", "--platforms=android", "--org", "com.parkflow.app", "--project-name", "parkflow_mobile"]
    print("Running:", " ".join(cmd))
    res = subprocess.run(cmd, cwd=root_dir)
    if res.returncode != 0:
        print(f"flutter create failed with code {res.returncode}")
        sys.exit(res.returncode)
    
    shutil.rmtree(lib_dir)
    shutil.copytree(backup_lib, lib_dir)
    shutil.copy2(backup_pubspec, pubspec_file)
    shutil.rmtree(temp_backup)
    print("Restored original ParkFlow lib/ and pubspec.yaml.")
    
    manifest_path = os.path.join(root_dir, "android", "app", "src", "main", "AndroidManifest.xml")
    if os.path.exists(manifest_path):
        with open(manifest_path, "r", encoding="utf-8") as f:
            manifest_content = f.read()
        
        if "android.permission.INTERNET" not in manifest_content:
            manifest_content = manifest_content.replace(
                "<application",
                "<uses-permission android:name=\"android.permission.INTERNET\"/>\n    <uses-permission android:name=\"android.permission.ACCESS_NETWORK_STATE\"/>\n    <application"
            )
        if 'android:label="parkflow_mobile"' in manifest_content:
            manifest_content = manifest_content.replace('android:label="parkflow_mobile"', 'android:label="ParkFlow"')
        
        with open(manifest_path, "w", encoding="utf-8") as f:
            f.write(manifest_content)
        print("Updated AndroidManifest.xml with permissions.")
    else:
        print(f"Warning: {manifest_path} not found.")

if __name__ == "__main__":
    main()
