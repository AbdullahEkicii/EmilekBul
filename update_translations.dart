// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

void main() async {
  final translations = {
    'tr': {
      'special_quiz_of_day': 'Günün Özel Yarışması',
      'double_points_badge': '2X PUAN',
      'hard_mode_extra_token': 'Zor Mod • Ekstra Token Ödüllü',
      'lucky_wheel': 'Şans Çarkı',
      'wheel_won': 'Tebrikler! Ödülünüz hesabınıza eklendi.',
      'wheel_spin_prompt': 'Çarkı çevir, harika token ödüllerinden birini kazan!',
      'wheel_spun_today': 'Bugün çarkı çevirdiniz. Yarın tekrar gelin!',
      'streak_claimed': 'Harika! Ödül Alındı!',
      'streak_title': 'Günlük Giriş Serisi',
      'streak_reward_added': '+{tokens} Token hesabına eklendi!',
      'streak_prompt': '{streak} Günlük Seri! Her gün gel, daha çok kazan!',
      'claim_reward': 'Ödülü Al',
      'wheel_you_won': 'Kazandın:',
      'wheel_awesome': 'Harika!',
      'wheel_spin_button': 'Çarkı Çevir 🔥',
      'wheel_done_today': 'Bugünlük Bitti',
      'streak_claim_today': 'Bugünün Ödülünü Al 🎉',
      'streak_ok': 'Tamam'
    },
    'en': {
      'special_quiz_of_day': 'Special Quiz of the Day',
      'double_points_badge': '2X POINTS',
      'hard_mode_extra_token': 'Hard Mode • Extra Token Reward',
      'lucky_wheel': 'Lucky Wheel',
      'wheel_won': 'Congratulations! Your reward has been added to your account.',
      'wheel_spin_prompt': 'Spin the wheel and win great token rewards!',
      'wheel_spun_today': 'You spun the wheel today. Come back tomorrow!',
      'streak_claimed': 'Great! Reward Claimed!',
      'streak_title': 'Daily Login Streak',
      'streak_reward_added': '+{tokens} Tokens added to your account!',
      'streak_prompt': '{streak} Day Streak! Come every day, win more!',
      'claim_reward': 'Claim Reward',
      'wheel_you_won': 'You won:',
      'wheel_awesome': 'Awesome!',
      'wheel_spin_button': 'Spin Wheel 🔥',
      'wheel_done_today': 'Done for Today',
      'streak_claim_today': 'Claim Today\'s Reward 🎉',
      'streak_ok': 'OK'
    },
    'es': {
      'special_quiz_of_day': 'Cuestionario Especial del Día',
      'double_points_badge': 'PUNTOS 2X',
      'hard_mode_extra_token': 'Modo Difícil • Recompensa Extra de Fichas',
      'lucky_wheel': 'Rueda de la Suerte',
      'wheel_won': '¡Felicidades! Tu recompensa ha sido añadida a tu cuenta.',
      'wheel_spin_prompt:': '¡Gira la rueda y gana grandes recompensas de fichas!',
      'wheel_spun_today': 'Hoy ya giraste la rueda. ¡Vuelve mañana!',
      'streak_claimed': '¡Genial! ¡Recompensa Reclamada!',
      'streak_title': 'Racha de Inicio de Sesión Diaria',
      'streak_reward_added': '¡+{tokens} Fichas añadidas a tu cuenta!',
      'streak_prompt': '¡Racha de {streak} Días! ¡Ven todos los días, gana más!',
      'claim_reward': 'Reclamar Recompensa',
      'wheel_you_won': 'Has ganado:',
      'wheel_awesome': '¡Genial!',
      'wheel_spin_button': 'Girar Rueda 🔥',
      'wheel_done_today': 'Hecho por Hoy',
      'streak_claim_today': 'Reclamar Recompensa de Hoy 🎉',
      'streak_ok': 'OK'
    },
    'fr': {
      'special_quiz_of_day': 'Quiz Spécial du Jour',
      'double_points_badge': 'POINTS 2X',
      'hard_mode_extra_token': 'Mode Difficile • Récompense de Jetons Supplémentaire',
      'lucky_wheel': 'Roue de la Chance',
      'wheel_won': 'Félicitations ! Votre récompense a été ajoutée à votre compte.',
      'wheel_spin_prompt': 'Faites tourner la roue et gagnez de superbes récompenses de jetons !',
      'wheel_spun_today': "Vous avez fait tourner la roue aujourd'hui. Revenez demain !",
      'streak_claimed': 'Super ! Récompense Réclamée !',
      'streak_title': 'Série de Connexions Quotidiennes',
      'streak_reward_added': '+{tokens} Jetons ajoutés à votre compte !',
      'streak_prompt': 'Série de {streak} Jours ! Venez tous les jours, gagnez plus !',
      'claim_reward': 'Réclamer la Récompense',
      'wheel_you_won': 'Tu as gagné:',
      'wheel_awesome': 'Génial!',
      'wheel_spin_button': 'Tourner la Roue 🔥',
      'wheel_done_today': 'Fini pour Aujourd\'hui',
      'streak_claim_today': 'Réclamer la Récompense du Jour 🎉',
      'streak_ok': 'OK'
    },
    'ru': {
      'special_quiz_of_day': 'Специальная Викторина Дня',
      'double_points_badge': 'ДВОЙНЫЕ ОЧКИ',
      'hard_mode_extra_token': 'Сложный Режим • Дополнительная Награда',
      'lucky_wheel': 'Колесо Удачи',
      'wheel_won': 'Поздравляем! Ваша награда добавлена на ваш счет.',
      'wheel_spin_prompt': 'Крутите колесо и выигрывайте отличные награды!',
      'wheel_spun_today': 'Вы уже крутили колесо сегодня. Приходите завтра!',
      'streak_claimed': 'Отлично! Награда Получена!',
      'streak_title': 'Серия Ежедневных Входов',
      'streak_reward_added': '+{tokens} Токенов добавлено на ваш счет!',
      'streak_prompt': '{streak} Дней Подряд! Заходите каждый день, выигрывайте больше!',
      'claim_reward': 'Получить Награду',
      'wheel_you_won': 'Вы выиграли:',
      'wheel_awesome': 'Здорово!',
      'wheel_spin_button': 'Крутить Колесо 🔥',
      'wheel_done_today': 'На сегодня всё',
      'streak_claim_today': 'Получить Награду Сегодня 🎉',
      'streak_ok': 'ОК'
    },
    'ar': {
      'special_quiz_of_day': 'اختبار اليوم الخاص',
      'double_points_badge': 'نقاط مضاعفة 2X',
      'hard_mode_extra_token': 'الوضع الصعب • مكافأة إضافية',
      'lucky_wheel': 'عجلة الحظ',
      'wheel_won': 'تهانينا! تمت إضافة مكافأتك إلى حسابك.',
      'wheel_spin_prompt': 'قم بتدوير العجلة واربح مكافآت رائعة!',
      'wheel_spun_today': 'لقد قمت بتدوير العجلة اليوم. عد غدًا!',
      'streak_claimed': 'رائع! تم استلام المكافأة!',
      'streak_title': 'سلسلة تسجيل الدخول اليومية',
      'streak_reward_added': 'تمت إضافة +{tokens} عملة إلى حسابك!',
      'streak_prompt': 'سلسلة من {streak} أيام! تعال كل يوم، اربح أكثر!',
      'claim_reward': 'المطالبة بالمكافأة',
      'wheel_you_won': 'لقد فزت:',
      'wheel_awesome': 'رائع!',
      'wheel_spin_button': 'أدر العجلة 🔥',
      'wheel_done_today': 'انتهى اليوم',
      'streak_claim_today': 'احصل على مكافأة اليوم 🎉',
      'streak_ok': 'حسناً'
    }
  };

  final dir = Directory('assets/translations');
  if (!dir.existsSync()) {
    print("Directory not found");
    return;
  }

  await for (var entity in dir.list()) {
    if (entity is File && entity.path.endsWith('.json')) {
      final lang = entity.uri.pathSegments.last.split('.').first;
      final contentStr = await entity.readAsString();
      final Map<String, dynamic> json = jsonDecode(contentStr);
      
      if (translations.containsKey(lang)) {
        json['new_features'] = translations[lang];
        final encoder = JsonEncoder.withIndent('  ');
        await entity.writeAsString(encoder.convert(json));
        print('Updated \${entity.path}');
      }
    }
  }
}
