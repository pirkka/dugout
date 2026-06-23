# Cyanide Studio Web Services API — A Friendlier Guide

This is a cleaned-up, plain-English walkthrough of the raw API listing Cyanide Studio's web services endpoint returns. The original is a dense JSON blob meant for machines; this version is meant for you. It covers four games that share the same API: **Blood Bowl 3** (most of the endpoints), plus the **Cyanide platform**, **Pro Cycling Manager**, and **Tour de France**.

## Before you start

### Your access

| | |
|---|---|
| **API key** | `c76acfe356ef424b1e7f9b1390e3d48a` |
| **Registered to** | Pirkka Esko (Seniorisankarit) |
| **Response format** | JSON |

Treat that key like a password — don't post it publicly or hand it to anyone else. It's tied to your registration, and the rest of this guide uses `YOUR_KEY` as a stand-in for it so you can paste your real key in wherever you see that placeholder.

If you ever want to re-fetch this same machine-readable list yourself (e.g. to check whether Cyanide added new endpoints), the URL is:
```
https://web.cyanide-studio.com/ws/?key=YOUR_KEY&bb=3
```

### The basic request pattern

Every endpoint follows the same shape:

```
https://web.cyanide-studio.com/ws/{game}/{method}/?key=YOUR_KEY&param=value&param2=value2...
```

- `{game}` is one of `bb3`, `cya`, `pcm`, or `tdf`.
- `{method}` is the endpoint name (`teams`, `ladder`, `match`, etc.)
- **For Blood Bowl, always add `bb=3` (or `opus=3`)** if you want Blood Bowl 3 data. These endpoints also serve the older BB1/BB2 games, so without that flag you may get legacy results instead of what you expect. This is the single most common gotcha when integrating with this API.

### Parameter aliases — read this first

Throughout the original doc, parameters are listed like `league|league_name` or `bb|opus`. The pipe (`|`) doesn't mean "pick a value" — it means **these are alternate names for the exact same parameter**. You can use whichever spelling you prefer; they behave identically. So `league=Official League` and `league_name=Official League` do the same thing. This guide keeps that notation in the tables below (shown as "use any of").

### Rules of the road

This is a free service Cyanide offers in good faith, so a few ground rules apply:

- **Rate limits:** 1,000 requests/hour and 10,000 requests/day. Going over either will cause requests to fail.
- **Be a good citizen:** cache results on your end rather than re-requesting the same data, and avoid firing off all your requests at once.
- **Registration ask:** Cyanide would like you to tell them your real name, a valid personal email, and the address of any website, app, bot, or tool you build using this API.
- **Keep your key private** — it's personal to your registration.
- **This is a beta service.** Cyanide can't promise heavy support, things occasionally break or go down, and they ask that you report any malfunctions you spot. Reach out to them directly for bugs or feature requests.

As a snapshot, the catalog behind this key currently reports roughly **675,619 games**, **93,722 teams**, **31,812 coaches/gamers**, and **205,648 competitions** on record — just to give you a sense of scale.

## Quick map of every endpoint

| Game | Endpoint | What it gives you |
|---|---|---|
| bb3 | `leagues` | List of leagues |
| bb3 | `league` | Details on one league |
| bb3 | `competitions` | Competitions within a league |
| bb3 | `lookup` | Search teams/leagues/competitions/coaches by name or ID |
| bb3 | `teams` | List of teams |
| bb3 | `team` | Full details on one team |
| bb3 | `coaches` | List of coaches/gamers |
| bb3 | `player` | Details on one player |
| bb3 | `matches` | List of played matches |
| bb3 | `match` | Full details on one match |
| bb3 | `contests` | Scheduled / in-progress / played fixtures |
| bb3 | `teammatches` | Matches for one specific team |
| bb3 | `gamecount` | Daily breakdown of games played in a date range |
| bb3 | `gamestats` | Stats on games played in a date range |
| bb3 | `ladder` | Ranked leaderboard, heavily filterable |
| bb3 | `top` | Top teams per faction |
| bb3 | `sprintranking` | "Sprint Ranking" for a competition |
| bb3 | `arenafinalscontenders` | Teams that qualified for playoffs via Arena |
| bb3 | `halloffame` | Hall of Fame (⚠️ BB1/BB2 only, not BB3) |
| bb3 | `rules` | Misc rules reference (e.g. skills list) |
| bb3 | `stats` | Miscellaneous requested statistics |
| bb3 | `rss` | Blood Bowl RSS feed |
| cya | `status` | Service health check |
| cya | `welcome` | Welcome message / news feed |
| pcm | `rss` | Pro Cycling Manager RSS feed |
| pcm | `tournaments` | Pro Cycling Manager tournaments |
| tdf | `liveraceleaderboard` | Live Tour de France race leaderboard |

