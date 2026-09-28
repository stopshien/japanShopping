# Credit Card Feedback — References

Market research gathered in 2026-09 from Taiwanese card comparison sites and bank campaign pages. Rates and dates change every campaign; use this for modelling decisions, never as default values in the app.

## How Cards Structure Feedback

| Card | Base | Bonus | Bonus cap (period) | Campaign | Conditions |
|---|---|---|---|---|---|
| 玉山熊本熊 | Japan 2.5%, uncapped | designated stores +6% | 500 / statement cycle, per 歸戶 | 2026/7/1–12/31 | register once |
| 永豐 JCB 現金回饋 | 2%, uncapped | Japan +3%; +5% after 20k per quarter | 300 / statement cycle; 1,000 / quarter | to 2026/12/31 | quarterly bonus needs registration (5,000 slots) |
| 中信 uniopen | overseas 3% | overseas in-store +8% | 500 points / month | to 2026/12/31 | none |
| 聯邦吉鶴 | — | up to 7% | 600 / month | to 2026/12/31 | contactless only, ≥ NT$100 per transaction |
| 富邦 J | 3% | +3% | 1,000 / quarter | to 2026/12/31 | ≥ NT$1,000 per transaction, registration |
| 中信 LINE Pay | 2.8% | +2.2% | 450 points / quarter | to 2026/12/31 | 3,000 registration slots each Tuesday |
| 台新 Richart (was @GoGo) | 玩旅刷 3.3% overseas, uncapped | — | none | to 2027/3/31 | switch plan in Richart Life app |
| 國泰 CUBE | up to 3.3% | — | none | to 2026/12/31 | App level 2 |

## Patterns

- **Two layers.** A long-term base rate, usually uncapped, plus a bonus that is capped, time-limited, and conditional. A card may have two or three layers, each with its own cap.
- **Cap periods.** Calendar month (by purchase date), statement cycle (previous closing day + 1 to this closing day), quarter, or the whole campaign. "每月上限" means calendar month at some banks and statement month at others.
- **Posting date.** Many banks assign a purchase to a period by its posting date (入帳日), 1–5 days after the purchase. The app only knows the purchase date, so period totals are estimates near period boundaries.
- **Cap unit.** Caps are written as feedback amounts (500 元 or 500 points), sometimes also as the equivalent spend.
- **歸戶.** Many caps are shared by every card the person holds at that bank.
- **Campaign length.** Bonuses usually run half a year (Jan–Jun, Jul–Dec), sometimes a quarter or into the next March. The next campaign often changes rate, cap, and conditions.
- **Unverifiable conditions.** Designated stores, contactless payment, per-transaction minimums, registration slots, member levels. The app cannot check them.
- **Switchable plans.** Richart lets the user switch plan once a day in the bank app. The whole day's purchases use the plan recorded at 23:59 (GMT+8). 假日刷 2% covers domestic holidays, so it likely does not apply to spending in Japan; 玩旅刷 3.3% is the overseas plan.
- **Foreign transaction fee.** About 1.5% (card network ~1% + bank ~0.5%). Published rates are gross, before the fee.

## Formulas

Current app:

```text
feedback  = round2((percent - 1.5) * priceTWD * 0.01)     // net of the fee
remaining = max(0, round2(remaining - feedback))
```

Planned (see `plan.md`):

```text
baseGross  = round2(plan.baseRate  * priceTWD * 0.01)
bonusGross = qualifies ? round2(plan.bonus.rate * priceTWD * 0.01) : 0
bonusGross = min(bonusGross, bonusRemainingInPeriod)       // cap applies to the gross bonus
fee        = round2(1.5 * priceTWD * 0.01)                  // per-card fee deferred (plan phase 6)
shown      = baseGross + bonusGross                         // 「這筆回饋」 shows the gross amount
                                                             // and the fee is listed beside it
bonusRemainingInPeriod = bonus.cap - Σ bonusGross of ledger entries for this plan in the period
```

## Sources

- https://www.cashfeel.com.tw/article/日本-信用卡-推薦
- https://www.beurlife.com/2022/09/best-credit-card-to-travel-japan.html
- https://event.esunbank.com.tw/credit/kumamon-card/japan-discount.html
- https://mkpcard.taishinbank.com.tw/tscccms/promotion/detail/WM_20251231102359184
- https://vocus.cc/article/68675703fd897800016d6397
- https://vocus.cc/article/67303c69fd897800016906b9
- https://bank.sinopac.com/sinopacBT/personal/article/smart-consumption/foreign-transaction-fee.html
