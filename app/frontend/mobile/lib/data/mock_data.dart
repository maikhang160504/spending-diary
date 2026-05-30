class OnboardingItem {
  final String title;
  final String subtitle;
  final String caption;

  const OnboardingItem({
    required this.title,
    required this.subtitle,
    required this.caption,
  });
}

class ChatMessage {
  final String text;
  final bool isUser;
  final String time;

  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.time,
  });
}

class ChatThread {
  final String title;
  final String preview;
  final String time;
  final String count;

  const ChatThread({
    required this.title,
    required this.preview,
    required this.time,
    required this.count,
  });
}

class GoalItem {
  final String title;
  final String emoji;
  final int targetAmount;
  final int savedAmount;

  const GoalItem({
    required this.title,
    required this.emoji,
    required this.targetAmount,
    required this.savedAmount,
  });
}

class TransactionItem {
  final String title;
  final String category;
  final String date;
  final double amount;
  final bool isIncome;

  const TransactionItem({
    required this.title,
    required this.category,
    required this.date,
    required this.amount,
    required this.isIncome,
  });
}

class HomeStory {
  final String userName;
  final String time;
  final String title;
  final String category;
  final String categoryEmoji;
  final String imageUrl;
  final int amount;
  final String aiMessage;
  final bool aiPositive;
  final bool isOwner;

  const HomeStory({
    required this.userName,
    required this.time,
    required this.title,
    required this.category,
    required this.categoryEmoji,
    required this.imageUrl,
    required this.amount,
    required this.aiMessage,
    required this.aiPositive,
    required this.isOwner,
  });
}

class GalleryItem {
  final String title;
  final String category;
  final String categoryEmoji;
  final String date;
  final String imageUrl;
  final int amount;

  const GalleryItem({
    required this.title,
    required this.category,
    required this.categoryEmoji,
    required this.date,
    required this.imageUrl,
    required this.amount,
  });
}

class ReportBar {
  final String label;
  final int amount;

  const ReportBar({
    required this.label,
    required this.amount,
  });
}

class ReportCategory {
  final String code;
  final String label;
  final String emoji;
  final double percent;
  final int amount;
  final int color;

  const ReportCategory({
    this.code = 'Other',
    required this.label,
    required this.emoji,
    required this.percent,
    required this.amount,
    required this.color,
  });
}

class TrendPoint {
  final String label;
  final int amount;

  const TrendPoint({
    required this.label,
    required this.amount,
  });
}

class StreakAchievement {
  final String title;
  final String subtitle;
  final String date;
  final String emoji;
  final bool achieved;

  const StreakAchievement({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.emoji,
    required this.achieved,
  });
}

class CalendarEntry {
  final int day;
  final int month;
  final int year;
  final List<String> imageUrls; // stacked photos
  final int totalAmount;

  const CalendarEntry({
    required this.day,
    required this.month,
    required this.year,
    required this.imageUrls,
    required this.totalAmount,
  });

  int get count => imageUrls.length;
}

class MiMoResponse {
  final String status; // Happy/Sad/Chill/Sassy/Thinking/Success/Taunting
  final String message;

  const MiMoResponse({required this.status, required this.message});
}

/// Map API mascot_mood (PascalCase từ LLM emotion field, hoặc legacy vui/buon/...)
/// sang Flutter asset name cho MiMoOverlay (assets/MiMo/emotions/{name}.png).
String mapApiStatusToAsset(String? value, {String fallback = 'Chill'}) {
  if (value == null || value.isEmpty) return fallback;
  const validAssets = {
    'Alert', 'Angry', 'Approved', 'Celebrate', 'Chill', 'Cooking', 'Cool',
    'Determined', 'Error', 'Excited', 'Gigle', 'Happy', 'Hello', 'Loading',
    'Love', 'Proud', 'Relax', 'Sad', 'Sleepy', 'Sassy', 'Shopping', 'Travel',
    'Sorry', 'Success', 'Taunting', 'Thankful', 'Thinking', 'Working', 'Worried',
  };
  if (validAssets.contains(value)) return value;
  const legacyMap = {
    'vui': 'Happy',
    'buon': 'Sad',
    'canh_bao': 'Thinking',
    'trung_lap': 'Chill',
    'Giggle': 'Gigle',
    'giggle': 'Gigle',
  };
  return legacyMap[value] ?? fallback;
}

