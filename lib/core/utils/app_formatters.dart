import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

abstract class Fmt {
  static final _currency = NumberFormat('#,##0.00', 'en_US');
  static final _int = NumberFormat('#,##0', 'en_US');
  static final _date = DateFormat('dd MMM yyyy');
  static final _dateTime = DateFormat('dd MMM yyyy, hh:mm a');
  static final _fileDate = DateFormat('yyyyMMdd_HHmmss');

  static String currency(num v) =>
      '${AppConstants.currency} ${_currency.format(v)}';
  static String qty(num v) => _int.format(v);
  static String date(DateTime d) => _date.format(d);
  static String dateTime(DateTime d) => _dateTime.format(d);
  static String fileDate(DateTime d) => _fileDate.format(d);

  static String backupTimestamp(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$y$m${d}_$hh$mm$ss';
  }
}
