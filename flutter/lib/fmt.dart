/// 数值与时间格式化（中文）。
library;

class Fmt {
  static String usd(double v) {
    if (v >= 1000) return '\$${v.toStringAsFixed(0)}';
    if (v >= 100) return '\$${v.toStringAsFixed(1)}';
    return '\$${v.toStringAsFixed(2)}';
  }

  static String tokens(int n) {
    final v = n.toDouble();
    if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(2)}B';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
    return '$n';
  }

  static String percent(double v) => '${v.round()}%';

  static String days(double v) => '${v.toStringAsFixed(1)} 天';

  static String relative(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    return '${(diff.inDays / 30).floor()}个月前';
  }

  static String countdown(DateTime date) {
    final s = date.difference(DateTime.now()).inSeconds;
    if (s <= 0) return '已到重置时间';
    final minutes = s ~/ 60;
    if (minutes < 60) return '$minutes分钟后重置';
    final hours = minutes ~/ 60;
    if (hours < 24) return '$hours小时${minutes % 60}分后重置';
    return '${hours ~/ 24}天${hours % 24}小时后重置';
  }

  static String dateTime(DateTime d) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${d.year}/${p(d.month)}/${p(d.day)} ${p(d.hour)}:${p(d.minute)}';
  }

  static String shortDay(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return key;
    return '${int.parse(parts[1])}/${int.parse(parts[2])}';
  }
}