class MockData {
  static const onboarding = [
    OnboardingItem(
      title: 'Xin chào! Mình là Mimo 😊',
      subtitle: 'Còn bạn tên gì nhỉ? Cho mình xin tên để dễ gọi nha~',
      caption: 'Tiếp nào! ✨',
    ),
    OnboardingItem(
      title: 'Thu nhập của bạn',
      subtitle: 'Để Mimo hiểu rõ tình hình tài chính của bạn hơn',
      caption: 'Tiếp tục',
    ),
    OnboardingItem(
      title: 'Bạn thích mình nói chuyện kiểu nào?',
      subtitle: 'Chọn phong cách mà bạn thấy "vibe" nhất nha!',
      caption: 'Tiếp nào! ✨',
    ),
    OnboardingItem(
      title: 'Giới hạn chi tiêu',
      subtitle: 'Đặt giới hạn cho từng danh mục (có thể bỏ qua)',
      caption: 'Tiếp tục',
    ),
    OnboardingItem(
      title: 'Thông tin cá nhân',
      subtitle: 'Để Mimo có thể tư vấn phù hợp với bạn nhất',
      caption: 'Hoàn thành',
    ),
  ];

  static const chatMessages = [
    ChatMessage(
      text: 'Chào bạn! Mình là Mimo đây 😎 Bạn muốn hỏi gì về chi tiêu không?',
      isUser: false,
      time: '00:23',
    ),
    ChatMessage(text: 'Tuần này sao?', isUser: true, time: '00:23'),
    ChatMessage(
      text: 'Hôm qua bạn tiêu 3 lần trà sữa rồi nè 😱 Coi chừng vượt limit đó!',
      isUser: false,
      time: '00:23',
    ),
  ];

  static const chatThreads = [
    ChatThread(
      title: 'Tu van chi tieu thang 5',
      preview: 'Tuan nay ban tieu khoang 680k doi! An uong chiem nhieu hon...',
      time: 'Vua xong',
      count: '12 tin nhan',
    ),
    ChatThread(
      title: 'Hoi ve muc tieu tiet kiem',
      preview: 'Muc tieu iPhone da dat 34% roi! Con 16.5 trieu nua thoi...',
      time: 'Hom qua',
      count: '8 tin nhan',
    ),
    ChatThread(
      title: 'Phan tich chi tieu cafe',
      preview: 'Thang nay ban di cafe hoi nhieu roi do. Thu giam cafe...',
      time: '29 thg 4',
      count: '6 tin nhan',
    ),
    ChatThread(
      title: 'Len ke hoach mua sam',
      preview: 'Voi budget hien tai, ban nen uu tien mua do can thiet...',
      time: '29 thg 4',
      count: '6 tin nhan',
    ),
    ChatThread(
      title: 'Tu van tiet kiem',
      preview: 'Ban co the tiet kiem them 500k/thang neu giam...',
      time: '22 thg 4',
      count: '20 tin nhan',
    ),
  ];

  static const goals = [
    GoalItem(
      title: 'Mua iPhone mới',
      emoji: '📱',
      targetAmount: 25000000,
      savedAmount: 8500000,
    ),
    GoalItem(
      title: 'Du lịch Đà Lạt',
      emoji: '✈️',
      targetAmount: 5000000,
      savedAmount: 3200000,
    ),
  ];

  static const homeStories = [
    HomeStory(
      userName: 'Bạn',
      time: '28 thg 3 • 08:30',
      title: 'Cà phê sáng',
      category: 'Ăn uống',
      categoryEmoji: '🍔',
      imageUrl:
          'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=800&q=80',
      amount: 45000,
      aiMessage: 'Cafe giá này hơi chát đó, thử pha nhà đi bạn ơi~ Tiết kiệm hơn mà vẫn ngon! 🫖',
      aiPositive: false,
      isOwner: false,
    ),
    HomeStory(
      userName: 'Bạn',
      time: '27 thg 3 • 14:20',
      title: 'Áo mới',
      category: 'Mua sắm',
      categoryEmoji: '🛍️',
      imageUrl:
          'https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&w=800&q=80',
      amount: 250000,
      aiMessage: 'Hơi nhiều rồi đó~ Coi chừng vượt budget nha 🤔',
      aiPositive: false,
      isOwner: false,
    ),
    HomeStory(
      userName: 'Bạn',
      time: '27 thg 3 • 12:15',
      title: 'Cơm trưa',
      category: 'Ăn uống',
      categoryEmoji: '🍔',
      imageUrl:
          'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=800&q=80',
      amount: 120000,
      aiMessage: 'Hôm nay ăn uống đã cân đối, good job! 👍',
      aiPositive: true,
      isOwner: false,
    ),
  ];

