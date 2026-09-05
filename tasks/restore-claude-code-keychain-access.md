# Restore Claude Code keychain access

## The issue

`claude doctor` under Claude Code 2.1.261 reports that the macOS login keychain is not writable.
`security` returns `-60008`, so Claude Console login cannot persist its API key. A model-backed
`claude -p` validation also exits with `Not logged in · Please run /login`. Local commands such as
`claude doctor`, `/skill-doctor`, and project configuration loading still work; Remote Control and
claude.ai subscription authentication are not active in this environment.

Reproduce with:

```sh
claude doctor
```

Claude's diagnostic recommends unlocking `~/Library/Keychains/login.keychain-db`; if that does not
resolve it, inspect the login keychain in Keychain Access for an account-password mismatch. This is
a local machine repair and must not add credentials or machine-specific secrets to the repository.
