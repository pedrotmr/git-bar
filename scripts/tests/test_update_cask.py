import subprocess
import sys
import tempfile
import unittest
import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "update-cask.py"


class UpdateCaskTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.project_dir = Path(self.temp_dir.name) / "project"
        self.tap_dir = self.project_dir / "tap"
        self.script = self.project_dir / "scripts" / "update-cask.py"
        (self.project_dir / "Config").mkdir(parents=True)
        self.script.parent.mkdir(parents=True)
        for config_name in ("App.xcconfig", "Project.xcconfig"):
            shutil.copy2(ROOT / "Config" / config_name, self.project_dir / "Config" / config_name)
        app_config = self.project_dir / "Config/App.xcconfig"
        app_contents = app_config.read_text(encoding="utf-8")
        app_contents = app_contents.replace(
            "APP_DESCRIPTION = Manage Git branches, worktrees, stashes, and pull requests",
            "APP_DESCRIPTION = Manage Git branches, worktrees, stashes, and pull requests // cask description",
        ).replace("HOMEBREW_CASK_TOKEN = pedrotmr-git-bar", "HOMEBREW_CASK_TOKEN = pedrotmr-git-bar // cask file name")
        app_contents = app_contents.replace("SPARKLE_ENABLED = YES", "SPARKLE_ENABLED = YES // optional update module")
        app_config.write_text(app_contents, encoding="utf-8")
        project_config = self.project_dir / "Config/Project.xcconfig"
        project_config.write_text(
            project_config.read_text(encoding="utf-8").replace(
                "MACOSX_DEPLOYMENT_TARGET = 14.6",
                "MACOSX_DEPLOYMENT_TARGET = 14.6 // minimum supported OS",
            ),
            encoding="utf-8",
        )
        shutil.copy2(SCRIPT, self.script)
        self.cask_path = self.tap_dir / "Casks" / "pedrotmr-git-bar.rb"

    def tearDown(self):
        self.temp_dir.cleanup()

    def run_generator(self, version, sha256):
        return subprocess.run(
            [
                sys.executable,
                str(self.script),
                "--tap-dir",
                str(self.tap_dir),
                "--version",
                version,
                "--sha256",
                sha256,
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
        self.assertIn('desc "Manage Git branches, worktrees, stashes, and pull requests"', content)
        self.assertNotIn("verified:", content)
        self.assertIn("preflight_steps do", content)
        self.assertIn('if osVersion < \\"14.6\\" then error', content)
        self.assertIn('"managedByHomebrewBundlePath",\n          "-string",\n          "{{appdir}}/GitBar.app"', content)
        self.assertNotIn("#{appdir}", content)
        self.assertIn(
            '"delete",\n          "com.GitBar.app.homebrew",\n          "managedByHomebrewBundlePath"',
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
