# Orbit Breaker

یک بازی آرکید دوبعدی تک‌لمسی با Flutter و Flame. بازیکن با هر لمس جهت گردش گوی را عوض می‌کند، از موانع نئونی جاخالی می‌دهد و کریستال جمع می‌کند.

## حلقه گیم‌پلی

- کنترل تک‌لمسی و قابل یادگیری در چند ثانیه
- سختی افزایشی بر اساس مدت زنده ماندن
- امتیاز برای زمان، کریستال و near-miss
- سپر پاداش پس از جمع‌کردن ۵ کریستال
- رکورد و موجودی دائمی روی دستگاه
- سه اسکین با سیستم unlock برای ایجاد هدف بلندمدت
- بازخورد لرزشی، صدا، pause و مدیریت lifecycle اندروید

## اجرا

```powershell
flutter pub get
flutter run
```

برای اجرای بررسی‌ها:

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

## ساختار

- `lib/game/orbit_breaker_game.dart`: حلقه Flame، ورودی، برخورد و رندر
- `lib/game/game_store.dart`: رکورد، کریستال، اسکین و تنظیمات
- `lib/game/run_rules.dart`: فرمول امتیاز و منحنی سختی قابل تست
- `lib/ui/game_overlays.dart`: منو، HUD، pause و game over
- `docs/RELEASE_CHECKLIST.md`: مراحل لازم پیش از انتشار تجاری

این نسخه بدون asset خارجی ساخته شده است؛ تمام گرافیک بازی با Canvas رندر می‌شود و مشکل مجوز تصویر یا sprite ندارد.
