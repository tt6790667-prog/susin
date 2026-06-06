import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'hd_data.dart';

class HdSizingPage extends StatefulWidget {
  const HdSizingPage({super.key});

  @override
  State<HdSizingPage> createState() => _HdSizingPageState();
}

class _SizingDonutChartPainter extends CustomPainter {
  final double t0;
  final double t45;
  final double t90;

  _SizingDonutChartPainter({required this.t0, required this.t45, required this.t90});

  @override
  void paint(Canvas canvas, Size size) {
    final double total = t0 + t45 + t90;
    if (total == 0) return;

    const double startAngle = -3.14159 / 2; // start from top (-90 degrees)
    final double sweep0 = (t0 / total) * 2 * 3.14159;
    final double sweep45 = (t45 / total) * 2 * 3.14159;
    final double sweep90 = (t90 / total) * 2 * 3.14159;

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.butt;

    final Rect rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (size.width - 24) / 2,
    );

    // Slice 1: Start Torque (Orange)
    paint.color = const Color(0xFFFF7A45);
    canvas.drawArc(rect, startAngle, sweep0, false, paint);

    // Slice 2: Mid Torque (Teal)
    paint.color = const Color(0xFF36CFC9);
    canvas.drawArc(rect, startAngle + sweep0, sweep45, false, paint);

