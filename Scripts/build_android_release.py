#!/usr/bin/env python3
"""Build the Google Play bundle with a private, durable local upload key.
The key/password are never written into the repository or printed. Google Play
App Signing keeps the distribution signing key; this is the upload key only.
"""
from pathlib import Path
import argparse,json,os,secrets,subprocess
r=Path(__file__).resolve().parent.parent
parser=argparse.ArgumentParser();parser.add_argument('--create-key',action='store_true');parser.add_argument('--bootstrap',action='store_true',help='Initial non-production upload to enable Play billing setup');args=parser.parse_args()
private=Path.home()/'.config/dress-by-the-weather/android-signing';config=private/'upload.json'
java=Path('/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home')
if not java.exists():raise SystemExit('Install JDK 21 or edit the local Java path before building.')
if not config.exists():
 if not args.create_key:raise SystemExit('No upload key configured. Run with --create-key for the first build.')
 private.mkdir(parents=True,exist_ok=True);private.chmod(0o700)
 password=secrets.token_urlsafe(36);key=private/'dress-upload.p12'
 env=dict(os.environ,JAVA_HOME=str(java),DRESS_KEY_PASSWORD=password)
 subprocess.run([str(java/'bin/keytool'),'-genkeypair','-storetype','PKCS12','-keystore',str(key),'-alias','dress-upload','-keyalg','RSA','-keysize','4096','-validity','10000','-dname','CN=Oana Rinaldi, OU=Dress by the Weather','-storepass:env','DRESS_KEY_PASSWORD','-keypass:env','DRESS_KEY_PASSWORD'],env=env,check=True)
 key.chmod(0o600)
 fd=os.open(config,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
 with os.fdopen(fd,'w') as f:json.dump({'keystore':str(key),'storePassword':password,'keyPassword':password,'alias':'dress-upload'},f)
keyinfo=json.loads(config.read_text())
public=(r/'Android/app/src/main/assets/play-billing-public-key.txt').read_text().strip()
if not public and not args.bootstrap:raise SystemExit('Set this app’s Google Play billing public key before a production build.')
env=dict(os.environ,JAVA_HOME=str(java),DRESS_UPLOAD_KEYSTORE=keyinfo['keystore'],DRESS_UPLOAD_STORE_PASSWORD=keyinfo['storePassword'],DRESS_UPLOAD_KEY_PASSWORD=keyinfo['keyPassword'],DRESS_UPLOAD_KEY_ALIAS=keyinfo['alias'])
subprocess.run([str(r/'Android/gradlew'),':app:bundleRelease',':app:assembleRelease',':app:lintRelease'],cwd=r/'Android',env=env,check=True)
print('Signed Android bundle:',r/'Android/app/build/outputs/bundle/release/app-release.aab')
print('Private upload-key backup folder:',private)
if args.bootstrap:print('Bootstrap upload only: do not submit this build to production before billing configuration is complete.')