---

## Blood Bowl 3 endpoints

### Leagues & competitions

#### `leagues`
Lists leagues, optionally filtered by name, ID, recent activity, or minimum number of registered teams/gamers.

| Parameter (use any of) | What it does |
|---|---|
| `platform` / `platform_name` | `pc`, `playstation`, or `xbox` |
| `league` / `league_name` | Filter by league name (default: all leagues) |
| `league` / `league_id` / `id` | Filter by league ID (default: all leagues) |
| `bb` / `opus` | Game version: `1`, `2`, or `3` |
| `limit` / `max` | Cap on number of results |
| `age` / `days` | Only leagues with a match within this many days (default 365; BB2 only) |
| `teams` / `teams_count` / `min_teams_count` | Minimum registered teams (default 1; BB2 only) |
| `gamers_count` | Minimum registered gamers (default 1; BB3 only) |

```
GET https://web.cyanide-studio.com/ws/bb3/leagues/?key=YOUR_KEY&bb=3&limit=20
```

Recent changes: added the BB3-only `gamers_count` filter (Feb 2025); confirmed BB3 compatibility (May 2023); originally launched July 2018, building on an even earlier Dec 2015 listing service.

#### `league`
Returns details for a single league.

| Parameter (use any of) | What it does |
|---|---|
| `platform` / `platform_name` | `pc`, `playstation`, or `xbox` |
| `league` / `league_name` / `name` | League name (default: Official League) |
| `league` / `league_id` / `id` | League ID (default: Official League) |
| `bb` / `opus` | Game version: `1`, `2`, or `3` |

```
GET https://web.cyanide-studio.com/ws/bb3/league/?key=YOUR_KEY&bb=3&league_name=Official League
```

Recent changes: added the `league_id` lookup option (June 2023); confirmed BB3 compatibility (May 2023); this endpoint itself dates to July 2018.

#### `competitions`
Lists the competitions inside a league.

| Parameter (use any of) | What it does |
|---|---|
| `league` / `league_name` | League name (default: Official League) |
| `league` / `league_id` | League ID (default: Official League) |
| `platform` / `platform_name` | `pc`, `playstation`, or `xbox` |
| `bb` / `opus` | Game version: `1`, `2`, or `3` |
| `limit` / `max` | Overall result cap |
| `limit` / `competitions_limit` | Cap specifically on competitions returned |
| `limit` / `leagues_limit` | Cap specifically on leagues returned |
| `exact` | `1` for an exact league-name match, `0` for fuzzy matching |

```
GET https://web.cyanide-studio.com/ws/bb3/competitions/?key=YOUR_KEY&bb=3&league_name=Official League
```

Good to know: competition `format` values differ between games — BB3 uses `Knockout`, `RoundRobin`, `Wissen`, or `Ladder`, while BB2 used `round_robin`, `single_elimination`, `ladder`, or `swiss`. Recent changes: league ID filtering added (June 2023); BB3 compatibility confirmed (May 2023); separate competition/league result caps added (March 2021); endpoint dates back to Dec 2015.

#### `lookup`
A general-purpose search endpoint: find teams, leagues, competitions, or coaches by name or ID in one call.

| Parameter (use any of) | What it does |
|---|---|
| `platform` / `platform_name` | `pc`, `playstation`, or `xbox` |
| `bb` / `opus` | Game version: `1`, `2`, or `3` |
| `league` / `league_name` | League name to search |
| `league` / `league_id` | League ID to search |
| `order` / `sort` | `ID`, `LastMatchDate`, or `CreationDate` |
| `competition` / `competition_name` | Competition name to search |
| `competition` / `competition_id` | Competition ID to search |
| `team` / `team_name` | Team name to search |
| `team` / `team_id` | Team ID to search |
| `coach` / `coach_name` | Coach name to search |
| `coach` / `coach_id` | Coach ID to search |
| `exact` | `1` for exact league-name match, `0` for fuzzy |
| `instruction` / `hint` | Competition lookup hint: `HAS_CONTESTS`, `NOT_LADDER`, or `ONLY_LADDER` |
| `fallback` | `1` to fall back to the default competition if no match is found, `0` to return nothing |