    // Slice 3: End Torque (Purple)
    paint.color = const Color(0xFF9254DE);
    canvas.drawArc(rect, startAngle + sweep0 + sweep45, sweep90, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _HdSizingPageState extends State<HdSizingPage> with SingleTickerProviderStateMixin {
  String _model = 'ISD-A1-10';
  double _pressure = 5.5;
  String _type = 'Double Acting'; // Double Acting or Single Acting
  double _valveTorque = 0;
  late TabController _resultsTabController;
  
  // Sub-toggles for Single Acting detailed views
  String _saBarViewType = 'Air'; // Air or Spring
  String _saDonutViewType = 'Air'; // Air or Spring

  final List<String> _daModels = hdDoubleActing.keys.toList();
  final List<String> _saModels = hdSingleActing.keys.toList();

  @override
  void initState() {
    super.initState();
    _resultsTabController = TabController(length: 2, vsync: this);
    _model = _daModels.first;
  }

  @override
  void dispose() {
    _resultsTabController.dispose();
    super.dispose();
  }

  void _recalculateBestModel() {
    if (_valveTorque <= 0) {
      setState(() {
        _model = _type == 'Double Acting' ? _daModels.first : _saModels.first;
      });
      return;
    }

    String? bestModel;
    double bestSf = 9999;
    double targetSf = _type == 'Double Acting' ? 1.25 : 1.5;

    final modelsList = _type == 'Double Acting' ? _daModels : _saModels;

    if (_type == 'Double Acting') {
      for (var m in modelsList) {
        final data = hdDoubleActing[m];
        if (data != null) {
          List<double> torques = interpolateHD(data, _pressure, false);
          double minTorque = torques[0];
          if (torques[1] < minTorque) minTorque = torques[1];
          if (torques[2] < minTorque) minTorque = torques[2];
          double sf = minTorque / _valveTorque;
          if (sf >= targetSf && sf < bestSf) {
            bestSf = sf;
            bestModel = m;
          }
        }
      }
    } else {
      for (var m in modelsList) {
        final data = hdSingleActing[m];
        if (data != null) {
          List<double> airTorques = interpolateHD(data, _pressure, false);
          List<double> springTorques = interpolateHD(data, _pressure, true);
          
          double minTorque = airTorques[0];
          for (var t in airTorques) { if (t < minTorque) minTorque = t; }
          for (var t in springTorques) { if (t < minTorque) minTorque = t; }
          double sf = minTorque / _valveTorque;
          if (sf >= targetSf && sf < bestSf) {
            bestSf = sf;
            bestModel = m;
          }
        }
      }
    }

    setState(() {
      if (bestModel != null) {
        _model = bestModel;
      } else {
        _model = modelsList.last;
      }
    });
  }

  void autoSelectModel() {
    if (_valveTorque <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter Valve Torque first!", style: TextStyle(color: Colors.white)),
          backgroundColor: Color(0xFFB71C1C),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    setState(() {
      _recalculateBestModel();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Auto-Selected $_model", style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDA = _type == 'Double Acting';
    List<String> currentModels = isDA ? _daModels : _saModels;
    
    if (!currentModels.contains(_model) && currentModels.isNotEmpty) {
      _model = currentModels.first;
    }
    
    // Calculate values
    List<double> airTorques = [0, 0, 0];
    List<double> springTorques = [0, 0, 0];
    
    if (isDA) {
      final data = hdDoubleActing[_model];
      if (data != null) airTorques = interpolateHD(data, _pressure, false);
    } else {
      final data = hdSingleActing[_model];
      if (data != null) {
        airTorques = interpolateHD(data, _pressure, false);
        springTorques = interpolateHD(data, _pressure, true);
      }
    }

    double runTorque;
    if (isDA) {
      double minT = airTorques[0];
      if (airTorques[1] < minT) minT = airTorques[1];
      if (airTorques[2] < minT) minT = airTorques[2];
      runTorque = minT;
    } else {
      double minT = airTorques[0];
      for (var t in airTorques) { if (t < minT) minT = t; }
      for (var t in springTorques) { if (t < minT) minT = t; }
      runTorque = minT;
    }
    double safetyFactor = _valveTorque > 0 ? runTorque / _valveTorque : 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 10, bottom: 10),
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: Color(0xFF475569)),
            ),
          ),
        ),
        title: Text(
          "HD Torque Hub",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w900,
            fontSize: 15,
            color: const Color(0xFF1E293B),
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Beautiful Pill Selector for HD Actuator Type
              _buildTypeSelector(),
              const SizedBox(height: 24),

              // Configuration Form Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Valve Torque Input Field
                    Text("VALVE TORQUE REQ (NM)", style: _labelStyle()),
                    const SizedBox(height: 8),
                    TextFormField(
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: const Color(0xFF1E293B)),
                      decoration: InputDecoration(
                        hintText: "Enter required torque (Nm)",
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFB71C1C), width: 1.5),
                        ),
                      ),
                      onChanged: (v) {
                        _valveTorque = double.tryParse(v) ?? 0;
                        _recalculateBestModel();
                      },
                    ),
                    const SizedBox(height: 24),

                    // Air Pressure Slider Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("AIR PRESSURE (BAR)", style: _labelStyle()),
                        Text(
                          "${_pressure.toStringAsFixed(1)} bar",
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFFB71C1C)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFFB71C1C),
                        inactiveTrackColor: const Color(0xFFF1F5F9),
                        thumbColor: const Color(0xFFB71C1C),
                        overlayColor: const Color(0xFFB71C1C).withOpacity(0.1),
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                        trackHeight: 4,
                      ),
                      child: Slider(
                        value: _pressure,
                        min: 3.5,
                        max: 7.0,
                        divisions: 35,
                        onChanged: (v) {
                          _pressure = v;
                          _recalculateBestModel();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Matched Model Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFB71C1C).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFB71C1C).withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "MATCHED ACTUATOR:",
                      style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 12, color: const Color(0xFFB71C1C), letterSpacing: 1.2),
                    ),
                    Text(
                      _model,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 17, color: const Color(0xFFB71C1C)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Segment Selector for Results Tab View
              Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
                ),
                child: TabBar(
                  controller: _resultsTabController,
                  indicatorColor: const Color(0xFFB71C1C),
                  indicatorWeight: 3,
                  labelColor: const Color(0xFF1E293B),
                  unselectedLabelColor: const Color(0xFF94A3B8),
                  labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13),
                  tabs: const [
                    Tab(text: "Torque Distribution"),
                    Tab(text: "Sizing Profile"),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Tab View Contents
              SizedBox(
                height: isDA ? 320 : 380, // Expand slightly for single acting toggles
                child: TabBarView(
                  controller: _resultsTabController,
                  children: [
                    // Tab 1: Torque Distribution (Bars)
                    _buildBarsView(airTorques, springTorques, isDA),
                    // Tab 2: Sizing Profile (Donut)
                    _buildDonutView(airTorques, springTorques, isDA),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Safety Factor Premium Indicator Card
              if (_valveTorque > 0) _buildSafetyFactorCard(safetyFactor),
            ],
          ),
        ),
      ),
    );
  }

  // Actuator Type Selector Pill Widget
  Widget _buildTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                _type = 'Double Acting';
                _recalculateBestModel();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _type == 'Double Acting' ? const Color(0xFFB71C1C) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  "Double Acting",
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: _type == 'Double Acting' ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                _type = 'Single Acting';
                _recalculateBestModel();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _type == 'Single Acting' ? const Color(0xFFB71C1C) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  "Single Acting",
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: _type == 'Single Acting' ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Tab 1 UI: Torque Distribution (Progress Bars Style)
  Widget _buildBarsView(List<double> airTorques, List<double> springTorques, bool isDA) {
    List<double> activeTorques = isDA ? airTorques : (_saBarViewType == 'Air' ? airTorques : springTorques);
    double maxTorque = activeTorques.reduce((curr, next) => curr > next ? curr : next);
    if (maxTorque == 0) maxTorque = 1;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // If Single Acting, show a tiny sub-toggle between Air and Spring
          if (!isDA) ...[
            _buildSubToggle(
              value: _saBarViewType,
              onChanged: (val) => setState(() => _saBarViewType = val),
            ),
            const SizedBox(height: 18),
          ],
          
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTorqueProgressBar(
                  "Start Torque (0°)",
                  "${activeTorques[0].toStringAsFixed(0)} Nm",
                  activeTorques[0] / maxTorque,
                  const Color(0xFFFF7A45), // Orange
                ),
                _buildTorqueProgressBar(
                  "Run Torque (45°)",
                  "${activeTorques[1].toStringAsFixed(0)} Nm",
                  activeTorques[1] / maxTorque,
                  const Color(0xFF36CFC9), // Teal
                ),
                _buildTorqueProgressBar(
                  "End Torque (90°)",
                  "${activeTorques[2].toStringAsFixed(0)} Nm",
                  activeTorques[2] / maxTorque,
                  const Color(0xFF9254DE), // Purple
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper Widget for Progress Bars
  Widget _buildTorqueProgressBar(String label, String value, double percent, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
            Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B))),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 10,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Stack(
              children: [
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: percent.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Tab 2 UI: Sizing Profile (Donut Chart Style)
  Widget _buildDonutView(List<double> airTorques, List<double> springTorques, bool isDA) {
    List<double> activeTorques = isDA ? airTorques : (_saDonutViewType == 'Air' ? airTorques : springTorques);
    double total = activeTorques[0] + activeTorques[1] + activeTorques[2];
    String p0 = total > 0 ? "${((activeTorques[0] / total) * 100).toStringAsFixed(0)}%" : "0%";
    String p45 = total > 0 ? "${((activeTorques[1] / total) * 100).toStringAsFixed(0)}%" : "0%";
    String p90 = total > 0 ? "${((activeTorques[2] / total) * 100).toStringAsFixed(0)}%" : "0%";

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sub-toggle for Single Acting in Donut View
          if (!isDA) ...[
            _buildSubToggle(
              value: _saDonutViewType,
              onChanged: (val) => setState(() => _saDonutViewType = val),
            ),
            const SizedBox(height: 18),
          ],
          
          Expanded(
            child: Row(
              children: [
                // Donut Custom Painter
                Expanded(
                  flex: 4,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: CustomPaint(
                      painter: _SizingDonutChartPainter(
                        t0: activeTorques[0],
                        t45: activeTorques[1],
                        t90: activeTorques[2],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                
                // Legend View on the right
                Expanded(
                  flex: 5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLegendItem("Start Torque", "${activeTorques[0].toStringAsFixed(0)} Nm", p0, const Color(0xFFFF7A45)),
                      const SizedBox(height: 16),
                      _buildLegendItem("Mid/Run Torque", "${activeTorques[1].toStringAsFixed(0)} Nm", p45, const Color(0xFF36CFC9)),
                      const SizedBox(height: 16),
                      _buildLegendItem("End Torque", "${activeTorques[2].toStringAsFixed(0)} Nm", p90, const Color(0xFF9254DE)),
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

  // Mini Sub-Toggle for Air vs Spring
  Widget _buildSubToggle({required String value, required ValueChanged<String> onChanged}) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSubToggleItem("Air Torque", value == 'Air', () => onChanged('Air')),
          _buildSubToggleItem("Spring Torque", value == 'Spring', () => onChanged('Spring')),
        ],
      ),
    );
  }

  Widget _buildSubToggleItem(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFB71C1C) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 10,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  // Helper Widget for Legend items
  Widget _buildLegendItem(String label, String value, String percent, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: const Color(0xFF1E293B))),
              Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 10, color: const Color(0xFF64748B))),
            ],
          ),
        ),
        Text(percent, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12, color: const Color(0xFF475569))),
      ],
    );
  }

  // Safety Factor Card
  Widget _buildSafetyFactorCard(double safetyFactor) {
    bool isDA = _type == 'Double Acting';
    double greenThreshold = isDA ? 1.25 : 1.5;
    double yellowThreshold = isDA ? 1.1 : 1.2;

    Color cardBg = safetyFactor >= greenThreshold 
        ? const Color(0xFFE2F0D9) 
        : (safetyFactor >= yellowThreshold ? const Color(0xFFFFF2CC) : const Color(0xFFFCE4D6));
    Color borderCol = safetyFactor >= greenThreshold 
        ? const Color(0xFFA9D08E) 
        : (safetyFactor >= yellowThreshold ? const Color(0xFFFFD966) : const Color(0xFFF4B084));
    Color textCol = safetyFactor >= greenThreshold 
        ? const Color(0xFF385723) 
        : (safetyFactor >= yellowThreshold ? const Color(0xFF7F6000) : const Color(0xFFC65911));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "SAFETY FACTOR",
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: textCol, letterSpacing: 1.2),
              ),
              const SizedBox(height: 4),
              Text(
                safetyFactor >= greenThreshold 
                    ? "OPTIMIZED SIZING" 
                    : (safetyFactor >= yellowThreshold ? "MARGINAL WARNING" : "UNDERSIZED DANGER"),
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: textCol),
              ),
            ],
          ),
          Text(
            safetyFactor.toStringAsFixed(2),
            style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: textCol),
          ),
        ],
      ),
    );
  }

  TextStyle _labelStyle() => const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B));
}