  static const galleryItems = [
    GalleryItem(
      title: 'Cà phê sáng',
      category: 'Ăn uống',
      categoryEmoji: '🍔',
      date: '28-03',
      imageUrl:
          'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=600&q=80',
      amount: 45000,
    ),
    GalleryItem(
      title: 'Áo mới',
      category: 'Mua sắm',
      categoryEmoji: '🛍️',
      date: '27-03',
      imageUrl:
          'https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&w=600&q=80',
      amount: 250000,
    ),
    GalleryItem(
      title: 'Cơm trưa',
      category: 'Ăn uống',
      categoryEmoji: '🍔',
      date: '27-03',
      imageUrl:
          'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=600&q=80',
      amount: 120000,
    ),
    GalleryItem(
      title: 'Xem phim',
      category: 'Giải trí',
      categoryEmoji: '🎬',
      date: '26-03',
      imageUrl:
          'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?auto=format&fit=crop&w=600&q=80',
      amount: 150000,
    ),
    GalleryItem(
      title: 'Grab về nhà',
      category: 'Di chuyển',
      categoryEmoji: '🚗',
      date: '26-03',
      imageUrl:
          'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?auto=format&fit=crop&w=600&q=80',
      amount: 60000,
    ),
    GalleryItem(
      title: 'Trà sữa',
      category: 'Ăn uống',
      categoryEmoji: '🍔',
      date: '25-03',
      imageUrl:
          'https://images.unsplash.com/photo-1527169402691-feff5539e52c?auto=format&fit=crop&w=600&q=80',
      amount: 55000,
    ),
  ];

  static const reportBars = [
    ReportBar(label: 'Mon', amount: 180000),
    ReportBar(label: 'Tue', amount: 250000),
    ReportBar(label: 'Wed', amount: 120000),
    ReportBar(label: 'Thu', amount: 300000),
    ReportBar(label: 'Fri', amount: 220000),
    ReportBar(label: 'Sat', amount: 400000),
    ReportBar(label: 'Sun', amount: 150000),
  ];

  static const reportCategories = [
    ReportCategory(
      label: 'Ăn uống',
      emoji: '🍔',
      percent: 32.4,
      amount: 220000,
      color: 0xFFEC4899,
    ),
    ReportCategory(
      label: 'Mua sắm',
      emoji: '🛍️',
      percent: 36.8,
      amount: 250000,
      color: 0xFFA78BFA,
    ),
    ReportCategory(
      label: 'Di chuyển',
      emoji: '🚗',
      percent: 8.8,
      amount: 60000,
      color: 0xFF60A5FA,
    ),
    ReportCategory(
      label: 'Giải trí',
      emoji: '🎬',
      percent: 22.1,
      amount: 150000,
      color: 0xFFFBBF24,
    ),
  ];

  static const reportTrend = [
    TrendPoint(label: 'Jan', amount: 1200000),
    TrendPoint(label: 'Feb', amount: 1450000),
    TrendPoint(label: 'Mar', amount: 1800000),
  ];

  static const streakAchievements = [
    StreakAchievement(
      title: 'Tuần đầu tiên',
      subtitle: 'Ghi chép 7 ngày liên tục',
      date: 'Đạt được: 15 Apr 2026',
      emoji: '🔥',
      achieved: true,
    ),
    StreakAchievement(
      title: 'Hai tuần kiên trì',
      subtitle: 'Ghi chép 14 ngày liên tục',
      date: 'Đạt được: 22 Apr 2026',
      emoji: '⭐',
      achieved: true,
    ),
    StreakAchievement(
      title: 'Tháng hoàn hảo',
      subtitle: 'Ghi chép 30 ngày liên tục',
      date: '',
      emoji: '🏆',
      achieved: false,
    ),
    StreakAchievement(
      title: 'Kỷ lục 100 ngày',
      subtitle: 'Ghi chép 100 ngày liên tục',
      date: '',
      emoji: '💎',
      achieved: false,
    ),
  ];