```
GET https://web.cyanide-studio.com/ws/bb3/lookup/?key=YOUR_KEY&bb=3&team_name=YourTeamName
```

Added June 2023 — this is one of the newer endpoints, built specifically to let you resolve names to IDs (or vice versa) without guessing.

### Teams, coaches & players

#### `teams`
Lists teams in a league or competition.

| Parameter (use any of) | What it does |
|---|---|
| `league` / `league_name` | League name (default: Official League) |
| `league` / `league_id` | League ID (default: Official League) |
| `competition` / `competition_name` | Competition name (default: all competitions in the league) |
| `competition` / `competition_id` | Competition ID (default: all competitions in the league) |
| `platform` / `platform_name` | `pc`, `playstation`, or `xbox` |
| `limit` / `max` | Max results (default 100). You can also pass `OFFSET,LIMIT` for pagination |
| `bb` / `opus` | Game version: `1`, `2`, or `3` |
| `sensitive` / `case_sensitive` | Case-sensitive name matching |
| `race` | Include race info — `1` (default) or `0` |
| `logo` | Include team logo — `1` (default) or `0` |
| `last_match` | Include last-match info — `1` (default) or `0` |

```
GET https://web.cyanide-studio.com/ws/bb3/teams/?key=YOUR_KEY&bb=3&league_name=Official League&limit=20
```

Good to know: BB3 races come back as camelCase values like `human`, `dwarf`, `skaven`, `woodElf`, etc. (June 2023). Pagination via `OFFSET,LIMIT` was added July 2023. Rerolls, apothecary, dedicated fans, and cheerleaders fields were added Feb 2024.

#### `team`
Full details for a single team — roster, stats, skills, casualties, and more, each toggleable.

| Parameter (use any of) | What it does |
|---|---|
| `platform` / `platform_name` | `pc`, `playstation`, or `xbox` |
| `team` / `id` | Team ID |
| `team` / `name` | Team name (ignored if an ID is given) |
| `order` / `sort` | `ID`, `LastMatchDate`, or `CreationDate` |
| `bb` / `opus` | Game version: `1`, `2`, or `3` |
| `coach` | Include coach info — `1` (default) or `0` |
| `roster` | Include roster — `1` (default) or `0` |
| `stats` / `statistics` | Include player stats — `0` (default) or `1` |
| `skills` | Include player skills — `1` (default) or `0` |
| `casualties` | Include casualties — `1` (default) or `0` |

```
GET https://web.cyanide-studio.com/ws/bb3/team/?key=YOUR_KEY&bb=3&name=YourTeamName
```

Recent changes: rerolls, apothecary, dedicated fans, and cheerleaders fields added (Feb 2024); cards/coach/roster filters added for BB2 (June 2023); BB3 compatibility confirmed (May 2023); casualty IDs and a `suspended_next_match` field added back in 2018.

#### `coaches`
Lists the coaches (gamers) registered in a league or competition.

| Parameter (use any of) | What it does |
|---|---|
| `league` / `league_name` | League name (default: Official League / Open Ladder) |
| `competition` / `competition_name` | Competition name (default: Official League / Open Ladder) |
| `platform` / `platform_name` | `pc`, `playstation`, or `xbox` |
| `limit` / `max` | Max coach results (default 100) |
| `bb` / `opus` | Game version: `1`, `2`, or `3` |

```
GET https://web.cyanide-studio.com/ws/bb3/coaches/?key=YOUR_KEY&bb=3&league_name=Official League
```

BB3 compatibility confirmed May 2023; the endpoint itself dates to Dec 2015.

#### `player`
Details for a single player, found by ID or name.

| Parameter (use any of) | What it does |
|---|---|
| `platform` / `platform_name` | `pc`, `playstation`, or `xbox` |
| `player` / `id` | Player ID |
| `player` / `name` | Player name (ignored if an ID is given) |
| `bb` / `opus` | Game version: `1`, `2`, or `3` |

```
GET https://web.cyanide-studio.com/ws/bb3/player/?key=YOUR_KEY&bb=3&id=PLAYER_ID
```

A `suspended_next_match` field was added in 2018; BB3 compatibility confirmed May 2023.

### Matches & contests

#### `matches`
Lists matches/games for a league or competition within a date range.

