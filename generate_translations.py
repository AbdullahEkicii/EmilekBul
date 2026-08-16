import json
import os
import urllib.request
import urllib.parse
import time
from concurrent.futures import ThreadPoolExecutor

LANGUAGES = {
    'de': 'German',
    'it': 'Italian',
    'pt': 'Portuguese',
    'ja': 'Japanese',
    'ko': 'Korean',
    'zh': 'Chinese (Simplified)',
    'hi': 'Hindi',
    'id': 'Indonesian',
    'nl': 'Dutch',
    'pl': 'Polish',
    'sv': 'Swedish',
    'uk': 'Ukrainian',
    'vi': 'Vietnamese',
    'th': 'Thai',
    'cs': 'Czech',
    'el': 'Greek',
    'ro': 'Romanian',
    'hu': 'Hungarian',
    'da': 'Danish',
    'fi': 'Finnish',
    'tr': 'Turkish',
    'ru': 'Russian',
    'ar': 'Arabic',
    'es': 'Spanish',
    'fr': 'French',
}

TRANSLATIONS_DIR = r'c:\flutterprojects\emilekbul\assets\translations'
EN_PATH = os.path.join(TRANSLATIONS_DIR, 'en.json')

with open(EN_PATH, 'r', encoding='utf-8') as f:
    en_data = json.load(f)

def extract_keys(obj, prefix=''):
    keys = {}
    for k, v in obj.items():
        curr_key = f"{prefix}.{k}" if prefix else k
        if isinstance(v, dict):
            keys.update(extract_keys(v, curr_key))
        elif isinstance(v, str):
            keys[curr_key] = v
    return keys

en_keys = extract_keys(en_data)

def translate_single(item):
    key, text, target_lang = item
    if not text.strip():
        return key, text
    url = f"https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl={target_lang}&dt=t&q={urllib.parse.quote(text)}"
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'})
    try:
        with urllib.request.urlopen(req, timeout=8) as response:
            res = json.loads(response.read().decode('utf-8'))
            translated = "".join([part[0] for part in res[0] if part and len(part) > 0 and part[0]])
            return key, translated if translated else text
    except Exception:
        return key, text

def set_nested(obj, key_path, value):
    parts = key_path.split('.')
    curr = obj
    for p in parts[:-1]:
        if p not in curr or not isinstance(curr[p], dict):
            curr[p] = {}
        curr = curr[p]
    curr[parts[-1]] = value

def process_language(lang_code, lang_name):
    lang_file = os.path.join(TRANSLATIONS_DIR, f"{lang_code}.json")
    existing_data = {}
    if os.path.exists(lang_file):
        try:
            with open(lang_file, 'r', encoding='utf-8') as f:
                existing_data = json.load(f)
        except Exception:
            existing_data = {}

    existing_keys = extract_keys(existing_data)
    missing_items = []
    
    # Exceptions that are identical in English and others (brand names, symbols, etc.)
    allowed_identical = {'emilekbul', 'ai', 'vs', 'ok', 'xp', 'token', 'tokens', '1v1', '1v1 ⚡', '1v1 🏎️', '2x', '3x', '5x', '10x'}

    for k, en_val in en_keys.items():
        curr_val = existing_keys.get(k)
        need_translation = False
        if not curr_val or not curr_val.strip():
            need_translation = True
        elif lang_code not in ('en', 'tr') and curr_val.strip() == en_val.strip() and en_val.strip().lower() not in allowed_identical:
            # If the text has English words (>3 chars) and is identical to English, it was untranslated English
            if any(len(word) >= 3 for word in en_val.split()):
                need_translation = True

        if need_translation:
            missing_items.append((k, en_val, lang_code))

    print(f"[{lang_code}] Translating {len(missing_items)} missing/English keys with 12 threads...", flush=True)

    translated_map = {}
    if missing_items:
        with ThreadPoolExecutor(max_workers=12) as executor:
            results = list(executor.map(translate_single, missing_items))
            for k, val in results:
                translated_map[k] = val

    final_output = {}
    for k, en_val in en_keys.items():
        if k in translated_map:
            val = translated_map[k]
        elif k in existing_keys and existing_keys[k]:
            val = existing_keys[k]
        else:
            val = en_val
        set_nested(final_output, k, val)

    with open(lang_file, 'w', encoding='utf-8') as f:
        json.dump(final_output, f, ensure_ascii=False, indent=2)

    print(f"[{lang_code}] Successfully written {lang_file}", flush=True)

for lang_code, lang_name in LANGUAGES.items():
    process_language(lang_code, lang_name)

print("ALL_TRANSLATIONS_COMPLETED_SUCCESSFULLY", flush=True)
