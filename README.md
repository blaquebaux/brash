# Blaque Baux Brash

**Deliberately aggressive. Crypto and alternatives, sized for convex upside — governed so aggression never becomes uncontrolled ruin.**

Brash is a member of the Blaque Baux family. The [core repo](https://github.com/Carter-Warrens/blaquebaux)
is the **engine and blueprint**: a governed, systematic platform (Julia) with a
venue-agnostic execution controller and a Layer-3 live-money safety gate. Brash points
that engine at the high-octane end of the market — crypto, leverage, alternative and
convex exposures — while inheriting the engine's governance wholesale. **Aggression here
is a sizing decision, never a governance bypass:** every order still routes through the
same idempotency, reconciliation, kill switch, and drawdown/loss gates as the spine.

> **Not investment advice.** Educational/research software. Aggressive strategies carry
> outsized risk, including total loss. Nothing here is validated. See [LICENSE](LICENSE).

```bash
git clone --recursive https://github.com/Carter-Warrens/blaquebaux-brash.git
julia --project=engine -e 'using Pkg; Pkg.instantiate()'   # one-time engine setup
```

## The thesis

The base research already mapped the growth-vs-ruin frontier: **aggression multiplies
edge, and with no edge it multiplies only ruin** (see the base's `growth_vs_ruin` sketch —
levering a ~1.0-Sharpe book past its Kelly point *lowers* growth while deepening drawdown).
Brash takes the honest implication seriously: pursue convex, high-return sleeves, but cap
them at a hard ruin boundary the governance layer enforces. The goal is asymmetric upside
with a floor, not maximal leverage.

## Research plan (Path A — not yet built)

Candidate directions to test with the same discipline as the base corpus (build it, test
it honestly, keep the record including what fails):

- **Crypto trend / vol-targeting** — BTC/ETH time-series momentum, each vol-targeted; the
  base already ingests Deribit BTC implied vol as a risk input.
- **Kelly-capped leverage** — size by fractional Kelly with a hard ruin cap; measure
  terminal-wealth distributions (block-bootstrap), not just Sharpe.
- **Crypto funding / basis carry** — perp funding and spot-futures basis, with the honest
  caveat (from the base's carry work) that carry is negative-skew and can be un-timeable.
- **Alternative / convex sleeves** — asymmetric payoffs where the downside is defined.

Nothing above is implemented or validated. This is the map, not the territory.

## Status
**Scaffold.** Engine wired as a submodule; strategy research not yet conducted.

## The Blaque Baux family
- **Blaque Baux** — base engine + validated slow risk-premium spine.
- **Blunt** — short-horizon tactical sleeves.
- **Brash** *(this repo)* — highly aggressive (crypto, alternatives).
- **Bleed** — deeply contrarian; positioned for the tails (Black/White/Grey Swans, Dragon Kings).
- **Bottom** — sub-small-cap / penny names.
- **Brittle** — near-expiry, far-OTM options/ETFs; the other side of the lottery ticket.
- **Boom** — mega-cap blue chips (the Magnificent 7 and peers).

## Layout
```
engine/     the Blaque Baux platform (git submodule → Carter-Warrens/blaquebaux)
research/   Path-A strategy sketches (to come)
live/       governed live drivers (once a sleeve graduates to paper A/B)
```

## License
[MIT](LICENSE). © 2026 Carter Warrens.