| Parameter (use any of) | What it does |
|---|---|
| `platform` / `platform_name` | `pc`, `playstation`, or `xbox` |
| `league` / `league_name` | League name (default: Official League) |
| `league` / `league_id` | League ID (default: Official League) |
| `competition` / `competition_name` | Competition name (optional) |
| `competition` / `competition_id` | Competition ID (optional) |
| `limit` / `max` | Max results per league (default 100) |
| `start` | Start date (default: 20 days ago) |
| `end` | End date (default: today) |
| `bb` / `opus` | Game version: `1`, `2`, or `3` |
| `order` / `ordering` | `started` or `finished` |
| `id_only` | Return only IDs — `0` or `1` |
| `team_id` / `team` | Filter to one team |
| `team_stats` / `stats` | Include team statistics (default: on) |

```
GET https://web.cyanide-studio.com/ws/bb3/matches/?key=YOUR_KEY&bb=3&league_name=Official League&start=2026-06-01&end=2026-06-17
```

Recent changes: a fix for away-team KO/injury stats (July 2023); an opt-out flag for team stats (June 2023); BB3 compatibility confirmed (May 2023).

#### `match`
Full details for a single match, including rosters, by its UUID.

| Parameter (use any of) | What it does |
|---|---|
| `platform` / `platform_name` | `pc`, `playstation`, or `xbox` |
| `match_id` / `uuid` / `id` | Match UUID |
| `bb` / `opus` | Game version: `1`, `2`, or `3` |
| `rosters` | Include rosters — `1` (default) or `0` |

```
GET https://web.cyanide-studio.com/ws/bb3/match/?key=YOUR_KEY&bb=3&uuid=MATCH_UUID
```

The platform can actually be auto-detected from the match UUID itself (added 2017). Player-stat aggregation was fixed for single-stat cases in Oct 2024; BB3 compatibility confirmed May 2023.

#### `contests`
Scheduled, in-progress, played, or validated fixtures — basically your match schedule, as opposed to `matches`, which covers completed games.

| Parameter (use any of) | What it does |
|---|---|
| `league` / `league_name` | League name (default: Official League) |
| `league` / `league_id` | League ID (default: Official League) |
| `competition` / `competition_name` | Competition name (default: all competitions) |
| `competition` / `competition_id` | Competition ID (optional) |
| `status` / `contest_status` | `Scheduled`, `InProgress`, `Played`, or `Validated` (default: Scheduled) |
| `round` | Round number |
| `platform` / `platform_name` | `pc`, `playstation`, or `xbox` |
| `bb` / `opus` | Game version: `1`, `2`, or `3` |
| `limit` / `max` | Result cap |
| `exact` | `1` for exact league-name match, `0` for fuzzy |

```
GET https://web.cyanide-studio.com/ws/bb3/contests/?key=YOUR_KEY&bb=3&league_name=Official League&status=Scheduled
```

⚠️ **Heads up on upcoming changes:** the older `upcoming_matches` key is deprecated — use `contests` instead. Cyanide has also flagged that the plain `round`, `status`, and `format` keys will eventually be retired in favor of `contest_round`/`competition_round` and `contest_status`/`competition_format`, so it's worth migrating to those names sooner rather than later. The `Played`/`Validated` status split (rather than just one "finished" state) was introduced in Feb 2024.

#### `teammatches`
Matches/games for one specific team.

| Parameter (use any of) | What it does |
|---|---|
| `platform` / `platform_name` | `pc`, `playstation`, or `xbox` |
| `limit` | Max results per league (default 100) |
| `start` | Start date (default: 1 hour ago) |
| `end` | End date (default: today) |
| `bb` / `opus` | Game version: `1`, `2`, or `3` |
| `order` / `ordering` | `started` or `finished` |
| `team_id` / `team` | Team ID |

```
GET https://web.cyanide-studio.com/ws/bb3/teammatches/?key=YOUR_KEY&bb=3&team_id=TEAM_ID
```

BB3 compatibility confirmed May 2023; the endpoint itself dates to Dec 2015.

#### `gamecount`
A day-by-day breakdown of how many games were played in a date range.

| Parameter | What it does |
|---|---|
| `start` | Start date, `YYYY-MM-DD` (default: 7 days ago) |
| `end` | End date, `YYYY-MM-DD` (default: today) |

```
GET https://web.cyanide-studio.com/ws/bb3/gamecount/?key=YOUR_KEY&start=2026-06-01&end=2026-06-17
```

Added July 2025 — one of the newest endpoints in the catalog.

