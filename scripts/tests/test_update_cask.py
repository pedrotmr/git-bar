import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "update-cask.py"


class UpdateCaskTests(unittest.TestCase):
    def test_minor_version_preflight_rejects_older_macos(self):
        for current_version, accepted in (("14.5", False), ("14.6", True), ("15.0", True)):
            with self.subTest(current_version=current_version):
                result = subprocess.run(
                    [
                        "/usr/bin/osascript",
                        "-e",
                        f'set osVersion to "{current_version}"',
                        "-e",
                        "considering numeric strings",
                        "-e",
                        'if osVersion < "14.6" then error "Requires macOS 14.6 or later." number 1',
                        "-e",
                        "end considering",
                    ],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(result.returncode == 0, accepted, result.stderr)

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
                "Manage demo workspaces...",
                "--min-macos",
                "14.6",
                "--sparkle",
                "yes",
            ],
            capture_output=True,
            text=True,
            check=False,
        )

    def test_generated_cask_uses_version_checksum_and_macos_release(self):
        checksum = "a" * 64
        result = self.run_generator("1.2.0", checksum)

        self.assertEqual(result.returncode, 0, result.stderr)
        content = self.cask_path.read_text()
        self.assertIn('version "1.2.0"', content)
        self.assertIn(f'sha256 "{checksum}"', content)
        self.assertIn("auto_updates true", content)
        self.assertIn("depends_on macos: :sonoma", content)
        self.assertIn('desc "Manage demo workspaces"', content)
        self.assertNotIn("verified:", content)
        self.assertIn("preflight_steps do", content)
        self.assertIn('if osVersion < \\"14.6\\" then error', content)
        self.assertIn('"managedByHomebrewBundlePath",\n          "-string",\n          "{{appdir}}/Demo.app"', content)
        self.assertNotIn("#{appdir}", content)
        self.assertIn(
            '"delete",\n          "com.example.Demo.homebrew",\n          "managedByHomebrewBundlePath"',
            content,
        )
        self.assertNotIn("preflight do", content)

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