  // Calendar entries for current month (May 2026)
  static const calendarEntries = [
    CalendarEntry(
      day: 3, month: 5, year: 2026,
      imageUrls: ['https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=200&q=80'],
      totalAmount: 45000,
    ),
    CalendarEntry(
      day: 5, month: 5, year: 2026,
      imageUrls: [
        'https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&w=200&q=80',
        'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=200&q=80',
      ],
      totalAmount: 370000,
    ),
    CalendarEntry(
      day: 7, month: 5, year: 2026,
      imageUrls: ['https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?auto=format&fit=crop&w=200&q=80'],
      totalAmount: 150000,
    ),
    CalendarEntry(
      day: 9, month: 5, year: 2026,
      imageUrls: [
        'https://images.unsplash.com/photo-1527169402691-feff5539e52c?auto=format&fit=crop&w=200&q=80',
        'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=200&q=80',
        'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?auto=format&fit=crop&w=200&q=80',
      ],
      totalAmount: 620000,
    ),
    CalendarEntry(
      day: 11, month: 5, year: 2026,
      imageUrls: ['https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&w=200&q=80'],
      totalAmount: 250000,
    ),
    CalendarEntry(
      day: 14, month: 5, year: 2026,
      imageUrls: [
        'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=200&q=80',
        'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?auto=format&fit=crop&w=200&q=80',
      ],
      totalAmount: 270000,
    ),
    CalendarEntry(
      day: 16, month: 5, year: 2026,
      imageUrls: ['https://images.unsplash.com/photo-1527169402691-feff5539e52c?auto=format&fit=crop&w=200&q=80'],
      totalAmount: 55000,
    ),
    CalendarEntry(
      day: 19, month: 5, year: 2026,
      imageUrls: [
        'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?auto=format&fit=crop&w=200&q=80',
        'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=200&q=80',
      ],
      totalAmount: 105000,
    ),
    CalendarEntry(
      day: 21, month: 5, year: 2026,
      imageUrls: ['https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&w=200&q=80'],
      totalAmount: 180000,
    ),
    CalendarEntry(
      day: 23, month: 5, year: 2026,
      imageUrls: [
        'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=200&q=80',
        'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?auto=format&fit=crop&w=200&q=80',
        'https://images.unsplash.com/photo-1527169402691-feff5539e52c?auto=format&fit=crop&w=200&q=80',
        'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?auto=format&fit=crop&w=200&q=80',
      ],
      totalAmount: 890000,
    ),
    CalendarEntry(
      day: 26, month: 5, year: 2026,
      imageUrls: ['https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=200&q=80'],
      totalAmount: 75000,
    ),
    CalendarEntry(
      day: 28, month: 5, year: 2026,
      imageUrls: [
        'https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&w=200&q=80',
        'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=200&q=80',
      ],
      totalAmount: 310000,
    ),
  ];

  // MiMo mock responses (simulate server)
  static const mimoResponses = [
    MiMoResponse(status: 'Happy', message: 'Chi tiêu hợp lý lắm bạn ơi! 😊 Hôm nay kiểm soát tốt, tiếp tục nha~'),
    MiMoResponse(status: 'Sad', message: 'Ôi hơi nhiều rồi đó bạn ơi 😢 Coi chừng vượt budget tháng này nha!'),
    MiMoResponse(status: 'Chill', message: 'Okay nha~ Mức này vẫn trong tầm kiểm soát 😎 Keep it up!'),
    MiMoResponse(status: 'Sassy', message: 'Lại café nữa rồi! Tháng này bạn uống bao nhiêu ly rồi vậy? 😏'),
    MiMoResponse(status: 'Success', message: 'Xuất sắc! Chi tiêu tháng này giảm 15% so với tháng trước 🎉'),
    MiMoResponse(status: 'Thinking', message: 'Hmm... Danh mục này đang chiếm hơn 30% ngân sách đó 🤔'),
    MiMoResponse(status: 'Taunting', message: 'Lại mua sắm nữa hả? Tuần này bạn mua nhiều lắm rồi đó~ 😒'),
  ];

  static const streakDays = [
    true,
    true,
    true,
    false,
    true,
    true,
    true,
  ];
}
