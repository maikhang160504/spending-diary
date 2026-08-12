import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../utils/formatters.dart';

class GoalRecapScreen extends StatefulWidget {
  final Map<String, dynamic> goal;

  const GoalRecapScreen({super.key, required this.goal});

  @override
  State<GoalRecapScreen> createState() => _GoalRecapScreenState();
}

class _GoalRecapScreenState extends State<GoalRecapScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  final ApiClient _api = ApiClient();

  int _currentPage = 0;
  bool _loadingAi = true;
  String? _title;
  String? _commentary;
  String _mascotMood = 'Celebrate';
  Map<String, dynamic>? _mvpMember;

  // Typewriter animation state for commentary
  String _displayedCommentary = '';
  Timer? _typewriterTimer;

  @override
  void initState() {
    super.initState();
    _prefetchAiCommentary();
  }

  Future<void> _prefetchAiCommentary() async {
    try {
      final res = await _api.getGoalRecap({
        'name': widget.goal['name'] ?? 'Mục tiêu',
        'targetAmount': widget.goal['targetAmount'] ?? 0,
        'currentAmount': widget.goal['currentAmount'] ?? 0,
        'isGroup': widget.goal['isGroup'] ?? false,
        'type': widget.goal['type'] ?? 'personal',
        'totalContributions': widget.goal['contributionsCount'] ?? 12,
      });
      if (!mounted) return;
      setState(() {
        _loadingAi = false;
        _title = res['title']?.toString() ?? 'CHỨNG NHẬN HOÀN THÀNH';
        _commentary =
            res['commentary']?.toString() ??
            'Chúc mừng bạn đã xuất sắc chinh phục mục tiêu!';
        _mascotMood = res['mascotMood']?.toString() ?? 'Celebrate';
        _mvpMember = res['mvpMember'] as Map<String, dynamic>?;
      });
      if (_currentPage == 2) {
        _startTypewriter(_commentary!);
      }
    } catch (_) {
      if (!mounted) return;
      final name = widget.goal['name'] ?? 'Mục tiêu';
      setState(() {
        _loadingAi = false;
        _title = 'CHỨNG NHẬN HOÀN THÀNH';
        _commentary =
            'Xuất sắc! Bạn đã chinh phục thành công "$name". Hãy tiếp tục phát huy kỷ luật tài chính tuyệt vời này nhé!';
        _mascotMood = 'Celebrate';
      });
      if (_currentPage == 2) {
        _startTypewriter(_commentary!);
      }
    }
  }

  void _startTypewriter(String text) {
    _typewriterTimer?.cancel();
    _displayedCommentary = '';
    int idx = 0;
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 25), (
      timer,
    ) {
      if (idx < text.length) {
        if (mounted) {
          setState(() {
            _displayedCommentary = text.substring(0, idx + 1);
          });
        }
        idx++;
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _typewriterTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    if (page == 2 && _commentary != null && _displayedCommentary.isEmpty) {
      _startTypewriter(_commentary!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.goal['name'] ?? 'Mục tiêu';
    final targetAmt =
        double.tryParse(widget.goal['targetAmount']?.toString() ?? '0') ?? 0;
    final emoji = widget.goal['emoji']?.toString() ?? '🎯';
    final isGroup = widget.goal['isGroup'] == true;
    final isChallenge =
        widget.goal['type']?.toString().contains('challenge') == true;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // Background Gradient Glow
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFF59E0B).withValues(alpha: 0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: SafeArea(
                child: Column(
                  children: [
                    // Top header & progress dots
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white70,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(3, (index) {
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  width: _currentPage == index ? 24 : 8,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: _currentPage == index
                                        ? const Color(0xFFF59E0B)
                                        : Colors.white24,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(width: 48), // balance space
                        ],
                      ),
                    ),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: _onPageChanged,
                        children: [
                          _buildSlide1(name, emoji, targetAmt, isChallenge),
                          _buildSlide2(name, targetAmt, isGroup, isChallenge),
                          _buildSlide3(name, emoji, targetAmt),
                        ],
                      ),
                    ),
                    // Bottom navigation controls
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (_currentPage > 0)
                            TextButton(
                              onPressed: () => _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              ),
                              child: const Text(
                                'Quay lại',
                                style: TextStyle(color: Colors.white60),
                              ),
                            )
                          else
                            const SizedBox(),
                          if (_currentPage < 2)
                            FilledButton(
                              onPressed: () => _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFF59E0B),
                                foregroundColor: const Color(0xFF0F172A),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                  vertical: 14,
                                ),
                              ),
                              child: const Text(
                                'Tiếp theo',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            )
                          else
                            FilledButton.icon(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.auto_awesome),
                              label: const Text('Hoàn tất hành trình'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.teal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 14,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlide1(
    String name,
    String emoji,
    double targetAmt,
    bool isChallenge,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 48)),
            ),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isChallenge
                  ? 'THỬ THÁCH ĐÃ HOÀN THÀNH 🏆'
                  : 'MỤC TIÊU ĐÃ HOÀN THÀNH ✨',
              style: const TextStyle(
                color: Color(0xFFFBBF24),
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Bạn đã kiên trì và hoàn tất cột mốc\n${formatVnd(targetAmt.round())}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlide2(
    String name,
    double targetAmt,
    bool isGroup,
    bool isChallenge,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'NHỮNG CON SỐ BIẾT NÓI 📊',
            style: TextStyle(
              color: Color(0xFF38BDF8),
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 24),
          _buildStatCard(
            'Thành quả đạt được',
            formatVnd(targetAmt.round()),
            Icons.verified,
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            'Trạng thái hành trình',
            '100% Hoàn thành',
            Icons.insights,
          ),
          if (isGroup) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    const Color(0xFFF59E0B).withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Text('👑', style: TextStyle(fontSize: 32)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'VINH DANH ĐỒNG ĐỘI MVP',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFFBBF24),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _mvpMember?['name']?.toString() ?? 'Đoàn kết tập thể',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Đã góp sức tích cực cho quỹ chung',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF38BDF8), size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 13, color: Colors.white60),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlide3(String name, String emoji, double targetAmt) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Mascot Mood Display
                  Image.asset(
                    'assets/MiMo/emotions/$_mascotMood.png',
                    height: 84,
                    errorBuilder: (context, error, stackTrace) =>
                        const Text('🎉', style: TextStyle(fontSize: 56)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _title ?? 'CHỨNG NHẬN HOÀN THÀNH',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFBBF24),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Certificate Card containing commentary
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.1),
                          Colors.white.withValues(alpha: 0.04),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(emoji, style: const TextStyle(fontSize: 24)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(color: Colors.white12),
                        const SizedBox(height: 14),
                        if (_loadingAi)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFFBBF24),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'MiMo đang viết lời nhận xét riêng cho bạn...',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            _displayedCommentary.isNotEmpty
                                ? _displayedCommentary
                                : (_commentary ?? ''),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              height: 1.55,
                            ),
                          ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '— MiMo AI Assistant',
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
