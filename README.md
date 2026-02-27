# bootstrap

Setup scripts for bootstrapping a new dev machine.

## macOS

```bash
bash <(curl -fsSL https://djtl.cz/gh/bootstrap.sh)
```

Auto-detects admin access. On admin accounts, installs system tools + configures user environment. On standard accounts, configures only (warns about missing tools).

### Non-admin users

If you use a separate standard (non-admin) account for daily work:

1. From your admin account — install system tools:

```bash
bash <(curl -fsSL https://djtl.cz/gh/bootstrap.sh) --install
```

2. From your standard account — configure your environment:

```bash
bash <(curl -fsSL https://djtl.cz/gh/bootstrap.sh) --configure
```

Each script is idempotent — safe to re-run on an already-configured machine.
