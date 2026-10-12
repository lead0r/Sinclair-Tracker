#!/usr/bin/env python3
"""Build the bundled John Sinclair audio-drama catalogue.

Wikipedia supplies stable episode tables; the official John Sinclair pages add
synopses, covers and canonical product links. Run this script whenever a new
episode is released, then commit the generated JSON with the app.
"""

from __future__ import annotations

import json
import re
import unicodedata
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path

from bs4 import BeautifulSoup


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "data" / "john_sinclair_episodes.json"
USER_AGENT = "SinclairTracker/1.0 (private, non-commercial catalogue builder)"

WIKI_LUEBBE = (
    "https://de.wikipedia.org/wiki/Geisterj%C3%A4ger_John_Sinclair_"
    "(H%C3%B6rspielserie_von_L%C3%BCbbe-Audio)"
)
WIKI_BRAUN = (
    "https://de.wikipedia.org/wiki/Geisterj%C3%A4ger_John_Sinclair_"
    "(H%C3%B6rspielserie_von_Tonstudio_Braun)"
)

OFFICIAL_SERIES = {
    "edition2000": "https://www.john-sinclair.de/serie/geisterjaeger-john-sinclair/2189646",
    "classics": "https://www.john-sinclair.de/serie/geisterjaeger-john-sinclair-classics/2189562",
    "specials": "https://www.john-sinclair.de/serie/john-sinclair-hoerspiel-sonderedition/2746036",
    "tonstudio_braun": "https://www.john-sinclair.de/serie/john-sinclair-tonstudio-braun/2476668",
    "dead_zone": "https://www.john-sinclair.de/serie/sinclair-staffel-01-dead-zone/2781722",
    "underworld": "https://www.john-sinclair.de/serie/sinclair-staffel-2-underworld/3622433",
}

SERIES_NAMES = {
    "edition2000": "Edition 2000",
    "classics": "Sinclair Classics",
    "specials": "Sondereditionen",
    "tonstudio_braun": "Tonstudio Braun",
    "sinclair_reboot": "SINCLAIR",
}

GERMAN_MONTHS = {
    "januar": 1,
    "februar": 2,
    "märz": 3,
    "april": 4,
    "mai": 5,
    "juni": 6,
    "juli": 7,
    "august": 8,
    "september": 9,
    "oktober": 10,
    "november": 11,
    "dezember": 12,
}


def fetch(url: str) -> BeautifulSoup:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=45) as response:
        return BeautifulSoup(response.read(), "html.parser")


def clean(value: str) -> str:
    return " ".join(value.replace("\xa0", " ").split())


def normalize(value: str) -> str:
    value = unicodedata.normalize("NFKD", value.lower())
    value = "".join(char for char in value if not unicodedata.combining(char))
    return re.sub(r"[^a-z0-9]+", "", value)


def iso_date(value: str) -> str | None:
    value = clean(value)
    if not value:
        return None
    match = re.search(r"(\d{1,2})\.(\d{1,2})\.(\d{4})", value)
    if match:
        day, month, year = map(int, match.groups())
        return f"{year:04d}-{month:02d}-{day:02d}"
    match = re.search(r"(\d{1,2})\.\s*([A-Za-zÄÖÜäöüß]+)\s+(\d{4})", value)
    if match:
        day = int(match.group(1))
        month = GERMAN_MONTHS.get(match.group(2).lower())
        if month:
            return f"{int(match.group(3)):04d}-{month:02d}-{day:02d}"
    return None


def cells(row) -> list[str]:
    return [clean(cell.get_text(" ", strip=True)) for cell in row.select("th,td")]


def episode(
    series: str,
    number: int,
    display_number: str,
    title: str,
    *,
    director: str = "",
    script: str = "",
    release_date: str | None = None,
    season: int | None = None,
    season_number: int | None = None,
) -> dict:
    suffix = re.sub(r"[^a-z0-9]+", "-", display_number.lower()).strip("-")
    item = {
        "id": f"{series}_{suffix or number}",
        "series": series,
        "number": number,
        "displayNumber": display_number,
        "title": title,
        "author": "Jason Dark",
        "description": "",
        "director": director,
        "script": script,
        "releaseDate": release_date,
        "coverUrl": None,
        "template": f"{SERIES_NAMES[series]} · Folge {display_number}",
        "links": {},
    }
    if season is not None:
        item["season"] = season
        item["seasonNumber"] = season_number
        item["template"] = f"SINCLAIR · Staffel {season} · Folge {season_number}"
    return item


def parse_luebbe_tables() -> list[dict]:
    soup = fetch(WIKI_LUEBBE)
    tables = soup.select("table.wikitable")
    result: list[dict] = []

    for row in tables[0].select("tr")[1:]:
        values = cells(row)
        if len(values) >= 5 and values[0].isdigit():
            number = int(values[0])
            result.append(episode(
                "edition2000", number, values[0], values[1],
                director=values[2], script=values[3], release_date=iso_date(values[4]),
            ))

    special_number = 0
    for row in tables[1].select("tr")[1:]:
        values = cells(row)
        if len(values) >= 5 and values[0]:
            special_number += 1
            result.append(episode(
                "specials", special_number, values[0], values[1],
                director=values[2], script=values[3], release_date=iso_date(values[4]),
            ))
    result.append(episode(
        "specials", special_number + 1, "2000", "Das Höllenkreuz",
        director="Dennis Ehrhardt", script="Dennis Ehrhardt", release_date="2016-11-11",
    ))

    for row in tables[2].select("tr")[1:]:
        values = cells(row)
        if len(values) >= 5 and values[0].isdigit():
            number = int(values[0])
            result.append(episode(
                "classics", number, values[0], values[1],
                director=values[2], script=values[3], release_date=iso_date(values[4]),
            ))

    for row in tables[9].select("tr")[1:]:
        values = cells(row)
        if len(values) < 4 or not values[0].isdigit():
            continue
        overall = int(values[0])
        season = 1 if overall <= 6 else 2
        season_number = int(values[1])
        result.append(episode(
            "sinclair_reboot", overall, values[0], values[2],
            release_date=iso_date(values[3]), season=season,
            season_number=season_number,
        ))
    return result


