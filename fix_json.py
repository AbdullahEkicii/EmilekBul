import json
import os

translations = {
    'tr': 'Gün {}',
    'en': 'Day {}',
    'es': 'Día {}',
    'fr': 'Jour {}',
    'ru': 'День {}',
    'ar': 'اليوم {}'
}

base = 'assets/translations'
for f in os.listdir(base):
    if f.endswith('.json'):
        lang = f.split('.')[0]
        filepath = os.path.join(base, f)
        with open(filepath, 'r', encoding='utf-8') as file:
            data = json.load(file)
            
        if 'daily_streak' not in data:
            data['daily_streak'] = {}
            
        if lang in translations:
            data['daily_streak']['day_num'] = translations[lang]
            
        with open(filepath, 'w', encoding='utf-8') as file:
            json.dump(data, file, ensure_ascii=False, indent=2)

print('Translations written with correct encoding.')
