#!/usr/bin/env python3
"""Verify local archive metadata; this does not claim App Store validation."""
import pathlib
import plistlib
import subprocess
import re
import sys

archive = pathlib.Path(sys.argv[1])
apps = list((archive / 'Products/Applications').glob('*.app'))
assert len(apps) == 1, 'Expected one app in archive'
app = apps[0]
info = plistlib.loads((app / 'Info.plist').read_bytes())
assert info['CFBundleIdentifier'] == 'com.terminallylazy.a0-ios'
assert info['CFBundleDisplayName'] == 'Agent Zero'
project = (pathlib.Path(__file__).resolve().parents[1] / 'project.yml').read_text()
for info_key, build_key in [('CFBundleShortVersionString', 'MARKETING_VERSION'), ('CFBundleVersion', 'CURRENT_PROJECT_VERSION')]:
    expected = re.search(r'^    ' + build_key + r': \"([^\"]+)\"', project, re.MULTILINE).group(1)
    assert info[info_key] == expected, f'{info_key} does not match project.yml'
assert info['ITSAppUsesNonExemptEncryption'] is False
privacy = plistlib.loads((app / 'PrivacyInfo.xcprivacy').read_bytes())
assert privacy['NSPrivacyTracking'] is False
reasons = {x['NSPrivacyAccessedAPIType']: x['NSPrivacyAccessedAPITypeReasons'] for x in privacy['NSPrivacyAccessedAPITypes']}
assert reasons['NSPrivacyAccessedAPICategoryUserDefaults'] == ['CA92.1']
assert set(reasons['NSPrivacyAccessedAPICategoryFileTimestamp']) == {'C617.1', '3B52.1'}
assert any('Starscream' in str(p) for p in app.rglob('PrivacyInfo.xcprivacy')), 'Missing Starscream privacy resource'
assert (app / 'ThirdPartyNotices.txt').stat().st_size > 10000
assert list((archive / 'dSYMs').glob('*.app.dSYM')), 'Missing app symbols'
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
print(f"Verified local signed archive: Agent Zero {info['CFBundleShortVersionString']} ({info['CFBundleVersion']})")
print('No TestFlight upload or Apple processing acceptance is implied.')