#### `gamestats`
Statistics on games played in a date range, optionally scoped to one competition.

| Parameter (use any of) | What it does |
|---|---|
| `competitionId` / `uuid` | Competition ID |
| `start` | Start date, `YYYY-MM-DD` (default: yesterday) |
| `end` | End date, `YYYY-MM-DD` (default: tomorrow) |

```
GET https://web.cyanide-studio.com/ws/bb3/gamestats/?key=YOUR_KEY&start=2026-06-10&end=2026-06-17
```

Also added July 2025, alongside `gamecount`.

### Rankings & leaderboards

#### `ladder`
The ranked ladder/leaderboard for a league or competition, with an extensive set of filters.

| Parameter (use any of) | What it does |
|---|---|
| `bb` / `opus` | Game version: `1`, `2`, or `3` |
| `platform` / `platform_name` | `pc`, `playstation`, or `xbox` |
| `league` / `league_name` | League name (default: Official League) |
| `league` / `league_id` | League ID (default: Official League) |
| `competition` / `competition_name` | Competition name (default: Open Ladder) |
| `competition` / `competition_id` | Competition ID (default: Open Ladder) |
| `ladder_size` / `size` / `limit` | Number of ladder entries to return |
| `tv_min` / `tvmin` | Minimum team value |
| `tv_max` / `tvmax` | Maximum team value |
| `concede_min` / `concedemin` | Minimum concede rate (%) |
| `concede_max` / `concedemax` | Maximum concede rate (%) |
| `match_min` / `matchmin` | Minimum number of matches played |
| `match_max` / `matchmax` | Maximum number of matches played |
| `winrate_min` / `winratemin` | Minimum win rate (%) |
| `winrate_max` / `winratemax` | Maximum win rate (%) |
| `lossrate_min` / `lossratemin` | Minimum loss rate (%) |
| `lossrate_max` / `lossratemax` | Maximum loss rate (%) |
| `drawrate_min` / `drawratemin` | Minimum draw rate (%) |
| `drawrate_max` / `drawratemax` | Maximum draw rate (%) |

```
GET https://web.cyanide-studio.com/ws/bb3/ladder/?key=YOUR_KEY&bb=3&league_name=Official League&ladder_size=50
```

Recent changes: BB3-specific filter parameters added Aug 2024; win/draw/loss info added back in 2017; this is one of the older endpoints, dating to Dec 2015.

#### `top`
For each faction/race, lists the top teams in a league or competition.

| Parameter (use any of) | What it does |
|---|---|
| `bb` / `opus` | Game version: `1`, `2`, or `3` |
| `platform` / `platform_name` | `pc`, `playstation`, or `xbox` |
| `league` / `league_name` | League name (default: Official League) |
| `league` / `league_id` | League ID (default: Official League) |
| `competition` / `competition_name` | Competition name (default: Open Ladder) |
| `competition` / `competition_id` | Competition ID (default: Open Ladder) |
| `top` / `top_size` / `size` / `limit` | How many teams to return per faction |

```
GET https://web.cyanide-studio.com/ws/bb3/top/?key=YOUR_KEY&bb=3&league_name=Official League&top_size=5
```

BB3-only, added September 2023.

#### `sprintranking`
A specialized "Sprint Ranking" for a competition.

| Parameter | What it does |
|---|---|
| `competition_id` | Competition ID |
| `competition_name` | Competition name |
| `match_threshold` | Minimum matches required to qualify (currently fixed at `20`) |

```
GET https://web.cyanide-studio.com/ws/bb3/sprintranking/?key=YOUR_KEY&competition_name=YourCompetition
```

Brand new — created December 2024.

#### `arenafinalscontenders`
Teams that qualified for the playoffs through the Arena qualifier, for a given season.

| Parameter | What it does |
|---|---|
| `season` | `0` for the most recent season, or a specific season number (`7`, `8`, `9`, ...) |

```
GET https://web.cyanide-studio.com/ws/bb3/arenafinalscontenders/?key=YOUR_KEY&season=0
```

Brand new — created July 2025.

#### `halloffame`
⚠️ **Not compatible with Blood Bowl 3.** This endpoint only works for Opus 1 and 2.

| Parameter (use any of) | What it does |
|---|---|
| `bb` / `opus` | Game version: `1` or `2` |
| `platform` / `platform_name` | `pc`, `playstation`, or `xbox` |
| `competition` / `competition_name` | Competition name (default: all competitions in the league) |
| `league` / `league_name` | League name (default: Official League) |
| `limit` / `max` | Max results (default 100) |
| `exact` | `1` for exact league-name match, `0` for fuzzy |

