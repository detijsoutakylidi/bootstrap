# Bootstrap

Skript pro nastavení nového počítače — nainstaluje VS Code, Claude a další nástroje. Podrobná verze v angličtině: [README-en.md](README-en.md)

## Jak na to

### macOS

1. Otevři aplikaci **Terminal**
2. Zkopíruj a vlož tento příkaz:

```bash
bash <(curl -fsSL https://djtl.cz/gh/bootstrap.sh)
```

3. Stiskni **Enter** a postupuj podle pokynů na obrazovce

### Windows

1. Otevři **PowerShell**
2. Zkopíruj a vlož tento příkaz:

```powershell
& ([scriptblock]::Create((irm https://djtl.cz/gh/bootstrap.ps1)))
```

3. Stiskni **Enter** a postupuj podle pokynů na obrazovce

## Co skript udělá

- Nainstaluje **VS Code** (editor pro psaní kódu)
- Nainstaluje **Claude Code** (AI asistent přímo v editoru)
- Nainstaluje **Claude Desktop** (samostatná aplikace)
- Nastaví **editor** — motiv, klávesové zkratky, rozšíření
- Nastaví **terminál** — barevný profil a prompt
- Nastaví **přiřazení souborů** — .json, .md a další se budou otvírat ve VS Code
- Volitelně nainstaluje **Laravel Herd** a nastaví `.private` doménu pro lokální služby

Skript je bezpečné spustit opakovaně — nic nepřepíše, pokud to neschválíš.

## Nemáš administrátorský účet?

Některé instalace (Homebrew, VS Code, …) vyžadují administrátorská práva. Pokud pracuješ na běžném účtu:

1. Požádej admina, aby spustil instalační část:

**macOS** (admin v Terminalu):
```bash
bash <(curl -fsSL https://djtl.cz/gh/bootstrap.sh) --install
```

**Windows** (admin v PowerShellu):
```powershell
& ([scriptblock]::Create((irm https://djtl.cz/gh/bootstrap.ps1))) --install
```

2. Potom na svém účtu spusť konfiguraci:

**macOS:**
```bash
bash <(curl -fsSL https://djtl.cz/gh/bootstrap.sh) --configure
```

**Windows:**
```powershell
& ([scriptblock]::Create((irm https://djtl.cz/gh/bootstrap.ps1))) --configure
```
