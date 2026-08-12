import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'theme.dart';

// ---------- Khung màn hình ----------
class Screen extends StatelessWidget {
  final Widget child;
  final PreferredSizeWidget? bar;
  final Widget? nav;
  const Screen({super.key, required this.child, this.bar, this.nav});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg(context),
      appBar: bar,
      bottomNavigationBar: nav,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: child,
        ),
      ),
    );
  }
}

// ---------- Thanh tiêu đề ----------
PreferredSizeWidget topBar(BuildContext context, String title,
    {Widget? left, List<Widget>? right}) {
  return AppBar(
    backgroundColor: C.surface(context),
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    centerTitle: true,
    leading: left,
    title: Text(title, style: T.title(context)),
    actions: right,
    shape: Border(bottom: BorderSide(color: C.line(context))),
  );
}

// ---------- Nút ----------
enum Tone { brand, danger, ghost, soft }

class AppButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Tone tone;
  final bool full;
  final bool enabled;
  final double height;
  final EdgeInsets? padding;
  const AppButton(this.label,
      {super.key, this.icon, this.onTap, this.tone = Tone.brand, this.full = true, this.enabled = true, this.height = 52, this.padding});

  @override
  Widget build(BuildContext context) {
    late Color bg, fg;
    switch (tone) {
      case Tone.brand:
        bg = C.brand(context);
        fg = Colors.white;
        break;
      case Tone.danger:
        bg = C.danger(context);
        fg = Colors.white;
        break;
      case Tone.soft:
        bg = C.brandBg(context);
        fg = C.brand(context);
        break;
      case Tone.ghost:
        bg = Colors.transparent;
        fg = C.brand(context);
        break;
    }
    if (!enabled) {
      bg = Colors.grey.shade300;
      fg = Colors.grey.shade500;
    }

    return SizedBox(
      width: full ? double.infinity : null,
      height: height,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onTap : null,
          child: Container(
            alignment: Alignment.center,
            decoration: (tone == Tone.ghost && enabled)
                ? BoxDecoration(
                    border: Border.all(color: C.line(context)),
                    borderRadius: BorderRadius.circular(12))
                : null,
            padding: padding ?? const EdgeInsets.symmetric(horizontal: S.x5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 19, color: fg), const SizedBox(width: S.x2)],
                Flexible(
                  child: Text(
                    label,
                    style: T.label(context, fg).copyWith(fontSize: height >= 56 ? 16 : 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- Thẻ ----------
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? color;
  const AppCard({super.key, required this.child, this.padding, this.margin, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(S.x4),
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? C.surface(context),
        border: color == null ? Border.all(color: C.line(context)) : null,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

// ---------- Nhập liệu ----------
class AppInput extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType keyboardType;
  const AppInput({super.key, required this.label, this.hint, this.controller, this.obscureText = false, this.keyboardType = TextInputType.text});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: T.small(context).copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: C.surface(context), border: Border.all(color: C.line(context)), borderRadius: BorderRadius.circular(12)),
        child: TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: T.body(context),
          decoration: InputDecoration(hintText: hint, border: InputBorder.none, hintStyle: T.small(context)),
        ),
      ),
    ]);
  }
}

// ---------- Nhãn trạng thái nhỏ (pill) ----------
class StatusTag extends StatelessWidget {
  final String text;
  final Color fg, bg;
  const StatusTag(this.text, {super.key, required this.fg, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: T.caption(context, fg).copyWith(fontWeight: FontWeight.w600, fontSize: 11)),
    );
  }
}

// ---------- Khối trạng thái lớn (phương án C) ----------
class HeroStatus extends StatelessWidget {
  final double cm, warnAt, dangerAt;
  final bool isWet;
  const HeroStatus({super.key, required this.cm, this.warnAt = 20, this.dangerAt = 35, this.isWet = true});

  @override
  Widget build(BuildContext context) {
    if (!isWet) {
      return Container(
        padding: const EdgeInsets.all(S.x5),
        decoration: BoxDecoration(
          color: Colors.grey.shade50, 
          borderRadius: BorderRadius.circular(20), 
          border: Border.all(color: Colors.grey.shade200)
        ),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('CHẾ ĐỘ CHỜ', style: T.label(context, Colors.grey).copyWith(letterSpacing: 1.2)),
            const Icon(Icons.watch_later_outlined, color: Colors.grey, size: 22),
          ]),
          const SizedBox(height: 24),
          const Icon(Icons.waves, size: 48, color: Colors.blueGrey),
          const SizedBox(height: 16),
          Text('Không phát hiện nước', style: T.title(context).copyWith(color: Colors.blueGrey)),
          const SizedBox(height: 4),
          Text('Hệ thống đang giám sát và sẽ đo khi có nước', style: T.caption(context)),
        ]),
      );
    }

    final lv = levelOf(cm, warnAt, dangerAt);
    final color = C.of(context, lv);
    final bg = C.bgOf(context, lv);
    final String label = lv == Level.safe ? 'AN TOÀN' : (lv == Level.warn ? 'CẢNH BÁO' : 'NGUY HIỂM');

    return Container(
      padding: const EdgeInsets.all(S.x5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: T.label(context, color).copyWith(letterSpacing: 1.2)),
          Icon(lv == Level.safe ? Icons.check_circle : Icons.warning_rounded, color: color, size: 22),
        ]),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(cm.toStringAsFixed(0), style: T.big(context, color)),
          const SizedBox(width: 8),
          Text('cm', style: T.mono(context, color.withValues(alpha: 0.6))),
        ]),
        const SizedBox(height: 8),
        Text('Mực nước hiện tại so với gầm xe', style: T.caption(context, color.withValues(alpha: 0.8))),
      ]),
    );
  }
}