```
GET https://web.cyanide-studio.com/ws/bb2/halloffame/?key=YOUR_KEY&opus=2&league_name=Official League
```

Cyanide explicitly confirmed (May 2023) this one was left behind when BB3 support was added elsewhere, so don't expect BB3 data from it.

### Rules & misc stats

#### `rules`
Reference info for miscellaneous BB3 rules, such as the current skills list.

| Parameter (use any of) | What it does |
|---|---|
| `platform` / `platform_name` | `pc`, `playstation`, or `xbox` |
| `bb` / `opus` | `3` (BB3-only endpoint) |
| `rule` / `rules` / `ruleset` | Ruleset name, e.g. `skills` |

```
GET https://web.cyanide-studio.com/ws/bb3/rules/?key=YOUR_KEY&bb=3&ruleset=skills
```

BB3-only, added November 2023.

#### `stats`
Miscellaneous statistics, picked by name.

| Parameter (use any of) | What it does |
|---|---|
| `stats` / `stat` | Comma-separated list of the stats you want |
| `bb` / `opus` | Game version: `1`, `2`, or `3` |

```
GET https://web.cyanide-studio.com/ws/bb3/stats/?key=YOUR_KEY&bb=3&stat=YOUR_STAT_NAME
```

The original documentation doesn't enumerate which stat names are valid — you'll likely need to experiment or contact Cyanide for the current list. BB3 compatibility confirmed May 2023; the endpoint dates back to Dec 2015.

### Feed

#### `rss`
The Blood Bowl RSS feed. No parameters.

```
GET https://web.cyanide-studio.com/ws/bb3/rss/?key=YOUR_KEY
```

---

## Other Cyanide games on this same API

### Cyanide platform (`cya`)

#### `status`
A simple health check for the service. No parameters.

```
GET https://web.cyanide-studio.com/ws/cya/status/?key=YOUR_KEY
```

#### `welcome`
Returns a welcome message / news feed.

| Parameter (use any of) | What it does |
|---|---|
| `env` | Environment |
| `lang` / `language` | Language |
| `platform` | Platform |
| `region` | Region |
| `accept_promo` / `promo` | Whether to include promotional content |
| `limit` | Max number of news items returned |

```
GET https://web.cyanide-studio.com/ws/cya/welcome/?key=YOUR_KEY&lang=en
```

### Pro Cycling Manager (`pcm`)

#### `rss`
The Pro Cycling Manager RSS feed. No parameters.

```
GET https://web.cyanide-studio.com/ws/pcm/rss/?key=YOUR_KEY
```

#### `tournaments`
List of Pro Cycling Manager tournaments. No parameters.

```
GET https://web.cyanide-studio.com/ws/pcm/tournaments/?key=YOUR_KEY
```

### Tour de France (`tdf`)

#### `liveraceleaderboard`
The live leaderboard for a Tour de France race.

| Parameter (use any of) | What it does |
|---|---|
| `opus` / `year` / `yy` / `y` | Tour de France year |
| `leaderboard` | `LATEST`, a specific `YYYY-MM-DD HH:MM:SS` timestamp, or a race name |
| `downhill` / `descent` | `1` for the downhill/descent leaderboard instead of the main one |
| `lang` / `language` | Language filter |

```
GET https://web.cyanide-studio.com/ws/tdf/liveraceleaderboard/?key=YOUR_KEY&year=2026&leaderboard=LATEST
```

This one's actively maintained — the underlying database table for the 2026 race was updated as recently as June 12, 2026, with `leaderboard_time` added and `score` renamed to `leaderboard_record` earlier this year.

---

## Gotchas worth remembering

- **Forgetting `bb=3`** is the easiest way to get confused by unexpected (legacy) data — add it to every Blood Bowl request.
- **`halloffame` doesn't support BB3** — it only works against Opus 1/2 data.
- **`upcoming_matches` is dead** — use `contests` with `status=Scheduled` instead.
- **`round`, `status`, and `format` are on their way out** for the `contests` endpoint — switch to `contest_round`/`competition_round` and `contest_status`/`competition_format` now to avoid a future breakage.
- **Parameter names with a `|` are interchangeable aliases**, not a menu of different behaviors — pick whichever reads best in your code.
