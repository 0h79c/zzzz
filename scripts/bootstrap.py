"""Install pinned official tooling locally, verifying GitHub release SHA-256s."""
from pathlib import Path
import hashlib
import io
import platform
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / ".tools"
RELEASES = [
    ("rojo-rbx/rojo", "v7.7.1", "rojo-7.7.1-linux-x86_64.zip", "00feb4fa0829a1dd72b49df2639da519a352bfe13cadcd83969e2ba2bb5693c4", ["rojo"]),
    ("lune-org/lune", "v0.11.0", "lune-0.11.0-linux-x86_64.zip", "5a0ea32c3e13e5e3b1dc415c2056bcfe44258b3a811dcd473c50e3b437d10f72", ["lune"]),
    ("luau-lang/luau", "0.742", "luau-ubuntu.zip", "152058b98c60ff1f5b5ec9bca0b8eb37793cae161dd3a05608cc3d8738ba1a4d", ["luau", "luau-analyze", "luau-compile"]),
]

def main():
    if (platform.system(), platform.machine()) != ("Linux", "x86_64"):
        raise SystemExit("This cloud installer targets Linux x86_64. See README for Roblox Studio on your own computer.")
    TOOLS.mkdir(exist_ok=True)
    for project, version, asset, expected, binaries in RELEASES:
        marker = TOOLS / (project.split("/")[1] + ".sha256")
        if marker.exists() and marker.read_text().strip() == expected and all((TOOLS / binary).is_file() for binary in binaries):
            print(f"Using retained {project} {version}")
            continue
        url = f"https://github.com/{project}/releases/download/{version}/{asset}"
        request = urllib.request.Request(url, headers={"User-Agent": "Wildbond-bootstrap"})
        with urllib.request.urlopen(request, timeout=60) as response:
            data = response.read()
        if hashlib.sha256(data).hexdigest() != expected:
            raise SystemExit(f"Checksum mismatch for {asset}; no binaries installed.")
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            for binary in binaries:
                matches = [name for name in archive.namelist() if Path(name).name == binary]
                if len(matches) != 1:
                    raise SystemExit(f"Expected one {binary} in {asset}")
                dest = TOOLS / binary
                dest.write_bytes(archive.read(matches[0]))
                dest.chmod(0o755)
        marker.write_text(expected + "\n")
        print(f"Verified and installed {project} {version}")

if __name__ == "__main__":
    main()
