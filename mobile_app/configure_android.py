import os

def main():
    manifest_path = os.path.join('android', 'app', 'src', 'main', 'AndroidManifest.xml')
    if not os.path.exists(manifest_path):
        print(f"Error: {manifest_path} not found!")
        return

    with open(manifest_path, 'r', encoding='utf-8') as f:
        content = f.read()

    if 'android.permission.INTERNET' not in content:
        content = content.replace('<application', '<uses-permission android:name="android.permission.INTERNET"/>\n    <application')
    if 'android:usesCleartextTraffic="true"' not in content:
        content = content.replace('<application', '<application\n        android:usesCleartextTraffic="true"')

    with open(manifest_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Successfully configured AndroidManifest.xml with INTERNET permission and cleartext traffic.")

if __name__ == '__main__':
    main()
