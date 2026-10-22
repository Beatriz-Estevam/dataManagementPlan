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

---

# `md5_manifest.sh` Script Documentation

`md5_manifest.sh` is a portable Bash utility designed to generate and verify tab-separated MD5 checksum manifests for data integrity management. It recursively processes files and directories, recording the MD5 hash alongside the absolute path of every file.

It integrates seamlessly with project environments established via `project.env` by automatically saving manifests into the `$PROJ_MANIFESTS` directory when loaded.

---

## 📋 Features

1. **Cross-Platform Compatibility:** Works on both Linux (`md5sum`) and macOS (`md5`), utilizing stream redirection to handle filenames containing special characters or spaces safely.
2. **Recursive Traversal:** Recursively processes directories to calculate checksums for all enclosed files.
3. **Atomic File Operations:** Writes output to temporary files before sorting and saving, preventing partially written manifests in the event of an interruption.
4. **Append & Overwrite Safety:** Prevents accidental overwrites of existing manifests by requiring explicit `--append` or `--overwrite` flags.
5. **Self-Exclusion:** Automatically avoids calculating and writing a checksum for the target manifest file itself.
6. **Integrity Checking Mode:** Reads generated manifests, recalculates current MD5 hashes, and flags missing or altered files.

---

## 📑 Manifest File Format

Manifest files are generated in tab-separated value (`.tsv`) format:

```text
<md5_hash><TAB><absolute_file_path>
```

### Example Manifest Content:
```tsv
d41d8cd98f00b204e9800998ecf8427e	/home/user/projects/gutbac/data/long-term/sample1.fastq.gz
7b8b965ad4bca0e41ab51de7b31363a1	/home/user/projects/gutbac/data/long-term/sample2.fastq.gz
```

---

## ⚙️ Options and Parameters

```text
Usage:
  md5_manifest.sh [options] PATH [PATH ...]     Register MD5 checksums
  md5_manifest.sh -c MANIFEST                   Verify files against a manifest
```

| Short Option | Long Option | Description | Default |
| :--- | :--- | :--- | :--- |
| `-o` | `--output FILE` | Output manifest file path. Bare filenames (without `/`) default to `$PROJ_MANIFESTS`. | `$PROJ_MANIFESTS/md5_<date>_<time>.tsv` |
| `-l` | `--list FILE` | Path to a text file containing one input path per line. | *None* |
| `-a` | `--append` | Append new files to an existing manifest, skipping paths already recorded. | Disabled (Requires choice if file exists) |
|      | `--overwrite` | Overwrite an existing manifest file completely. | Disabled (Requires choice if file exists) |
| `-c` | `--check FILE` | Verification mode: Recompute hashes and compare against the specified manifest. | *None* |
| `-h` | `--help` | Display help text and exit. | — |

---

## 🚀 Usage Examples

### 1. Generating a Manifest for a Directory
Generate a checksum manifest for all files under the raw data directory:

```bash
# Ensure project variables are active
source project.env

# Generate manifest in $PROJ_MANIFESTS/raw_data.tsv
md5_manifest.sh -o raw_data.tsv ~/projects/gutbac/data/long-term
```

### 2. Appending New Files to an Existing Manifest
Add new files or folders to a previously created manifest without recalculating existing entries:

```bash
md5_manifest.sh -a -o raw_data.tsv new_sample.fastq.gz additional_dir/
```

### 3. Using an Input List File
Provide input targets via a text file listing paths line by line:

```bash
md5_manifest.sh -l paths_list.txt -o batch_manifest.tsv
```

### 4. Verifying Data Integrity (`--check`)
Validate that files have not been corrupted, altered, or deleted:

```bash
md5_manifest.sh -c $PROJ_MANIFESTS/raw_data.tsv
```

**Example Output (Verification Passed):**
```text
[info] Check done: 42 OK, 0 changed, 0 missing.
```

**Example Output (Integrity Failures):**
```text
FAILED:  /home/user/projects/gutbac/data/long-term/sample1.fastq.gz
MISSING: /home/user/projects/gutbac/data/long-term/sample3.fastq.gz
[info] Check done: 40 OK, 1 changed, 1 missing.
```

---

## 🚦 Exit Statuses

* `0`: Operation completed successfully / Verification passed with 0 errors.
* `1`: Script failed due to missing inputs, read errors, invalid arguments, or verification failures (missing or modified files).