// ---------- Mục danh sách ----------
class RowItem extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  final Color iconColor, iconBg;
  final VoidCallback? onTap;
  final Widget? trailing;
  const RowItem({super.key, required this.icon, required this.title, required this.sub, required this.iconColor, required this.iconBg, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(border: Border.all(color: C.line(context)), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 19, color: iconColor),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: T.body(context).copyWith(fontWeight: FontWeight.w500)),
                Text(sub, style: T.caption(context)),
              ]),
            ),
            trailing ?? Icon(Icons.chevron_right, size: 18, color: C.muted(context)),
          ]),
        ),
      ),
    );
  }
}

// ---------- Dải cảnh báo ----------
class AlertBanner extends StatelessWidget {
  final Level level;
  final IconData icon;
  final String text;
  const AlertBanner({super.key, this.level = Level.warn, this.icon = Icons.warning_amber_rounded, required this.text});

  @override
  Widget build(BuildContext context) {
    final color = C.of(context, level);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(color: C.bgOf(context, level), borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 9),
        Expanded(child: Text(text, style: T.body(context, color).copyWith(fontSize: 13))),
      ]),
    );
  }
}

// ---------- Biểu đồ cột 24h ----------
class MiniChart extends StatelessWidget {
  final List<double> values; // 0..1
  final List<Level> levels;
  const MiniChart({super.key, required this.values, required this.levels});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (i) {
          final color = C.bgOf(context, levels[i]) == C.safeBg(context) && levels[i] == Level.safe
              ? (values[i] > 0.4 ? C.safe(context) : C.safeBg(context))
              : C.of(context, levels[i]);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: FractionallySizedBox(
                heightFactor: values[i].clamp(0.05, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ---------- Shimmer (Loading) ----------
class ShimmerBox extends StatelessWidget {
  final double width, height, radius;
  const ShimmerBox({super.key, this.width = double.infinity, required this.height, this.radius = 12});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width, height: height,
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(radius)),
    ).animate(onPlay: (c) => c.repeat()).shimmer(duration: const Duration(milliseconds: 1200), color: Colors.white.withValues(alpha: 0.5));
  }
}

// ---------- Thanh điều hướng dưới (thứ tự: Xe của tôi · Bản đồ · SOS · Bảo hiểm · Cá nhân) ----------
class AppBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const AppBottomNav({super.key, required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: index,
      onDestinationSelected: onChanged,
      backgroundColor: C.surface(context),
      surfaceTintColor: Colors.transparent,
      indicatorColor: C.brandBg(context),
      height: 66,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.directions_car_outlined), selectedIcon: Icon(Icons.directions_car), label: 'Xe của tôi'),
        NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Bản đồ'),
        NavigationDestination(icon: Icon(Icons.sos_outlined), selectedIcon: Icon(Icons.sos), label: 'SOS'),
        NavigationDestination(icon: Icon(Icons.verified_user_outlined), selectedIcon: Icon(Icons.verified_user), label: 'Bảo hiểm'),
        NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Cá nhân'),
      ],
    );
  }
}

// ---------- Icon Loại xe Silhouette ----------
class VehicleIcon extends StatelessWidget {
  final String? type;
  final double width, height;
  final Color? color;
  const VehicleIcon({super.key, this.type, this.width = 80, this.height = 48, this.color});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    final t = (type ?? 'Sedan').toLowerCase();
    
    if (t.contains('suv')) {
      icon = Icons.directions_car_filled;
    } else if (t.contains('hatchback')) {
      icon = Icons.time_to_leave;
    } else if (t.contains('bán tải') || t.contains('pickup')) {
      icon = Icons.airport_shuttle;
    } else if (t.contains('van') || t.contains('mpv')) {
      icon = Icons.airport_shuttle;
    } else if (t.contains('điện')) {
      icon = Icons.electric_car;
    } else if (t.contains('coupe')) {
      icon = Icons.directions_car;
    } else {
      icon = Icons.directions_car;
    }

    return Container(
      width: width, height: height,
      decoration: BoxDecoration(
        color: C.brandBg(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color ?? C.brand(context), size: height * 0.6),
    );
  }
}
