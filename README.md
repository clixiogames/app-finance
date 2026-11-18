# APP FINANCE

All your savings and investments in one place — an Android app (Google Play) and an identical website.
Built with **Godot 4.7.2**. Data stays on the device; no accounts, no servers, €0 to run.

## What it does (v0.1 — Wealth)
- Accounts (PEA, CTO, assurance vie, PER, livrets, crypto, property…) holding any type of asset:
  ETFs, funds, stocks, crypto, Livret A / LDDS / LEP, other savings, euro funds, property, loans.
- Record money in/out as **amount + date**; units are computed from that day's **real price**
  (or enter exact units/price from your statement).
- Savings interest per account: **automatic** (official rates + French "quinzaine" rules, estimated),
  **manual**, or **ignored**.
- Overview: total wealth, gain/loss, value over time vs money invested, allocation by type/account,
  monthly savings and savings rate.
- Backup: export/import a JSON file (or copy/paste as text).
- Spending section (bank statements) — next milestone.

## Price sources (free)
| What | Source | Notes |
|---|---|---|
| ETFs, funds, stocks | Yahoo Finance public chart data | Unofficial; website needs the relay (CORS) |
| Crypto | CoinGecko public API (keyless) | Last 365 days of history on the free plan |
| Exchange rates | ECB via Frankfurter | Free, no key |
| Livret A / LDDS / LEP rates | Built-in table `src/core/regulated_rates.gd` | Update each 1 Feb / 1 Aug |

## Project layout
```
src/core/      data, money maths, interest engine, portfolio calculations, price fetching
src/ui/        app shell, theme, widgets, screens
tests/         automated tests (run_tests.gd), end-to-end flow test, screenshot tool
relay/         Cloudflare Worker that lets the website fetch Yahoo prices
.github/       CI: tests → web build (GitHub Pages) → Android .aab/.apk
```

## Money rules
Amounts are integer cents; units ×1e6; prices ×1e4; FX ×1e6. No floats for stored money.
Dates are `YYYY-MM-DD` (UTC).

## Run the checks
```
godot --headless --path . --import
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . res://tests/flow_test.tscn
xvfb-run godot --path . --rendering-driver opengl3 --resolution 824x1800 res://tests/shots.tscn -- --out=/tmp/shots
```

## Build secrets (GitHub → Settings → Secrets and variables → Actions)
| Secret | What |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Upload keystore, base64-encoded |
| `ANDROID_KEY_ALIAS` | Key alias in the keystore |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |

Without these, CI still builds the website and a test APK.

## Price relay for the website
1. Cloudflare dashboard → Workers & Pages → Create → Worker → paste `relay/worker.js` → Deploy.
2. Put the worker URL in `PriceService.DEFAULT_RELAY` (or in the app: Settings › Price relay).

Disclaimer: informational only, not financial advice.
