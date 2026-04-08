# Editorial Landing Page Redesign — Design Spec

## Goal
Replace the current landing page with an editorial-style design that feels handcrafted (not AI-generated), includes public asset search without login, real market data, trust signals, and zero background animations (ticker scroll is the only continuous animation).

## Design Reference
The approved mockup is at `.superpowers/brainstorm/86555-1775685196/content/03-editorial-v2.html`. This is the source of truth for all visual decisions.

## Architecture

### Performance constraints (hard requirements)
- **Zero `backdrop-filter`** anywhere
- **Zero `filter: blur()`** anywhere
- **Zero background canvas elements** — no JS-driven background animations
- **Zero `will-change`** — not needed without animations
- **Only continuous animation**: ticker scroll (single CSS `translateX` on one element)
- **Background depth**: static CSS `radial-gradient` on body with `background-attachment: fixed`
- All interactive canvas (portfolio chart, sparklines) throttled to ≥3s intervals

### Page structure (top to bottom)
1. **Nav** — logo, 2 links (Features, How it works), "Sign up free" button
2. **Ticker bar** — real prices from Finnhub API, CSS scroll animation
3. **Hero** — headline, subtitle, public search bar, dashboard preview
4. **Trust bar** — 3 metrics + 2 security badges
5. **Features** — asymmetric 2-column grid (1 tall card + 2 short), with tags
6. **How it works** — 4 horizontal steps with connecting line
7. **Social proof** — testimonial quote + partner/data-source logos
8. **CTA** — heading, subtitle, button, security reassurance items
9. **Footer** — copyright + links

### Public search (no login required)
- Search input in hero section
- Stimulus controller fetches `/api/search?q=...` endpoint
- Backend proxies to Finnhub symbol search API (`/search?q=...&token=...`)
- Results dropdown shows: company name, symbol, exchange, current price + change
- Clicking a result navigates to `/quote/SYMBOL` (new public page)

### Public quote page (`/quote/:symbol`)
- No login required
- Fetches real-time quote from Finnhub REST API
- Shows: symbol, company name, price, change, open/high/low/volume
- Chart: static clip-path CSS chart (no canvas) OR a single small canvas with throttled updates
- Below chart: CTA to sign up for alerts on this symbol
- Same nav/footer as landing

### Auth pages (login/register)
- Same background as landing (static radial-gradients on body)
- No background divs at all — body gradient shows through
- Card: `--bg-surface` background, `--border` border, blue top border (2px)
- Clean form fields, solid blue submit button
- Trust note below register form (Terms + Privacy)
- Login: inline forgot-password link next to Remember Me

### Real data sources
- **Ticker**: fetches `/api/prices` on load (existing endpoint), falls back to hardcoded
- **Search**: fetches `/api/search?q=...` (new endpoint)
- **Quote page**: fetches `/api/quote/:symbol` (new endpoint)
- All endpoints proxy to Finnhub REST API with server-side caching (5-minute TTL)

### Design tokens (from mockup)
```
Background:     #050810
Surface:        #0A0F1C  
Card:           #111832
Border:         rgba(255,255,255,0.06)
Border light:   rgba(255,255,255,0.1)
Text primary:   #E8ECF4
Text secondary: #7E89A7
Text muted:     #4A5370
Accent blue:    #3B82F6
Green:          #10B981
Red:            #F43F5E
Purple:         #8B5CF6

Font UI:        Inter (400, 500, 600, 700)
Font data:      JetBrains Mono (400, 500)
```

### Typography rules
- Headlines: Inter 700, tight letter-spacing (-2px), no gradient text
- Accent words: solid `--blue` color, no animation
- Section labels: 11px uppercase, 2px letter-spacing, `--blue` color
- Body: 13-15px, `--text2` color
- Data/prices: JetBrains Mono
- All buttons: solid `--blue` background, no gradients, 6-8px border-radius

### Files to create/modify

**New files:**
- `app/controllers/quotes_controller.rb` — public quote page
- `app/views/quotes/show.html.erb` — quote page view
- `app/controllers/api/v1/search_controller.rb` — search endpoint
- `app/javascript/controllers/landing/search_controller.js` — search input Stimulus

**Replace entirely:**
- `app/views/landing/index.html.erb` — new editorial layout from mockup
- `app/assets/stylesheets/landing.css` — new CSS from mockup

**Modify:**
- `config/routes.rb` — add search + quote routes
- `app/controllers/landing_controller.rb` — add search action
- All 5 devise views — remove background divs (body gradient handles it)

**Delete:**
- `app/javascript/controllers/landing/feature_visuals_controller.js` — no longer needed
- `app/javascript/controllers/landing/counter_controller.js` — no longer needed
