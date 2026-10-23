import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const DataRadarApp());
}

class DataRadarApp extends StatelessWidget {
  const DataRadarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'رادار بيانات الهاتف',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0EA5E9),
          secondary: Color(0xFF10B981),
        ),
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: const DataMonitorHomeScreen(),
    );
  }
}

class DataMonitorHomeScreen extends StatefulWidget {
  const DataMonitorHomeScreen({super.key});

  @override
  State<DataMonitorHomeScreen> createState() => _DataMonitorHomeScreenState();
}

class _DataMonitorHomeScreenState extends State<DataMonitorHomeScreen> {
  static const platform = MethodChannel('com.example.dataradar/usage');

  bool _hasPermission = false;
  bool _loading = true;
  String _selectedPeriod = 'daily';
  String _selectedNetwork = 'all';
  List<Map<String, dynamic>> _appsUsage = [];

  @override
  void initState() {
    super.initState();
    _checkPermissionAndLoad();
  }

  Future<void> _checkPermissionAndLoad() async {
    setState(() => _loading = true);
    try {
      final bool granted = await platform.invokeMethod('hasUsagePermission');
      _hasPermission = granted;
      if (granted) {
        await _fetchSystemUsage();
      }
    } catch (e) {
      _hasPermission = false;
    }
    setState(() => _loading = false);
  }

  Future<void> _fetchSystemUsage() async {
    setState(() => _loading = true);
    try {
      final List<dynamic> result = await platform.invokeMethod('getRealDataUsage', {
        'period': _selectedPeriod,
        'network': _selectedNetwork,
      });
      _appsUsage = result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      _appsUsage = [];
    }
    setState(() => _loading = false);
  }

  Future<void> _requestUsagePermission() async {
    await platform.invokeMethod('openUsageSettings');
  }

  String _formatSize(double mb) {
    if (mb >= 1024) {
      return '${(mb / 1024).toStringAsFixed(2)} GB';
    }
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    double totalDown = 0;
    double totalUp = 0;
    double totalBg = 0;
    for (final app in _appsUsage) {
      totalDown += (app['downloadMB'] as num?)?.toDouble() ?? 0;
      totalUp += (app['uploadMB'] as num?)?.toDouble() ?? 0;
      totalBg += (app['backgroundMB'] as num?)?.toDouble() ?? 0;
    }
    final double grandTotal = totalDown + totalUp;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('رادار بيانات الهاتف (قراءة النظام)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        actions: [
          IconButton(
            onPressed: _checkPermissionAndLoad,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث القراءات',
          ),
        ],
      ),
      body: !_hasPermission
          ? _buildPermissionCard()
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _fetchSystemUsage,
                  child: ListView(
                    padding: const EdgeInsets.all(14),
                    children: [
                      _buildFiltersRow(),
                      const SizedBox(height: 12),
                      _buildSummaryGrid(grandTotal, totalDown, totalUp, totalBg),
                      const SizedBox(height: 14),
                      if (_appsUsage.isNotEmpty) _buildTopConsumerBanner(_appsUsage.first, grandTotal),
                      const SizedBox(height: 14),
                      const Text(
                        'ترتيب التطبيقات حسب الاستهلاك الفعلي:',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ..._appsUsage.map((app) => _buildAppTile(app, grandTotal)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildPermissionCard() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          color: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.security_update_good, size: 56, color: Color(0xFF38BDF8)),
                const SizedBox(height: 14),
                const Text(
                  'مطلوب إذن قراءة بيانات الاستخدام من الهاتف',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'لقراءة حجم التحميل (Download) والرفع (Upload) الحقيقي لكل تطبيق في هاتفك، اضغط الزر بالأسفل وفعّل خيار (السماح بالوصول إلى بيانات الاستخدام) لتطبيق رادار البيانات.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: _requestUsagePermission,
                  icon: const Icon(Icons.settings),
                  label: const Text('فتح إعدادات الصلاحية الآن'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _checkPermissionAndLoad,
                  child: const Text('لقد منحت الصلاحية، تحديث الآن'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFiltersRow() {
    return Row(
      children: [
        Expanded(
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'daily', label: Text('اليومي')),
              ButtonSegment(value: 'weekly', label: Text('الأسبوعي')),
              ButtonSegment(value: 'monthly', label: Text('الشهري')),
            ],
            selected: {_selectedPeriod},
            onSelectionChanged: (s) {
              setState(() => _selectedPeriod = s.first);
              _fetchSystemUsage();
            },
          ),
        ),
        const SizedBox(width: 10),
        DropdownButton<String>(
          value: _selectedNetwork,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('كل الشبكات')),
            DropdownMenuItem(value: 'mobile', child: Text('بيانات الهاتف')),
            DropdownMenuItem(value: 'wifi', child: Text('واي فاي')),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedNetwork = val);
              _fetchSystemUsage();
            }
          },
        ),
      ],
    );
  }

  Widget _buildSummaryGrid(double total, double down, double up, double bg) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.9,
      children: [
        _metricCard('الإجمالي الكلي', _formatSize(total), const Color(0xFF38BDF8)),
        _metricCard('التحميل (Download ↓)', _formatSize(down), const Color(0xFF10B981)),
        _metricCard('الرفع (Upload ↑)', _formatSize(up), const Color(0xFF818CF8)),
        _metricCard('استهلاك الخلفية', _formatSize(bg), const Color(0xFFF59E0B)),
      ],
    );
  }

  Widget _metricCard(String title, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border(top: BorderSide(color: accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: accent)),
        ],
      ),
    );
  }

  Widget _buildTopConsumerBanner(Map<String, dynamic> topApp, double grandTotal) {
    final double total = (topApp['totalMB'] as num).toDouble();
    final int pct = grandTotal > 0 ? ((total / grandTotal) * 100).round() : 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF4C0519),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الأكثر استهلاكاً: ${topApp['appName']} ($pct%)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                ),
                Text(
                  'استهلك ${_formatSize(total)} (تحميل: ${_formatSize((topApp['downloadMB'] as num).toDouble())} | رفع: ${_formatSize((topApp['uploadMB'] as num).toDouble())})',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppTile(Map<String, dynamic> app, double grandTotal) {
    final double total = (app['totalMB'] as num).toDouble();
    final double down = (app['downloadMB'] as num).toDouble();
    final double up = (app['uploadMB'] as num).toDouble();
    final double bg = (app['backgroundMB'] as num).toDouble();
    final double ratio = grandTotal > 0 ? (total / grandTotal).clamp(0.0, 1.0) : 0.0;

    return Card(
      color: const Color(0xFF1E293B),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    app['appName'].toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Text(
                  '${_formatSize(total)} (${(ratio * 100).round()}%)',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: ratio,
              backgroundColor: Colors.white12,
              color: ratio > 0.25 ? Colors.redAccent : const Color(0xFF0EA5E9),
              minHeight: 6,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('تحميل ↓: ${_formatSize(down)}', style: const TextStyle(fontSize: 12, color: Color(0xFF10B981))),
                Text('رفع ↑: ${_formatSize(up)}', style: const TextStyle(fontSize: 12, color: Color(0xFF818CF8))),
                Text('بالخلفية: ${_formatSize(bg)}', style: const TextStyle(fontSize: 12, color: Color(0xFFF59E0B))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
