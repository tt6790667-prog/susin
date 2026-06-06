import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pds_data.dart';

class PdsSizingPage extends StatefulWidget {
  const PdsSizingPage({super.key});

  @override
  State<PdsSizingPage> createState() => _PdsSizingPageState();
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

class _PdsSizingPageState extends State<PdsSizingPage> with SingleTickerProviderStateMixin {
  String _model = 'PD-050';
  double _pressure = 4.2;
  String _type = 'PD'; // PD (Double Acting) or PS (Spring Return)
  double _valveTorque = 0;
  late TabController _resultsTabController;

  final List<String> _pdModels = pdModels.keys.toList();
  final List<String> _psModels = psSpringCloseData.keys.toList();

  @override
  void initState() {
    super.initState();
    _resultsTabController = TabController(length: 2, vsync: this);
    _model = _pdModels.first;
  }

  @override
  void dispose() {
    _resultsTabController.dispose();
    super.dispose();
  }

  void _recalculateBestModel() {
    if (_valveTorque <= 0) {
      setState(() {
        _model = _type == 'PD' ? _pdModels.first : _psModels.first;
      });
      return;
    }

    String? bestModel;
    double bestSf = 9999;
    double targetSf = _type == 'PD' ? 1.25 : 1.5;

    final modelsList = _type == 'PD' ? _pdModels : _psModels;

    if (_type == 'PD') {
      for (var m in modelsList) {
        final data = pdModels[m];
        if (data != null) {
          double runTorque = interpolatePDS(data['45']!, _pressure);
          double sf = runTorque / _valveTorque;
          if (sf >= targetSf && sf < bestSf) {
            bestSf = sf;
            bestModel = m;
          }
        }
      }
    } else {
      for (var m in modelsList) {
        final data = psSpringCloseData[m];
        if (data != null) {
          List<double> torques = interpolatePS(data, _pressure);
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
    }

    setState(() {
      if (bestModel != null) {
        _model = bestModel;
      } else {
        _model = modelsList.last;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isPD = _type == 'PD';
    List<String> models = isPD ? _pdModels : _psModels;

    if (!models.contains(_model) && models.isNotEmpty) {
      _model = models.first;
    }

    // Calculate dynamic values
    double t0 = 0, t45 = 0, t90 = 0;
    if (isPD) {
      final data = pdModels[_model];
      if (data != null) {
        t0 = interpolatePDS(data['0']!, _pressure);
        t45 = interpolatePDS(data['45']!, _pressure);
        t90 = interpolatePDS(data['90']!, _pressure);
      }
    } else {
      final data = psSpringCloseData[_model];
      if (data != null) {
        List<double> torques = interpolatePS(data, _pressure);
        t0 = torques[0]; // Air Start / Spring End
        t45 = torques[1]; // Air End / Spring Start
        t90 = torques[2]; // Mid Torque
      }
    }

    double runTorque;
    if (isPD) {
      runTorque = t45;
    } else {
      double minT = t0;
      if (t45 < minT) minT = t45;
      if (t90 < minT) minT = t90;
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
          "PDS Torque Hub",
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
              // Beautiful Pill Selector for Actuator Type
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
                        min: isPD ? 2.8 : 4.2,
                        max: isPD ? 8.0 : 7.0,
                        divisions: isPD ? 52 : 28,
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
                      "$_type-$_model",
                      style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18, color: const Color(0xFFB71C1C)),
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
                height: 320,
                child: TabBarView(
                  controller: _resultsTabController,
                  children: [
                    // Tab 1: Torque Distribution (Bars)
                    _buildBarsView(t0, t45, t90, isPD),
                    // Tab 2: Sizing Profile (Donut)
                    _buildDonutView(t0, t45, t90),
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
                _type = 'PD';
                if (_pressure < 2.8) _pressure = 2.8;
                _recalculateBestModel();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _type == 'PD' ? const Color(0xFFB71C1C) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  "Double Acting (PD)",
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: _type == 'PD' ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                _type = 'PS';
                if (_pressure < 4.2) _pressure = 4.2;
                _recalculateBestModel();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _type == 'PS' ? const Color(0xFFB71C1C) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  "Spring Return (PS)",
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: _type == 'PS' ? Colors.white : const Color(0xFF64748B),
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
  Widget _buildBarsView(double t0, double t45, double t90, bool isPD) {
    double maxTorque = [t0, t45, t90].reduce((curr, next) => curr > next ? curr : next);
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
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTorqueProgressBar(
            "Start Torque (0°)",
            "${t0.toStringAsFixed(1)} Nm",
            t0 / maxTorque,
            const Color(0xFFFF7A45), // Orange
          ),
          _buildTorqueProgressBar(
            isPD ? "Run Torque (45°)" : "Mid Torque (35°)",
            "${t45.toStringAsFixed(1)} Nm",
            t45 / maxTorque,
            const Color(0xFF36CFC9), // Teal
          ),
          _buildTorqueProgressBar(
            "End Torque (90°)",
            "${t90.toStringAsFixed(1)} Nm",
            t90 / maxTorque,
            const Color(0xFF9254DE), // Purple
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
  Widget _buildDonutView(double t0, double t45, double t90) {
    double total = t0 + t45 + t90;
    String p0 = total > 0 ? "${((t0 / total) * 100).toStringAsFixed(0)}%" : "0%";
    String p45 = total > 0 ? "${((t45 / total) * 100).toStringAsFixed(0)}%" : "0%";
    String p90 = total > 0 ? "${((t90 / total) * 100).toStringAsFixed(0)}%" : "0%";

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Row(
        children: [
          // Donut Custom Painter
          Expanded(
            flex: 4,
            child: AspectRatio(
              aspectRatio: 1,
              child: CustomPaint(
                painter: _SizingDonutChartPainter(t0: t0, t45: t45, t90: t90),
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
                _buildLegendItem("Start Torque", "${t0.toStringAsFixed(0)} Nm", p0, const Color(0xFFFF7A45)),
                const SizedBox(height: 16),
                _buildLegendItem("Mid/Run Torque", "${t45.toStringAsFixed(0)} Nm", p45, const Color(0xFF36CFC9)),
                const SizedBox(height: 16),
                _buildLegendItem("End Torque", "${t90.toStringAsFixed(0)} Nm", p90, const Color(0xFF9254DE)),
              ],
            ),
          ),
        ],
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
    bool isPD = _type == 'PD';
    double greenThreshold = isPD ? 1.25 : 1.5;
    double yellowThreshold = isPD ? 1.1 : 1.2;

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
