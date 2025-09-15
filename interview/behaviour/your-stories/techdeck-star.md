# TechDeck — STAR (Idea → Revenue)

Situation

- Hard to discover high‑signal builders on X/Twitter; bio links lack structure and searchability; noisy signal.

Task

- Build a discovery engine with collectible “cards,” a directory, and an API, while keeping ops lean and costs predictable.

Action

- Built Rails app with Stripe‑gated submissions ($3.50) to filter noise; queue‑backed AI pipeline (solidqueue + Gemini) to generate cards from public data.
- Shipped a searchable directory, leaderboards, and JSON endpoints; deployed with kamal to DigitalOcean; documented simple, auditable releases.

Result

- Production site with live users and payments; public directory and API used for leaderboards; repeatable pipeline in place.

Learnings

- Small, well‑scoped payments reduce spam and fund ops; keep deployment boring and observable.

Keywords

- Rails, Stripe, solidqueue, Gemini, kamal, DigitalOcean, API, Leaderboards
