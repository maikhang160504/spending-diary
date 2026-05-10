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
  final String label;
  final String emoji;
  final double percent;
  final int amount;
  final int color;

  const ReportCategory({
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
  final String imageUrl;
  final int count;

  const CalendarEntry({
    required this.day,
    required this.imageUrl,
    required this.count,
  });
}

class MockData {
  static const onboarding = [
    OnboardingItem(
      title: 'Xin chao! Minh la Mimo 😊',
      subtitle: 'Con ban ten gi nhi? Cho minh xin ten de de goi nha~',
      caption: 'Tien nao! ✨',
    ),
    OnboardingItem(
      title: 'Thu nhap cua ban',
      subtitle: 'De Mimo hieu ro tinh hinh tai chinh cua ban hon',
      caption: 'Tiep tuc',
    ),
    OnboardingItem(
      title: 'Ban thich minh noi chuyen kieu nao?',
      subtitle: 'Chon phong cach ma ban thay "vibe" nhat nha!',
      caption: 'Tiep nao! ✨',
    ),
    OnboardingItem(
      title: 'Gioi han chi tieu',
      subtitle: 'Dat gioi han cho tung danh muc (co the bo qua)',
      caption: 'Tiep tuc',
    ),
    OnboardingItem(
      title: 'Thong tin ca nhan',
      subtitle: 'De Mimo co the tu van phu hop voi ban nhat',
      caption: 'Hoan thanh',
    ),
  ];

  static const chatMessages = [
    ChatMessage(
      text: 'Chao ban! Minh la Mimo day 😎 Ban muon hoi gi ve chi tieu khong?',
      isUser: false,
      time: '00:23',
    ),
    ChatMessage(text: 'Tuan nay sao?', isUser: true, time: '00:23'),
    ChatMessage(
      text: 'Hom qua ban tieu 3 lan tra sua roi ne 😱 Coi chung vuot limit do!',
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
      title: 'Mua iPhone moi',
      emoji: '📱',
      targetAmount: 25000000,
      savedAmount: 8500000,
    ),
    GoalItem(
      title: 'Du lich Da Lat',
      emoji: '✈️',
      targetAmount: 5000000,
      savedAmount: 3200000,
    ),
  ];

  static const homeStories = [
    HomeStory(
      userName: 'Ban',
      time: '28 thg 3 • 08:30',
      title: 'Ca phe sang',
      category: 'An uong',
      categoryEmoji: '🍔',
      imageUrl:
          'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=800&q=80',
      amount: 45000,
      aiMessage: 'Cafe gia nay hoi chat do, thu pha nha di ban oi~ Tiet kiem hon ma van ngon!',
      aiPositive: false,
      isOwner: false,
    ),
    HomeStory(
      userName: 'Ban',
      time: '27 thg 3 • 14:20',
      title: 'Ao moi',
      category: 'Mua sam',
      categoryEmoji: '🛍️',
      imageUrl:
          'https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&w=800&q=80',
      amount: 250000,
      aiMessage: 'Hoi nhieu roi do~ Coi chung vuot budget nha 🤔',
      aiPositive: false,
      isOwner: false,
    ),
    HomeStory(
      userName: 'Ban',
      time: '27 thg 3 • 12:15',
      title: 'Com trua',
      category: 'An uong',
      categoryEmoji: '🍔',
      imageUrl:
          'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=800&q=80',
      amount: 120000,
      aiMessage: 'Hom nay an uong da can doi, good job!',
      aiPositive: true,
      isOwner: false,
    ),
  ];

  static const galleryItems = [
    GalleryItem(
      title: 'Ca phe sang',
      category: 'An uong',
      categoryEmoji: '🍔',
      date: '28 thg 3',
      imageUrl:
          'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=600&q=80',
      amount: 45000,
    ),
    GalleryItem(
      title: 'Ao moi',
      category: 'Mua sam',
      categoryEmoji: '🛍️',
      date: '27 thg 3',
      imageUrl:
          'https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&w=600&q=80',
      amount: 250000,
    ),
    GalleryItem(
      title: 'Com trua',
      category: 'An uong',
      categoryEmoji: '🍔',
      date: '27 thg 3',
      imageUrl:
          'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=600&q=80',
      amount: 120000,
    ),
    GalleryItem(
      title: 'Xem phim',
      category: 'Giai tri',
      categoryEmoji: '🎬',
      date: '26 thg 3',
      imageUrl:
          'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?auto=format&fit=crop&w=600&q=80',
      amount: 150000,
    ),
    GalleryItem(
      title: 'Grab ve nha',
      category: 'Di chuyen',
      categoryEmoji: '🚗',
      date: '26 thg 3',
      imageUrl:
          'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?auto=format&fit=crop&w=600&q=80',
      amount: 60000,
    ),
    GalleryItem(
      title: 'Tra sua',
      category: 'An uong',
      categoryEmoji: '🍔',
      date: '25 thg 3',
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
      label: 'An uong',
      emoji: '🍔',
      percent: 32.4,
      amount: 220000,
      color: 0xFFEF77B9,
    ),
    ReportCategory(
      label: 'Mua sam',
      emoji: '🛍️',
      percent: 36.8,
      amount: 250000,
      color: 0xFFA78BFA,
    ),
    ReportCategory(
      label: 'Di chuyen',
      emoji: '🚗',
      percent: 8.8,
      amount: 60000,
      color: 0xFF60A5FA,
    ),
    ReportCategory(
      label: 'Giai tri',
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
      title: 'Tuan dau tien',
      subtitle: 'Ghi chep 7 ngay lien tuc',
      date: 'Dat duoc: 15 Apr 2026',
      emoji: '🔥',
      achieved: true,
    ),
    StreakAchievement(
      title: 'Hai tuan kien tri',
      subtitle: 'Ghi chep 14 ngay lien tuc',
      date: 'Dat duoc: 22 Apr 2026',
      emoji: '⭐',
      achieved: true,
    ),
    StreakAchievement(
      title: 'Thang hoan hao',
      subtitle: 'Ghi chep 30 ngay lien tuc',
      date: '',
      emoji: '🏆',
      achieved: false,
    ),
    StreakAchievement(
      title: 'Ky luc 100 ngay',
      subtitle: 'Ghi chep 100 ngay lien tuc',
      date: '',
      emoji: '💎',
      achieved: false,
    ),
  ];

  static const calendarEntries = [
    CalendarEntry(
      day: 26,
      imageUrl:
          'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=100&q=80',
      count: 1,
    ),
    CalendarEntry(
      day: 27,
      imageUrl:
          'https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&w=100&q=80',
      count: 1,
    ),
    CalendarEntry(
      day: 28,
      imageUrl:
          'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=100&q=80',
      count: 2,
    ),
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
