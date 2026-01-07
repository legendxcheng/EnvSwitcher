# EnvVarSwitcher (evs)

A PowerShell tool to quickly switch between different environment variable configurations.

## Installation

```powershell
# Navigate to the tool directory
cd E:\EnvVarSwitcher

# Run the installer
.\Install.ps1

# Reload your profile (or restart PowerShell)
. $PROFILE
```

## Usage

### List available profiles

```powershell
evs list
# or
evs ls
```

### Switch to a profile

```powershell
evs use dev
# or
evs switch prod
```

### Show current state

```powershell
# Show active profile and variables
evs show

# Preview a specific profile
evs show prod
```

### Clear current session

```powershell
evs clear
```

### Create a new profile

```powershell
evs add staging
```

### Edit a profile

```powershell
evs edit dev
```

### Remove a profile

```powershell
evs remove old-profile
# or
evs rm old-profile
```

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

## Directory Structure

```
E:\EnvVarSwitcher\
├── evs.ps1              # Main script
├── Install.ps1          # Installation script
├── profiles/            # Profile configurations
│   ├── dev.json
│   └── prod.json
└── README.md
```

## How It Works

- Environment variables are set at the **process level** (current session only)
- Switching profiles clears previously set variables first
- Variables are tracked so `evs clear` knows what to remove
- No system-wide changes are made

## Tips

1. **Quick switching**: Use `evs use <profile>` to instantly switch environments
2. **Preview before switch**: Use `evs show <profile>` to see what variables will be set
3. **Clean state**: Use `evs clear` to return to a clean state without any evs-managed variables

## Troubleshooting

### "evs: command not found"

Run the installer again:
```powershell
cd E:\EnvVarSwitcher
.\Install.ps1
. $PROFILE
```

### Variables not showing after switch

Make sure you're checking in the same PowerShell session where you ran `evs use`.

### Profile not found

Check that your profile file:
1. Is in the `profiles/` directory
2. Has a `.json` extension
3. Is valid JSON format

## License

MIT
