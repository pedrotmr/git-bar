import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "update-cask.py"


class UpdateCaskTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.tap_dir = Path(self.temp_dir.name) / "tap"
        self.cask_path = self.tap_dir / "Casks" / "demo-app.rb"

    def tearDown(self):
        self.temp_dir.cleanup()

    def run_generator(self, version, sha256):
        return subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--tap-dir",
                str(self.tap_dir),
                "--version",
                version,
                "--sha256",
                sha256,
                "--owner",
                "example",
                "--slug",
                "demo-app",
                "--cask-token",
                "demo-app",
                "--bundle-id",
                "com.example.Demo",
                "--app-name",
                "Demo",
                "--app-display-name",
                "Demo",
                "--description",
                "A demo app.",
                "--min-macos",
                "14.6",
                "--sparkle",
                "yes",
            ],
            capture_output=True,
            text=True,
            check=False,
        )

    def test_generated_cask_uses_version_checksum_and_exact_macos_floor(self):
        checksum = "a" * 64
        result = self.run_generator("1.2.0", checksum)

        self.assertEqual(result.returncode, 0, result.stderr)
        content = self.cask_path.read_text()
        self.assertIn('version "1.2.0"', content)
        self.assertIn(f'sha256 "{checksum}"', content)
        self.assertIn("auto_updates true", content)
        self.assertIn('"managedByHomebrewBundlePath", "-string", "#{appdir}/Demo.app"', content)
        self.assertIn('"delete", "com.example.Demo.homebrew", "managedByHomebrewBundlePath"', content)
        self.assertIn('if MacOS.full_version < "14.6"', content)

    def test_older_release_does_not_replace_a_newer_cask(self):
        self.assertEqual(self.run_generator("1.2.0", "a" * 64).returncode, 0)
        original = self.cask_path.read_text()

        result = self.run_generator("1.1.9", "b" * 64)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Skipped old release 1.1.9", result.stdout)
        self.assertEqual(self.cask_path.read_text(), original)

    def test_same_version_with_a_different_checksum_fails(self):
        self.assertEqual(self.run_generator("1.2.0", "a" * 64).returncode, 0)
        original = self.cask_path.read_text()

        result = self.run_generator("1.2.0", "b" * 64)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("different SHA-256", result.stderr)
        self.assertEqual(self.cask_path.read_text(), original)


if __name__ == "__main__":
    unittest.main()
