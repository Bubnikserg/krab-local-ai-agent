# -*- coding: utf-8 -*-
r"""
update_model_descriptions.py — обновление описаний моделей Selectel AI Router
в файле model_descriptions.json для окна «Описание модели» в веб-интерфейсе.

Каталог /aig/v1/models (OpenAI-совместимый) не отдаёт описания, поэтому они
хранятся локально в model_descriptions.json и подмешиваются бэкендом в /api/models.

Структура model_descriptions.json:
  updated  — дата последнего обновления (заполняется этим скриптом)
  source   — источник скачанных описаний
  selectel — полные описания из каталога Selectel (ключи: id модели и её алиасы)
  exact    — ручные заметки по конкретным id (приоритет ниже selectel)
  prefix   — описания семейств по префиксу id (запасной вариант)

Режимы запуска (описания можно обновлять любым из двух):

1. Скачать прямо из API панели (нужен сессионный токен my.selectel.ru):
     python update_model_descriptions.py --token gAAAAA...
   Токен: F12 на странице моделей → Network → любой запрос к
   api.selectel.ru/aig/gateway/v1/models → заголовок x-auth-token.
   Если --token не указан, скрипт спросит его интерактивно.

2. Импорт из скачанного JSON (массив моделей, как в ответе
   api.selectel.ru/aig/gateway/v1/models):
     python update_model_descriptions.py --file путь\к\models.json
"""

import argparse
import json
import os
import sys
import urllib.parse
import urllib.request
from datetime import datetime
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
DESCRIPTIONS_FILE = BASE_DIR / "model_descriptions.json"
GATEWAY_URL = "https://api.selectel.ru/aig/gateway/v1/models"
PAGE_LIMIT = 100


def _http_get_json(url, token):
    req = urllib.request.Request(url, headers={
        "accept": "application/json",
        "origin": "https://my.selectel.ru",
        "referer": "https://my.selectel.ru/",
        "user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
        "x-auth-token": token,
    })
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.loads(resp.read().decode("utf-8"))


def fetch_from_api(token):
    """Все модели каталога постранично (has_more/total как в API панели)."""
    models, page = [], 1
    while True:
        q = urllib.parse.urlencode({"q": "", "vendor": "", "page": page, "limit": PAGE_LIMIT})
        obj = _http_get_json(GATEWAY_URL + "?" + q, token)
        batch = obj.get("data") or []
        models.extend(batch)
        print("страница %d: +%d (всего собрано %d из %s)" % (page, len(batch), len(models), obj.get("total")))
        if not obj.get("has_more") or not batch:
            break
        page += 1
    return models


def build_selectel_section(models):
    """Словарь {id/алиас: описание} — ключи дублируются по алиасам, чтобы
    описание находилось и по короткому имени модели."""
    section, seen = {}, 0
    for m in models:
        desc = (m.get("description") or "").strip()
        if not desc:
            continue
        for key in [m.get("id")] + list(m.get("aliases") or []):
            key = (key or "").strip()
            if key and key not in section:
                section[key] = desc
                seen += 1
    return section, seen


def load_existing():
    if not DESCRIPTIONS_FILE.exists():
        return {}
    try:
        data = json.loads(DESCRIPTIONS_FILE.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {}
    except Exception as e:
        print("ПРЕДУПРЕЖДЕНИЕ: %s не прочитан (%s), ручные разделы будут потеряны" % (DESCRIPTIONS_FILE.name, e))
        return {}


def save_descriptions(models, source):
    """Пересобирает JSON: сохраняет ручные exact/prefix, заменяет selectel."""
    old = load_existing()
    section, count = build_selectel_section(models)
    data = {
        "updated": datetime.now().isoformat(timespec="seconds"),
        "source": source,
        "selectel": section,
        "exact": old.get("exact", {}),
        "prefix": old.get("prefix", {}),
    }
    tmp = DESCRIPTIONS_FILE.with_suffix(".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
        f.write("\n")
    os.replace(tmp, DESCRIPTIONS_FILE)
    return count


def main():
    parser = argparse.ArgumentParser(description="Обновление описаний моделей в model_descriptions.json")
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--token", help="сессионный токен x-auth-token с my.selectel.ru")
    group.add_argument("--file", help="импорт из скачанного JSON (массив моделей)")
    args = parser.parse_args()

    try:
        if args.file:
            path = Path(args.file.strip().strip('"'))
            models = json.loads(path.read_text(encoding="utf-8-sig"))
            if isinstance(models, dict) and isinstance(models.get("data"), list):
                models = models["data"]  # на случай сохранённого ответа API целиком
            if not isinstance(models, list):
                raise SystemExit("Ошибка: в файле не массив моделей и не ответ API.")
            source = "файл %s" % path.name
        else:
            token = args.token or os.getenv("SELECTEL_SESSION_TOKEN", "").strip()
            if not token:
                token = input("Вставьте сессионный токен (x-auth-token из F12 на my.selectel.ru): ").strip()
            if not token:
                raise SystemExit("Ошибка: токен не указан.")
            models = fetch_from_api(token)
            source = GATEWAY_URL
        if not models:
            raise SystemExit("Ошибка: не получено ни одной модели — данные не изменены.")

        count = save_descriptions(models, source)
        total = sum(1 for m in models if (m.get("description") or "").strip())
        print("Готово: %s обновлён — %d моделей, %d описаний (%d ключей id/алиасов)." % (
            DESCRIPTIONS_FILE.name, len(models), total, count))
        print("Перезапускать сервер не обязательно: описание подхватится при следующем запросе /api/models.")
    except SystemExit:
        raise
    except Exception as e:
        raise SystemExit("Ошибка: %s" % e)


if __name__ == "__main__":
    main()