def parse_braun_table() -> list[dict]:
    soup = fetch(WIKI_BRAUN)
    result: list[dict] = []
    for row in soup.select("table.wikitable")[1].select("tr")[1:]:
        values = cells(row)
        if len(values) < 3 or not values[1].isdigit():
            continue
        official_number = int(values[1])
        if official_number > 108:
            continue
        result.append(episode(
            "tonstudio_braun", official_number, values[1], values[2],
            director="Erwin Scherschel" if official_number < 108 else "Michael Braun",
        ))
    return sorted(result, key=lambda item: item["number"])


def parse_official_series(url: str) -> list[dict]:
    products: list[dict] = []
    seen_pages: set[str] = set()
    next_url: str | None = url
    while next_url and next_url not in seen_pages:
        seen_pages.add(next_url)
        soup = fetch(next_url)
        for article in soup.select("article.list-item"):
            title_node = article.select_one(".text-header__subline")
            heading = article.select_one(".headline")
            if title_node is None and heading is None:
                continue
            heading_text = clean(heading.get_text(" ", strip=True)) if heading else ""
            subline_text = clean(title_node.get_text(" ", strip=True)) if title_node else ""
            if "sonderedition" in normalize(subline_text) or not subline_text:
                title = re.sub(r"^John Sinclair\s*[-–]\s*", "", heading_text, flags=re.I)
            elif heading_text.endswith("Oculus") or heading_text.endswith("Deadwood"):
                base = re.sub(r"^John Sinclair\s*[-–]\s*", "", heading_text, flags=re.I)
                title = f"{base} – {subline_text}"
            else:
                title = subline_text
            number_node = article.select_one(".product-number__count")
            number = clean(number_node.get_text(" ", strip=True)) if number_node else ""
            description_node = article.select_one(".product-result__details .paragraph")
            link_node = article.select_one("a.link[href]") or article.select_one("a[href]")
            image_node = article.select_one("img.product__cover")
            link = urllib.parse.urljoin(url, link_node.get("href")) if link_node else None
            cover = urllib.parse.urljoin(url, image_node.get("src")) if image_node else None
            if cover:
                cover = cover.replace("/site/thumbnails/225/", "/site/thumbnails/736/")
            products.append({
                "number": number,
                "title": title,
                "description": clean(description_node.get_text(" ", strip=True)) if description_node else "",
                "official": link,
                "cover": cover,
            })
        more = soup.select_one("a.pagination-control__more[href]")
        next_url = urllib.parse.urljoin(url, more.get("href")) if more else None
    return products


def provider_links(item: dict) -> dict[str, str]:
    query = urllib.parse.quote_plus(f"John Sinclair {item['displayNumber']} {item['title']}")
    return {
        "spotify": f"https://open.spotify.com/search/{query}",
        "appleMusic": f"https://music.apple.com/de/search?term={query}",
        "amazonMusic": f"https://music.amazon.de/search/{query}",
        "audible": f"https://www.audible.de/search?keywords={query}",
        "youtubeMusic": f"https://music.youtube.com/search?q={query}",
    }


def enrich(episodes: list[dict]) -> int:
    with ThreadPoolExecutor(max_workers=len(OFFICIAL_SERIES)) as executor:
        official = dict(zip(
            OFFICIAL_SERIES,
            executor.map(parse_official_series, OFFICIAL_SERIES.values()),
        ))
    matched = 0
    for item in episodes:
        if item["series"] == "sinclair_reboot":
            candidates = official["dead_zone" if item.get("season") == 1 else "underworld"]
        else:
            candidates = official[item["series"]]
        match = next(
            (candidate for candidate in candidates if normalize(candidate["title"]) == normalize(item["title"])),
            None,
        )
        if match is None and item["series"] != "sinclair_reboot":
            match = next(
                (candidate for candidate in candidates
                 if candidate["number"].lstrip("0") == item["displayNumber"].lstrip("0")),
                None,
            )
        item["links"] = provider_links(item)
        if match:
            matched += 1
            item["description"] = match["description"]
            item["coverUrl"] = match["cover"]
            if match["official"]:
                item["links"] = {"official": match["official"], **item["links"]}
    return matched


def validate(episodes: list[dict]) -> None:
    expected = {
        "edition2000": 196,
        "classics": 50,
        "specials": 21,
        "tonstudio_braun": 108,
        "sinclair_reboot": 15,
    }
    counts = {key: 0 for key in expected}
    for item in episodes:
        counts[item["series"]] += 1
    assert counts == expected, f"Unexpected series counts: {counts}"
    ids = [item["id"] for item in episodes]
    assert len(ids) == len(set(ids)), "Episode IDs are not unique"
    assert len(episodes) == 390


def main() -> None:
    episodes = parse_luebbe_tables() + parse_braun_table()
    episodes.sort(key=lambda item: (list(SERIES_NAMES).index(item["series"]), item["number"]))
    validate(episodes)
    matched = enrich(episodes)
    payload = {
        "generatedAt": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "sources": [WIKI_LUEBBE, WIKI_BRAUN, *OFFICIAL_SERIES.values()],
        "episodes": episodes,
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(episodes)} episodes; {matched} official matches; {OUTPUT}")


if __name__ == "__main__":
    main()
