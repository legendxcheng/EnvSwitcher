# EnvVarSwitcher (evs)

A tool to quickly switch between different environment variable configurations.

Supports both **Windows PowerShell** and **WSL/Linux Bash**.

---

## Windows Installation (PowerShell)

```powershell
cd E:\EnvVarSwitcher
.\Install.ps1
. $PROFILE
```

## WSL/Linux Installation (Bash)

```bash
cd /mnt/e/EnvVarSwitcher
bash install-wsl.sh
source ~/.bashrc
```

**Prerequisite**: Install `jq` for JSON parsing:
```bash
sudo apt install jq    # Ubuntu/Debian
```

---

## Usage

Commands are identical on both Windows and WSL:

### List available profiles

```bash
evs list
evs ls
```

### Switch to a profile

```bash
evs use dev
evs switch prod
```

### Show current state

```bash
evs show           # Show active profile and variables
evs show prod      # Preview a specific profile
```

### Clear current session

```bash
evs clear
```

### Create a new profile

```bash
evs add staging
```

### Edit a profile

```bash
evs edit dev
```

### Remove a profile

```bash
evs remove old-profile
evs rm old-profile
```

---

## Profile Format

Profiles are stored as JSON files in the `profiles/` directory:

```json
{
  "name": "dev",
  "description": "Local development environment",
  "variables": {
    "NODE_ENV": "development",
    "API_URL": "http://localhost:3000",
    "DEBUG": "true"
  }
}
```

---

## Directory Structure

```
E:\EnvVarSwitcher\
├── evs.ps1              # Windows PowerShell script
├── evs.sh               # WSL/Linux Bash script
├── Install.ps1          # Windows installer
├── install-wsl.sh       # WSL/Linux installer
├── profiles/            # Shared profile configurations
│   ├── dev.json
│   └── prod.json
└── README.md
```

---

## How It Works

- Environment variables are set at the **process level** (current session only)
- Switching profiles clears previously set variables first
- Variables are tracked so `evs clear` knows what to remove
- No system-wide changes are made
- **Windows and WSL share the same `profiles/` directory**

---

## WSL-Specific Notes

### Profile Locations

WSL checks for profiles in this order:
1. `~/.config/evs/profiles/` (local, takes priority)
2. `/mnt/e/EnvVarSwitcher/profiles/` (shared with Windows)

### Create Local Profiles

```bash
mkdir -p ~/.config/evs/profiles
```

Local profiles override shared ones with the same name.

---

## Tips

1. **Quick switching**: Use `evs use <profile>` to instantly switch environments
2. **Preview before switch**: Use `evs show <profile>` to see what variables will be set
3. **Clean state**: Use `evs clear` to return to a clean state
4. **Cross-platform**: Edit profiles on Windows, use them in WSL (and vice versa)

---

## Troubleshooting

### "evs: command not found"

**Windows:**
```powershell
cd E:\EnvVarSwitcher
.\Install.ps1
. $PROFILE
```

**WSL:**
```bash
cd /mnt/e/EnvVarSwitcher
bash install-wsl.sh
source ~/.bashrc
```

### Variables not showing after switch

Make sure you're checking in the same terminal session where you ran `evs use`.

### Profile not found

Check that your profile file:
1. Is in the `profiles/` directory
2. Has a `.json` extension
3. Is valid JSON format

### WSL: "jq: command not found"

Install jq:
```bash
sudo apt install jq
```

---

## License

MIT
