"""Menyesuaikan folder android/ hasil `flutter create`:
izin kamera, query TTS (Android 11+), dan minSdk 23."""
import pathlib
import re
import sys

manifest = pathlib.Path("android/app/src/main/AndroidManifest.xml")
text = manifest.read_text()

if "android.permission.CAMERA" not in text:
    text = text.replace(
        "<application",
        '<uses-permission android:name="android.permission.CAMERA"/>\n'
        '    <uses-feature android:name="android.hardware.camera" android:required="false"/>\n'
        "    <application",
        1,
    )

tts_intent = (
    '<intent><action android:name="android.intent.action.TTS_SERVICE"/></intent>'
)
if "TTS_SERVICE" not in text:
    if "</queries>" in text:
        text = text.replace("</queries>", f"    {tts_intent}\n    </queries>", 1)
    else:
        text = text.replace(
            "</manifest>", f"    <queries>{tts_intent}</queries>\n</manifest>", 1
        )
manifest.write_text(text)

patched = False
for name, repl in (
    ("android/app/build.gradle.kts", "minSdk = 23"),
    ("android/app/build.gradle", "minSdkVersion 23"),
):
    f = pathlib.Path(name)
    if not f.exists():
        continue
    src = f.read_text()
    new = re.sub(r"minSdk(Version)?\s*=?\s*flutter\.minSdkVersion", repl, src)
    if new != src:
        f.write_text(new)
        patched = True

if not patched:
    print("PERINGATAN: minSdk tidak diubah. Set minSdk 23 manual di android/app/build.gradle*.")
    sys.exit(0)
print("Android berhasil dipatch.")
