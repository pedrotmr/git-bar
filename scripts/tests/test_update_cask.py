import json
import shutil
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
        ).replace("HOMEBREW_CASK_TOKEN = pedrotmr-git-bar", "HOMEBREW_CASK_TOKEN   =   pedrotmr-git-bar   // cask file name")
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

    def test_path_like_cask_token_is_rejected(self):
        app_config = self.project_dir / "Config/App.xcconfig"
        app_config.write_text(
            app_config.read_text(encoding="utf-8").replace(
                "HOMEBREW_CASK_TOKEN   =   pedrotmr-git-bar   // cask file name",
                "HOMEBREW_CASK_TOKEN = ../invalid-token",
            ),
            encoding="utf-8",
        )
        result = subprocess.run(
            [sys.executable, str(self.script), "--print-cask-token"],
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("cask token", result.stderr)

    def test_product_name_is_used_instead_of_executable_name(self):
        app_config = self.project_dir / "Config/App.xcconfig"
        app_config.write_text(
            app_config.read_text(encoding="utf-8")
            + "\nAPP_EXECUTABLE_NAME = LegacyExecutable\nPRODUCT_NAME = ReleaseProduct\n",
            encoding="utf-8",
        )

        result = self.run_generator("1.2.0", "a" * 64)

        self.assertEqual(result.returncode, 0, result.stderr)
        content = self.cask_path.read_text()
        self.assertIn('app "ReleaseProduct.app"', content)
        self.assertIn("ReleaseProduct-#{version}.zip", content)
        self.assertNotIn("LegacyExecutable", content)

    def test_legacy_release_uses_current_cask_metadata_when_missing(self):
        legacy_release = Path(self.temp_dir.name) / "legacy-release"
        (legacy_release / "Config").mkdir(parents=True)
        (legacy_release / "Config/App.xcconfig").write_text(
            "RELEASE_OWNER = pedrotmr\nRELEASE_SLUG = git-bar\n"
            "PRODUCT_BUNDLE_IDENTIFIER = com.GitBar.app\nPRODUCT_NAME = LegacyGitBar\nSPARKLE_ENABLED = YES\n",
            encoding="utf-8",
        )
        (legacy_release / "Config/Project.xcconfig").write_text("MACOSX_DEPLOYMENT_TARGET = 14.6\n", encoding="utf-8")
        current = subprocess.run(
            [sys.executable, str(self.script), "--print-homebrew-settings"],
            capture_output=True,
            text=True,
            check=False,
        )
        legacy = subprocess.run(
            [
                sys.executable,
                str(self.script),
                "--config-root", str(legacy_release),
                "--fallback-config-root", str(self.project_dir),
                "--print-homebrew-settings",
            ],
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertEqual(current.returncode, 0, current.stderr)
        self.assertEqual(legacy.returncode, 0, legacy.stderr)
        current_settings = json.loads(current.stdout)
        legacy_settings = json.loads(legacy.stdout)
        self.assertEqual(legacy_settings["app_name"], "LegacyGitBar")
        self.assertEqual(legacy_settings["cask_token"], current_settings["cask_token"])
        self.assertEqual(legacy_settings["app_display_name"], current_settings["app_display_name"])
        self.assertEqual(legacy_settings["description"], current_settings["description"])

    def test_same_version_with_a_different_checksum_fails(self):
        self.assertEqual(self.run_generator("1.2.0", "a" * 64).returncode, 0)
        original = self.cask_path.read_text()

        result = self.run_generator("1.2.0", "b" * 64)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("different SHA-256", result.stderr)
        self.assertEqual(self.cask_path.read_text(), original)


if __name__ == "__main__":
    unittest.main()
