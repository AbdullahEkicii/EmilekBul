import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/user_service.dart';
import '../widgets/glass_container.dart';
import '../widgets/navigation_buttons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LevelProgressionScreen extends StatefulWidget {
  const LevelProgressionScreen({super.key});

  @override
  State<LevelProgressionScreen> createState() => _LevelProgressionScreenState();
}

class _LevelProgressionScreenState extends State<LevelProgressionScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              ),
            ),
          ),

          SafeArea(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data?.data() as Map<String, dynamic>?;
                final currentQuizzes = data?['completedQuizzes'] ?? 0;
                final currentLevel = data?['level'] ?? 1;

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildHeader(),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverToBoxAdapter(
                        child:
                            _buildCurrentStatus(currentQuizzes, currentLevel),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          'level_progression.level_list_title'.tr(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final level = index + 1;
                            final quizzesNeeded = level == 1
                                ? 0
                                : UserService.getQuizzesNeededForNextLevel(
                                    level - 1);
                            final reward = index * 100;
                            final isUnlocked = currentLevel >= level;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildLevelItem(
                                  level, quizzesNeeded, reward, isUnlocked),
                            );
                          },
                          childCount: 20,
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 40),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          const AppBackButton(),
          const SizedBox(width: 16),
          Text(
            'level_progression.title'.tr(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStatus(int quizzes, int level) {
    final nextLevelReq = UserService.getQuizzesNeededForNextLevel(level);
    final prevLevelReq =
        level == 1 ? 0 : UserService.getQuizzesNeededForNextLevel(level - 1);

    final progress = nextLevelReq == prevLevelReq
        ? 1.0
        : (quizzes - prevLevelReq) / (nextLevelReq - prevLevelReq);

    final displayProgress = progress.clamp(0.0, 1.0);

    return GlassContainer(
      opacity: 0.1,
      borderRadius: 24,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'level_progression.current_progress'.tr(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${'level_system.level'.tr()} $level',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.indigoAccent.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: Colors.indigoAccent,
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'level_progression.quizzes_completed'.tr(),
                style: const TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.w600),
              ),
              Text(
                '$quizzes / $nextLevelReq',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: displayProgress,
              minHeight: 12,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.indigoAccent),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.toll_rounded, color: Colors.amber, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'level_progression.next_level_reward'.tr(),
                        style: TextStyle(
                          color: Colors.amber.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${level * 100} ${'token.unit'.tr()}',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelItem(int level, int quizzes, int reward, bool isUnlocked) {
    final color =
        isUnlocked ? Colors.greenAccent : Colors.white.withValues(alpha: 0.3);

    return Container(
      decoration: BoxDecoration(
        color: isUnlocked
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUnlocked
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Center(
              child: Text(
                '$level',
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${'level_system.level'.tr()} $level',
                  style: TextStyle(
                    color: isUnlocked
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.4),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'level_progression.req_quizzes'
                      .tr(args: [quizzes.toString()]),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (reward > 0)
                Text(
                  '+$reward',
                  style: TextStyle(
                    color: isUnlocked
                        ? Colors.amber
                        : Colors.white.withValues(alpha: 0.2),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              Text(
                isUnlocked
                    ? 'level_progression.unlocked'.tr()
                    : 'level_progression.locked'.tr(),
                style: TextStyle(
                  color: color.withValues(alpha: 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
