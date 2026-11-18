import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../models/quest.dart';
import '../../../services/quest_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_container.dart';

class QuestsPanel extends StatefulWidget {
  const QuestsPanel({super.key});

  @override
  State<QuestsPanel> createState() => _QuestsPanelState();
}

class _QuestsPanelState extends State<QuestsPanel> {
  List<Quest> _quests = [];
  bool _isLoading = true;
  String _activeTab = 'daily'; // 'daily' or 'weekly'

  @override
  void initState() {
    super.initState();
    _loadQuests();
  }

  Future<void> _loadQuests() async {
    try {
      await QuestService.initializeQuests();
      final quests = await QuestService.getActiveQuests();
      if (mounted) {
        setState(() {
          _quests = quests;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Quests load error: $e');
    }
  }

  Future<void> _claimReward(String questId) async {
    try {
      final success = await QuestService.claimQuestReward(questId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('quests.reward_claimed'.tr()),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        _loadQuests();
      }
    } catch (e) {
      debugPrint('Claim reward error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    EasyLocalization.of(context)?.locale;
    Localizations.maybeLocaleOf(context);
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(color: Colors.amber),
        ),
      );
    }

    final filteredQuests = _quests.where((q) => q.type == _activeTab).toList();

    return GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      opacity: 0.08,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        color: Colors.amberAccent, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'quests.title'.tr(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  _buildTabButton('daily', 'quests.daily'.tr()),
                  const SizedBox(width: 8),
                  _buildTabButton('weekly', 'quests.weekly'.tr()),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (filteredQuests.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Center(
                child: Text(
                  'quests.empty'.tr(),
                  style: const TextStyle(color: Colors.white60),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: filteredQuests.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _buildQuestItem(filteredQuests[index]),
            ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String tab, String label) {
    final isActive = _activeTab == tab;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = tab),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.amberAccent.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.small),
          border: Border.all(
            color: isActive
                ? Colors.amberAccent.withValues(alpha: 0.5)
                : Colors.white24,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.amberAccent : Colors.white60,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildQuestItem(Quest quest) {
    final bool isCompleted = quest.currentProgress >= quest.targetProgress;
    final progressVal =
        (quest.currentProgress / quest.targetProgress).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(
          color: isCompleted && !quest.isClaimed
              ? Colors.amberAccent.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isCompleted
                  ? (quest.isClaimed
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.amber.withValues(alpha: 0.1))
                  : Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted
                  ? (quest.isClaimed
                      ? Icons.check_circle_outline_rounded
                      : Icons.star_rounded)
                  : Icons.bolt_rounded,
              color: isCompleted
                  ? (quest.isClaimed ? Colors.greenAccent : Colors.amberAccent)
                  : Colors.grey,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  QuestService.getQuestTitle(quest.id),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    decoration:
                        quest.isClaimed ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressVal,
                    minHeight: 6,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isCompleted ? Colors.greenAccent : Colors.amberAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${quest.currentProgress}/${quest.targetProgress}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildQuestAction(quest, isCompleted),
        ],
      ),
    );
  }

  Widget _buildQuestAction(Quest quest, bool isCompleted) {
    if (quest.isClaimed) {
      return Text(
        'quests.claimed'.tr().toUpperCase(),
        style: const TextStyle(
          color: Colors.greenAccent,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    if (isCompleted) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amberAccent,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.small)),
          elevation: 4,
          shadowColor: Colors.amberAccent.withValues(alpha: 0.4),
        ),
        onPressed: () => _claimReward(quest.id),
        child: Text(
          'quests.claim'.tr(),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '+${quest.rewardTokens}',
            style: const TextStyle(
              color: Colors.amberAccent,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 2),
          const Icon(
            Icons.generating_tokens_outlined,
            color: Colors.amberAccent,
            size: 14,
          ),
        ],
      ),
    );
  }
}
