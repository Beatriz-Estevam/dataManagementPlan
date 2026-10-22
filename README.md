# dataManagementPlan

# `setup_project.sh` Script Documentation

`setup_project.sh` is a Bash script designed to automate and standardise the creation of directory structures for data analysis, high-performance computing (HPC), and software development projects.

Its primary feature is the management of distributed storage: it enables you to point large-volume or high-speed directories (such as scratch or backup drives) to external locations, linking them back to the main project via **symbolic links (symlinks)**.

---

## 🏗️ Generated Project Structure

Upon execution, the script creates the following directory and file hierarchy:

```text
<path>/<proj>/
├── data/
│   ├── short-term/          # Fast access / scratch storage
│   ├── manifests/           # Metadata, sample sheets, or manifest files
│   └── long-term/           # Raw, preserved data or backups
├── results/
│   ├── working/             # Intermediate or active processing results
│   └── validated/           # Final, validated results
├── scripts/
│   ├── code/                # Main source code (Git clone, symlink, or plain dir)
│   └── submit_scripts/
│       ├── under_work/      # Active submission scripts (e.g. Slurm/PBS)
│       └── validated/       # Validated submission scripts (Git clone, symlink, or plain dir)
└── project.env              # Project environment variable definitions
```

---

## ⚙️ Options and Parameters

The script can be run **interactively** (without arguments) or via **command-line options**:

| Short Option | Long Option | Description | Default |
| :--- | :--- | :--- | :--- |
| `-n` | `--name NAME` | Project name *(required)*. | *None* |
| `-p` | `--path DIR` | Directory where the project root will be created. | `$HOME` |
| | `--short-term DIR` | External target folder for `data/short-term`. | Internal directory |
| | `--manifests DIR` | External target folder for `data/manifests`. | Internal directory |
| | `--long-term DIR` | External target folder for `data/long-term`. | Internal directory |
| | `--working DIR` | External target folder for `results/working`. | Internal directory |
| | `--validated DIR` | External target folder for `results/validated`. | Internal directory |
| | `--code REPO\|DIR` | GitHub SSH address to clone **OR** directory path to link into `scripts/code`. | Plain directory |
| | `--submit REPO\|DIR` | GitHub SSH address to clone **OR** directory path to link into `scripts/submit_scripts/validated`. | Plain directory |
| `-y` | `--yes` | Non-interactive mode: never prompt, use defaults for omitted values. | Disabled (`0`) |
| `-h` | `--help` | Display help message and exit. | — |

*Note: The deprecated `--code-repo` and `--submit-repo` flags remain supported for backwards compatibility.*

---

## 🚨 Before using it

`setup_project.sh` clones with the SSH address from GitHub (`git@github.com:user/repo.git`).
It does not create keys or edit your SSH settings, so the steps below must be done first,
on the machine where you will run the script.

### 1. Check for an existing key

```bash
ls ~/.ssh/id_ed25519.pub
```

If the file exists, go to step 3. If not, create one.

### 2. Create a key

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
```

Press Enter to accept the default location. A passphrase is recommended.

### 3. Load the key into the SSH agent

macOS:
```bash
eval "$(ssh-agent -s)"
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
```

Linux:
```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

Optional, but saves retyping the passphrase. Add this to `~/.ssh/config`
(drop the `UseKeychain` line on Linux):

```
Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
```

### 4. Add the public key to GitHub

Copy it (`pbcopy < ~/.ssh/id_ed25519.pub` on macOS, or `cat ~/.ssh/id_ed25519.pub`),
then paste it at https://github.com/settings/ssh/new

### 5. Test

```bash
ssh -T git@github.com
```

You should see: `Hi <username>! You've successfully authenticated...`

### 6. Get the repo address

On the repository page: **Code → SSH tab**. Copy the address
(`git@github.com:user/repo.git`) and give it to the script:

```bash
./setup_project.sh -n myproj --code git@github.com:user/myproj-code.git
```

Do not use the `https://` address; the script rejects it.

### Troubleshooting

- `Permission denied (publickey)`: the key is not in the agent (`ssh-add -l`) or the public key was not added to GitHub.
- Asked for the passphrase on every run: add the `~/.ssh/config` block from step 3.
- Running the script unattended (`-y`): load the key into the agent first, since no prompts are allowed.



## 🚀 Back to `setup_project.sh`...  How to Use it

### 1. Interactive Mode

Run the script without arguments in a terminal session. It will guide you through each option:

```bash
./setup_project.sh
```

### 2. Automated / Command-Line Mode

Pass options directly for scripted or rapid deployment:

```bash
./setup_project.sh -n gutbac -p ~/projects \
    --short-term /scratch/$USER/gutbac \
    --long-term /backup/$USER/gutbac \
    --code git@github.com:username/gutbac-code.git \
    -y
```

---

## 🔑 Environment Variables (`project.env`)

The script generates a `project.env` file in the project root directory. Load these variables into your shell or pipeline scripts using:

```bash
source project.env
```

### Exported Variables:

* **Project Root:**
  * `PROJ_NAME`: Name of the project.
  * `PROJ_ROOT`: Absolute path to the project root directory.
* **Data Directories (`data/`):**
  
  * `PROJ_DATA`: `$PROJ_ROOT/data`
  * `PROJ_SHORT_TERM`: `$PROJ_DATA/short-term`
  * `PROJ_MANIFESTS`: `$PROJ_DATA/manifests`
  * `PROJ_LONG_TERM`: `$PROJ_DATA/long-term`
* **Results Directories (`results/`):**
  
  * `PROJ_RESULTS`: `$PROJ_ROOT/results`
  * `PROJ_WORKING`: `$PROJ_RESULTS/working`
  * `PROJ_VALIDATED`: `$PROJ_RESULTS/validated`
    
* **Script Directories (`scripts/`):**
  * `PROJ_SCRIPTS`: `$PROJ_ROOT/scripts`
  * `PROJ_CODE`: `$PROJ_SCRIPTS/code`
  * `PROJ_SUBMIT`: `$PROJ_SCRIPTS/submit_scripts`
  * `PROJ_SUBMIT_DEV`: `$PROJ_SUBMIT/under_work`
  * `PROJ_SUBMIT_PROD`: `$PROJ_SUBMIT/validated`

## 🛠️ Integrity Rules and Behaviour

1. **Handling Existing Folders:** If the project or any subfolder already exists, the script **will not overwrite** existing files. It only creates missing components.
2. **Git Integration:**
   * If a repository SSH is provided, it executes `git clone`.
3. **Symbolic Links (Symlinks):** When alternative base paths are specified, a symlink is created inside the main project tree pointing to that target.
