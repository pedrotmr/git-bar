# Screenshot capture

`Screenshots/git-bar-placeholder.svg` is a labeled placeholder, not a product screenshot. The app was built and launched with an isolated bundle identifier and a synthetic local repository. The available computer-use bridge could not expose GitBar's menu bar popover, so a real capture is still needed before replacing the placeholder.

Use a temporary local repository with fictional branches and commits. Do not use private repositories, personal branch names, real pull requests, or private file paths. Capture the actual menu bar popover after opening GitBar and selecting the demo repository. Save the unedited capture as `Screenshots/git-bar.png`, then update the image and alt text near the top of `README.md`.

One capture command after arranging the real app on screen is:

```sh
screencapture -x -w Screenshots/git-bar.png
```
