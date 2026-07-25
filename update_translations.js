const fs = require('fs');
const path = require('path');

const translations = {
  tr: {
    special_quiz_of_day: 'Günün Özel Yarışması',
    double_points_badge: '2X PUAN',
    hard_mode_extra_token: 'Zor Mod • Ekstra Token Ödüllü',
    lucky_wheel: 'Şans Çarkı',
    wheel_won: 'Tebrikler! Ödülünüz hesabınıza eklendi.',
    wheel_spin_prompt: 'Çarkı çevir, harika token ödüllerinden birini kazan!',
    wheel_spun_today: 'Bugün çarkı çevirdiniz. Yarın tekrar gelin!',
    streak_claimed: 'Harika! Ödül Alındı!',
    streak_title: 'Günlük Giriş Serisi',
    streak_reward_added: '+{tokens} Token hesabına eklendi!',
    streak_prompt: '{streak} Günlük Seri! Her gün gel, daha çok kazan!',
    claim_reward: 'Ödülü Al'
  },
  en: {
    special_quiz_of_day: 'Special Quiz of the Day',
    double_points_badge: '2X POINTS',
    hard_mode_extra_token: 'Hard Mode • Extra Token Reward',
    lucky_wheel: 'Lucky Wheel',
    wheel_won: 'Congratulations! Your reward has been added to your account.',
    wheel_spin_prompt: 'Spin the wheel and win great token rewards!',
    wheel_spun_today: 'You spun the wheel today. Come back tomorrow!',
    streak_claimed: 'Great! Reward Claimed!',
    streak_title: 'Daily Login Streak',
    streak_reward_added: '+{tokens} Tokens added to your account!',
    streak_prompt: '{streak} Day Streak! Come every day, win more!',
    claim_reward: 'Claim Reward'
  },
  es: {
    special_quiz_of_day: 'Cuestionario Especial del Día',
    double_points_badge: 'PUNTOS 2X',
    hard_mode_extra_token: 'Modo Difícil • Recompensa Extra de Fichas',
    lucky_wheel: 'Rueda de la Suerte',
    wheel_won: '¡Felicidades! Tu recompensa ha sido añadida a tu cuenta.',
    wheel_spin_prompt: '¡Gira la rueda y gana grandes recompensas de fichas!',
    wheel_spun_today: 'Hoy ya giraste la rueda. ¡Vuelve mañana!',
    streak_claimed: '¡Genial! ¡Recompensa Reclamada!',
    streak_title: 'Racha de Inicio de Sesión Diaria',
    streak_reward_added: '¡+{tokens} Fichas añadidas a tu cuenta!',
    streak_prompt: '¡Racha de {streak} Días! ¡Ven todos los días, gana más!',
    claim_reward: 'Reclamar Recompensa'
  },
  fr: {
    special_quiz_of_day: 'Quiz Spécial du Jour',
    double_points_badge: 'POINTS 2X',
    hard_mode_extra_token: 'Mode Difficile • Récompense de Jetons Supplémentaire',
    lucky_wheel: 'Roue de la Chance',
    wheel_won: 'Félicitations ! Votre récompense a été ajoutée à votre compte.',
    wheel_spin_prompt: 'Faites tourner la roue et gagnez de superbes récompenses de jetons !',
    wheel_spun_today: 'Vous avez fait tourner la roue aujourd\'hui. Revenez demain !',
    streak_claimed: 'Super ! Récompense Réclamée !',
    streak_title: 'Série de Connexions Quotidiennes',
    streak_reward_added: '+{tokens} Jetons ajoutés à votre compte !',
    streak_prompt: 'Série de {streak} Jours ! Venez tous les jours, gagnez plus !',
    claim_reward: 'Réclamer la Récompense'
  },
  ru: {
    special_quiz_of_day: 'Специальная Викторина Дня',
    double_points_badge: 'ДВОЙНЫЕ ОЧКИ',
    hard_mode_extra_token: 'Сложный Режим • Дополнительная Награда',
    lucky_wheel: 'Колесо Удачи',
    wheel_won: 'Поздравляем! Ваша награда добавлена на ваш счет.',
    wheel_spin_prompt: 'Крутите колесо и выигрывайте отличные награды!',
    wheel_spun_today: 'Вы уже крутили колесо сегодня. Приходите завтра!',
    streak_claimed: 'Отлично! Награда Получена!',
    streak_title: 'Серия Ежедневных Входов',
    streak_reward_added: '+{tokens} Токенов добавлено на ваш счет!',
    streak_prompt: '{streak} Дней Подряд! Заходите каждый день, выигрывайте больше!',
    claim_reward: 'Получить Награду'
  },
  ar: {
    special_quiz_of_day: 'اختبار اليوم الخاص',
    double_points_badge: 'نقاط مضاعفة 2X',
    hard_mode_extra_token: 'الوضع الصعب • مكافأة إضافية',
    lucky_wheel: 'عجلة الحظ',
    wheel_won: 'تهانينا! تمت إضافة مكافأتك إلى حسابك.',
    wheel_spin_prompt: 'قم بتدوير العجلة واربح مكافآت رائعة!',
    wheel_spun_today: 'لقد قمت بتدوير العجلة اليوم. عد غدًا!',
    streak_claimed: 'رائع! تم استلام المكافأة!',
    streak_title: 'سلسلة تسجيل الدخول اليومية',
    streak_reward_added: 'تمت إضافة +{tokens} عملة إلى حسابك!',
    streak_prompt: 'سلسلة من {streak} أيام! تعال كل يوم، اربح أكثر!',
    claim_reward: 'المطالبة بالمكافأة'
  }
};

const dir = path.join(__dirname, 'assets', 'translations');
console.error("Directory:", dir);
try {
  fs.readdirSync(dir).forEach(file => {
    if (file.endsWith('.json')) {
      const lang = file.split('.')[0];
      const filePath = path.join(dir, file);
      console.error("Processing", filePath);
      const content = JSON.parse(fs.readFileSync(filePath, 'utf8'));
      
      if (translations[lang]) {
        content.new_features = translations[lang];
        fs.writeFileSync(filePath, JSON.stringify(content, null, 2), 'utf8');
        console.error('Updated ' + file);
      } else {
        console.error('No translations for ' + lang);
      }
    }
  });
} catch (e) {
  console.error("Error:", e);
}
