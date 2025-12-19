# FancyVerteiler-Tools

![PowerShell](https://custom-icon-badges.demolab.com/badge/PowerShell-5391FE?logo=powershell-white&logoColor=fff)
![Bash](https://custom-icon-badges.demolab.com/badge/Bash-4EAA25?logo=gnubash&logoColor=white)

![Test Scripts](https://github.com/CloveTwilight3/FancyVerteiler-Tools/actions/workflows/test.yml/badge.svg)
![API Check](https://github.com/CloveTwilight3/FancyVerteiler-Tools/actions/workflows/api-check.yml/badge.svg)
![License](https://img.shields.io/github/license/CloveTwilight3/FancyVerteiler-Tools)

Minimal cross-platform scripts to fetch **Minecraft** and **Hytale** version IDs from the  [CurseForge API](https://www.curseforge.com) for use with  [FancyVerteiler](https://github.com/FancyInnovations/FancyVerteiler).

Created by [CloveTwilight3](https://github.com/clovetwilight3)

## ✨ Features

- Fetch Minecraft **plugin** or **mod** version IDs
- Fetch **Hytale** version IDs
- Works on **Windows (PowerShell)** and **Linux/macOS (Bash)**
- Outputs **JSON** + ready-to-use **Go maps**


## Prerequisites

### Get an API Token
Generate one in your [CurseForge account settings](https://www.curseforge.com/account/api-tokens).

## Usage

**Minecraft:**
```txt
./minecraft/fetch-minecraft-versions.[ps1|sh] -ApiToken <token> [-Type plugin|mod]
```
> `-Type` defaults to `plugin` if not specified.

**Hytale:**
```txt
./hytale/fetch-hytale-versions.[ps1|sh] -ApiToken <token>
```


## 📄 License

MIT: see [LICENSE](LICENSE) for details

🔗 **Related:**
[FancyVerteiler](https://github.com/FancyInnovations/FancyVerteiler) by [FancyInnovations](https://github.com/FancyInnovation)